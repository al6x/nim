import supportm, stringm, os, seqm, sets, docm, jsonm, rem, tablem

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

# colors -------------------------------------------------------------------------------------------
proc green(s: string): string = "\e[32m" & s & "\e[0m"
proc grey(s: string): string = "\e[90m" & s & "\e[0m"

proc yellow(s: string): string = "\e[33m" & s & "\e[0m"
proc red(s: string): string = "\e[31m" & s & "\e[0m"


# Log ----------------------------------------------------------------------------------------------
type Log* = object
  component*: string
  data*:      JsonNode


proc init*(_: type[Log], component: string): Log =
  Log(component: component)


proc format_component(log: Log): string
proc format_data(log: Log): string
proc format_message(log: Log, message: string): string


proc with*(log: Log, data: tuple): Log =
  var log = log
  if log.data.is_nil: log.data = new_JObject()
  # Merging new data with existing
  for key, value in (% data).fields: log.data.fields[key] = value
  log


proc debug*(log: Log, message: string): void =
  if log_config.is_enabled(log.component, "debug"):
    echo grey fmt"  {log.format_component()}{log.format_message(message)}{log.format_data()}"


proc info*(log: Log, message: string): void =
  if log_config.is_enabled(log.component, "info"):
    let message = fmt"  {log.format_component()}{log.format_message(message)}{log.format_data()}"
    if log_config.is_debug(log.component): echo grey message
    else:                                  echo message


proc warn*(log: Log, message: string): void =
  if log_config.is_enabled(log.component, "warn"):
    echo yellow fmt"W {log.format_component()}{log.format_message(message)}{log.format_data()}"


proc error*(log: Log, message: string): void =
  if log_config.is_enabled(log.component, "error"):
    stderr.write_line red fmt"E {log.format_component()}{log.format_message(message)}{log.format_data()}"


proc error*(log: Log, message: string, exception: ref Exception): void =
  if log_config.is_enabled(log.component, "error"):
    stderr.write_line red fmt"E {log.format_component()}{log.format_message(message)}{log.format_data()}"
    stderr.write_line red exception.get_stack_trace()


# Shortcuts ----------------------------------------------------------------------------------------
proc debug*(message: string): void = Log.init("Main").debug(message)

proc info*(message: string): void = Log.init("Main").info(message)

proc warn*(message: string): void = Log.init("Main").warn(message)

proc error*(message: string): void = Log.init("Main").error(message)

proc error*(message: string, exception: ref Exception): void = Log.init("Main").error(message, exception)


# Utils --------------------------------------------------------------------------------------------
proc format_component(log: Log): string =
  let truncated = if log.component.len > 3: log.component[0..3] else: log.component
  fmt"{truncated.to_lower.align(4)} | "


proc format_data(log: Log): string =
  if log_config.log_data:
    if log.data.is_nil: " | {}" else: " | " & log.data.to_json(pretty = false)
  else:
    ""


let keyre = re"(\{[a-zA-Z0-9_]+\})"
proc format_message(log: Log, message: string): string =
  message.replace(keyre, proc (skey: string): string =
    if log.data.is_nil: skey
    else:
      assert log.data.kind == JObject
      let key = skey[1..^2]
      if key in log.data.fields:
        let value = log.data.fields[key]
        if value.kind == JString: value.get_str
        else:                     $(value)
      else:                      skey
  )


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let log = Log.init("Finance")
  log.with((symbol: "MSFT", currency: "USD")).info("getting prices for {symbol} in {currency}")

  # Chaining
  log.with((symbol: "MSFT",)).with((currency: "USD",)).info("getting prices for {symbol} in {currency}")