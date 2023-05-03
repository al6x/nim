// deno bundle --config mono/browser/tsconfig.json mono/browser/mono.ts mono/browser/mono.js

let p = console.log.bind(console), global = window as any

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
interface UpdateElement {
  el:            number[]
  set?:          Record<string, unknown>
  set_attrs?:    Record<string, unknown>
  del_attrs?:    string[]
  set_children?: Record<string, Record<string, unknown>>
  del_children?: number[]
}

type OutEvent =
  { kind: 'eval',   code: string } |
  { kind: 'update', updates: UpdateElement[] }

// Session events
type SessionPostEvent = { kind: 'events', mono_id: string, events: InEvent[] }
type SessionPostPullEvent = { kind: 'pull',   mono_id: string }

type SessionPullEvent =
  { kind: 'events', events: OutEvent[] } |
  { kind: 'ignore' } |
  { kind: 'expired' } |
  { kind: 'error', message: string }


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
              event.updates.forEach((update) => apply_update(root, update))
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

const http_log = Log("http", false)
function send<In, Out>(method: string, url: string, data: In, timeout = 5000): Promise<Out> {
  http_log.info("send", { method, url, data })
  return new Promise((resolve, reject) => {
    var responded = false
    var xhr = new XMLHttpRequest()
    xhr.open(method.toUpperCase(), url, true)
    xhr.onreadystatechange = function(){
      if(responded) return
      if(xhr.readyState == 4){
        responded = true
        if(xhr.status == 200) {
          const response = JSON.parse(xhr.responseText)
          http_log.info("receive", { method, url, data, response })
          resolve(response)
        } else {
          const error = new Error(xhr.responseText)
          http_log.info("error", { method, url, data, error })
          reject(error)
        }
      }
    }
    if (timeout > 0) {
      setTimeout(function(){
        if(responded) return
        responded = true
        const error = new Error("no response from " + url + "!")
        http_log.info("error", { method, url, data, error })
        reject(error)
      }, timeout)
    }
    xhr.send(JSON.stringify(data))
  })
}

function find_all(query: string): HTMLElement[] {
  let list: HTMLElement[] = [], els = document.querySelectorAll(query)
  for (var i = 0; i < els.length; i++) list.push(els[i] as HTMLElement)
  return list
}

