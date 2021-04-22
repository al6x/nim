import tables, hashes, strformat
import ./supportm

export tables, hashes

type NodeName* = distinct string
# Refer to nodes by names instead of urls, like `"red_node"` instead of `"tcp://localhost:4000"`

proc `$`*(name: NodeName): string = name.string
proc hash*(name: NodeName): Hash = name.string.hash
proc `==`*(a, b: NodeName): bool = a.string == b.string

# Define mapping between node namees and urls
var nodes_names*: Table[NodeName, string]

proc to_url*(name: NodeName): string =
  if name notin nodes_names:
    # Assuming it's localhost and deriving port in range 6000-7000
    nodes_names[name] = fmt"tcp://localhost:{6000 + (name.string.hash.int mod 1000)}"
  nodes_names[name]