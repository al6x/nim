import { assert, http_call } from 'bon/base.ts'
import { $, build, find_one, find, waiting, TEvent, get_form_data } from './tquery.ts'
import { get_user_token, get_session_token } from './helpers.ts'


// Command -------------------------------------------------------------------------------------------
export interface Command {
  command: string
}


// CommandExecutor ---------------------------------------------------------------------------------
export type CommandExecutor = (command: Command) => Promise<void>

export const executors: {[command: string]: CommandExecutor} = {}

export function register_executor<C extends Command>(name: string, executor: (command: C) => Promise<void>): void {
  executors[name] = executor as CommandExecutor
}


// execute_command ---------------------------------------------------------------------------------
export async function execute_command(command: Command, event?: Event | TEvent) {
  // log('info', `executing '${command.command}' command`)
  if (!(command.command in executors)) throw new Error(`unknown command '${command.command}'`)
  let executor: CommandExecutor = executors[command.command]
  if (event) {
    await waiting(event, () => executor(command))
  } else {
    await executor(command)
  }
}


// ShowErrorCommand ----------------------------------------------------------------------------------
export interface ShowErrorCommand {
  command: 'show_error'
  error:   string
}
export async function show_error({ error }: ShowErrorCommand) {
  alert(error || 'Unknown error')
}
register_executor("show_error", show_error)


// ConfirmCommand --------------------------------------------------------------------------------
export interface ConfirmCommand {
  command: 'confirm'
  message?: string
  execute:  Command
}
export async function confirm({ message, execute }: ConfirmCommand) {
  if (window.confirm(message || 'Are you sure?')) await execute_command(execute)
}
register_executor("confirm", confirm)


// ExecuteCommand --------------------------------------------------------------------------------
// Execute command from another DOM element
export interface ExecuteCommand {
  command: 'execute'
  id:      string
}
export async function execute({ id }: ExecuteCommand) {
  const command = JSON.parse(find_one(`#${id}`).ensure_attr('command'))
  execute_command(command)
}
register_executor("show_error", show_error)


// CallCommand -------------------------------------------------------------------------------------
// Call server
export interface CallCommand {
  command: 'call'
  path:     string
  args?:    object
  state?:   boolean
}
export async function call(command: CallCommand) {
  let args       = command.args || {}
  let location   = '' + window.location.href
  let with_state = 'state' in command ? command.state : false
  let state      = with_state ? get_state() : {}

  // Calling server
  let commands = await http_call<object, object[]>(command.path, {
    ...args,
    ...state,
    location
  }, {
    method: 'post',
    params: {
      format:        'json',
      user_token:    get_user_token(),
      session_token: get_session_token()
    }
  })

  // Processing response commands
  assert(commands && commands instanceof Array, `wrong command response format`)
  for (const command of commands) await execute_command(command as Command)
}
register_executor("call", call)


// FlashCommand --------------------------------------------------------------------------------------
export interface FlashCommand {
  command: 'flash'
  id:      string
}
export async function flash({ id }: FlashCommand) {
  find_one(`#${id}`).flash()
}
register_executor("flash", flash)


// JsCommand -----------------------------------------------------------------------------------------
export interface JsCommand {
  command: 'eval_js'
  js:      string
}
export async function eval_js({ js }: JsCommand) {
  eval(js)
}
register_executor("eval_js", eval_js)


// ReloadCommand -------------------------------------------------------------------------------------
export interface ReloadCommand {
  command: 'reload'
  url?:     string
}
export async function reload({ url }: ReloadCommand) {
  const result = await fetch(url || window.location.href)
  if (!result.ok) {
    show_error({ command: 'show_error', error: `Unknown error, please reload page` })
    return
  }
  await replace({ command: 'replace', page: await result.text() })
}
register_executor("reload", reload)


// ReplaceCommand ----------------------------------------------------------------------------------
// TODO 2 also add `location`
export type ReplaceCommand =
  { command: 'replace', element: string, id?: string, flash?: boolean } |
  // { command: 'replace', element: string,  flash?: boolean } |
  { command: 'replace', page: string }