function find_one(query: string): HTMLElement {
  let el = document.querySelector(query)
  if (!el) throw new Error("query_one haven't found any " + query)
  return el as HTMLElement
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

function sleep(ms: number): Promise<void> {
  return new Promise((resolve, _reject) => { setTimeout(() => { resolve() }, ms) })
}

function Log(component: string, enabled = true) {
  if (!enabled) return {
    info(msg: string, data: unknown = {})  {},
    error(msg: string, data: unknown = {}) {},
    warn(msg: string, data: unknown = {})  {}
  }

  component = component.substring(0, 4).toLowerCase().padEnd(4)
  return {
    info(msg: string, data: unknown = {})  { console.log("  " + component + " " + msg, data) },
    error(msg: string, data: unknown = {}) { console.log("E " + component + " " + msg, data) },
    warn(msg: string, data: unknown = {})  { console.log("W " + component + " " + msg, data) }
  }
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

function to_element(data: Record<string, unknown>): HTMLElement {
  let tag: string = "tag" in data ? data["tag"] as string : "div"
  let el = document.createElement(tag)

  for (const k in data) {
    if (["tag", "children", "text"].indexOf(k) >= 0) continue
    el.setAttribute(k, "" + data[k])
  }
  if        ("text" in data) {
    assert(!("children" in data), "to_element doesn't support both text and children")
    el.textContent = "" + data["text"]
  } else if ("children" in data) {
    assert(Array.isArray(data["children"]), "to_element element children should be JArray")
    let children = data["children"] as Record<string, unknown>[]
    for (const child of children) el.appendChild(to_element(child))
  }
  return el
}

function el_by_path(root: HTMLElement, path: number[]): HTMLElement {
  let el = root
  for (const pos of path) {
    assert(pos < el.children.length, "wrong path, child index is out of bounds")
    el = el.children[pos] as HTMLElement
  }
  return el
}

let attr_properties = ["value"]
let boolean_attr_properties = ["checked"]
function apply_update(root: HTMLElement, update: UpdateElement) {
  let el = el_by_path(root, update.el)
  let set = update.set

  let self_updated = false
  if (set) {
    el.replaceWith(to_element(set))
    self_updated = true
  }

  let set_attrs = update.set_attrs, attrs_updated = false
  let window_title: string | undefined, window_location: string | undefined
  if (set_attrs) {
    for (const k in set_attrs) {
      let v_str = "" + set_attrs[k]
      assert(k != "children", "set_attrs can't set children")
      if        (k == "window_title") {
        window_title = v_str
      } else if (k == "window_location") {
        window_location = v_str
      } else {
        if (k == "text") {
          if (el.children.length > 0) el.innerHTML = ""
          el.innerText = v_str
        } else if (boolean_attr_properties.includes(k)) {
          (el as any)[k] = !!v_str
        } else if (attr_properties.includes(k)) {
          (el as any)[k] = v_str
        } else {
          el.setAttribute(k, v_str)
        }
        attrs_updated = true
      }
    }
  }

  if (window_title) set_window_title(window_title)
  if (window_location) set_window_location(window_location)

  let del_attrs = update.del_attrs
  if (del_attrs) {
    for (const k of del_attrs) {
      assert(k != "children", "del_attrs can't del children")
      if (["window_title", "window_location"].includes(k)) {
        // do nothing
      } else {
        if (k == "text") {
          el.innerText = ""
        } else if (boolean_attr_properties.includes(k)) {
          (el as any)[k] = false
        } else {
          el.removeAttribute(k)
        }
        attrs_updated = true
      }
    }
  }

  let set_children = update.set_children, children_updated = []
  if (set_children) {
    // Sorting by position, as map is not sorted
    let positions: [number, HTMLElement][] = []
    for (const pos_s in set_children) {
      positions.push([parseInt(pos_s), to_element(set_children[pos_s])])
    }
    positions.sort((a, b) => a[0] - b[0])

    for (const [pos, child] of positions) {
      if (pos < el.children.length) {
        el.children[pos].replaceWith(child)
      } else {
        assert(pos == el.children.length, "set_children can't have gaps in children positions")
        el.appendChild(child)
      }
      children_updated.push(pos)
    }
  }

  let del_children = update.del_children, children_deleted = false
  if (del_children) {
    // Sorting by position descending
    let positions = [...del_children]
    positions.sort((a, b) => a - b)
    positions.reverse()
    for (const pos of positions) {
      assert(pos <= el.children.length, "del_children index out of bounds")
      el.children[pos].remove()
      children_deleted = true
    }
  }

  // Flashing changed children
  for (let pos of children_updated) {
    let child = el.children[pos] as HTMLElement
    if (child.hasAttribute("flash")) flash(child)
  }
  if (self_updated || attrs_updated || children_updated.length > 0 || children_deleted) {
    let flasheable: HTMLElement | null = el // Flashing self or parent element
    while (flasheable) {
      if (flasheable.hasAttribute("flash")) {
        flash(flasheable)
        break
      }
      flasheable = flasheable.parentElement
    }
  }
}

function set_window_title(title: string) {
  if (document.title != title) document.title = title
}

function set_window_location(location: string) {
  let current = window.location.pathname + window.location.search + window.location.hash
  if (location != current) history.pushState({}, "", location)
}

function assert(cond: boolean, message = "assertion failed") {
  if (!cond) throw new Error(message)
}

function arrays_equal<T>(a: T[], b: T[]): boolean {
  return JSON.stringify(a) == JSON.stringify(b)
}

// Highlight element with yellow flash
let update_timeouts: { [key: string]: number } = {}
let flash_id_counter = 0
function flash(
  el: HTMLElement,
  before_delete         = false,
  timeout               = 1500, // should be same as in CSS animation
  before_delete_timeout = 400   // should be same as in CSS animation
): void {
  // const id = $el.get_attr('id')
  let [klass, delay] = before_delete ?
    ['flash_before_delete', before_delete_timeout] :
    ['flash', timeout]

  // ID needed when flash repeatedly triggered on the same element, before the previous flash has
  // been finished. Without ID such fast flashes won't work properly.
  // Example - frequent updates from the server changing counter.
  if (!el.dataset.flash_id) el.dataset.flash_id = "" + (flash_id_counter++)
  let id = el.dataset.flash_id

  if (id in update_timeouts) {
    clearTimeout(update_timeouts[id])
    el.classList.remove(klass)
    setTimeout(() => {
      void (el as any).offsetWidth
      el.classList.add(klass)
    }) // Triggering re-render
  } else {
    el.classList.add(klass)
  }

  update_timeouts[id] = setTimeout(() => {
    el.classList.remove(klass)
    delete update_timeouts[id]
  }, delay)
}