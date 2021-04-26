import tables, hashes, strformat, json, options
import ./supportm

export tables, hashes

let default_timeout_ms = 2000
type NodeDefinition* = ref object
  url*:        string
  timeout_ms*: int

type Node* = ref object of RootObj
  # Refer to nodes by node instead of urls, like `"red_node"` instead of `"tcp://localhost:4000"`
  # Nodes usually not defined immediately, but at runtime config,
  # immediately defined nodes are usually for temporarry.
  id*:  string
  def:  Option[NodeDefinition]

proc node*(id: string): Node =
  Node(id: id)

proc node*(id: string, url: string, timeout_ms = default_timeout_ms): Node =
  Node(id: id, def: NodeDefinition(url: url, timeout_ms: timeout_ms).some)

proc `$`*(node: Node): string = node.id
proc hash*(node: Node): Hash = node.id.hash
proc `==`*(a, b: Node): bool = a.id == b.id

var nodes_definitions*: Table[Node, NodeDefinition]

# proc is_defined*(node: Node): bool =
#   node.def.is_some

proc define*(node: Node, url: string, timeout_ms = default_timeout_ms): void =
  nodes_definitions[node] = NodeDefinition(url: url, timeout_ms: timeout_ms)

# proc define*[N](node: N): N =
#   if node.is_defined: node
#   else:               N(id: node.id, def: node.definition.some)

proc definition*(node: Node): NodeDefinition =
  if node.def.is_some:
    if node in nodes_definitions and node.def.get != nodes_definitions[node]:
      throw "node {node.id} definition doesn't match"
    return node.def.get
  if node notin nodes_definitions:
    # Assuming it's localhost and deriving port in range 6000-7000
    node.define fmt"tcp://localhost:{6000 + (node.id.hash.int mod 1000)}"
  nodes_definitions[node]


proc `%`*(node: Node): JsonNode =
  # Always define node when converting to JSON
  %(id: node.id, def: node.definition.some)


# proc node_from_json*[N](_: type[N], json: JsonNode): N =
#   if json.kind == JString: N(id: json.get_str)
#   else:                    json.to(N)