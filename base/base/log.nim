import std/[options]
import ./json, ./enumm, ./option, ./tuplem, ./table

type LogLevel* = enum debug, info, warn, error
autoconvert LogLevel

type LogMessage* = object
  level*:   LogLevel
  message*: string
  module*:  Option[string]
  id*:      Option[seq[string]]
  data*:    Option[JsonNode]

type Log* = object
  module*:  Option[string]
  lid*:     Option[seq[string]]
  level*:   Option[LogLevel]
  message*: Option[string]
  data*:    Option[JsonNode]

var log_emitters*: seq[proc(message: LogMessage): void] # it's possible to add custom emitters

proc init*(tself: type[Log], module: string, id: string): Log =
  Log(module: module.some, lid: @[id].some)

proc init*(tself: type[Log], module: string): Log =
  Log(module: module.some)

proc init*(tself: type[Log]): Log =
  Log()

proc id*(self: Log, id: seq[string] | seq[int]): Log =
  var log = self
  if log.lid.is_empty: log.lid = (new_seq[string]()).some
  for v in id: log.lid.get.add $v
  log

proc id*(self: Log, id: string | int): Log =
  self.id @[id]

proc with*(self: Log, msg: tuple): Log =
  # Merging new data with existing
  var log = self
  for key, value in msg.field_pairs:
    if key == "module":
      assert log.module.is_empty, "module already defined"
      assert value is string, "module should be string"
      log.module = ($value).some
    elif key == "id":
      log = log.id $value
    elif key == "level":
      assert log.level.is_empty, "level already defined"
      log.level = ($value).LogLevel.some
    elif key == "message":
      assert log.message.is_empty, "message already defined"
      assert value is string, "message should be string"
      log.message = ($value).some
    else:
      if log.data.is_empty: log.data = new_JObject().some
      log.data.get.fields[key] = value.to_json
  log

proc with*[T](self: Log, data: T): Log =
  var log = self
  let json_data = data.to_json
  assert json_data.kind == JObject, "object required"
  if log.data.is_empty: log.data = new_JObject().some
  for k, v in json_data.fields: log.data.get[k] = v
  log

proc with*(self: Log, id: string | int): Log =
  var log = self.copy
  if log.id.is_none: log.id = seq[string].init.some
  log.id.get.add $id # Merging new id with existing
  log

proc with*(self: Log, error: ref Exception): Log =
  self.with((level: LogLevel.error, error: error.msg.some, stack: error.get_stack_trace))


# debug, info, warn, error -------------------------------------------------------------------------
proc emit*(self: Log, msg: tuple): void =
  let log = self.with(msg)
  let level = log.level.ensure("log level required")
  let message = log.message.ensure("log message required")
  for e in log_emitters:
    e(LogMessage(level: level, message: message, module: log.module, id: log.lid, data: log.data))

proc debug*(self: Log, msg: string): void =
  self.emit((level: LogLevel.debug, message: msg))

proc info*(self: Log, msg: string): void =
  self.emit((level: LogLevel.info, message: msg))

proc warn*(self: Log, msg: string): void =
  self.emit((level: LogLevel.warn, message: msg))

proc warn*(self: Log, msg: string, exception: ref Exception): void =
  self.emit((level: LogLevel.warn, message: msg, exception: exception.msg, stack: exception.get_stack_trace))

proc error*(self: Log, msg: string): void =
  self.emit((level: LogLevel.error, message: msg))

proc error*(self: Log, msg: string, exception: ref Exception): void =
  self.emit((level: LogLevel.error, message: msg, exception: exception.msg, stack: exception.get_stack_trace))


# Shortcuts ----------------------------------------------------------------------------------------
proc debug*(message: string): void = Log.init("").debug(message)

proc info*(message: string): void = Log.init("").info(message)

proc warn*(message: string): void = Log.init("").warn(message)

proc error*(message: string): void = Log.init("").error(message)

proc error*(message: string, error: ref Exception): void = Log.init("").error(message, error)