// deno bundle --config mono/browser/tsconfig.json mono/browser/mono.ts mono/browser/mono.js
import { p, el_by_path, assert, build_el, flash, send, Log, find_all, find_one, arrays_equal,
  sleep, set_favicon, set_window_location, set_window_title, svg_to_base64_data_url,
  get_window_location } from "./helpers.js"

// Types -------------------------------------------------------------------------------------------
// In events
type SpecialInputKeys = 'alt' | 'ctrl' | 'meta' | 'shift'
interface ClickEvent   { special_keys: SpecialInputKeys[] }
interface KeydownEvent { key: string, special_keys: SpecialInputKeys[] }
interface ChangeEvent  { stub: string }
interface BlurEvent    { stub: string }
interface InputEvent   { value: string }

type InEvent =
  { kind: 'location', el: number[], location: string } | // el not needed for location but Nim requires it.
  { kind: 'click',    el: number[], click:    ClickEvent } |
  { kind: 'dblclick', el: number[], dblclick: ClickEvent } |
  { kind: 'keydown',  el: number[], keydown:  KeydownEvent } |
  { kind: 'change',   el: number[], change:   ChangeEvent } |
  { kind: 'blur',     el: number[], blur:     BlurEvent } |
  { kind: 'input',    el: number[], input:    InputEvent }

type OutEvent =
  { kind: 'eval',   code: string } |
  { kind: 'update', diffs: Diff[] } |
  { kind: 'ignore' } |
  { kind: 'expired' } |
  { kind: 'error', message: string }

type InEventEnvelope =
  { kind: 'events', mono_id: string, events: InEvent[] } |
  { kind: 'pull', mono_id: string }

// Diff
type SafeHtml = string
type ElAttrKind = "string_prop" | "string_attr" | "bool_prop"
type ElAttrVal = [string, ElAttrKind] | string
type ElAttrDel = [string, ElAttrKind] | string

type Diff = any[]

interface ApplyDiff {
  replace(id: number[], html: SafeHtml): void
  add_children(id: number[], els: SafeHtml[]): void
  set_children_len(id: number[], len: number): void
  set_attrs(id: number[], attrs: Record<string, ElAttrVal>): void
  del_attrs(id: number[], attrs: ElAttrDel[]): void
  set_text(id: number[], text: string): void
  set_html(id: number[], html: SafeHtml): void
}

// run ---------------------------------------------------------------------------------------------
function get_main_mono_root(): { mono_id: string, mono_root: HTMLElement } {
  // Theoretically, mono supports multiple mono_root elements on the page, but currently only one
  // supported.
  let mono_roots = find_all('[mono_id]')
  if (mono_roots.length < 1) throw new Error("mono_id not found")
  if (mono_roots.length > 1) throw new Error("multiple mono_id not supported yet")
  let mono_root = mono_roots[0]
  let mono_id = mono_root.getAttribute("mono_id")
  if (!mono_id) throw new Error("mono_id can't be empty")
  return { mono_id, mono_root }
}

export function run() {
  listen_to_dom_events()

  let { mono_id, mono_root } = get_main_mono_root()

  let window_location = mono_root.getAttribute("window_location")
  if (window_location) set_window_location(window_location)

  set_window_icon(mono_id)

  pull(mono_id)
}

async function pull(mono_id: string): Promise<void> {
  let log = Log("mono")
  log.info("started")
  main_loop: while (true) {
    let res: OutEvent | OutEvent[]
    let last_call_was_retry = false
    try {
      res = await send<InEventEnvelope, OutEvent | OutEvent[]>(
        "post", location.href, { kind: "pull", mono_id }, -1
      )
      if (last_call_was_retry) set_window_icon(mono_id)
      last_call_was_retry = false
    } catch {
      last_call_was_retry = true
      set_window_icon_disabled(mono_id)
      if (!last_call_was_retry) log.warn("retrying...")
      await sleep(1000)
      continue
    }
    let events: OutEvent[] = Array.isArray(res) ? res : [res]
    for (let event of events) {
      switch (event.kind) {
        case 'eval':
          log.info("<<", event)
          eval("'use strict'; " + event.code)
          break
        case 'update':
          log.info("<<", event)
          let root = get_mono_root(mono_id)
          update(root, event.diffs)
          break
        case 'ignore':
          break
        case 'expired':
          set_window_icon_disabled(mono_id)
          log.info("expired")
          break main_loop
        case 'error':
          log.error(event.message)
          throw new Error(event.message)
      }
    }
  }
}

