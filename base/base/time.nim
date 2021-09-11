from std/times as times import nil
import std/[sequtils, sugar, re as stdre]
import ./stringm, ./json, ./support, ./hash, ./math

with "Helpers":
  const day_hours*  = 24
  const day_min*    = 24 * 60
  const day_sec*    = 24 * 60 * 60

  const hour_min*   = 60
  const hour_sec*   = 60 * 60

  const minute_sec* = 60


  proc epoch_days(y: int, m: int, d: int): int =
    var y = y
    if m <= 2: y.dec

    let era = (if y >= 0: y else: y-399) div 400
    let yoe = y - era * 400
    let doy = (153 * (m + (if m > 2: -3 else: 9)) + 2) div 5 + d-1
    let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
    return era * 146097 + doe - 719468


  proc epoch_seconds*(year: int, month: int, day: int, hour: int, minute: int, second: int): int =
    let epoch_days = epoch_days(year, month, day)
    var seconds = epoch_days * day_sec
    seconds.inc hour * hour_sec
    seconds.inc minute * 60
    seconds.inc second
    seconds


type Time* = object
  year*:   Natural
  month*:  1..12
  day*:    1..31
  hour*:   0..23
  minute*: 0..59
  second*: 0..59
  epoch*:  int # in seconds, could be negative

with Time:
  proc init*(tself; year: int, month: int, day: int, hour: int, minute: int, second: int): Time =
    let epoch = epoch_seconds(year, month, day, hour, minute, second)
    Time(year: year, month: month, day: day, hour: hour, minute: minute, second: second, epoch: epoch)

  proc init*(tself; t: times.DateTime): Time = Time.init(
      times.year(t), times.month(t).ord, times.monthday(t),
      times.hour(t), times.minute(t), times.second(t)
    )

  proc init*(tself; epoch_seconds: int): Time =
    Time.init times.utc(times.fromUnix(epoch_seconds))

  let time_format = times.init_time_format "yyyy-MM-dd HH:mm:ss"
  proc init*(tself; time: string): Time =
    Time.init times.parse(time, time_format, times.utc())

  proc now*(tself): Time = Time.init times.utc(times.now())

  proc `$`*(self): string =
    self.year.align(4) & "-" & self.month.align(2)  & "-" & self.day.align(2) & " " &
    self.hour.align(2) & ":" & self.minute.align(2) & ":" & self.second.align(2)

  proc to_datetime*(self): times.DateTime =
    times.init_date_time(
      year = self.year, month = times.Month(self.month), monthday = self.day,
      hour = self.hour, minute = self.minute, second = self.second, nanosecond = 0,
      zone = times.utc()
    )

  test "to_datetime":
    let t = Time.now
    assert Time.init(t.to_datetime) == t

  json_as_string Time


type TimeD* = object
  year*:  Natural
  month*: 1..12
  day*:   1..31
  epoch*: int # in seconds, could be negative

with TimeD:
  proc init*(tself; year: int, month: int, day: int): TimeD =
    let epoch = epoch_seconds(year, month, day, 0, 0, 1)
    TimeD(year: year, month: month, day: day, epoch: epoch)

  proc init*(tself; t: times.DateTime): TimeD =
    TimeD.init(t.year, t.month.ord, t.monthday)

  proc init*(tself; t: Time): TimeD =
    TimeD.init(t.year, t.month.ord, t.day)

  let time_d_format = times.init_time_format "yyyy-MM-dd"
  proc init*(tself; time: string): TimeD =
    let t = times.parse(time, time_d_format, times.utc())
    let epoch = epoch_seconds(times.year(t), times.month(t).ord, times.monthday(t), 0, 0, 1)
    TimeD(year: times.year(t), month: times.month(t).ord, day: times.monthday(t), epoch: epoch)


  proc now*(tself): TimeD = Time.now.to TimeD


  proc `$`*(self): string = self.year.align(4) & "-" & self.month.align(2) & "-" & self.day.align(2)

  json_as_string TimeD


type TimeM* = object
  year*:  Natural
  month*: 1..12
  epoch*: int # in seconds, could be negative

with TimeM:
  proc init*(tself; year: int, month: int): TimeM =
    let epoch = epoch_seconds(year, month, 1, 0, 0, 1)
    TimeM(year: year, month: month, epoch: epoch)

  proc init*(tself; t: Time | TimeD): TimeM =
    TimeM.init(t.year, t.month)

  let time_m_format = times.init_time_format "yyyy-MM"
  proc init*(tself; time: string): TimeM =
    let t = times.parse(time, time_m_format, times.utc())
    let epoch = epoch_seconds(times.year(t), times.month(t).ord, 1, 0, 0, 1)
    TimeM(year: times.year(t), month: times.month(t).ord, epoch: epoch)

  proc now*(tself): TimeM = Time.now.to TimeM

  proc `$`*(self): string = self.year.align(4) & "-" & self.month.align(2)

  json_as_string TimeM


proc `<`*(a, b: Time | TimeD | TimeM): bool = a.epoch < b.epoch
proc `<=`*(a, b: Time | TimeD | TimeM): bool = a.epoch <= b.epoch


