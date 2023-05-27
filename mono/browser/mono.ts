// deno bundle --config mono/browser/tsconfig.json mono/browser/mono.ts mono/browser/mono.js
import { p, el_by_path, assert, build_el, flash, send, Log, find_all, find_one, arrays_equal,
  sleep } from "./helpers.js"

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

// Out events
type OutEvent =
  { kind: 'eval',   code: string } |
  { kind: 'update', diffs: Diff[] }

// Session events
type SessionPostEvent = { kind: 'events', mono_id: string, events: InEvent[] }
type SessionPostPullEvent = { kind: 'pull',   mono_id: string }

type SessionPullEvent =
  { kind: 'events', events: OutEvent[] } |
  { kind: 'ignore' } |
  { kind: 'expired' } |
  { kind: 'error', message: string }

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
export function run() {
  listen_to_dom_events()

  let mono_els = find_all('[mono_id]')
  if (mono_els.length < 1) throw new Error("mono_id not found")
  if (mono_els.length > 1) throw new Error("multiple mono_id not supported yet")
  let mono_el = mono_els[0]

  let mono_id         = mono_el.getAttribute("mono_id") || ""
  let window_location = mono_el.getAttribute("window_location")

  if (window_location) set_window_location(window_location)
  pull(mono_id)
}

async function pull(mono_id: string): Promise<void> {
  let log = Log("")
  log.info("started")
  main_loop: while (true) {
    let res: SessionPullEvent
    let last_call_was_retry = false
    try {
      res = await send<SessionPostPullEvent, SessionPullEvent>(
        "post", location.href, { kind: "pull", mono_id }, -1
      )
      document.body.style.opacity = "1.0"
      last_call_was_retry = false
    } catch {
      last_call_was_retry = true
      if (!last_call_was_retry) log.warn("retrying...")
      document.body.style.opacity = "0.7"
      await sleep(1000)
      continue
    }

    switch (res.kind) {
      case 'events':
        for (const event of res.events) {
          log.info("<<", event)
          switch(event.kind) {
            case 'eval':
              eval("'use strict'; " + event.code)
              break
            case 'update':
              let root = find_one(`[mono_id="${mono_id}"]`)
              if (!root) throw new Error("can't find mono root")
              update(root, event.diffs)
              break
          }
        }
        break
      case 'ignore':
        break
      case 'expired':
        document.body.style.opacity = "0.4"
        log.info("expired")
        break main_loop
      case 'error':
        log.error(res.message)
        throw new Error(res.message)
    }
  }
}

// events ------------------------------------------------------------------------------------------
function listen_to_dom_events() {
  let changed_inputs: { [k: string]: InEvent } = {} // Keeping track of changed inputs

  async function on_click(raw_event: MouseEvent) {
    let el = raw_event.target as HTMLElement, location = "" + (el as any).href
    if (el.tagName.toLowerCase() == "a" && location != "") {
      // Click with redirect
      let found = find_el_with_listener(el)
      if (!found) return
      raw_event.preventDefault()
      history.pushState({}, "", location)
      await post_event(found.mono_id, { kind: 'location', location, el: [] })
    } else {
      // Click without redirect
      let found = find_el_with_listener(el, "on_click")
      if (!found) return
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

  async function post_event(mono_id: string, event: InEvent): Promise<void> {
    // Sending changed input events with event
    let input_events = Object.values(changed_inputs)
    changed_inputs = {}

    Log("").info(">>", event)
    let data: SessionPostEvent = { kind: 'events', mono_id, events: [...input_events, event] }
    try   { await send("post", location.href, data) }
    catch { Log("http").error("can't send event") }
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
  } else {
    return "" + el.value
  }
}

// diff --------------------------------------------------------------------------------------------
function set_attr(el: HTMLElement, k: string, v: ElAttrVal) {
  // Some attrs requiring special threatment
  let [value, kind]: [string, ElAttrKind] = Array.isArray(v) ? v : [v, "string_attr"]

  if (k == "window_title")    return set_window_title(value)
  if (k == "window_location") return set_window_location(value)

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

  if (k == "window_title") return set_window_title("")
  if (k == "window_location") return

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

    for (const el of this.flash_els) flash(el) // Flashing
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
  }
  set_html(id: number[], html: SafeHtml): void {
    let el = el_by_path(this.root, id)
    el.innerHTML = html
  }

  flash_if_needed(el: HTMLElement) {
    let flasheable: HTMLElement | null = el // Flashing self or parent element
    while (flasheable) {
      if (flasheable.hasAttribute("flash")) break
      flasheable = flasheable.parentElement
    }
    if (flasheable) this.flash_els.add(flasheable)
  }
}

function set_window_title(title: string) {
  if (document.title != title) document.title = title
}

function set_window_location(location: string) {
  let current = window.location.pathname + window.location.search + window.location.hash
  if (location != current) history.pushState({}, "", location)
}