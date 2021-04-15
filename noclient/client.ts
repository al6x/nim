import { log } from 'bon/base.ts'
import { register_action_executor } from './commands.ts'
import { FetchTransport } from './transport.ts'
import './events.ts'
import { get_user_token, get_session_token } from './helpers.ts'

let transport = new FetchTransport(get_user_token(), get_session_token())
register_action_executor(transport)