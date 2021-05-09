import supportm, stringm, os, seqm, sets, docm, jsonm, rem, tablem, terminalm, options

todo "Alter get_env to use env.yml in current dir"


# LogConfig ----------------------------------------------------------------------------------------
type LogConfig* = object
  disable_logs: HashSet[string]
  log_as_debug: HashSet[string]
  log_data:     bool

let log_config = LogConfig(
  # List of components and levels to hide, separated by comma, case insensitive,
  # could be "HTTP" or "debug" or "HTTP_debug"
  disable_logs: get_env("disable_logs", "").to_lower.split(",").to_hash_set,
  # List of components that will be logged with debug level, separated by comma, case insensitive,
  # could be "HTTP" or "HTTP,DB"
  log_as_debug: get_env("log_as_debug", "").to_lower.split(",").to_hash_set,
  log_data:     get_env("log_data", "false").parse_bool,
)

proc is_enabled(config: LogConfig, component: string, level: string): bool =
  let (c, l) = (component.to_lower, level.to_lower)
  let cl = fmt"{c}.{l}"
  not (c in config.disable_logs or l in config.disable_logs or cl in config.disable_logs)

proc is_debug(config: LogConfig, component: string): bool =
  component.to_lower in config.log_as_debug


# Log ----------------------------------------------------------------------------------------------
type Log* = object
  component*: string
  id*:        Option[string]
  data*:      JsonNode


proc init*(_: type[Log], component: string): Log =
  Log(component: component, id: string.none)
proc init*(_: type[Log], component, id: string): Log =
  Log(component: component, id: id.some)


proc format_id(log: Log): string
proc format_component(log: Log): string
proc format_data(log: Log): string
proc format_message(log: Log, message: string): string


proc with*(log: Log, data: tuple): Log =
  var log = log
  if log.data.is_nil: log.data = new_JObject()
  # Merging new data with existing
  for key, value in data.field_pairs: log.data.fields[key] = value.to_json
  log


proc with*(log: Log, error: ref Exception): Log =
  log.with((error: error.message, trace: error.get_stack_trace))


proc debug*(log: Log, message: string): void =
  if not log_config.is_enabled(log.component, "debug"): return
  let message = log.format_component() & log.format_id() & log.format_message(message) & log.format_data()
  echo "  " & message.grey


proc info*(log: Log, message: string): void =
  if not log_config.is_enabled(log.component, "info"): return
  let message = log.format_component() & log.format_id() & log.format_message(message) & log.format_data()
  if log_config.is_debug(log.component): echo "  " & message.grey
  else:                                  echo "  " & message


proc warn*(log: Log, message: string): void =
  if not log_config.is_enabled(log.component, "warn"): return
  let message = log.format_component() & log.format_id() & log.format_message(message) & log.format_data()
  echo ("W " & message).yellow

proc warn*(log: Log, message: string, exception: ref Exception): void =
  if not log_config.is_enabled(log.component, "warn"): return
  log.warn(message)
  stderr.write_line exception.get_stack_trace.red


proc error*(log: Log, message: string): void =
  if not log_config.is_enabled(log.component, "error"): return
  let message = log.format_component() & log.format_id() & log.format_message(message) & log.format_data()
  stderr.write_line ("E " & message).red

proc error*(log: Log, message: string, exception: ref Exception): void =
  if not log_config.is_enabled(log.component, "error"): return
  log.error(message)
  stderr.write_line exception.get_stack_trace.red


# Shortcuts ----------------------------------------------------------------------------------------
proc debug*(message: string): void = Log.init("Main").debug(message)

proc info*(message: string): void = Log.init("Main").info(message)

proc warn*(message: string): void = Log.init("Main").warn(message)

proc error*(message: string): void = Log.init("Main").error(message)

proc error*(message: string, exception: ref Exception): void =
  Log.init("Main").error(message, exception)


# Utils --------------------------------------------------------------------------------------------
proc format_component(log: Log): string =
  let max_len = 4; let component = log.component
  let truncated = if component.len > max_len: component[0..<max_len]
  else:                                       component
  fmt"{truncated.to_lower.align(max_len)} | "


proc format_id(log: Log): string =
  if log.id.is_none: return ""
  let max_len = 7; let id = log.id.get
  let truncated = if id.len > max_len: id[0..<max_len] else: id
  fmt"{truncated.to_lower.align_left(max_len)} "


proc format_data(log: Log): string =
  if log_config.log_data:
    if log.data.is_nil: " | {}" else: " | " & $(log.data.to_json)
  else:
    ""

proc format_message(log: Log, message: string): string =
  let keyre = re"(\{[a-zA-Z0-9_]+\})"
  message.replace(keyre, proc (skey: string): string =
    let value = if log.data.is_nil: skey
    else:
      assert log.data.kind == JObject
      let key = skey[1..^2]
      if key in log.data.fields:
        let value = log.data.fields[key]
        if value.kind == JString: value.get_str
        else:                     $(value)
      else:                      skey
    value.replace("\n", " ")
  )


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let log = Log.init("Finance")
  log.with((symbol: "MSFT", currency: "USD")).info("getting prices for {symbol} in {currency}")

  # Chaining
  log.with((symbol: "MSFT",)).with((currency: "USD",)).info("getting prices for {symbol} in {currency}")