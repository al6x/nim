import std/sugar
import ./base/[support, stringm, seqm, option, re, fallible, table, hash, tuplem, setm, enumm,
  log, json, env, say, math, random, time, basefs]

import ./base/console_log

export sugar
export support, stringm, seqm, option, re, fallible, table, hash, tuplem, setm, enumm,
  log, json, env, say, math, random, time, basefs

log_emitters.add emit_to_console