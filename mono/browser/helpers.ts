export let p = console.log.bind(console), global = window as any

const http_log = Log("http", false)
export function send<In, Out>(method: string, url: string, data: In, timeout = 5000): Promise<Out> {
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

export function find_all(query: string): HTMLElement[] {
  let list: HTMLElement[] = [], els = document.querySelectorAll(query)
  for (var i = 0; i < els.length; i++) list.push(els[i] as HTMLElement)
  return list
}

export function find_one(query: string): HTMLElement {
  let el = document.querySelector(query)
  if (!el) throw new Error("query_one haven't found any " + query)
  return el as HTMLElement
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve, _reject) => { setTimeout(() => { resolve() }, ms) })
}

export function Log(component: string, enabled = true) {
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

export function el_by_path(root: HTMLElement, path: number[]): HTMLElement {
  let el = root
  for (const pos of path) {
    assert(pos < el.children.length, "wrong path, child index is out of bounds")
    el = el.children[pos] as HTMLElement
  }
  return el
}

export function build_el(html: string): HTMLElement {
  var tmp = document.createElement('div')
  tmp.innerHTML = html
  assert(tmp.children.length == 1, "exactly one el expected")
  return tmp.firstChild as HTMLElement
}

export function assert(cond: boolean, message = "assertion failed") {
  if (!cond) throw new Error(message)
}

export function arrays_equal<T>(a: T[], b: T[]): boolean {
  return JSON.stringify(a) == JSON.stringify(b)
}

// Highlight element with yellow flash
let update_timeouts: { [key: string]: number } = {}
let flash_id_counter = 0
export function flash(
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

export function set_window_title(title: string) {
  if (document.title != title) document.title = title
}

export function set_window_location(location: string) {
  let current = window.location.pathname + window.location.search + window.location.hash
  if (location != current) history.pushState({}, "", location)
}

export function get_window_location(): string {
  return window.location.pathname + window.location.search
}

export function set_favicon(href: string) {
  var link: HTMLLinkElement | null = document.head.querySelector("link[rel~='icon']")
  if (link) {
    if (link.href != href) link.href = href
  } else {
    Log("mono").error("no favicon in html")
  }
}

export function svg_to_base64_data_url(svg: string): string {
  return "data:image/svg+xml;base64," + btoa(svg)
}

export function dcopy<T>(v: T): T {
  return JSON.parse(JSON.stringify(v))
}

export function escape_js(js: unknown): string {
  if (js === undefined || js === null) return ''
  return JSON.stringify(js).replace(/^"|"$/g, '')
}

const ESCAPE_HTML_MAP: { [key: string]: string } = {
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}
const ESCAPE_HTML_MAP_WITHOUT_QUOTES: { [key: string]: string } = {
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}
export function escape_html(html: unknown, quotes = true): string {
  if (html === undefined || html === null) return ''
  let map = quotes ? ESCAPE_HTML_MAP : ESCAPE_HTML_MAP_WITHOUT_QUOTES
  return ('' + html).replace(/[&<>'"]/g, function(c) { return map[c] })
}