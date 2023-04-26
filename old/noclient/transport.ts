import { p, ensure, assert, http_call, something } from 'bon/base.ts'


// Transport ---------------------------------------------------------------------------------------
export type MessageListener = (message: object) => Promise<void>

export interface Transport {
  send<A extends { action: string }>(action: A): Promise<void>
  on(listener: MessageListener): void
}


// FetchTransport ----------------------------------------------------------------------------------
export class FetchTransport implements Transport {
  private listener?: MessageListener

  constructor(
    public readonly user_token:    string,
    public readonly session_token: string
  ) {}

  async send<A extends { action: string }>(action: A): Promise<void> {
    let response = await http_call<object, object>(action.action, action, {
      method: 'post',
      params: {
        format:        'json',
        user_token:    this.user_token,
        session_token: this.session_token
      }
    })

    ensure(this.listener, "listener not set")(response)
  }

  on(listener: MessageListener): void {
    if (this.listener != null) throw new Error("only one listener supported")
    this.listener = listener
  }
}
