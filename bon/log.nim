import ./support, strformat, os, strutils, sets

todo "Alter get_env to use env.yml in current dir"

type LogConfig* = object
  disable: HashSet[string]

let log_config = LogConfig(
  # List of components and levels to hide, separated by comma, case insensitive,
  # could be "HTTP" or "debug" or "HTTP_debug"
  disable: get_env("disable_logs", "").to_lower.split(",").to_hash_set
)

proc is_enabled(config: LogConfig, component: string, level: string): bool =
  let c = component.to_lower; let l = level.to_lower; let cl = fmt"{c}.{l}"
  not (c in config.disable or l in config.disable or cl in config.disable)

type Log* = object
  component*: string
  prefixes*:  seq[string]

proc format_component(component: string): string =
  let truncated = if component.len > 3: component[0..3] else: component
  fmt"{truncated.to_lower.align(4)} | "

proc format_prefixes(prefixes: seq[string]): string =
  if prefixes.is_empty: ""
  else:                 prefixes.join("], [") & " "

proc debug*(log: Log, message: string): void =
  if log_config.is_enabled(log.component, "debug"):
    echo fmt"  {format_component(log.component)}{format_prefixes(log.prefixes)}{message}"

proc info*(log: Log, message: string): void =
  if log_config.is_enabled(log.component, "info"):
    echo fmt"  {format_component(log.component)}{format_prefixes(log.prefixes)}{message}"

proc warn*(log: Log, message: string): void =
  if log_config.is_enabled(log.component, "warn"):
    echo fmt"W {format_component(log.component)}{format_prefixes(log.prefixes)}{message}"

proc error*(log: Log, message: string): void =
  if log_config.is_enabled(log.component, "error"):
    stderr.write_line fmt"E {format_component(log.component)}{format_prefixes(log.prefixes)}{message}"

proc error*(log: Log, message: string, exception: ref Exception): void =
  if log_config.is_enabled(log.component, "error"):
    stderr.write_line fmt"E {format_component(log.component)}{format_prefixes(log.prefixes)}{message}"
    stderr.write_line exception.get_stack_trace()