import strformat, sequtils, sugar, strutils, re, std/math, json, ./supportm, hashes

from std/times as nt import nil

type
  Time* = object
    year*:  Natural
    month*: 1..12
    day*:   1..31
    hour*:  0..23
    min*:   0..59
    sec*:   0..59
    epoch*: int64 # Could be negative

  TimeD* = object
    year*:  Natural
    month*: 1..12
    day*:   1..31
    epoch*: int64 # Could be negative

  TimeM* = object
    year*:  Natural
    month*: 1..12
    epoch*: int64 # Could be negative


# Epoch --------------------------------------------------------------------------------------------
proc epoch_day(y: int, m: int, d: int): int64 =
  var y = y
  if m <= 2: y.dec

  let era = (if y >= 0: y else: y-399) div 400
  let yoe = y - era * 400
  let doy = (153 * (m + (if m > 2: -3 else: 9)) + 2) div 5 + d-1
  let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
  return era * 146097 + doe - 719468


proc epoch_sec*(year: int, month: int, day: int, hour: int, min: int, sec: int): int64 =
  let epoch_day = epoch_day(year, month, day)
  var seconds = epoch_day * day_sec
  seconds.inc hour * hour_sec
  seconds.inc min * 60
  seconds.inc sec
  seconds


# Time ---------------------------------------------------------------------------------------------
proc now*(_: type[Time]): Time = Time.init nt.utc(nt.now())

proc init*(_: type[Time], year: int, month: int, day: int, hour: int, min: int, sec: int): Time =
  let epoch = epoch_sec(year, month, day, hour, min, sec)
  Time(year: year, month: month, day: day, hour: hour, min: min, sec: sec, epoch: epoch)

proc init*(_: type[Time], t: nt.DateTime): Time =
  Time.init(t.year, t.month.ord, t.monthday, t.hour, t.minute, t.second)

proc init*(_: type[Time], epoch_sec: int64): Time =
  Time.init nt.utc(nt.fromUnix(epoch_sec))

let time_format = nt.init_time_format "yyyy-MM-dd HH:mm:ss"
proc init*(_: type[Time], time: string): Time =
  Time.init nt.parse(time, time_format, nt.utc())


proc `$`*(t: Time): string =
  # p d.format(time_format)
  t.year.align(4) & "-" & t.month.align(2)  & "-" & t.day.align(2) & " " &
  t.hour.align(2) & ":" & t.min.align(2)  & ":" &  t.sec.align(2)


proc `%`*(time: Time): JsonNode = %($time)
proc init_from_json*(dst: var Time, json: JsonNode, json_path: string) =
  dst = Time.init(json.get_str)


# TimeD --------------------------------------------------------------------------------------------
proc init*(_: type[TimeD], year: int, month: int, day: int): TimeD =
  let epoch = epoch_sec(year, month, day, 0, 0, 1)
  TimeD(year: year, month: month, day: day, epoch: epoch)

proc init*(_: type[TimeD], t: nt.DateTime): TimeD =
  TimeD.init(t.year, t.month.ord, t.monthday)

proc init*(_: type[TimeD], t: Time): TimeD =
  TimeD.init(t.year, t.month.ord, t.day)

let time_d_format = nt.init_time_format "yyyy-MM-dd"
proc init*(_: type[TimeD], time: string): TimeD =
  let t = nt.parse(time, time_d_format, nt.utc())
  let epoch = epoch_sec(t.year, t.month.ord, t.monthday, 0, 0, 1)
  TimeD(year: t.year, month: t.month.ord, day: t.monthday, epoch: epoch)


proc to*(t: Time, _: type[TimeD]): TimeD = TimeD.init t


proc now*(_: type[TimeD]): TimeD = Time.now.to TimeD


proc `$`*(t: TimeD): string = t.year.align(4) & "-" & t.month.align(2) & "-" & t.day.align(2)


proc `%`*(time: TimeD): JsonNode = %($time)
proc init_from_json*(dst: var TimeD, json: JsonNode, json_path: string) =
  dst = TimeD.init(json.get_str)


# TimeM --------------------------------------------------------------------------------------------
proc init*(_: type[TimeM], year: int, month: int): TimeM =
  let epoch = epoch_sec(year, month, 1, 0, 0, 1)
  TimeM(year: year, month: month, epoch: epoch)

proc init*(_: type[TimeM], t: Time | TimeD): TimeM = TimeM.init(t.year, t.month)


proc to*(t: Time, _: type[TimeM]): TimeM = TimeM.init t
proc to*(t: TimeD, _: type[TimeM]): TimeM = TimeM.init t


proc now*(_: type[TimeM]): TimeM = Time.now.to TimeM