async function replace(command: ReplaceCommand) {
  function is_page(html: string) { return /<html/.test(html) }

  if ('page' in command) {
    const match = command.page.match(/<head.*?><title>(.*?)<\/title>/)
    if (match) window.document.title = match[1]
    const bodyInnerHtml = command.page
      .replace(/^[\s\S]*<body[\s\S]*?>/, '')
      .replace(/<\/body[\s\S]*/, '')
      .replace(/<script[\s\S]*?script>/g, '')
      .replace(/<link[\s\S]*?>/g, '')
    find_one('body').set_content(bodyInnerHtml)
  } else {
    assert(!is_page(command.element), `use 'page' command to replace the whole HTML page`)
    // Extracting `id` from html text
    const $elements = build(command.element)
    for (const $el of $elements) {
      const find_element = () => {
        // group_id will be used in case when elements united with the `<group id="some-id">`
        const id = command.id || $el.get_attr('id'), group_id = $el.get_attr('group_id')
        if      (id)       return find_one(`#${id}`)
        else if (group_id) return find_one(`[group_id="${group_id}"]`)
        else               throw new Error(`nether id nor group_id are defined`)
      }

      find_element().replace_with($el)
      if (command.flash) find_element().flash()
    }
  }
}
register_executor("replace", replace)


// RedirectCommand ---------------------------------------------------------------------------------
export type RedirectCommand =
  { command: 'redirect', redirect: string, page: string } |
  { command: 'redirect', redirect: string, method?: 'get' | 'post' }

export async function redirect(command: RedirectCommand) {
  const { redirect: path } = command
  const url: string = /^\//.test(path) ? window.location.origin + path : path

  function update_history() {
    window.history.pushState({}, '', url)
    skip_reload_on_location_change = parse_location(url)
    on_location_change()
  }

  if ('page' in command) {
    await replace({ command: 'replace', page: command.page })
    update_history()
  } else if ('method' in command) {
    let method = command.method || 'get'
    if (method == 'get') {
      // await is important, we need to wait untill the page is updated,
      // because next command may ask to flash some of the new elements
      // and expect it to be in the DOM
      const result = await fetch(url || window.location.href)
      if (!result.ok) {
        show_error({ command: 'show_error', error: `Unknown error, please reload page` })
        return
      }
      await replace({ command: 'replace', page: await result.text() })
      update_history()
    } else {
      // Redirect with post
      const form = window.document.createElement('form')
      form.method = 'post'
      form.action = url
      window.document.body.appendChild(form)
      form.submit()
    }
  }

  // window.location.href = url
  // window.open(url, '_parent')
}
register_executor("redirect", redirect)


// -------------------------------------------------------------------------------------------------
// Helpers -----------------------------------------------------------------------------------------
// -------------------------------------------------------------------------------------------------


// Back button handling ----------------------------------------------------------------------------
let skip_reload_on_location_change: string | null = null
let current_location = window.location.href

async function check_for_location_change(): Promise<boolean> {
  if (current_location != window.location.href) {
    if (
      parse_location(window.location.href) != parse_location(current_location) &&
      parse_location(window.location.href) != skip_reload_on_location_change
    ) await reload({ command: 'reload' })
    current_location = window.location.href
    skip_reload_on_location_change = null
    return true
  } else return false
}

function on_location_change() {
  const started = Date.now()
  async function pool() {
    const changed = await check_for_location_change()
    if ((Date.now() - started) < 1000 && !changed) setTimeout(pool, 10)
  }
  setTimeout(pool, 0)
}

$(window).on('popstate', on_location_change)
$(window).on('pushstate', on_location_change)
setInterval(check_for_location_change, 1000)


// parse_location ----------------------------------------------------------------------------------
const parse_location_cache: { [key: string]: string } = {}
function parse_location(url: string): string {
  if (!(url in parse_location_cache)) {
    var el = window.document.createElement('a')
    el.href = url
    parse_location_cache[url] = `${el.pathname}${el.search}`
  }
  return parse_location_cache[url]
}


// get_state ---------------------------------------------------------------------------------------
export function get_state(): { [key: string]: string } {
  let state: { [key: string]: string } = {}
  for (let $form of find("form")) state = {...state, ...get_form_data($form)}
  return state
}