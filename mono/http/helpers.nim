import base, ext/[url, async]
import std/[deques, httpcore, asynchttpserver, asyncnet]

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

proc read_asset_file*(path: string): string =
  fs.read("mono/http/assets" & path)

proc serve_asset_files*(req: Request, url: Url): Future[void] {.async.} =
  let data = read_asset_file url.path.replace("/_assets")
  if url.path =~ re"\.js$": await req.respond(data, "text/javascript")
  else:                     await req.respond(data)

proc serve_app_html*(req: Request, url: Url, session_id, html: string): Future[void] {.async.} =
  let data = read_asset_file("/page.html")
    .replace("{session_id}", session_id)
    .replace("{html}", html)
  await req.respond(data, "text/html")