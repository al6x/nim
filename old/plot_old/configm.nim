import basem, envm, urlm

let public_domain = env["public_domain"]

proc home_path*(user_id: string): string =
  let parsed = Url.parse public_domain
  let port = if parsed.port == 80: "" else: fmt":{parsed.port}"
  fmt"{parsed.scheme}://{user_id}.{parsed.host}{port}"