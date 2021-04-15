import { p, something, log } from 'bon/base.ts'
import { $ } from './tquery.ts'
import { execute_command } from './commands.ts'


// Input events ------------------------------------------------------------------------------------
const events = [
  'touchstart', 'touchend',
  'click', 'dblclick', 'blur', 'focus',
  'change', 'submit',
  'keydown', 'keypress', 'keyup'
]

for(const event of events) {
  const command_attr = `on_${event}`
  $(document).on(event as something, `*[${command_attr}]`, ($e) => {
    const command = JSON.parse($e.current_target.ensure_attr(command_attr))
    execute_command(command, $e)
  })
}


// Error handling ----------------------------------------------------------------------------------
window.addEventListener('error', (event) => {
  alert(`Unknown error`)
  if (event instanceof ErrorEvent) log('error', `unknown error`, event.error)
  else                             log('error', `unknown error`, "unknown error event")
})

window.addEventListener("unhandledrejection", (event) => {
  alert(`Unknown async error`)
  log('error', `unknown async error`, "" + event)
})