import basem, jsonm, randomm, dbm, kvdbm, envm, logm, urlm
import http_serverm, http_clientm, decode_querym
import ./usersm, ../configm

# Config -------------------------------------------------------------------------------------------
let github_oauth_id     = env["github_oauth_id"]
let github_oauth_secret = env["github_oauth_secret"]
let public_domain       = Url.parse env["public_domain"]

let server = Server.init
let log = Log.init "users"
using req: Request


# login_with_github --------------------------------------------------------------------------------
server.get("/users/login_with_github", proc (req): auto =
  if req.host != public_domain.host: throw "wrong host"

  let secure_state = secure_random_token()
  # kvdb["/users/original_url/v1", req.session_token] = ""
  kvdb["/users/secure_state/v1", req.session_token] = secure_state

  let url = build_url("https://github.com/login/oauth/authorize", {
    "client_id": github_oauth_id,
    "scope":     "user:email",
    "state":     secure_state
  })
  redirect url
)


# github_callback ----------------------------------------------------------------------------------
proc get_github_user(code: string): SourceUser

server.get("/users/github_callback", proc (req): auto =
  if req.host != public_domain.host: throw "wrong host"

  let github_user = try:
    let secure_state = kvdb.delete("/users/secure_state/v1", req.session_token).ensure("no login state")
    if req["state"] != secure_state: throw "invalid state token"

    get_github_user(req["code"])
  except Exception as e:
    log.warn("can't auth with github", e)
    throw fmt"authentification failed, please try again later, {e.msg}"

  let user = User.create_or_update_from_source github_user

  let redirect_url = kvdb.delete("/users/original_url/v1", req.session_token).get(home_path(user.nick))
  echo redirect_url
  let response = redirect redirect_url

  # Resetting auth tokens
  response.headers.set_permanent_cookie("user_token", user.token)
  response.headers.set_session_cookie("session_token", secure_random_token())
  response
)


# authenticate ----------------------------------------------------------------------------------
# proc authenticate*(req: Request): (User, bool) =
#   if req.host == public_domain.host or req.host.ends_with("." & public_domain.host): throw "wrong host"

#   let user = users.fget((token: req.user_token)).get "not authenticated"

#   let redirect_url = kvdb.delete("/users/original_url/v1", req.session_token).get(home_path(user.nick))
#   echo redirect_url
#   let response = redirect redirect_url

#   # Resetting auth tokens
#   response.headers.set_permanent_cookie("user_token", user.token)
#   response.headers.set_session_cookie("session_token", secure_random_token())
#   response
# )


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
    name:   json["name"].json_to(Option[string]),
    avatar: json["avatar_url"].json_to(Option[string])
  )


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let db = Db.init
  db.define "plot_dev"

  server.get("/", proc (req): auto =
    respond "ok"
  )

  server.define(host = env["host"], port = env["port"].parse_int)
  server.run