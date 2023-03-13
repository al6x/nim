(function () {
  const page_log = Log("page")
  class Page {
    constructor(session_id) {
      this.session_id = session_id
      this._listen_to_dom_events()
      this._pull()
    }

    _listen_to_dom_events() {
      let session_id = this.session_id
      async function handle(raw_event) {
        const event = {}
        const keys = ["altKey", "ctrlKey", "shiftKey", "metaKey", "srcElement", "type"]
        for (let key of keys) event[key] = raw_event[key]
        page_log.info("event", event)
        try {   await send("post", location.href, { type: "event", session_id, event }) }
        catch { page_log.error("can't send event") }
      }
      document.body.addEventListener("click", handle)
    }

    async _pull() {
      page_log.info("started")
      let init = true
      while (true) {
        let response
        try {
          response = await send("post", location.href, { type: "pull", init, session_id: this.session_id }, -1)
        } catch {
          page_log.warn("retrying")
          await sleep(1000)
          continue
        }

        if ("eval" in response) {
          page_log.info("eval", response.eval)
          eval("'use strict'; " + response.eval)
        } else if (Object.keys(response).length == 0) {
          // page_log.info("empty response")
        } else {
          const error = new Error("unknown response")
          page_log.error("unknown response", response)
          throw error
        }
      }
    }
  }
  window.Page = Page


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

    component = component.substring(0, 4).toUpperCase().padEnd(4)
    return {
      info(msg, data = {})  { console.log("  " + component + " " + msg, data) },
      error(msg, data = {}) { console.log("E " + component + " " + msg, data) },
      warn(msg, data = {})  { console.log("W " + component + " " + msg, data) }
    }
  }
})()