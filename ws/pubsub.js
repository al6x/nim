// First reconnect is instant, consequent reconnects are randomised progressive `+ increment_ms`
class PubSub {
  static last_messages_ids = {}

  constructor(
    url,
    topics,
    onmessage,
    increment_ms           = 500,
    max_reconnect_delay_ms = 5000
  ) {
    url = url + (url.includes("?") ? "&" : "?") + "topics=" + encodeURIComponent(topics.join(","))
    console.log("pubsub connected to " + url)
    this.url = url; this.onmessage = onmessage,
    this.increment_ms = increment_ms, this.max_reconnect_delay_ms = max_reconnect_delay_ms
    this._reconnect(1)
  }

  close() {
    if (!this.es) return
    try { this.es.close() } catch (e) {}
    this.es = null
  }

  _reconnect(attempt) {
    this.close()
    let es = this.es = new EventSource(this.url)

    setTimeout(() => {
      let success = false
      es.ononopen = (_event) => {
        if (this.es != es) return
        success = true
      }

      es.onmessage = (event) => {
        if (this.es != es) return
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
        if (this.es != es) return
        this._reconnect(success ? 1 : attempt + 1)
      }
    }, this._calculate_timeout_ms(attempt))
  }

  _calculate_timeout_ms(attempt) {
    return attempt == 1 ?
      0 :
      // Randomising to distribute server load more evenly
      Math.max(this.max_reconnect_delay_ms, (attempt - 1) * this.increment_ms * Math.random())
  }
}
window.PubSub = PubSub