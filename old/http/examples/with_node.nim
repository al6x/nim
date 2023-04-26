import basem, jsonm, serverm, nodem, envm

var server = Server.init()

type CNode* = ref object of Node
  user_id*: string

proc profile(client: CNode, name: string): string {.nexport.} =
  p "request_from ", client.user_id
  fmt"Hi, {name}"

# /api/profile?name=Alex
server.get("/api/:fname", proc (req: Request): auto =
  let user_id = fmt"user_id_{req.user_token}" # authentication
  let cnode = CNode(id: "none", user_id: user_id)
  let data = (if req.body == "": "{}" else: req.body).parse_json
  let reply = call_nexport_function(req.params["fname"], cnode.to_json, @[], req.query, data).get("{}")
  respond_data reply
)

server.get("/users/:name/profile", proc(req: Request): auto =
  let name = req["name"]
  respond fmt"Hi {name}"
)

server.run