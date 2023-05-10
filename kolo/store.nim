import base
import ./ftext except FBlock

type
  Block* = ref object of RootObj
    kind*:     string
    space*:    string
    version*:  int
    id*:       string
    tags*:     seq[string]
    links*:    seq[string]
    glinks*:   seq[string]
    text*:     string

  Store* = ref object
    version*: int
    blocks*:  seq[Block]

# FText --------------------------------------------------------------------------------------------
type FBlock* = ref object of Block
  fblock: ftext.Fblock

proc add_





  #   line_n*:   int
  #   warnings*: seq[string]

  # FSection* = object
  #   title*:    string
  #   blocks*:   seq[FBlock]
  #   tags*:     seq[string]
  #   warnings*: seq[string]
  #   line_n*:   int

  # FDoc* = object
  #   location*:    string
  #   title*:       string
  #   sections*:    seq[FSection]
  #   tags*:        seq[string]
  #   tags_line_n*: int
  #   warnings*:    seq[string]