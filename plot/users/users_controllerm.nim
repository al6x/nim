import basem, jsonm, randomm, http_serverm, dbm, kvdbm, envm, decode_querym, http_clientm
import ./usersm, ../configm

# Config -------------------------------------------------------------------------------------------
let github_oauth_id     = env["github_oauth_id"]
let github_oauth_secret = env["github_oauth_secret"]

let server = Server.init


# login_with_github --------------------------------------------------------------------------------
type LoginState = tuple[original_url: string, token: string]

proc login_with_github(req: Request): Response =
  let token = secure_random_token()
  kvdb[LoginState, req.session_token] = (
    req["original_url", home_path], # Storing original url if present, to restore it after the login
    token
  )

  let url = build_url("https://github.com/login/oauth/authorize", {
    "client_id": github_oauth_id,
    "scope":     "user:email",
    "state":     token
  })
  redirect url
server.get("/users/login_with_github", login_with_github)


# github_callback ----------------------------------------------------------------------------------
type GitHubUser = object
  nick:   string         # github_data.login
  id:     int            # github_data.id
  email:  string         # github_data.email
  avatar: Option[string] # github_data.avatar_url / null
  name:   Option[string] # github_data.name / null

proc get_github_user(code: string): GitHubUser

proc github_callback(req: Request): Response =
  let (original_url, token) = kvdb.get_optional(LoginState, req.session_token)
    .ensure("authentication failed, no login state, please try again later")
  if req["state"] != token: throw "authentication failed, invalid state token, please try again later"

  echo get_github_user(req["code"])

  respond "ok"
server.get("/users/github_callback", github_callback)


# get_github_user ----------------------------------------------------------------------------------
proc get_github_user(code: string): GitHubUser =
  # Getting access token
  let url = build_url("https://github.com/login/oauth/access_token", {
    "client_id":     github_oauth_id,
    "client_secret": github_oauth_secret,
    "code":          code
  })

  let access_token_raw = try: http_post(url, "")
  except:
    throw "authentication failed, can't get access token, please try again later"
  let access_token = re"(?i)access_token=([a-z0-9_\-]+)".parse1(access_token_raw)
    .ensure("authentication failed, no access token, please try again later")

  # Getting user info
  let user_info_raw = try:
    http_get("https://api.github.com/user", headers = {"Authorization": fmt"token {access_token}"})
  except:
    throw "authentication failed, can't get user info, please try again later"

  # Parsing user info
  let json = try:
    user_info_raw.parse_json
  except:
    throw "authentication failed, can't parse user info, please try again later"

  try:
    GitHubUser(
      nick:   json["login"].get_str,
      id:     json["id"].get_int,
      email:  json["email"].get_str,
      name:   json["name"].to(Option[string]),
      avatar: json["avatar_url"].to(Option[string])
    )
  except:
    throw "authentication failed, can't parse user info json, please try again later"


# Test ---------------------------------------------------------------------------------------------
if is_main_module:
  let db = Db.init
  db.define "plot_dev"

  server.define(host = "pl0t.com", port = 8080)
  server.run