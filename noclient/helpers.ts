import { p, ensure, something } from 'bon/base.ts'
import { $, find_one } from './tquery.ts'

export function get_user_token(): string {
  // return ensure(find_one(`meta[name="user_token"]`).get_attr('content'), "user_token")
  return ensure((window as something)["user_token"], "user_token")
}

export function get_session_token(): string {
  // return ensure(find_one(`meta[name="session_token"]`).get_attr('content'), "session_token")
  return ensure((window as something)["session_token"], "session_token")
}