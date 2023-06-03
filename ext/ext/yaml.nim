import base

import yaml/tojson # nimble install yaml

proc parse_yaml*(yaml: string): JsonNode =
  let list = load_to_json(yaml)
  assert list.len == 1
  list[0]

when is_main_module:
  p parse_yaml("a: 1")

# when defined(development):
#   # Speeding up compilation during development by avoiding extra Nim library
#   # Requires `brew install yj`
#   import std/osproc
#
#   proc parse_yaml*(yaml: string): JsonNode =
#     let output = exec_cmd_ex(command = "yj -y", input = yaml)
#     output.output.parse_json
# else:
#   import yaml/tojson # nimble install yaml
#
#   proc parse_yaml*(yaml: string): JsonNode =
#     let list = load_to_json(yaml)
#     assert list.len == 1
#     list[0]