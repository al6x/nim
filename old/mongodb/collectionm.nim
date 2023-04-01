import basem
import ./utils
from asyncdispatch import wait_for
from anonimongo as native import nil


proc to_bson[T: tuple | object](o: T): native.BsonDocument =
  result = native.new_bson()
  for k, v in o.field_pairs:
    native.`[]=`(result, k, native.to_bson(v))


type Collection*[D] = ref object
  db_name*:      string
  name*:         string
  n_connection*: native.Mongo
  n_db*:         native.Database
  n_collection*: native.Collection


proc init*[D](_: type[Collection[D]], db_name: string, name: string, n_connection: native.Mongo): Collection[D] =
  let n_db         = native.`[]`(n_connection, db_name)
  let n_collection = native.`[]`(n_db, name)
  Collection[D](db_name: db_name, name: name, n_connection: n_connection, n_db: n_db, n_collection: n_collection)


proc drop*[D](collection: Collection[D]): void =
  let res = wait_for native.drop(collection.n_collection)
  if not res.success and res.reason != "ns not found":
    throw fmt"can't drop {collection.db_name}.{collection.name}, {res.reason}"


proc insert*[D](collection: Collection[D], documents: openarray[D]): void =
  let res = wait_for native.insert(collection.n_collection, documents.map(to_bson))
  if not res.success:
    throw fmt"can't write to {collection.db_name}.{collection.name}, {res.reason}"

proc insert*[D](collection: Collection[D], document: D): void =
  collection.insert([document])


# interface FindOptions<D> {
#   skip?:       number
#   limit?:      number
#   sort?:       { [K in keyof D]?: number }
#   projection?: { [K in keyof D]?: number } & { _id?: number }
# }

  # protected abstract _getNativeCollection(name: string): NativeCollection<D>

#   get native(): NativeCollection<D> { return this._getNativeCollection(this.name) }

# proc exist(query?: FilterQuery<D>, options: FindOneOptions = {}): Promise<boolean> {
#   query = postProcessQuery(query || {})
#   return !!(await this.native.findOne(query, { projection: { _id: 1 }, ...options }))
# }

#   async ensureExist(query?: FilterQuery<D>, options: FindOneOptions = {}): Promise<void> {
#     assert(await this.exist(query, options), `expected document to exist in ${this.name}`)
#   }

#   async find(query?: FilterQuery<D>, options: FindOptions<D> = {}): Promise<D[]> {
#     query = postProcessQuery(query || {})
#     let cursor = this.native.find(query)
#     if (options.skip)  cursor = cursor.skip(options.skip)
#     if (options.limit) cursor = cursor.limit(options.limit)
#     if (options.sort)  cursor = cursor.sort(options.sort)
#     return await cursor.toArray()
#   }

#   async findOne(query?: FilterQuery<D>, options: FindOneOptions = {}): Promise<D | undefined> {
#     query = postProcessQuery(query || {})
#     const found = await this.native.find(query, { ...options, ...{ limit: 1 } }).toArray()
#     return found[0] ? found[0] : undefined
#   }

#   async ensureOne(query?: FilterQuery<D>, options: FindOneOptions = {}): Promise<D & WithId> {
#     query = postProcessQuery(query || {})
#     const found = await this.native.find(query, { ...options, ...{ limit: 2 } }).toArray()
#     if (found.length == 0) throw new Error(`exactly one document required but found none in ${this.name}`)
#     if (found.length > 1) throw new Error(`exactly one document required but found multiple in ${this.name}`)
#     return found[0] as something
#   }

#   async count(query?: FilterQuery<D>, options: MongoCountPreferences = {}): Promise<number> {
#     query = postProcessQuery(query || {})
#     return this.native.countDocuments(query, options)
#   }

