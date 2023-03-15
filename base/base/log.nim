import std/[sugar, options]
import ./support, ./stringm, ./seqm, ./setm, ./doc, ./json, ./re as rem, ./table, ./terminal, ./enumm, ./option,
  ./env as envm, ./tuplem

# Log ----------------------------------------------------------------------------------------------
type LogLevel* = enum debug, info, warning, error
autoconvert LogLevel

type LogMessage* = object
  level*:   LogLevel
  message*: string
  module*:  Option[string]
  id*:      Option[seq[string]]
  data*:    Option[JsonNode]

type Log* = object
  module*:  Option[string]
  id*:      Option[seq[string]]
  level*:   Option[LogLevel]
  message*: Option[string]
  data*:    Option[JsonNode]

var log_emitters*: seq[proc(message: LogMessage): void] # it's possible to add custom emitters

proc init*(tself: type[Log], module: string): Log =
  Log(module: module.some)

proc init*(tself: type[Log]): Log =
  Log()

proc with*(self: Log, msg: tuple): Log =
  # Merging new data with existing
  var log = self.copy
  for key, value in msg.field_pairs:
    if key == "module":
      assert log.module.is_empty, "module already defined"
      assert value is string, "module should be string"
      log.module = value.to_s.some
    elif key == "id":
      if log.id.is_empty: log.id = seq[string].init.some
      when value is seq:
        for id in value: log.id.get.add $id
      else:
        log.id.get.add $value
    elif key == "level":
      assert log.level.is_empty, "level already defined"
      log.level = value.to_s.LogLevel.some
    elif key == "message":
      assert log.message.is_empty, "message already defined"
      assert value is string, "message should be string"
      log.message = value.to_s.some
    else:
      if log.data.is_empty: log.data = new_JObject().some
      log.data.get.fields[key] = value.to_json
  log

proc with*(self: Log, data: JsonNode): Log =
  var log = self.copy
  assert data.kind == JObject, "object required"
  if log.data.is_empty: log.data = new_JObject().some
  for k, v in data.fields: log.data.get[k] = v
  log

proc with*(self: Log, id: string | int): Log =
  var log = self.copy
  if log.id.is_none: log.id = seq[string].init.some
  log.id.get.add $id # Merging new id with existing
  log

proc with*(self: Log, error: ref Exception): Log =
  self.with((level: LogLevel.error, error: error.message.some, stack: error.get_stack_trace))


# debug, info, warning, error -------------------------------------------------------------------------
proc emit*(self: Log, msg: tuple): void =
  let log = self.with(msg)
  let level = log.level.ensure("log level required")
  let message = log.message.ensure("log message required")
  for e in log_emitters:
    e(LogMessage(level: level, message: message, module: log.module, id: log.id, data: log.data))

proc debug*(self: Log, msg: string): void =
  self.emit((level: LogLevel.debug, message: msg))

proc info*(self: Log, msg: string): void =
  self.emit((level: LogLevel.info, message: msg))

proc warning*(self: Log, msg: string): void =
  self.emit((level: LogLevel.warning, message: msg))

proc warning*(self: Log, msg: string, exception: ref Exception): void =
  self.emit((level: LogLevel.warning, message: msg,
    exception: exception.message.trim, stack: exception.get_stack_trace.trim))

proc error*(self: Log, msg: string): void =
  self.emit((level: LogLevel.error, message: msg))

proc error*(self: Log, msg: string, exception: ref Exception): void =
  self.emit((level: LogLevel.error, message: msg,
    exception: exception.message.trim, stack: exception.get_stack_trace.trim))


# Shortcuts ----------------------------------------------------------------------------------------
proc debug*(message: string): void = Log.init("").debug(message)

proc info*(message: string): void = Log.init("").info(message)

proc warning*(message: string): void = Log.init("").warning(message)

proc error*(message: string): void = Log.init("").error(message)

proc error*(message: string, error: ref Exception): void = Log.init("").error(message, error)


# ConsoleLog ---------------------------------------------------------------------------------------
type ConsoleLog = ref object
  disable_logs: HashSet[string]
  log_as_debug: HashSet[string]
  log_data:     bool

