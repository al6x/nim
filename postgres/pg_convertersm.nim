import base/[basem, timem, jsonm]
import db_common

proc postgres_to*(json: JsonNode, T: type): T =
  result = json.json_to(T, Joptions(allow_extra_keys: true))
  when compiles(result.post_postgres_to()):
    result.post_postgres_to()

proc to_string_json(v: string): JsonNode =
  # Nim driver for PostgreSQL doesn't differentiate between empty string and null, fixing it
  if v == "": newJNull() else: v.to_json

# from_postgres_to_json ----------------------------------------------------------------------------
proc from_postgres_to_json*(kind: DbTypeKind, s: string): JsonNode =
  case kind
  of dbSerial:    s.parse_int.to_json
  of dbNull:      newJNull()
  # dbBit,        ## bit datatype
  of dbBool:      (if s == "t": true elif s == "f": false else: throw fmt"unknown bool value '{s}'").to_json
  # dbBlob,       ## blob datatype
  of dbFixedChar: s.to_string_json  ## string of fixed length
  of dbVarchar:   s.to_string_json  ## string datatype
  # dbJson,       ## JSON datatype
  # dbXml,        ## XML datatype
  of dbInt:       s.parse_int.to_json
  of dbUInt:      s.parse_int.to_json    ## some unsigned integer type
  # dbDecimal,    ## decimal numbers (fixed-point number)
  of dbFloat:     s.parse_float.to_json ## some floating point type
  of dbDate:      s.to_json ## a year-month-day description
  of dbTime:      s.to_json ## HH:MM:SS information
  of dbDatetime:  s.to_json ## year-month-day and HH:MM:SS information,
  #                   ## plus optional time or timezone information
  of dbTimestamp: s.to_json ## Timestamp values are stored as the number of seconds
  #                   ## since the epoch ('1970-01-01 00:00:00' UTC).
  # dbTimeInterval,  ## an interval [a,b] of times
  # dbEnum,          ## some enum
  # dbSet,           ## set of enum values
  # dbArray,         ## an array of values
  # dbComposite,     ## composite type (record, struct, etc)
  # dbUrl,           ## a URL
  # dbUuid,          ## a UUID
  # dbInet,          ## an IP address
  # dbMacAddress,    ## a MAC address
  # dbGeometry,      ## some geometric type
  # dbPoint,         ## Point on a plane   (x,y)
  # dbLine,          ## Infinite line ((x1,y1),(x2,y2))
  # dbLseg,          ## Finite line segment   ((x1,y1),(x2,y2))
  # dbBox,           ## Rectangular box   ((x1,y1),(x2,y2))
  # dbPath,          ## Closed or open path (similar to polygon) ((x1,y1),...)
  # dbPolygon,       ## Polygon (similar to closed path)   ((x1,y1),...)
  # dbCircle,        ## Circle   <(x,y),r> (center point and radius)
  # dbUser1,         ## user definable datatype 1 (for unknown extensions)
  # dbUser2,         ## user definable datatype 2 (for unknown extensions)
  # dbUser3,         ## user definable datatype 3 (for unknown extensions)
  # dbUser4,         ## user definable datatype 4 (for unknown extensions)
  # dbUser5          ## user definable datatype 5 (for unknown extensions)
  else:
    throw fmt"unknown postgres value type '{kind}'"


# # from_json_to_postgres_string ---------------------------------------------------------------------
# proc from_json_to_postgres_string*(json: JsonNode): string =
#   case json.kind
#   of JString:
#     str*: string
#   of JInt:
#     num*: BiggestInt
#   of JFloat:
#     fnum*: float
#   of JBool:
#     bval*: bool
#   of JNull:
#     nil
#   of JObject:
#     fields*: OrderedTable[string, JsonNode]
#   of JArray:
#     elems*: seq[JsonNode]
#   else:
#     throw fmt"unknown postgres value type '{kind}'"