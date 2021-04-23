import tables, hashes, strformat
import ./supportm

export tables, hashes

type Address* = distinct string
# Refer to nodes by address instead of urls, like `"red_node"` instead of `"tcp://localhost:4000"`

proc `$`*(address: Address): string = address.string
proc hash*(address: Address): Hash = address.string.hash
proc `==`*(a, b: Address): bool = a.string == b.string

type AddressImpl* = tuple
  url:        string
  timeout_ms: int

# Define mapping between addresses and urls
var addresses: Table[Address, AddressImpl]

proc define*(address: Address, url: string, timeout = 500): void =
  addresses[address] = (url, timeout)

proc get*(address: Address): AddressImpl =
  if address notin addresses:
    # Assuming it's localhost and deriving port in range 6000-7000
    address.define fmt"tcp://localhost:{6000 + (address.string.hash.int mod 1000)}"
  addresses[address]