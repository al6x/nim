import basem, urlm, jsonm

export basem, urlm, jsonm

let default_timeout_ms = 2000
type NodeDefinition* = ref object
  url*:        string
  parsed_url*: Url
  timeout_ms*: int

type Node* = ref object of RootObj
  # Refer to nodes by string id, instead of url, like `"red_node"` instead of `"tcp://localhost:4000"`
  # Usually nodes defined not immediately, but later, at runtime config, like IoC.
  # Immediately defined nodes are usually temporarry nodes.
  id*:  string
  def:  Option[NodeDefinition]

proc node*(id: string): Node =
  Node(id: id)

proc node*(id: string, url: string, timeout_ms = default_timeout_ms): Node =
  Node(id: id, def: NodeDefinition(url: url, parsed_url: Url.parse(url), timeout_ms: timeout_ms).some)

proc `$`*(node: Node): string = node.id
proc hash*(node: Node): Hash = node.id.hash
proc `==`*(a, b: Node): bool = a.id == b.id

var nodes_definitions*: Table[Node, NodeDefinition]

proc define*(node: Node, url: string, timeout_ms = default_timeout_ms): void =
  nodes_definitions[node] = NodeDefinition(url: url, parsed_url: Url.parse(url), timeout_ms: timeout_ms)

proc definition*(node: Node): NodeDefinition =
  if node.def.is_some:
    if node in nodes_definitions and node.def.get != nodes_definitions[node]:
      throw "node {node.id} definition doesn't match"
    return node.def.get
  if node notin nodes_definitions:
    # Assuming it's localhost and deriving port from the node name, in range 6000-56000
    #
    # Possible improvement would be to use shared file like `~/.nodes` to store mapping and
    # resolve conflicts, but it feels too complicated.
    node.define fmt"http://localhost:{6000 + (node.id.hash.int mod 50000)}/{node.id}"
  nodes_definitions[node]

proc `%`*(node: Node): JsonNode =
  # Always define node when converting to JSON
  %(id: node.id, def: node.definition.some)