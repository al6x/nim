import basem, jsonm, ./serverm, nodem/nexportm

var server = Server.init()

proc profile(_: Node, name: string): string {.nexport.} =
  fmt"Hi, {name}"

server.get("/api/:fname", proc (req: Request): auto =
  let data = req.body.parse_json
  let reply = call_nexport_function(req.params["fname"], @[], req.query, data).get("{}")
  respond_data reply
)

# server.get_data("/api/users/:name/profile", (req: Request) =>
#   (name: req["name"], age: 20)
# )

server.get("/users/:name/profile", proc(req: Request): auto =
  let name = req["name"]
  respond fmt"Hi {name}"
)

server.run