proc hash*(t: Time | TimeD | TimeM): Hash = t.epoch.hash


converter to_time*(t: (int, int, int, int, int, int)): Time = Time.init(t[0], t[1], t[2], t[3], t[4], t[5])
converter to_timed*(t: Time): TimeD = TimeD.init(t)
converter to_timed*(d: (int, int, int)): TimeD = TimeD.init(d[0], d[1], d[2])
converter to_timem*(m: (int, int)): TimeM = TimeM.init(m[0], m[1])


test "epoch":
  proc nt_epoch(time: string): int =
    let format = times.init_time_format "yyyy-MM-dd HH:mm:ss"
    let t = times.parse(time, format, times.utc())
    times.to_unix(times.to_time(t)).int

  assert nt_epoch("2000-01-01 01:01:01") == Time.init("2000-01-01 01:01:01").epoch
  assert nt_epoch("2002-02-01 01:01:01") == Time.init("2002-02-01 01:01:01").epoch

  assert nt_epoch("2000-01-01 00:00:01") == TimeD.init("2000-01-01").epoch
  assert nt_epoch("2002-02-01 00:00:01") == TimeD.init("2002-02-01").epoch

  assert nt_epoch("2000-01-01 00:00:01") == TimeM.init("2000-01").epoch
  assert nt_epoch("2002-02-01 00:00:01") == TimeM.init("2002-02").epoch


type TInterval* = object
  total_seconds*: int
  # minutes_part*: int
  # hours_part*:   int
  # days_part*:    int

with TInterval:
  proc init*(tself; seconds = 0, minutes = 0, hours = 0, days = 0): TInterval =
    TInterval(total_seconds: days * day_sec + hours * hour_sec + minutes * minute_sec + seconds)

  proc seconds*(self): int {.inline.} = self.total_seconds
  proc days*(self): float = self.seconds / day_sec
  proc hours*(self): float = self.seconds / hour_sec

  proc `+`*(self; other: TInterval): TInterval = TInterval.init(self.seconds + other.seconds)
  proc `-`*(self; other: TInterval): TInterval = TInterval.init(self.seconds - other.seconds)

  proc `<`*(self; other: TInterval): bool = self.seconds < other.seconds
  proc `<=`*(self; other: TInterval): bool = self.seconds <= other.seconds

  proc `*`*(self; multiplier: int): TInterval = TInterval.init(self.seconds * multiplier)
  proc `/`*(self; multiplier: int): TInterval = TInterval.init((self.seconds / multiplier).round.int)


proc seconds*(s: int): TInterval = TInterval.init(s)
proc minutes*(m: int): TInterval = TInterval.init(0, m)
proc hours*(h: int): TInterval   = TInterval.init(0, 0, h)
proc days*(d: int): TInterval    = TInterval.init(0, 0, 0, d)


proc `-`*(t: Time, i: TInterval): Time =
  Time.init(t.epoch - i.seconds)

test "-":
  assert (Time.init("2001-03-01 00:00:01") - 2.seconds) == Time.init("2001-02-28 23:59:59")


proc `-`*(a: Time | TimeD | TimeM, b: Time | TimeD | TimeM): TInterval =
  TInterval.init(a.epoch - b.epoch)

test "-":
  assert (TimeD.init(2001, 3, 1) - TimeD.init(2001, 1, 1)).days =~ 59.0
  assert (TimeM.init(2001, 3) - TimeD.init(2001, 1, 1)).days =~ 59.0
  assert (TimeD.init(2001, 1, 1) - TimeM.init(2001, 3)).days =~ -59.0


proc `+`*(t: Time, ti: TInterval): Time =
  Time.init(t.epoch + ti.seconds)

proc `-`*(t: Time, ti: TInterval): Time =
  Time.init(t.epoch - ti.seconds)

test "days":
  assert 12.hours.days =~ 0.5
  assert 2.minutes.seconds == 120


type CInterval* = object
  # seconds_part*: int
  # minutes_part*: int
  # hours_part*:   int
  # days_part*:    int
  # seconds_part*: int
  months_part*:  int
  years_part*:   int

with CInterval:
  proc init*(tself; months = 0, years = 0): CInterval =
    CInterval(months_part: months, years_part: years)

proc years*(y: int): CInterval   = CInterval.init(0, y)
proc months*(m: int): CInterval  = CInterval.init(m)

proc `+`*(t: TimeM, ti: CInterval): TimeM =
  # assert ti.days_part == 0
  # assert ti.hours_part == 0
  # assert ti.minutes_part == 0
  # assert ti.seconds_part == 0
  let mcount = t.month + ti.months_part
  var years  = t.year + ti.years_part + (mcount div 12)
  var months = mcount mod 12
  if months == 0:
    years  -= 1
    months = 12
  TimeM.init(years, months)

test "+":
  assert (TimeM.init(2001, 1)  + 2.months)  == TimeM.init(2001, 3)
  assert (TimeM.init(2001, 1)  + 12.months) == TimeM.init(2002, 1)
  assert (TimeM.init(2001, 1)  + 14.months) == TimeM.init(2002, 3)
  assert (TimeM.init(2001, 11) + 1.months)  == TimeM.init(2001, 12)
  assert (TimeM.init(2001, 11) + 13.months) == TimeM.init(2002, 12)


