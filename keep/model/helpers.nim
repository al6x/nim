import base, ./docm

# to_json ------------------------------------------------------------------------------------------
method to_json_hook_method*(embed: Embed): JsonNode {.base.} =
  %{}

method to_json_hook_method*(embed: ImageEmbed): JsonNode =
  embed.to_json

method to_json_hook_method*(embed: CodeEmbed): JsonNode =
  embed.to_json

method to_json_hook_method*(embed: UnparsedEmbed): JsonNode =
  embed.to_json

proc to_json_hook*(embed: Embed): JsonNode =
  embed.to_json_hook_method