let time_m_format = nt.init_time_format "yyyy-MM"
proc init*(_: type[TimeM], time: string): TimeM =
  let t = nt.parse(time, time_m_format, nt.utc())
  let epoch = epoch_sec(t.year, t.month.ord, 1, 0, 0, 1)
  TimeM(year: t.year, month: t.month.ord, epoch: epoch)


proc `$`*(t: TimeM): string = t.year.align(4) & "-" & t.month.align(2)


proc `%`*(time: TimeM): JsonNode = %($time)
proc init_from_json*(dst: var TimeM, json: JsonNode, json_path: string) =
  dst = TimeM.init(json.get_str)


test "epoch":
  proc nt_epoch(time: string): int64 =
    let format = nt.init_time_format "yyyy-MM-dd HH:mm:ss"
    let t = nt.parse(time, format, nt.utc())
    nt.to_unix(nt.to_time(t))

  assert nt_epoch("2000-01-01 01:01:01") == Time.init("2000-01-01 01:01:01").epoch
  assert nt_epoch("2002-02-01 01:01:01") == Time.init("2002-02-01 01:01:01").epoch

  assert nt_epoch("2000-01-01 00:00:01") == TimeD.init("2000-01-01").epoch
  assert nt_epoch("2002-02-01 00:00:01") == TimeD.init("2002-02-01").epoch

  assert nt_epoch("2000-01-01 00:00:01") == TimeM.init("2000-01").epoch
  assert nt_epoch("2002-02-01 00:00:01") == TimeM.init("2002-02").epoch


# Helpers ------------------------------------------------------------------------------------------

proc `<`*(a, b: Time | TimeD | TimeM): bool = a.epoch < b.epoch
proc `<=`*(a, b: Time | TimeD | TimeM): bool = a.epoch <= b.epoch

proc hash*(t: Time | TimeD | TimeM): Hash = t.epoch.hash

# proc `==`*(a: string, b: TimeM): bool = TimeM.init(a) == b
# proc `==`*(a: TimeM, b: string): bool = b == a

proc sec_to_min*(sec: int64): int64 = sec div 60
proc sec_to_hour*(sec: int64): int64 = sec div 3600
proc sec_to_day*(sec: int64): int64 = sec div (24 * 3600)





proc assert_yyyy_mm*(yyyy_mm: string): void =
  assert yyyy_mm.match(re"\d\d\d\d-\d\d"), fmt"date format is not yyyy-mm '{yyyy_mm}'"


proc assert_yyyy_mm_dd*(yyyy_mm_dd: string): void =
  assert yyyy_mm_dd.match(re"\d\d\d\d-\d\d-\d\d"), fmt"date format is not yyyy-mm-dd '{yyyy_mm_dd}'"


proc yyyy_mm_dd_to_ymd*(yyyy_mm_dd: string): tuple[y:int, m:int, d:int] =
  assert_yyyy_mm_dd yyyy_mm_dd
  let parts = yyyy_mm_dd.split('-').map((v) => v.parse_int)
  (parts[0], parts[1], parts[2])


proc yyyy_mm_to_ym*(yyyy_mm: string): tuple[y:int, m:int] =
  assert_yyyy_mm yyyy_mm
  let parts = yyyy_mm.split('-').map((v) => v.parse_int)
  (parts[0], parts[1])


proc yyyy_mm_to_m*(yyyy_mm: string, base_year: int): int =
  let (y, m) = yyyy_mm_to_ym yyyy_mm
  assert y >= base_year, fmt"year should be >= {base_year}"
  12 * (y - base_year) + m


proc to_yyyy_mm*(y: int, m: int): string =
  assert y > 0 and (m > 0 and m <= 12)
  let m_prefix = if m < 10: "0" else: ""
  fmt"{y}-{m_prefix}{m}"


proc to_yyyy_mm_dd(y: int, m: int, d: int): string =
  assert y > 0 and (m > 0 and m <= 12) and (d > 0 and d <= 31)
  let m_prefix = if m < 10: "0" else: ""
  let d_prefix = if d < 10: "0" else: ""
  fmt"{y}-{m_prefix}{m}-{d_prefix}{d}"


proc m_to_yyyy_mm*(m: int, base_year: int): string =
  to_yyyy_mm base_year + floor_div(m, 12), 1 + (m mod 12)


proc current_yyyy_mm*(): string =
  let d = nt.utc(nt.now())
  to_yyyy_mm d.year, d.month.ord


proc current_yyyy_mm_dd*(): string =
  let d = nt.utc(nt.now())
  to_yyyy_mm_dd d.year, d.month.ord, d.monthday

proc now_sec*(): int64 = nt.to_unix(nt.to_time(nt.utc(nt.now())))

# todo "Convert timestamps in JSON and other data to human readable format"
# let time_format = init_time_format "yyyy-MM-dd HH:mm:ss"
# let d = now().utc
# p d.format(time_format)
# p "2020-09-02 10:48:39".parse(time_format, utc())