// events ------------------------------------------------------------------------------------------
function listen_to_dom_events() {
  let changed_inputs: { [k: string]: InEvent } = {} // Keeping track of changed inputs

  // Watching back and forward buttons
  window.addEventListener('popstate', function(event) {
    let { mono_root, mono_id } = get_main_mono_root()
    mono_root.setAttribute("skip_flash", "true") // Skipping flash on redirect, it's annoying
    post_event(mono_id, { kind: 'location', location: get_window_location(), el: [] })
  })

  async function on_click(raw_event: MouseEvent) {
    let el = raw_event.target as HTMLElement, location = "" + (el as any).href
    if (location == get_window_location()) return
    if (el.tagName.toLowerCase() == "a" && location != "") {
      // Click with redirect
      let found = find_el_with_listener(el)
      if (!found) return
      raw_event.preventDefault()
      history.pushState({}, "", location)

      get_mono_root(found.mono_id).setAttribute("skip_flash", "true") // Skipping flash on redirect, it's annoying
      await post_event(found.mono_id, { kind: 'location', location, el: [] })
    } else {
      // Click without redirect
      let found = find_el_with_listener(el, "on_click")
      if (!found) return
      raw_event.preventDefault()
      await post_event(found.mono_id, { kind: 'click', el: found.path,
        click: { special_keys: get_keys(raw_event) }
      })
    }
  }
  document.body.addEventListener("click", on_click)

  async function on_dblclick(raw_event: MouseEvent) {
    let found = find_el_with_listener(raw_event.target as HTMLElement, "on_dblclick")
    if (!found) return
    post_event(found.mono_id, { kind: 'dblclick', el: found.path,
      dblclick: { special_keys: get_keys(raw_event) }
    })
  }
  document.body.addEventListener("dblclick", on_dblclick)

  async function on_keydown(raw_event: KeyboardEvent) {
    let keydown: KeydownEvent = { key: raw_event.key, special_keys: get_keys(raw_event) }
    // Ignoring some events
    if (keydown.key == "Meta" && arrays_equal(keydown.special_keys, ["meta"])) {
      return
    }

    let found = find_el_with_listener(raw_event.target as HTMLElement, "on_keydown")
    if (!found) return
    post_event(found.mono_id, { kind: 'keydown', el: found.path, keydown })
  }
  document.body.addEventListener("keydown", on_keydown)

  async function on_change(raw_event: Event) {
    let found = find_el_with_listener(raw_event.target as HTMLElement, "on_change")
    if (!found) return
    post_event(found.mono_id, { kind: 'change', el: found.path, change: { stub: "" } })
  }
  document.body.addEventListener("change", on_change)

  async function on_blur(raw_event: FocusEvent) {
    let found = find_el_with_listener(raw_event.target as HTMLElement, "on_blur")
    if (!found) return
    post_event(found.mono_id, { kind: 'blur', el: found.path, blur: { stub: "" } })
  }
  document.body.addEventListener("blur", on_blur)

  async function on_input(raw_event: Event) {
    let found = find_el_with_listener(raw_event.target as HTMLElement)
    if (!found) throw new Error("can't find element for input event")

    let input = raw_event.target! as HTMLInputElement
    let input_key = found.path.join(",")
    let in_event: InEvent = { kind: 'input', el: found.path, input: { value: get_value(input) } }

    if (input.getAttribute("on_input") == "delay") {
      // Performance optimisation, avoinding sending every change, and keeping only the last value
      changed_inputs[input_key] = in_event
    } else {
      delete changed_inputs[input_key]
      post_event(found.mono_id, in_event)
    }
  }
  document.body.addEventListener("input", on_input)

  function get_keys(raw_event: MouseEvent | KeyboardEvent): SpecialInputKeys[] {
    let keys: SpecialInputKeys[] = []
    if (raw_event.altKey) keys.push("alt")
    if (raw_event.ctrlKey) keys.push("ctrl")
    if (raw_event.shiftKey) keys.push("shift")
    if (raw_event.metaKey) keys.push("meta")
    return keys
  }

  let post_batches: { [mono_id: string]: InEvent[] } = {} // Batching events to avoid multiple sends
  let batch_timeout: number | undefined = undefined
  function post_event(mono_id: string, event: InEvent) {
    if (!(mono_id in post_batches)) post_batches[mono_id] = []
    post_batches[mono_id].push(event)
    if (batch_timeout != undefined) clearTimeout(batch_timeout)
    batch_timeout = setTimeout(post_events, 1)
  }

  async function post_events(): Promise<void> {
    // Sending changed input events with event
    // LODO inputs should be limited to mono root el
    let input_events = Object.values(changed_inputs)
    changed_inputs = {}

    let batches = post_batches
    post_batches = {}

    for (const mono_id in batches) {
      let events = batches[mono_id]
      Log("mono").info(">>", events)
      async function send_mono_x() {
        let data: InEventEnvelope = { kind: 'events', mono_id, events: [...input_events, ...events] }
        try   { await send("post", location.href, data) }
        catch { Log("http").error("can't send event") }
      }
      send_mono_x()
    }
  }
}

