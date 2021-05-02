import basem, ./dbm, ./cdbm, ./db_tablem

let db = Db.init("nim_test")
db.test_db_tablem

let cdb = Cdb.init("nim_test")
cdb.test_db_tablem