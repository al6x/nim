import basem, logm, jsonm, envm, persistencem, timem
from fs import nil
{.experimental: "code_reordering".}


# FsStorage ----------------------------------------------------------------------------------------
# Simple storage with local file system as a storage
type FsStorage*[T] = object
  path*:           string
  expiration_sec*: Option[int]

proc init*[T](
  _:               type[FsStorage[T]],
  path           = env["fs_storage_path", "./tmp/storage"],
  expiration_sec = int.none
): FsStorage[T] =
  FsStorage[T](path: path, expiration_sec: expiration_sec)


# StorageData --------------------------------------------------------------------------------------
type StorageData[T] = object
  storage:   T
  timestamp: Time

proc init[T](_: type[StorageData[T]], storage: T): StorageData[T] =
  StorageData[T](storage: storage, timestamp: Time.now)


# [], []=, delete ----------------------------------------------------------------------------------
func fs_path(storages: FsStorage, id: string): string =
  fmt"{storages.path}/{id.take(2)}/{id}.json"

proc `[]`*[T](storages: FsStorage[T], id: string): T =
  let data = StorageData[T].read_from(storages.fs_path(id), () => StorageData.init(T.init))
  if storages.expiration_sec.is_some and (Time.now.epoch - data.timestamp.epoch) < storages.expiration_sec.get:
    return data.storage

proc `[]=`*[T](storages: FsStorage[T], id: string, storage: T) =
  StorageData.init(storage).write_to(storages.fs_path(id))

proc delete*[T](storages: FsStorage[T], id: string) =
  fs.delete(storages.fs_path(id))

proc delete*[T](storages: FsStorage[T]) =
  fs.delete(storages.path, recursive = true)


# Test ---------------------------------------------------------------------------------------------
when is_main_module:
  type TestStorage = ref object
    value: int

  proc init*(_: type[TestStorage]): TestStorage = TestStorage(value: 1)

  let storages = FsStorage[TestStorage].init(path = "./tmp/test_storages")
  storages.delete("jim")
  var storage = storages["jim"]
  assert storage.value == 1
  storage.value = 2
  storages["jim"] = storage
  assert storages["jim"].value == 2