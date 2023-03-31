import std/[sugar, options]
import ./log, ./setm, ./env as envm, ./re as rem, ./json, ./stringm, ./seqm, ./terminal, ./table, ./stringm

type ConsoleLog = ref object
  disable_logs: HashSet[string]
  log_as_debug: HashSet[string]
  # log_data:     bool

let console_log = ConsoleLog(
  # List of modules and levels to hide, separated by comma, case insensitive,
  # could be "HTTP" or "debug" or "HTTP_debug"
  disable_logs: env["disable_logs", ""].to_lower.split(",").filter((s) => not s.is_empty).to_hash_set,
  # List of modules that will be logged with debug level, separated by comma, case insensitive,
  # could be "HTTP" or "HTTP,DB"
  log_as_debug: env["log_as_debug", ""].to_lower.split(",").filter((s) => not s.is_empty).to_hash_set,
  # log_data:     env["log_data", "false"].parse_bool,
)

const max_module_len = 4
const max_id_len = 7
const module_id_delimiter = " | "
const indent_len = 2 + max_module_len + max_id_len + 1 + module_id_delimiter.len
const indent = "".align_left(indent_len)

proc is_enabled(self: ConsoleLog, module: string, level: LogLevel): bool =
  let (c, l) = (module.to_lower, $level)
  not (c in self.disable_logs or l in self.disable_logs or fmt"{c}.{l}" in self.disable_logs)

proc is_debug(self: ConsoleLog, module: string): bool =
  module.to_lower in self.log_as_debug

proc format_module(module: string): string =
  # let truncated = if module.len > max_module_len:
  #   module[0..<max_module_len]
  # else:
  #   module
  module.take(max_module_len).to_lower.align(max_module_len)

proc format_id(id: seq[string]): string =
  let sid = id.join(".")
  # let truncated = if sid.len > max_module_len: sid[0..<max_module_len] else: sid
  sid.take(max_id_len).align_left(max_id_len)

proc format_data(data: JsonNode): string =
  var data = data.copy
  if true: #console_log.log_data:
    # if data.is_nil: " | {}" else: " | " & data.to_s(false)
    if "exception" in data:
      data.delete("exception")
    if "stack" in data:
      data.delete("stack")
    let json = data.to_s
    if json != "{}":
      let clean_json = json
        .replace(re"^\{\n|\n\}$", "")
        .replace(re",\n  ", ",\n")
        .replace(re("\"([^\"]+)\": "), (match) => match & ": ")
        .trim
      let oneline_json = clean_json.replace(re",[\n\s]+", ", ")
      return if oneline_json.len < 50:
        (" " & oneline_json).grey
      else:
        ("\n" & clean_json).replace("\n", "\n" & indent).grey
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
        else:                     $value
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
    format_module(m.module.get("")) & module_id_delimiter &
    format_id(m.id.get(seq[string].init)) & " " &
    format_message(data, m.message) &
    format_data(data)

  # Formatting level
  case m.level
  of debug:
    echo "  " & line.grey
  of info:
    let as_grey = console_log.is_debug(m.module.get(""))
    echo "  " & (if as_grey: line.grey else: line)
  of warn:
    echo ("W " & line).yellow
  of error:
    stderr.write_line ("E " & line).red

  # Printing exception and stack if exist
  if "exception" in data:
    let exception = try: data["exception"].get_str except: "can't get exception"
    stderr.write_line (indent & exception).replace("\n", "\n" & indent).red
  if "stack" in data:
    let stack = try: data["stack"].get_str except: "can't get stack"
    stderr.write_line (indent & stack).replace("\n", "\n" & indent).grey

# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  log_emitters.add(emit_to_console)

  # console_log.log_data = true
  let log = Log.init "Finance"
  log.with((id: "MSFT", currency: "USD")).info("getting prices in {currency}")
  log.id("MSFT").with((currency: "USD",)).info("getting prices in {currency}")

  # Chaining
  log.with((id: "MSFT",)).with((currency: "USD",)).info("getting prices in {currency}")

  log.id("MSFT").warn "no response"

  # Printing stack trace
  try:
    raise Exception.new_exception("some error")
  except Exception as e:
    log.id("MSFT").error("can't get price", e)