import base, base/[url]


# InEvent, OutEvent --------------------------------------------------------------------------------
type SpecialInputKeys* = enum alt, ctrl, meta, shift
type InEventType* = enum location, click
type InEvent* = object
  case kind*: InEventType
  of location:
    path*:  seq[string]
    query*: Table[string, string]
  of click:
    id*:   string
    keys*: seq[string]

type OutEventType* = enum eval
type OutEvent* = object
  kind*: OutEventType
  code*: string


# App ----------------------------------------------------------------------------------------------
type App* = ref object of RootObj
  id*: string

method process*(self: App, event: InEvent): Option[OutEvent] {.base.} =
  throw "not implemented"

type Apps* = ref Table[string, proc: App]

proc get*(apps: Apps, url: Url): (App, InEvent) =
  # Returns app and initial events, like going to given url
  let id = if url.host == "localhost": url.query.ensure("_app", "_app query parameter required") else: url.host
  let app = apps[].ensure(id, fmt"Error, unknown application '{id}'")()

  var query = url.query
  query.del "_app"
  let path = url.path.replace(re"/$", "").split("/").reject(is_empty)
  let location_event = InEvent(kind: location, path: path, query: query)

  (app, location_event)