proc format_humanized(days, hours, minutes, seconds: int, short: bool): string =
  var buff: seq[string] = @[]
  if days > 0:    buff.add($days &    (if short: "d" else: " " & days.pluralize("day")))
  if hours > 0:   buff.add($hours &   (if short: "h" else: " " & hours.pluralize("hour")))
  if minutes > 0: buff.add($minutes & (if short: "m" else: " " & minutes.pluralize("min")))
  if seconds > 0: buff.add($seconds & (if short: "s" else: " " & seconds.pluralize("second")))
  buff.join(" ")

proc humanize_impl*(seconds: int, round = false, short = true): string =
  if round:
    let days = (seconds.float / day_sec.float).round.int
    if days > 0: format_humanized(days, 0, 0, 0, short)
    else:
      let hours = (seconds.float / hour_sec.float).round.int
      if hours > 0: format_humanized(0, hours, 0, 0, short)
      else:
        let minutes = (seconds.float / minute_sec.float).round.int
        if minutes > 0: format_humanized(0, 0, minutes, 0, short)
        else:
          format_humanized(0, 0, 0, seconds, short)
  else:
    let (days,    left_after_days)    = seconds.div_rem(day_sec)
    let (hours,   left_after_hours)   = left_after_days.div_rem(hour_sec)
    let (minutes, left_after_minutes) = left_after_hours.div_rem(minute_sec)
    let seconds                       = left_after_minutes
    format_humanized(days, hours, minutes, seconds, short)


proc humanize*(self: TInterval, round = true, short = false): string =
  self.seconds.humanize_impl(round = round, short = short)

test "humanize":
  assert 12.hours.humanize(round = false, short = true) == "12h"
  assert 70.minutes.humanize(round = false, short = true) == "1h 10m"

  assert 130.minutes.humanize() == "2 hours"


proc `$`*(self: TInterval): string =
  self.humanize(round = false, short = true)



# proc seconds_to_minuntes*(sec: int): int = sec div 60
# proc seconds_to_hours*(sec: int): int = sec div 3600
# proc seconds_to_days*(sec: int): int = sec div (24 * 3600)


# # Hash ---------------------------------------------------------------------------------------------

# proc assert_yyyy_mm*(yyyy_mm: string): void =
#   assert yyyy_mm.match(re"\d\d\d\d-\d\d"), fmt"date format is not yyyy-mm '{yyyy_mm}'"


# proc assert_yyyy_mm_dd*(yyyy_mm_dd: string): void =
#   assert yyyy_mm_dd.match(re"\d\d\d\d-\d\d-\d\d"), fmt"date format is not yyyy-mm-dd '{yyyy_mm_dd}'"


# proc yyyy_mm_dd_to_ymd*(yyyy_mm_dd: string): tuple[y:int, m:int, d:int] =
#   assert_yyyy_mm_dd yyyy_mm_dd
#   let parts = yyyy_mm_dd.split('-').map((v) => v.parse_int)
#   (parts[0], parts[1], parts[2])


# proc yyyy_mm_to_ym*(yyyy_mm: string): tuple[y:int, m:int] =
#   assert_yyyy_mm yyyy_mm
#   let parts = yyyy_mm.split('-').map((v) => v.parse_int)
#   (parts[0], parts[1])


# proc yyyy_mm_to_m*(yyyy_mm: string, base_year: int): int =
#   let (y, m) = yyyy_mm_to_ym yyyy_mm
#   assert y >= base_year, fmt"year should be >= {base_year}"
#   12 * (y - base_year) + m


# proc to_yyyy_mm*(y: int, m: int): string =
#   assert y > 0 and (m > 0 and m <= 12)
#   let m_prefix = if m < 10: "0" else: ""
#   fmt"{y}-{m_prefix}{m}"


# proc to_yyyy_mm_dd(y: int, m: int, d: int): string =
#   assert y > 0 and (m > 0 and m <= 12) and (d > 0 and d <= 31)
#   let m_prefix = if m < 10: "0" else: ""
#   let d_prefix = if d < 10: "0" else: ""
#   fmt"{y}-{m_prefix}{m}-{d_prefix}{d}"


# proc m_to_yyyy_mm*(m: int, base_year: int): string =
#   to_yyyy_mm base_year + floor_div(m, 12), 1 + (m mod 12)


# proc current_yyyy_mm*(): string =
#   let d = times.utc(times.now())
#   to_yyyy_mm times.year(d), times.month(d).ord


# proc current_yyyy_mm_dd*(): string =
#   let d = times.utc(times.now())
#   to_yyyy_mm_dd times.year(d), times.month(d).ord, times.monthday(d)

# proc now_sec*(): int = times.to_unix(times.to_time(times.utc(times.now()))).int

# # todo "Convert timestamps in JSON and other data to human readable format"
# # let time_format = init_time_format "yyyy-MM-dd HH:mm:ss"
# # let d = now().utc
# # p d.format(time_format)
# # p "2020-09-02 10:48:39".parse(time_format, utc())