let console_log = ConsoleLog(
  # List of modules and levels to hide, separated by comma, case insensitive,
  # could be "HTTP" or "debug" or "HTTP_debug"
  disable_logs: env["disable_logs", ""].to_lower.split(",").filter((s) => not s.is_empty).to_hash_set,
  # List of modules that will be logged with debug level, separated by comma, case insensitive,
  # could be "HTTP" or "HTTP,DB"
  log_as_debug: env["log_as_debug", ""].to_lower.split(",").filter((s) => not s.is_empty).to_hash_set,
  log_data:     env["log_data", "false"].parse_bool,
)

proc is_enabled(self: ConsoleLog, module: string, level: LogLevel): bool =
  let (c, l) = (module.to_lower, level.to_s)
  not (c in self.disable_logs or l in self.disable_logs or fmt"{c}.{l}" in self.disable_logs)

proc is_debug(self: ConsoleLog, module: string): bool =
  module.to_lower in self.log_as_debug

proc format_module(module: string): string =
  let max_len = 4
  let truncated = if module.len > max_len: module[0..<max_len]
  else:                                       module
  fmt"{truncated.to_lower.align(max_len)} | "

proc format_id(id: seq[string]): string =
  if id.is_empty: return ""

  proc format_id(id: string): string =
    let max_len = 7
    let truncated = if id.len > max_len: id[0..<max_len] else: id
    fmt"{truncated.align_left(max_len)} "

  id.map(format_id).join(", ")

proc format_data(data: JsonNode): string =
  if console_log.log_data:
    # if data.is_nil: " | {}" else: " | " & data.to_s(false)
    let s = data.to_s.trim.replace(re"^\{\n|\n\}$", "")
    if s != "{}": return ("\n" & s).replace("\n", "\n         ").grey
  ""

proc format_message(data: JsonNode, msg: string): string =
  let keyre = re"(\{[a-zA-Z0-9_]+\})"
  let resolved = msg.replace(keyre, proc (skey: string): string =
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
  resolved
  # if console_log.log_data: resolved & (" | " & msg).grey else: resolved

proc emit_to_console(m: LogMessage): void =
  # Detecting level and message
  # var level = ""; var msg = ""
  # for l in ["debug", "info", "warn", "error"]:
  #   if l in log.data:
  #     level = l; msg = try: log.data[l].get_str except: "invalid log message type"
  #     break
  # if level == "":
  #   message_to_console(log.with((warn: "invalid log message, no level")))
  #   return
  # let module = m.module.get("")
  let data = m.data.get(new_JObject())

  # Checking config
  if m.module.is_some and not console_log.is_enabled(m.module.get, m.level): return

  # Formatting message
  let line =
    format_module(m.module.get("")) &
    format_id(m.id.get(seq[string].init)) &
    format_message(data, m.message) &
    format_data(data)

  # Formatting level
  case m.level
  of debug:
    echo "  " & line.grey
  of info:
    let as_grey = console_log.is_debug(m.module.get(""))
    echo "  " & (if as_grey: line.grey else: line)
  of LogLevel.warning:
    echo ("W " & line).yellow
  of LogLevel.error:
    stderr.write_line ("E " & line).red

  # Printing exception and stack if exist
  if "exception" in data:
    let exception = try: data["exception"].get_str except: "can't get exception"
    stderr.write_line ("           " & exception).replace("\n", "\n           ").red
  if "stack" in data:
    let stack = try: data["stack"].get_str except: "can't get stack"
    stderr.write_line ("           " & stack).replace("\n", "\n           ").red

log_emitters.add(emit_to_console)


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  console_log.log_data = true
  let log = Log.init("Finance")
  log.with((symbol: "MSFT", currency: "USD")).info("getting prices for {symbol} in {currency}")

  # Chaining
  log.with((symbol: "MSFT",)).with((currency: "USD",)).info("getting prices for {symbol} in {currency}")

  # Printing stack trace
  try:
    throw "some error"
  except Exception as e:
    log.with((symbol: "MSFT",)).error("can't get price for {symbol}", e)


# LogFn --------------------------------------------------------------------------------------------
# type LogFn* = proc (log: Log): void

# converter to_logfn*(info_msg: string): LogFn =
#   return proc (log: Log) = log.info(info_msg)

# converter to_logfn*(msg: tuple): LogFn =
#   return proc (log: Log) = log.message(msg)

# proc logfn*(log: Log, logfn: LogFn): void =
#   if logfn.is_nil: return
#   logfn(log)

# proc is_empty*(log: Log): bool =
#   log.data.is_nil or log.data.len == 0