function find_el_with_listener(
  target: HTMLElement, listener: string | undefined = undefined
): { mono_id: string, path: number[] } | undefined {
  // Finds if there's element with specific listener
  let path: number[] = [], current = target, el_with_listener_found = false
  while (true) {
    el_with_listener_found = el_with_listener_found || (listener === undefined) || current.hasAttribute(listener)
    if (el_with_listener_found && current.hasAttribute("mono_id")) {
      return { mono_id: current.getAttribute("mono_id")!, path }
    }
    let parent = current.parentElement
    if (!parent) break
    for (var i = 0; i < parent.children.length; i++) {
      if (parent.children[i] == current) {
        if (el_with_listener_found) path.unshift(i)
        break
      }
    }
    current = parent
  }
  return undefined
}

// Different HTML inputs use different attributes for value
function get_value(el: HTMLInputElement): string {
  let tag = el.tagName.toLowerCase()
  if (tag == "input" && el.type == "checkbox") {
    return "" + el.checked
  } else if (tag == "textarea") {
    return "" + el.value
  } else {
    return "" + el.value
  }
}

// diff --------------------------------------------------------------------------------------------
function set_attr(el: HTMLElement, k: string, v: ElAttrVal) {
  // Some attrs requiring special threatment
  let [value, kind]: [string, ElAttrKind] = Array.isArray(v) ? v : [v, "string_attr"]

  switch(k) {
    case "window_title":    set_window_title(value); break
    case "window_location": set_window_location(value); break
    case "window_icon":     set_window_icon(value); break
  }

  switch(kind) {
    case "bool_prop":
      assert(["true", "false"].includes(value), "invalid bool_prop value: " + value)
      ;(el as any)[k] = value == "true"
      break
    case "string_prop":
      (el as any)[k] = value
      break
    case "string_attr":
      el.setAttribute(k, value)
      break
    default:
      throw new Error("unknown kind")
  }
}

function del_attr(el: HTMLElement, attr: ElAttrVal) {
  // Some attrs requiring special threatment
  let [k, kind]: [string, ElAttrKind] = Array.isArray(attr) ? attr : [attr, "string_attr"]

  switch(k) {
    case "window_title":    set_window_title(""); break
    case "window_location": break
    case "window_icon":     set_window_icon(""); break
  }

  switch(kind) {
    case "bool_prop":
      ;(el as any)[k] = false
      break
    case "string_prop":
      delete (el as any)[k]
      el.removeAttribute(k)
      break
    case "string_attr":
      el.removeAttribute(k)
      break
    default:
      throw new Error("unknown kind")
  }
}

