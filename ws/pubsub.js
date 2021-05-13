(function () {
  function info(msg) { console.log("  pubsub " + msg) }
  function error(msg) { console.log("E pubsub " + msg) }
  function warn(msg) { console.log("W pubsub " + msg) }

  // First reconnect is instant, consequent reconnects are randomised progressive `+ increment_ms`
  class PubSub {
    static last_messages_ids = {}

    constructor(
      url,
      topics,
      onmessage,
      increment_ms           = 500,
      max_reconnect_delay_ms = 10000
    ) {
      url = url + (url.includes("?") ? "&" : "?") + "topics=" + encodeURIComponent(topics.join(","))
      this.url = url; this.onmessage = onmessage,
      this.increment_ms = increment_ms, this.max_reconnect_delay_ms = max_reconnect_delay_ms
      this._reconnect(1)
    }

    close() {
      if (!this.es) return
      // info("closing")
      try { this.es.close() } catch (e) {}
      this.es = null
    }

    _reconnect(attempt) {
      info("connecting to " + this.url)
      let es = new EventSource(this.url)
      this.es = es

      function close_again() {
        // Sometimes it's still not closed
        warn("closing again")
        try { es.close() } catch (e) {}
      }

      let success = false, closed = false
      es.onopen = (_event) => {
        if (closed) {
          close_again()
          return
        }
        info("connected")
        success = true
      }

      es.onmessage = (event) => {
        if (closed) {
          close_again()
        }

        success = true

        let message = JSON.parse(event.data)

        if ("special" in message) {
          if (message.special == "ping") return
          else console.error("pubsub, unknown special message " + message.special)
        }

        // Server may resend message twice, if network error occured, id is random and not not increasing
        if (PubSub.last_messages_ids[message.topic] == message.id) return
        PubSub.last_messages_ids[message.topic] = message.id

        this.onmessage(message.topic, message.message)
      }

      es.onerror = (_event) => {
        if (closed) {
          close_again()
          return
        }
        this.close()
        closed = true

        if (success) {
          // First reconnect not counted as error
          info("disconnected, reconnecting")
          setTimeout(() => this._reconnect(1), 1)
        } else {
          let delay_ms = this._calculate_timeout_ms(success ? 1 : attempt + 1)
          error("error, will try to reconnect for " + (attempt + 1) + "th time, after " + delay_ms + "ms")
          setTimeout(() => this._reconnect(attempt + 1), delay_ms)
        }
      }
    }

    _calculate_timeout_ms(attempt) {
      // Timeout is randomised, but it never will be more than the max timeout
      let delay_ms = attempt == 1 ?
        0 :
        Math.min(this.max_reconnect_delay_ms, Math.pow(2, attempt - 1) * this.increment_ms)
      // Randomising to distribute server load evenly
      return Math.round(((Math.random() * delay_ms) + delay_ms) / 2)
    }
  }
  window.PubSub = PubSub
})()