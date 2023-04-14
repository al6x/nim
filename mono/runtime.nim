import base, ext/ring_buffer, ../web/app
import ../page

type Element* = ref object of RootObj

type View* = ref object of RootObj
  last_ui*: Element

# proc update

type LogsView = ref object of View


type GlobaslView = ref object of View


type Tabs = enum globals, logs
type RuntimeView = ref object of View
  active_tab: Tabs


type Runtime = ref object of App
  logs:       RingBuffer[LogMessage]

method process*(self: Runtime, event: InEvent): Option[OutEvent] =
  OutEvent(kind: eval, code: fmt"console.log('ok', {event.to_json.to_s(false)})").some

proc init(tself: type[Runtime], logs_cap = 1000): Runtime =
  let runtime = Runtime(logs: RingBuffer.init(logs_cap))
  log_emitters.add (m) => runtime.logs.add(m)
  runtime

method run(app: Runtime) =
  throw "not implemented"

if is_main_module:
  let apps = Apps()
  apps[]["runtime"] = proc: App = Runtime()
  run_page(apps, port = 8080)