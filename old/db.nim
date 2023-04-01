# table_columns ------------------------------------------------------------------------------------
# var table_columns_cache: Table[string, seq[string]] # table_name -> columns
# proc table_columns*(db: Db, table: string): seq[string] =
#   # table columns, fetched from database
#   if table notin table_columns_cache:
#     db.log.debug "get columns"
#     db.with_connection do (conn: auto) -> void:
#       var rows: seq[JsonNode]
#       var columns: db_postgres.DbColumns
#       for _ in db_postgres.instant_rows(conn, columns, db_postgres.sql(fmt"select * from {table} limit 1"), @[]):
#         discard
#       var names: seq[string]
#       for i in 0..<columns.len: names.add columns[i].name
#       table_columns_cache[table] = names
#   table_columns_cache[table]
