import base

type
  Block* = ref object
    id*:       string
    version*:  int
    tags*:     seq[string]
    links*:    seq[string]
    glinks*:   seq[string]
    text*:     string
    warnings*: seq[string]

  Doc* = ref object of RootObj
    id*:       string
    version*:  int
    title*:    string
    blocks*:   seq[Block]
    warnings*: seq[string]

  Space* = ref object
    name*:     string
    version*:  int
    docs*:     Table[string, Doc]
    warnings*: seq[string]

proc init*(_: type[Space], name: string, version = 0): Space =
  Space(name: name, version: version)