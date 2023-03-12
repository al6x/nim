import base, base/[url, async]
import std/[deques, httpcore, asynchttpserver, asyncnet]

proc respond*(req: Request, content: string, ctype: string): Future[void] {.async.} =
  await req.respond(Http200, content, new_http_headers([("Content-Type", ctype)]))

proc respond*(req: Request, content: string): Future[void] {.async.} =
  await req.respond(Http200, content)

proc respond_json*[T](req: Request, data: T): Future[void] {.async.} =
  await req.respond(data.to_s, "application/json")

proc read_client_file*(path: string): string =
  fs.read("store/client" & path)

proc serve_client_files*(req: Request, url: Url): Future[void] {.async.} =
  let data = read_client_file url.path.replace("/_client")
  if url.path =~ re"\.js$": await req.respond(data, "text/javascript")
  else:                     await req.respond(data)

proc serve_client_page*(req: Request, url: Url, session_id: string): Future[void] {.async.} =
  let data = read_client_file("/page.html")
    .replace("{session_id}", session_id)
  await req.respond(data, "text/html")