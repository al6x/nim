export class Page {
  constructor(session_id) {
    this.session_id = session_id
    this.log = Log("")
    this._listen_to_dom_events()
    this._pull()
  }

  _listen_to_dom_events() {
    let self = this
    async function handle(raw_event) {
      const event = { kind: raw_event.type, keys: [] }
      if (raw_event.altKey) event.keys.push("alt")
      if (raw_event.ctrlKey) event.keys.push("ctrl")
      if (raw_event.shiftKey) event.keys.push("shift")
      if (raw_event.metaKey) event.keys.push("meta")
      let target = raw_event.srcElement
      while (target && target != document.body) {
        if (target.id != "") {
          event.id = target.id
          break
        }
        target = target.parentElement
      }
      if (!event.id) throw new Error("can't get id for event")
      self.log.info("event", event)
      try   { await send("post", location.href, { kind: "event", session_id: self.session_id, event }) }
      catch { self.log.error("can't send event") }
    }
    document.body.addEventListener("click", handle)
  }

  async _pull() {
    this.log.info("started")
    main_loop: while (true) {
      let out_events
      try {
        out_events = await send("post", location.href, { kind: "pull", session_id: this.session_id }, -1)
        document.body.style.opacity = 1.0
      } catch {
        document.body.style.opacity = 0.7
        this.log.warn("retrying")
        await sleep(1000)
        continue
      }

      if (!Array.isArray(out_events)) {
        this.log.error("invalid pull response", out_events)
        throw error
      }

      for (const event of out_events) {
        this.log.info("<<", event)
        if (event.kind == "expired") {
          document.body.style.opacity = 0.3
          break main_loop
        } else if (event.kind == "eval") {
          eval("'use strict'; " + event.code)
        } else {
          const error = new Error("unknown response")
          this.log.error("unknown event", res)
          throw error
        }
      }
    }
  }
}

const http_log = Log("http", false)
function send(method, url, data = {}, timeout = 5000) {
  http_log.info("http send", { method, url, data })
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
          http_log.info("http receive", { method, url, data, response })
          resolve(response)
        } else {
          const error = new Error(xhr.responseText)
          http_log.info("http error", { method, url, data, error })
          reject(error)
        }
      }
    }
    if (timeout > 0) {
      setTimeout(function(){
        if(responded) return
        responded = true
        const error = new Error("no response from " + url + "!")
        http_log.info("http error", { method, url, data, error })
        reject(error)
      }, timeout)
    }
    xhr.send(JSON.stringify(data))
  })
}

function sleep(ms) {
  return new Promise((resolve, reject) => {
    setTimeout(() => { resolve() }, ms)
  })
}

function Log(component, enabled = true) {
  if (!enabled) return {
    info(msg, data = {})  {},
    error(msg, data = {}) {},
    warn(msg, data = {})  {}
  }

  component = component.substring(0, 4).toLowerCase().padEnd(4)
  return {
    info(msg, data = {})  { console.log("  " + component + " " + msg, data) },
    error(msg, data = {}) { console.log("E " + component + " " + msg, data) },
    warn(msg, data = {})  { console.log("W " + component + " " + msg, data) }
  }
}