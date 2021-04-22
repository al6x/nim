import ./greetingi

proc feedback*(): string {.nexport.} = "yes"

echo hi("Alex")
# => Hi Alex

if is_main_module:
  Address("user").run