# proc create*[D](_: type[Collection[D]], document: D, options: CollectionInsertOneOptions = {}):
# Promise<undefined | Errors<D>> =
proc create*[D](_: type[Collection[D]], document: D): void =
  when compiles(document.validate):
    if not document.validate: throw "document is invalid"
  # try:
  #   const { insertedId } = await this.native.insertOne(document, options)
  #   ;(document as something)._id = insertedId
  #   return undefined
  # } catch (e) {
  #   const message = isKnownError(e)
  #   if (message) return { '': [message] } as something // TODO 1 fixit
  #   else         throw e
  # }
# }

#   async ensureCreate(document: D, options: CollectionInsertOneOptions = {}): Promise<void> {
#     const errors = await this.create(document, options)
#     if (errors) throw new Error(`can't create ${this.name} ${stableJsonStringify(errors)}`)
#   }

#   async update(document: D, options: ReplaceOneOptions = {}): Promise<undefined | Errors<D>> {
#     const vresult = this.validate(document)
#     if (vresult.isError) return vresult.errors
#     try {
#       assert('_id' in document, `can't update document without _id`)
#       await this.native.replaceOne(postProcessQuery({ _id: (document as something)._id }), document, options)
#     } catch (e) {
#       const message = isKnownError(e)
#       if (message) return { '': [message] } as something // TODO 1 fixit
#       else         throw e
#     }
#     return undefined
#   }

#   async updatePart(query: Partial<D>, part: Partial<D>): Promise<undefined | Errors<D>> {
#     const found = await this.ensureOne(query)
#     const document = { ...found, ...part }
#     return await this.update({ ...document })
#   }

#   async ensureUpdatePart(query: Partial<D>, part: Partial<D>): Promise<void> {
#     const found = await this.ensureOne(query)
#     const document = { ...found, ...part }
#     await this.ensureUpdate({ ...document })
#   }

#   async ensureUpdate(document: D, options: CollectionInsertOneOptions = {}): Promise<void> {
#     const errors = await this.update(document, options)
#     if (errors) throw new Error(`can't update ${stableJsonStringify(errors)}`)
#   }

#   async deleteAll(query: FilterQuery<D>, options: CommonOptions = {}): Promise<number> {
#     query = postProcessQuery(query)
#     const { deletedCount } = await this.native.deleteMany(query, options)
#     if (deletedCount === null || deletedCount === undefined) throw new Error("no deleted count")
#     return deletedCount
#   }

#   async refresh(document: D): Promise<D & WithId> {
#     assert('_id' in document, `can't refresh model without _id`)
#     const _id = (document as something)._id
#     const found = await this.native.findOne(postProcessQuery({ _id }))
#     if (!found) throw new Error(`can't refresh model ${_id}, it doesn't exist in DB`)
#     return found as something
#   }
# }

# function postProcessQuery<T extends { [key: string]: something }>(query: T): T {
#   let result: something = query

#   // MongoDB requires `_id` to be of exact ObjectID tupe, it's very inconvenient, using autocasting
#   result = map(query, (v: something, k) => k == '_id' && !(v instanceof ObjectId) ? new ObjectId(v) : v)

#   // If _id supplied, removing everything else, use case to easily check if document exists
#   result = '_id' in query ? { _id: query._id } : query

#   return result
# }


if is_main_module:
  type
    User = object
      name: string

    Post = object
      title: string

  # Connecting
  let url = "mongodb://localhost:27017/"
  var n_connection = native.new_mongo(native.MongoUri(url), poolconn = 1)
  if not wait_for native.connect(n_connection):
    throw fmt"can't connect to {url}"

  let users = Collection[User].init("test_mdb", "users", n_connection)


  # CRUD
  users.drop

  let jim = User(name: "Jim")
  users.insert(jim)

  # Find
  let query = native.find(users.n_collection)
  echo waitfor native.all(query)

  # let id5doc = waitfor coll.findOne(bson {
  #   insertId: 5
  # })
  # doAssert id5doc["datetime"] == currtime + initDuration(hours = 5)
