import base/[basem, jsonm, timem]
import ./http_supportm
import random
from jester import nil
from times import nil

export escape_html


# escape_js ----------------------------------------------------------------------------------------
func escape_js*(js: string): string =
  js.to_json.to_s.replace(re"""^"|"$""", "")

test "escape_js":
  assert escape_js("""); alert("hi there""") == """); alert(\"hi there"""


# set_cookie ---------------------------------------------------------------------------------------
proc has_cookie_set*(headers: seq[(string, string)], key: string): bool =
  headers.contains((h) => h[0] == "Set-Cookie" and h[1].starts_with(key & "="))

proc set_permanent_cookie*(headers: var seq[(string, string)], key, value: string, domain: string) =
  if headers.has_cookie_set(key): throw fmt"cookie {key} already set"
  let expires_in_sec = 10 * 12 * 30.days.seconds # Set expiration in 10 years
  let expires = times.`+`(times.now(), times.seconds(expires_in_sec))
  let headers_copy = headers
  proc wrapperfn(): jester.ResponseData =
    result.headers = headers_copy.some
    jester.set_cookie(key, value, expires = expires, domain = domain, path = "/")
  headers = wrapperfn().headers.get

proc set_permanent_cookie_if_not_set*(headers: var seq[(string, string)], key, value: string, domain: string) =
  if headers.has_cookie_set(key): return
  headers.set_permanent_cookie(key, value, domain)

proc set_session_cookie*(headers: var seq[(string, string)], key, value: string) =
  if headers.has_cookie_set(key): throw fmt"cookie {key} already set"
  let headers_copy = headers
  proc wrapperfn(): jester.ResponseData =
    result.headers = headers_copy.some
    jester.set_cookie(key, value, path = "/")
  headers = wrapperfn().headers.get

proc set_session_cookie_if_not_set*(headers: var seq[(string, string)], key, value: string) =
  if headers.has_cookie_set(key): return
  headers.set_session_cookie(key, value)

# asset_path ---------------------------------------------------------------------------------------
proc asset_path*(
  path: string, assets_path: string, assets_file_paths: seq[string], max_file_size: int, cache_assets: bool
): string =
  assert path.starts_with("/"), fmt"path '{path}' must start with /"
  var hash = if cache_assets:
    asset_hash(path, assets_file_paths, max_file_size)
  else:
    Time.now.epoch.to_s
  fmt"{assets_path}{path}?hash={hash}"

proc asset_path*[R](req: R, path: string): string =
  let config = req.config
  asset_path(path, config.assets_path, config.assets_file_paths, config.max_file_size, config.cache_assets)