function update(root: HTMLElement, diffs: Diff[]) {
  new ApplyDiffImpl(root).update(diffs)
}

class ApplyDiffImpl implements ApplyDiff {
  private flash_els = new Set<HTMLElement>()

  constructor(
    private root: HTMLElement
  ) {}

  update(diffs: Diff[]) {
    this.flash_els.clear()

    for (const diff of diffs) {
      // Applying diffs
      let fname = diff[0], [, ...args] = diff
      assert(fname in this, "unknown diff function")
      ;((this as any)[fname] as Function).apply(this, args)
    }

    if (!this.root.hasAttribute("skip_flash")) for (const el of this.flash_els) flash(el) // Flashing
    this.root.removeAttribute("skip_flash")
  }

  replace(id: number[], html: SafeHtml): void {
    el_by_path(this.root, id).outerHTML = html
    this.flash_if_needed(el_by_path(this.root, id))
  }
  add_children(id: number[], els: SafeHtml[]): void {
    for (const el of els) {
      let parent = el_by_path(this.root, id)
      parent.appendChild(build_el(el))
      this.flash_if_needed(parent.lastChild as HTMLElement)
    }
  }
  set_children_len(id: number[], len: number): void {
    let parent = el_by_path(this.root, id)
    assert(parent.children.length >= len)
    while (parent.children.length > len) parent.removeChild(parent.lastChild as HTMLElement)
    this.flash_if_needed(parent) // flashing parent of deleted element
  }
  set_attrs(id: number[], attrs: Record<string, string>): void {
    let el = el_by_path(this.root, id)
    for (const k in attrs) set_attr(el, k, attrs[k])
    this.flash_if_needed(el)
  }
  del_attrs(id: number[], attrs: string[]): void {
    let el = el_by_path(this.root, id)
    for (const attr of attrs) del_attr(el, attr)
    this.flash_if_needed(el)
  }
  set_text(id: number[], text: string): void {
    let el = el_by_path(this.root, id)
    el.innerText = text
    this.flash_if_needed(el)
  }
  set_html(id: number[], html: SafeHtml): void {
    let el = el_by_path(this.root, id)
    el.innerHTML = html
    this.flash_if_needed(el)
  }

  flash_if_needed(el: HTMLElement) {
    let flasheable: HTMLElement | null = el // Flashing self or parent element
    while (flasheable) {
      if (flasheable.hasAttribute("noflash")) {
        flasheable = null
        break
      }
      if (flasheable.hasAttribute("flash")) break
      flasheable = flasheable.parentElement
    }
    if (flasheable) this.flash_els.add(flasheable)
  }
}

// helpers -----------------------------------------------------------------------------------------
function get_mono_root(mono_id: string): HTMLElement {
  return find_one(`[mono_id="${mono_id}"]`)
}

// window icon -------------------------------------------------------------------------------------
function set_window_icon(mono_id: string, attr = "window_icon") {
  let mono_root = get_mono_root(mono_id)
  let href_or_id = mono_root.getAttribute(attr)
  if (!href_or_id) {
    // If attribute not set explicitly on root mono element, checking if there's template with such id
    let id = "#" + attr
    if (find_all(id).length > 0) href_or_id = id
  }
  if (!href_or_id) return
  // Cold be the id of template with svg icon, or the image itself.
  if (href_or_id.startsWith("#")) {
    let template = find_one(href_or_id)
    let svg = template.innerHTML
    set_favicon(svg_to_base64_data_url(svg))
  } else {
    set_favicon(href_or_id)
  }
}

function set_window_icon_disabled(mono_id: string) {
  set_window_icon(mono_id, "window_icon_disabled")
}