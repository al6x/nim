#!/usr/bin/env nim c -r

import base/[basem, asyncm, urlm, logm, jsonm]
from nimsha2 import nil

export urlm


# Store --------------------------------------------------------------------------------------------
type Store* = object
  id*: string

proc init*(_: type[Store], id = "default"): Store =
  Store(id: id)

proc `$`*(ps: Store): string = ps.id
proc hash*(ps: Store): Hash = ps.id.hash
proc `==`*(a, b: Store): bool = a.id == b.id

proc log(ps: Store): Log = Log.init("Store", ps.id)


# StoreImpl ----------------------------------------------------------------------------------------
type
  StoreImpl = ref object
    path:            string
    max_object_kb:   int
    max_per_user_kb: int

var impls: Table[Store, StoreImpl]


# impl ---------------------------------------------------------------------------------------------
proc impl*(
  store:            Store,
  path:             string,
  max_object_kb   = 2_000,
  max_per_user_kb = 10_000
): void =
  impls[store] = StoreImpl(path: path, max_object_kb: max_object_kb, max_per_user_kb: max_per_user_kb)

proc save()


# Helpers ------------------------------------------------------------------------------------------
proc sha256(data: string): string =
  var sha = nimsha2.initSHA[nimsha2.SHA256]()
  nimsha2.update(sha, data)
  $nimsha2.final(sha)