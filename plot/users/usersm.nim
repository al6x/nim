import basem, httpm, randomm, http_serverm, envm, ./userm

proc mount_users*(server: var Server) =
  server.get("/users/login_with_github", proc (req: Request): auto =
    let url = build_url("https://github.com/login/oauth/authorize", {
      "client_id": env["github_oauth_client_id"],
      "scope":     "user:email",
      "state":     secure_random_token()
    })
    redirect url
  )

  server.get("/users/", proc (req: Request): auto =
    let url = build_url("https://github.com/login/oauth/authorize", {
      "client_id": env["github_oauth_client_id"],
      "scope":     "user:email",
      "state":     secure_random_token()
    })
    redirect url
  )

  # server.get("/users/:name/profile", proc(req: Request): auto =
  #   let name = req["name"]
  #   respond fmt"Hi {name}"
  # )

# https://github.com/login/oauth/authorize