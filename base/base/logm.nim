import sugar
import ./supportm, ./stringm, ./seqm, ./sets, ./docm, ./jsonm, ./rem, ./tablem, ./terminalm,
  options, ./envm, ./tuplem

todo "Alter get_env to use env.yml in current dir"

# Override log_method to provide custom logging

# LogConfig ----------------------------------------------------------------------------------------
type LogConfig* = ref object
  disable_logs: HashSet[string]
  log_as_debug: HashSet[string]
  log_data:     bool

let log_config = LogConfig(
  # List of components and levels to hide, separated by comma, case insensitive,
  # could be "HTTP" or "debug" or "HTTP_debug"
  disable_logs: env["disable_logs", ""].to_lower.split(",").filter((s) => not s.is_empty).to_hash_set,
  # List of components that will be logged with debug level, separated by comma, case insensitive,
  # could be "HTTP" or "HTTP,DB"
  log_as_debug: env["log_as_debug", ""].to_lower.split(",").filter((s) => not s.is_empty).to_hash_set,
  log_data:     env["log_data", "false"].parse_bool,
)

proc is_enabled(config: LogConfig, component: string, level: string): bool =
  let (c, l) = (component.to_lower, level.to_lower)
  not (c in config.disable_logs or l in config.disable_logs or fmt"{c}.{l}" in config.disable_logs)

proc is_debug(config: LogConfig, component: string): bool =
  component.to_lower in config.log_as_debug


# Log ----------------------------------------------------------------------------------------------
type Log* = ref object
  component*:  string
  ids*:        seq[string]
  data*:       JsonNode


proc init*(_: type[Log], component: string): Log =
  Log(component: component)


# log.is_empty -------------------------------------------------------------------------------------
proc is_empty*(log: Log): bool =
  log.data.is_nil or log.data.len == 0


# log.with -----------------------------------------------------------------------------------------
proc with*(log: Log, msg: tuple): Log =
  var log = log.copy
  # Merging new data with existing
  if log.data.is_nil: log.data = new_JObject()
  for key, value in msg.field_pairs:
    if key == "id": log.ids.add $value
    if key == "ids":
      when value is seq:
        for id in value: log.ids.add $id
    log.data.fields[key] = value.to_json
  log

proc with*(log: Log, id: string | int): Log =
  var log = log.copy
  # Merging new id with existing
  log.ids.add $id
  log

proc with*(log: Log, error: ref Exception): Log =
  log.with((error: error.message, stack: error.get_stack_trace))


# log_method ---------------------------------------------------------------------------------------
proc format_component(component: string): string
proc format_ids(ids: seq[string]): string
proc format_data(data: JsonNode): string
proc format_message(data: JsonNode, msg: string): string

proc default_log_method(log: Log): void =
  # Detecting level and message
  var level = ""; var msg = ""
  for l in ["debug", "info", "warn", "error"]:
    if l in log.data:
      level = l; msg = try: log.data[l].get_str except: "invalid log message type"
      break
  if level == "":
    default_log_method(log.with((warn: "invalid log message, no level")))
    return

  # Checking config
  if not log_config.is_enabled(log.component, level): return

  # Formatting message
  let line =
    format_component(log.component) &
    format_ids(log.ids) &
    format_message(log.data, msg) &
    format_data(log.data)

  # Formatting level
  case level
  of "debug":
    echo "  " & line.grey
  of "info":
    let as_grey = log_config.is_debug(log.component)
    echo "  " & (if as_grey: line.grey else: line)
  of "warn":
    echo ("W " & line).yellow
  of "error":
    stderr.write_line ("E " & line).red

  # Printing exception and stack if exist
  if "exception" in log.data:
    let exception = try: log.data["exception"].get_str except: "can't get exception"
    stderr.write_line "\n" & exception.red
  if "stack" in log.data:
    let stack = try: log.data["stack"].get_str except: "can't get stack"
    stderr.write_line "\n" & stack

var log_method* = default_log_method # Override to provide custom logging


# log.message, debug, info, warn, error ------------------------------------------------------------
# proc message*(log: Log): void =
#   if log.data.len == 0: return
#   log_method(log)

proc message*(log: Log, msg: tuple): void =
  log_method(log.with(msg))

proc debug*(log: Log, msg: string): void =
  log.message((debug: msg))

proc info*(log: Log, msg: string): void =
  log.message((info: msg))

proc warn*(log: Log, msg: string): void =
  log.message((warn: msg))

proc warn*(log: Log, msg: string, exception: ref Exception): void =
  log.message((warn: msg, exception: exception.message, stack: exception.get_stack_trace))

proc error*(log: Log, msg: string): void =
  log.message((error: msg))

proc error*(log: Log, msg: string, exception: ref Exception): void =
  log.message((error: msg, exception: exception.message, stack: exception.get_stack_trace))


# LogFn --------------------------------------------------------------------------------------------
type LogFn* = proc (log: Log): void

converter to_logfn*(info_msg: string): LogFn =
  return proc (log: Log) = log.info(info_msg)

converter to_logfn*(msg: tuple): LogFn =
  return proc (log: Log) = log.message(msg)

# proc logfn*(log: Log, logfn: LogFn): void =
#   if logfn.is_nil: return
#   logfn(log)

# Shortcuts ----------------------------------------------------------------------------------------
proc debug*(message: string): void = Log.init("").debug(message)

proc info*(message: string): void = Log.init("").info(message)

proc warn*(message: string): void = Log.init("").warn(message)

proc error*(message: string): void = Log.init("").error(message)

proc error*(message: string, error: ref Exception): void = Log.init("").error(message, error)


# Utils --------------------------------------------------------------------------------------------
proc format_component(component: string): string =
  let max_len = 4
  let truncated = if component.len > max_len: component[0..<max_len]
  else:                                       component
  fmt"{truncated.to_lower.align(max_len)} | "


proc format_ids(ids: seq[string]): string =
  if ids.is_empty: return ""

  proc format_id(id: string): string =
    let max_len = 7
    let truncated = if id.len > max_len: id[0..<max_len] else: id
    fmt"{truncated.to_lower.align_left(max_len)} "

  ids.map(format_id).join(", ")


proc format_data(data: JsonNode): string =
  if log_config.log_data:
    if data.is_nil: " | {}" else: " | " & data.to_s
  else:
    ""

proc format_message(data: JsonNode, msg: string): string =
  let keyre = re"(\{[a-zA-Z0-9_]+\})"
  msg.replace(keyre, proc (skey: string): string =
    let value = if data.is_nil: skey
    else:
      assert data.kind == JObject
      let key = skey[1..^2]
      if key in data.fields:
        let value = data.fields[key]
        if value.kind == JString: value.get_str
        else:                     value.to_s
      else:                      skey
    value.replace("\n", " ")
  )


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let log = Log.init("Finance")
  log.with((symbol: "MSFT", currency: "USD")).info("getting prices for {symbol} in {currency}")

  # Chaining
  log.with((symbol: "MSFT",)).with((currency: "USD",)).info("getting prices for {symbol} in {currency}")

  # Printing stack trace
  try:
    throw "some error"
  except Exception as e:
    log.with((symbol: "MSFT",)).error("can't get price for {symbol}", e)