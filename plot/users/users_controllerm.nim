import basem, jsonm, randomm, http_serverm, dbm, kvdbm, envm, decode_querym, http_clientm, logm
import ./usersm, ../configm

# Config -------------------------------------------------------------------------------------------
let github_oauth_id     = env["github_oauth_id"]
let github_oauth_secret = env["github_oauth_secret"]

let server = Server.init
let log = Log.init "users"


# login_with_github --------------------------------------------------------------------------------
proc login_with_github(req: Request): Response =
  let secure_state = secure_random_token()
  # kvdb["/users/original_url/v1", req.session_token] = ""
  kvdb["/users/secure_state/v1", req.session_token] = secure_state

  let url = build_url("https://github.com/login/oauth/authorize", {
    "client_id": github_oauth_id,
    "scope":     "user:email",
    "state":     secure_state
  })
  redirect url
server.get("/users/login_with_github", login_with_github)


# github_callback ----------------------------------------------------------------------------------
proc get_github_user(code: string): SourceUser

proc github_callback(req: Request): Response =
  let github_user = try:
    let secure_state = kvdb.get_optional("/users/secure_state/v1", req.session_token).ensure("no login state")
    kvdb.delete("/users/secure_state/v1", req.session_token)
    if req["state"] != secure_state: throw "invalid state token"

    get_github_user(req["code"])
  except Exception as e:
    log.warn("can't auth with github", e)
    throw fmt"authentification failed, please try again later, {e.msg}"

  let user = User.create_or_update_from_source github_user

  let response = respond "ok"

  response.headers.set_permanent_cookie("user_token", user.token)
  response.headers.set_session_cookie("session_token", secure_random_token())

  response

server.get("/users/github_callback", github_callback)


# get_github_user ----------------------------------------------------------------------------------
proc get_github_user(code: string): SourceUser =
  # Getting access token
  let url = build_url("https://github.com/login/oauth/access_token", {
    "client_id":     github_oauth_id,
    "client_secret": github_oauth_secret,
    "code":          code
  })
  let access_token_raw = http_post(url, "")
  let access_token = re"(?i)access_token=([a-z0-9_\-]+)".parse1(access_token_raw).ensure("no access token")

  # Getting user info
  let user_info_raw = http_get("https://api.github.com/user", headers = {
    "Authorization": fmt"token {access_token}"
  })
  let json = user_info_raw.parse_json

  # Parsing user info
  SourceUser(
    source: "github",
    nick:   json["login"].get_str,
    id:     json["id"].get_int,
    email:  json["email"].get_str,
    name:   json["name"].to(Option[string]),
    avatar: json["avatar_url"].to(Option[string])
  )


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let db = Db.init
  db.define "plot_dev"

  server.define(host = "pl0t.com", port = 8080)
  server.run