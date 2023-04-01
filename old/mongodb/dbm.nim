# import { assert, inlineTest, log, p } from '../../base'
# import { MongoClient, Db, Collection } from 'mongodb'

# export type GetCollection = <T>(name: string) => Collection<T>

# export type DbCallback = (db: Db) => void | Promise<void>
# export interface GetDb {
#   (): Db
#   (cb: DbCallback): void
#   (cb?: DbCallback): Db | void
# }

# export function buildConnection() {
#   // getDb --------------------------------------------------------------------------

#   let db: Db | null = null
#   const callbacks: DbCallback[] = []
#   function getDb(): Db
#   function getDb(cb: DbCallback): void
#   function getDb(cb?: DbCallback): Db | void {
#     if (cb) db ? cb(db) : callbacks.push(cb)
#     else {
#       if (!db) throw new Error(`wrong usage, it should be used only after db is connected`)
#       return db
#     }
#   }

#   // getCollection ------------------------------------------------------------------
#   function getCollection<T>(name: string): Collection<T> {
#     if (!db) throw new Error(`wrong usage, collection ${name} used before db is connected`)
#     return db.collection(name)
#   }

#   // connect ------------------------------------------------------------------------
#   let cachedPromise: Promise<MongoClient> | null = null
#   function connect(url: string): Promise<MongoClient> {
#     if (cachedPromise) return cachedPromise
#     cachedPromise = new Promise((resolve, reject) => {
#       const client = new MongoClient(url, { useNewUrlParser: true })
#       client.connect()
#         .then(() => {
#           db = client.db()
#           log('info', `db connected to ${db.databaseName}`)
#           // Intentionally not waiting for cb to resolve to not block startup
#           for (const cb of callbacks) {
#             const result = cb(db)
#             if (result) result.catch((e) => {
#               log('error', `error during execution of db callbacks, exiting`, e)
#               process.exit()
#             })
#           }
#           resolve(client)
#         })
#         .catch(reject)
#     })
#     return cachedPromise
#   }

#   return { getDb, getCollection, connect }
# }