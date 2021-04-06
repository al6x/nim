import { p, log, sort, something, flatten } from 'bon/base.ts'
import { $, build, build_one, find_by_id, find, waiting, TEvent, get_form_data,
  smart_dom_update } from './tquery.ts'
import { Transport } from './transport.ts'

// CommandExecutor ---------------------------------------------------------------------------------
export type CommandExecutor = (command: object) => Promise<void>

export const executors: { [command: string]: CommandExecutor } = {}

export function register_executor<C extends object>(name: string, executor: (command: C) => Promise<void>): void {
  executors[name] = executor as CommandExecutor
}


// execute_command ---------------------------------------------------------------------------------
export async function execute_command(command: object, event?: Event | TEvent) {
  // if (!(command.command in executors)) throw new Error(`unknown command '${command.command}'`)
  // let executor: CommandExecutor = executors[command.command]

  var found: string | null = null
  for (let name in executors) {
    if (name in command) {
      // Some commands may have conflict, like `update/flash` and `flash`, resolving it
      if (found != null) {
        let abname = sort([name, found]).join("/")
        if (abname in executors) found = abname
        else                     throw new Error(`Can't resolve executor for ${found}, ${name}!`)
      } else {
        found = name
      }
    }
  }
  if (found == null) throw new Error(`Executor not found for command ${Object.keys(command).join(", ")}!`)
  let executor = executors[found]

  log('info', `executing ${found}`)
  try {
    if (event) {
      await waiting(event, () => executor(command))
    } else {
      await executor(command)
    }
  } catch (e) {
    show_error({ show_error: e.message || "Unknown error" })
    log('error', `executing '${found}' command`, e)
  }
}


// ShowErrorCommand ----------------------------------------------------------------------------------
export interface ShowErrorCommand {
  show_error: string
}
export async function show_error({ show_error }: ShowErrorCommand) {
  alert(show_error || 'Unknown error')
}
register_executor("show_error", show_error)


// ConfirmCommand --------------------------------------------------------------------------------
export interface ConfirmCommand {
  confirm:  object // Command to execute
  message?: string
}
export async function confirm({ confirm: command, message }: ConfirmCommand) {
  if (window.confirm(message || 'Are you sure?')) await execute_command(command)
}
register_executor("confirm", confirm)


// ExecuteCommand --------------------------------------------------------------------------------
// Execute command from another DOM element
export interface ExecuteCommand {
  execute: string // ID of DOM element
}
export async function execute({ execute: id }: ExecuteCommand) {
  const command = JSON.parse(find_by_id(id).ensure_attr('command'))
  execute_command(command)
}
register_executor("execute", execute)


// FlashCommand --------------------------------------------------------------------------------------
export interface FlashCommand {
  flash: string // ID of DOM element to flash
}
export async function flash({ flash: id }: FlashCommand) {
  find_by_id(id).flash()
}
register_executor("flash", flash)


// JsCommand -----------------------------------------------------------------------------------------
export interface JsCommand {
  eval_js: string
}
export async function eval_js({ eval_js }: JsCommand) {
  eval(eval_js)
}
register_executor("eval_js", eval_js)


// ReloadCommand -------------------------------------------------------------------------------------
export interface ReloadCommand {
  reload: boolean | string
}
export async function reload({ reload: url }: ReloadCommand) {
  const result = await fetch((typeof url == "boolean") ? window.location.href : url)
  if (!result.ok) {
    show_error({ show_error: `Unknown error, please reload page` })
    return
  }
  await update({ update: await result.text() })
}
register_executor("reload", reload)


// UpdateCommand ----------------------------------------------------------------------------------
// TODO 2 also add `location`
export interface UpdateCommand {
  update: string
  id?:    string
}
async function update(command: UpdateCommand) {
  let html = command.update
  function is_page(html: string) { return /<html/.test(html) }
  let flash = true // command.flash == true

  if (is_page(html)) {
    const match = html.match(/<head.*?><title>(.*?)<\/title>/)
    if (match) window.document.title = match[1]
    const bodyInnerHtml = html
      .replace(/^[\s\S]*<body[\s\S]*?>/, '')
      .replace(/<\/body[\s\S]*/, '')
      .replace(/<script[\s\S]*?script>/g, '')
      .replace(/<link[\s\S]*?>/g, '')
    smart_dom_update(document.body, bodyInnerHtml, flash)
    // find_one('body').set_content(bodyInnerHtml)
  } else {
    if (command.id) {
      // Updating single element with explicit ID
      build_one(html) // Ensuring there's only one element in partial
      smart_dom_update(find_by_id(command.id).native, html, flash)
      // if (command.flash) find_by_id(command.id).flash()
    } else {
      // Updating one or more elements with id specified implicitly in HTML chunks
      const $elements = build(html)
      for (const $el of $elements) {
        const id = $el.get_attr('id')
        if (!id) throw new Error(`explicit id or id in the partial required for update`)
        smart_dom_update(find_by_id(id).native, $el.native, flash)
        // if (command.flash) find_by_id(id).flash()
      }
    }
  }
}
register_executor("update", update)
register_executor("flash/update", update) // To resolve conflict with the `flash` command


// RedirectCommand ---------------------------------------------------------------------------------
export type RedirectCommand =
  { redirect: string, page: string } |
  { redirect: string, method?: 'get' | 'post' }

export async function redirect(command: RedirectCommand) {
  const { redirect: path } = command
  const url: string = /^\//.test(path) ? window.location.origin + path : path

  function update_history() {
    window.history.pushState({}, '', url)
    skip_reload_on_location_change = parse_location(url)
    on_location_change()
  }

  if ('page' in command) {
    await update({ update: command.page })
    update_history()
  } else if ('method' in command) {
    let method = command.method || 'get'
    if (method == 'get') {
      // await is important, we need to wait untill the page is updated,
      // because next command may ask to flash some of the new elements
      // and expect it to be in the DOM
      const result = await fetch(url || window.location.href)
      if (!result.ok) {
        show_error({ show_error: `Unknown error, please reload page` })
        return
      }
      await update({ update: await result.text() })
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


// ActionCommand -----------------------------------------------------------------------------------
// Sending action to server
export interface ActionCommand {
  action:   string
  args?:    object
  state?:   boolean
}

export async function action(command: ActionCommand, transport: Transport) {
  let args       = command.args || {}
  let location   = '' + window.location.href
  let with_state = 'state' in command ? command.state : false
  let state      = with_state ? get_state() : {}

  // Sending action to server
  log("info", `sending ${command.action}`)
  transport.send({
    action: command.action,
    ...args,
    ...state,
    location
  })
}

export async function on_server_command(message: object) {
  // Processing commands sent from server
  let commands = message instanceof Array ? message : [message]
  log("info", `received ${commands.length} commands`)
  for (const command of commands) await execute_command(command)
}

export function register_action_executor(transport: Transport) {
  register_executor("action", (command) => action(command as ActionCommand, transport))
  transport.on(on_server_command)
}


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
    ) await reload({ reload: true })
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