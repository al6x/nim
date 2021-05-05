import sugar, httpclient
import ./supportm, ./jsonm, ./urlm, ./seqm, ./falliblem, ./tablem
from uri import nil

let default_timeout_sec = 30


# http_get -----------------------------------------------------------------------------------------
var clients_pool: Table[string, HttpClient]
proc with_client[T](
  url: string, op: proc (client: HttpClient): T, timeout_sec: int, use_pool: bool
): T =
  proc new_client: HttpClient =
    new_http_client(
      timeout = timeout_sec * 1000,
      headers = new_http_headers({ "Content-Type": "application/json" })
    )
  if use_pool:
    let domain = Url.parse(url).domain
    if domain notin clients_pool: clients_pool[domain] = new_client()
    op(clients_pool[domain])
  else:
    let client = new_client()
    defer: client.close
    op(client)


proc http_get*[Res](url: string, timeout_sec = default_timeout_sec, use_pool = false): Res =
  proc request(client: HttpClient): Res =
    let resp = client.get_content(url)
    Fallible[Res].from_json(resp.parse_json).get
  with_client(url, request, timeout_sec, use_pool)


# http_post ----------------------------------------------------------------------------------------
proc http_post_raw*(url: string, req: string, timeout_sec = default_timeout_sec, use_pool = false): string =
  proc request(client: HttpClient): string =
    client.post_content(url, req)
  with_client(url, request, timeout_sec, use_pool)

proc http_post*[Req, Res](url: string, req: Req, timeout_sec = default_timeout_sec, use_pool = false): Res =
  let resp = http_post_raw(url, req.to_json, timeout_sec, use_pool)
  Fallible[Res].from_json(resp.parse_json).get

# proc http_post*[B, R](url: string, body: B, timeout_sec = default_timeout_sec, close = false): R =
#   http_post(url, $(%body), timeout_sec, close = close)


# http_post_batch ----------------------------------------------------------------------------------
proc http_post_batch*[B, R](
  url: string, requests: seq[B], timeout_sec = default_timeout_sec, close = false
): seq[Fallible[R]] =
  let client = new_http_client(
    timeout = timeout_sec * 1000,
    headers = new_http_headers({ "Content-Type": "application/json" })
  )
  if close:
    defer: client.close
  let data = client.post_content(url, requests.to_json)
  let json = data.parse_json
  if json.kind == JObject and "is_error" in json:
    for _ in requests:
      result.add Fallible[R].from_json(json)
  else:
    for item in json:
      result.add Fallible[R].from_json(item)


# build_url ----------------------------------------------------------------------------------------
proc build_url*(url: string, query: varargs[(string, string)]): string =
  if query.len > 0: url & "?" & uri.encode_query(query)
  else:            url

proc build_url*(url: string, query: tuple): string =
  var squery: seq[(string, string)] = @[]
  for k, v in query.field_pairs: squery.add((k, $v))
  build_url(url, squery)

test "build_url":
  assert build_url("http://some.com") == "http://some.com"
  assert build_url("http://some.com", { "a": "1", "b": "two" }) == "http://some.com?a=1&b=two"

  assert build_url("http://some.com", (a: 1, b: "two")) == "http://some.com?a=1&b=two"


# parse_result -------------------------------------------------------------------------------------
# Parses JSON `data` into Nim type `R`, unless JSON is `{ is_error: true, error: "..." } then it
# rises the error
# proc parse_result[R](data: string): R =
#   let json = data.parse_json
#   if json.kind == JObject and "is_error" in json:
#     throw json["error"].get_str
#   else:
#     json.to R
