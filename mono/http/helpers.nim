import base, ext/[url, async]
import std/[deques, httpcore, asynchttpserver, asyncnet, os]

proc init*(_: type[Url], request: Request): Url =
  let url = Url.init(request.url) # doesn't have host
  let host_port = request.headers["host"].split(":")
  let (host, port) = if host_port.len == 1: (host_port[0], 80) else: (host_port[0], host_port[1].parse_int)
  Url.init(scheme = "", host = host, port = port, path = url.path, query = url.query)

proc respond*(req: Request, content: string, ctype: string): Future[void] {.async.} =
  await req.respond(Http200, content, new_http_headers([("Content-Type", ctype)]))

proc respond*(req: Request, content: string): Future[void] {.async.} =
  await req.respond(Http200, content)

proc respond_json*[T](req: Request, data: T): Future[void] {.async.} =
  await req.respond(data.to_json.to_s, "application/json")

proc read_asset_file*(asset_paths: seq[string], path: string): string =
  for asset_path in asset_paths:
    let try_path = asset_path & path
    if fs.exist(try_path):
      return fs.read(try_path)
  throw fmt"no asset file '{path}'"

proc serve_asset_files*(req: Request, asset_paths: seq[string], url: Url): Future[void] {.async.} =
  let data = read_asset_file(asset_paths, url.path.replace("/assets/", "/"))
  let (dir, name, ext) = url.path.split_file
  case ext
  of ".js":  await req.respond(data, "text/javascript; charset=UTF-8")
  of ".css": await req.respond(data, "text/css; charset=UTF-8")
  else:      await req.respond(data)

# proc serve_app_html*(
#   req: Request, asset_paths: seq[string], page_fname: string, session_id, html: string, meta: string
# ): Future[void] {.async.} =
#   let data = read_asset_file(asset_paths, "/" & page_fname)
#     .replace("{session_id}", session_id)
#     .replace("{html}", html)
#     .replace("{meta}", meta)
#   await req.respond(data, "text/html")