import ./greetingi

proc feedback*(): string {.nexport.} = "yes"

echo hi("Alex")
# => Hi Alex

Address("user").run