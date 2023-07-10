import base, ext/[url, async], ../core
import std/[deques, httpcore, asynchttpserver, os]

type Mime* = ref Table[string, string]
let mime* = Mime()
mime["js"]   = "text/javascript; charset=UTF-8"
mime["css"]  = "text/css; charset=UTF-8"
mime["svg"]  = "image/svg+xml"
mime["jpg"]  = "image/jpeg"
mime["jpeg"] = "image/jpeg"
mime["png"]  = "image/png"
mime["ico"]  = "image/png"

proc init*(_: type[Url], request: Request): Url =
  let url = Url.init(request.url) # doesn't have host
  let host_port = request.headers["host"].split(":")
  let (host, port) = if host_port.len == 1: (host_port[0], 80) else: (host_port[0], host_port[1].parse_int)
  Url.init(scheme = "http", host = host, port = port, path = url.path, params = url.params)

proc respond*(req: Request, content: string, ctype: string): Future[void] {.async.} =
  await req.respond(Http200, content, new_http_headers([("Content-Type", ctype)]))

proc respond*(req: Request, content: string): Future[void] {.async.} =
  await req.respond(Http200, content)

proc respond_json*[T](req: Request, data: T): Future[void] {.async.} =
  await req.respond(data.to_json.to_s, "application/json")

proc read_asset_file*(asset_paths: seq[string], path: string): Option[string] =
  for asset_path in asset_paths:
    let try_path = asset_path & path
    if fs.exist(try_path):
      return fs.read(try_path).some

proc get_for_path*(mime: Mime, path: string): string =
  var (_, _, ext) = path.split_file
  ext = ext.replace(re"^\.", "")
  mime[].get(ext, "text/html")

proc serve_asset_file*(req: Request, asset_paths: seq[string], url: Url): Future[void] {.async.} =
  let data = read_asset_file(asset_paths, url.path_as_s.replace("/assets/", "/"))
  if data.is_some: await req.respond(data.get, mime.get_for_path(url.path_as_s))
  else:            await req.respond(Http404, "Not found")

proc serve_file*(req: Request, path: string): Future[void] {.async.} =
  assert path.starts_with "/", "path should be absolute"
  if fs.exist(path): await req.respond(fs.read(path), mime.get_for_path(path))
  else:              await req.respond(Http404, "Not found")