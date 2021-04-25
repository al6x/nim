import tables, hashes, strformat
import ./supportm

export tables, hashes

type Node* = distinct string
# Refer to nodes by node instead of urls, like `"red_node"` instead of `"tcp://localhost:4000"`

proc `$`*(node: Node): string = node.string
proc hash*(node: Node): Hash = node.string.hash
proc `==`*(a, b: Node): bool = a.string == b.string

type NodeImpl* = tuple
  url:        string
  timeout_ms: int

# Define mapping between nodees and urls
var nodees: Table[Node, NodeImpl]

proc define*(node: Node, url: string, timeout = 2000): void =
  nodees[node] = (url, timeout)

proc get*(node: Node): NodeImpl =
  if node notin nodees:
    # Assuming it's localhost and deriving port in range 6000-7000
    node.define fmt"tcp://localhost:{6000 + (node.string.hash.int mod 1000)}"
  nodees[node]