import base, ./docm

# to_json ------------------------------------------------------------------------------------------
method to_json_hook_method*(embed: Embed): JsonNode {.base.} =
  %{}

method to_json_hook_method*(embed: ImageEmbed): JsonNode =
  %{ path: embed.path }

method to_json_hook_method*(embed: CodeEmbed): JsonNode =
  %{ code: embed.code }

proc to_json_hook*(embed: Embed): JsonNode =
  embed.to_json_hook_method