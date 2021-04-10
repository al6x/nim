import basem
import ./utils
# import { Collection as NativeCollection, FilterQuery, FindOneOptions,
#   CollectionInsertOneOptions, MongoCountPreferences, ReplaceOneOptions, CommonOptions, ObjectId } from 'mongodb'

# // Empty string indicates that there's some error without specific message
# export type Errors<D> = { [k in ('' | (keyof D))]?: string }

# export type ValidatorReturn = true | false | { error: string }
# export type Validators<D> = {
#   readonly [K in keyof D]?: (value: D[K] | undefined, partial: Partial<D>) => ValidatorReturn
# }

# export interface WithId { _id: ObjectId }

# export function validate<D>(
#   partial: Partial<D>, validators: Validators<D>
# ): { isError: false, validated: D } | { isError: true, errors: Errors<D> } {
#   const errors: Errors<D> = {}
#   each(validators, (validator, k) => {
#     if (!validator) throw new Error(`undefined validator ${validator}`)
#     const result = validator(partial[k], partial)
#     if      (result === false) errors[k] = ''
#     else if (result instanceof Object) errors[k] = result.error
#   })
#   return isEmpty(errors) ? { isError: false, validated: partial as D } : { isError: true, errors }
# }

# export function ensureValid<D>(partial: Partial<D>, validators: Validators<D>): D {
#   const result = validate(partial, validators)
#   if (result.isError) throw new Error(`expected document to be valid`)
#   return result.validated
# }

# // export function validatePartial<D>(
# //   partial: Partial<D>, validators: Validators<D>
# // ): { isError: false } | { isError: true, errors: Errors<D> } {
# //   const errors: Errors<D> = {}
# //   each(validators, (validator, k) => {
# //     if (!validator) throw new Error(`undefined validator ${validator}`)
# //     if (k in partial) {
# //       const result = validator(partial[k], partial)
# //       if (result && result.length > 0) errors[k] = result instanceof Array ? result : [result]
# //     }
# //   })
# //   return isEmpty(errors) ? { isError: false } : { isError: true, errors }
# // }

# interface FindOptions<D> {
#   skip?:       number
#   limit?:      number
#   sort?:       { [K in keyof D]?: number }
#   projection?: { [K in keyof D]?: number } & { _id?: number }
# }

# export abstract class AbstractCollection<D> {
#   public abstract readonly name:  string

#   // Both `validate` and `validators` could be overriden in actual collection to define validatio rules
#   public validate(document: D) { return validate(document, this.validators) }
#   public readonly validators: Validators<D> = {}

#   protected abstract _getNativeCollection(name: string): NativeCollection<D>

#   get native(): NativeCollection<D> { return this._getNativeCollection(this.name) }

#   async exist(query?: FilterQuery<D>, options: FindOneOptions = {}): Promise<boolean> {
#     query = postProcessQuery(query || {})
#     return !!(await this.native.findOne(query, { projection: { _id: 1 }, ...options }))
#   }

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

#   async create(document: D, options: CollectionInsertOneOptions = {}): Promise<undefined | Errors<D>> {
#     const vresult = this.validate(document)
#     if (vresult.isError) return vresult.errors
#     try {
#       const { insertedId } = await this.native.insertOne(document, options)
#       ;(document as something)._id = insertedId
#       return undefined
#     } catch (e) {
#       const message = isKnownError(e)
#       if (message) return { '': [message] } as something // TODO 1 fixit
#       else         throw e
#     }
#   }

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