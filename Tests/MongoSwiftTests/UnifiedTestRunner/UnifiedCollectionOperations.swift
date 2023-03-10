#if compiler(>=5.5.2) && canImport(_Concurrency)
import Foundation
@testable import MongoSwift
import TestsCommon

@available(macOS 10.15, *)
struct UnifiedAggregate: UnifiedOperationProtocol {
    /// Aggregation pipeline.
    let pipeline: [BSONDocument]

    /// Options to use for the operation.
    let options: AggregateOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case pipeline, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                AggregateOptions.CodingKeys.allCases.map { $0.rawValue }
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pipeline = try container.decode([BSONDocument].self, forKey: .pipeline)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(AggregateOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.resolveSession(id: self.session)
        let entity = try context.entities.getEntity(from: object)

        let cursor: MongoCursor<BSONDocument>
        switch entity {
        case let .collection(coll):
            cursor = try await coll.aggregate(self.pipeline, options: self.options, session: session)
        case let .database(db):
            cursor = try await db.aggregate(self.pipeline, options: self.options, session: session)
        default:
            throw TestError(message: "Unsupported entity \(entity) for aggregate")
        }

        let docs = try await cursor.toArray()
        return .rootDocumentArray(docs)
    }
}

@available(macOS 10.15, *)
struct UnifiedCreateIndex: UnifiedOperationProtocol {
    /// The name of the index to create.
    let name: String

    /// Keys for the index.
    let keys: BSONDocument

    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> {
        ["name", "keys", "session"]
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let opts = IndexOptions(name: self.name)
        let model = IndexModel(keys: self.keys, options: opts)
        _ = try await collection.createIndex(model, session: session)
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedListIndexes: UnifiedOperationProtocol {
    /// Optional identifier for a session entity to use.
    let session: String?

    /// We consider this a known argument and decode it even though we don't support it, because a load balancer test
    /// file uses this option and we could not decode/run the entire file otherwise.
    let batchSize: Int?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case session, batchSize
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue }
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.batchSize = try container.decodeIfPresent(Int.self, forKey: .batchSize)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        guard self.batchSize == nil else {
            throw TestError(
                message: "listIndexes operation specifies a batchSize, but we do not support the option -- you may " +
                    "need to skip this test. Path: \(context.path)"
            )
        }
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let results = try await collection.listIndexes(session: session).toArray()
        return .rootDocumentArray(try results.map { try BSONEncoder().encode($0) })
    }
}

@available(macOS 10.15, *)
struct UnifiedBulkWrite: UnifiedOperationProtocol {
    /// Writes to perform.
    let requests: [WriteModel<BSONDocument>]

    /// Options to use for the operation.
    let options: BulkWriteOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case requests, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                BulkWriteOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(BulkWriteOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        let decodedRequests = try container.decode([TestWriteModel].self, forKey: .requests)
        self.requests = decodedRequests.map { $0.toWriteModel() }
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try await collection.bulkWrite(self.requests, options: self.options, session: session) else {
            return .unacknowledgedWrite
        }
        let encodedResult = try BSONEncoder().encode(result)
        return .rootDocument(encodedResult)
    }
}

@available(macOS 10.15, *)
struct UnifiedFind: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Options to use for the operation.
    let options: FindOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case session, filter
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOptions.CodingKeys.allCases.map { $0.rawValue }
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(FindOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let cursor = try await collection.find(self.filter, options: self.options, session: session).toArray()
        return .rootDocumentArray(cursor)
    }
}

@available(macOS 10.15, *)
struct UnifiedCreateFindCursor: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Options to use for the operation.
    let options: FindOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case session, filter
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOptions.CodingKeys.allCases.map { $0.rawValue }
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(FindOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        return .findCursor(try await collection.find(self.filter, options: self.options, session: session))
    }
}

@available(macOS 10.15, *)
struct UnifiedFindOneAndReplace: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Replacement document.
    let replacement: BSONDocument

    /// Options to use for the operation.
    let options: FindOneAndReplaceOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, replacement, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOneAndReplaceOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(FindOneAndReplaceOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.replacement = try container.decode(BSONDocument.self, forKey: .replacement)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try await collection.findOneAndReplace(
            filter: filter,
            replacement: replacement,
            options: options,
            session: session
        ) else {
            return .none
        }
        return .rootDocument(result)
    }
}

@available(macOS 10.15, *)
struct UnifiedFindOneAndUpdate: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Update to use for this operation.
    let updateModel: UpdateModel

    /// Options to use for the operation.
    let options: FindOneAndUpdateOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, update, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOneAndUpdateOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(FindOneAndUpdateOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.updateModel = try container.decode(UpdateModel.self, forKey: .update)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let result: BSONDocument?
        switch self.updateModel {
        case let .updateDoc(update):
            result = try await collection.findOneAndUpdate(
                filter: self.filter,
                update: update,
                options: self.options,
                session: session
            )
        case let .pipeline(pipeline):
            result = try await collection.findOneAndUpdate(
                filter: self.filter,
                pipeline: pipeline,
                options: self.options,
                session: session
            )
        }
        if let doc = result {
            return .rootDocument(doc)
        } else {
            return .none
        }
    }
}

@available(macOS 10.15, *)
struct UnifiedFindOneAndDelete: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    let options: FindOneAndDeleteOptions?

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                FindOneAndDeleteOptions().propertyNames
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case filter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.options = try decoder.singleValueContainer().decode(FindOneAndDeleteOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        guard let result = try await collection.findOneAndDelete(filter, options: self.options) else {
            return .none
        }
        return .rootDocument(result)
    }
}

@available(macOS 10.15, *)
struct UnifiedDeleteOne: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    /// Options to use for the operation.
    let options: DeleteOptions

    /// Optional identifier for a session entity to use.
    let session: String?

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case session, filter
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                DeleteOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(DeleteOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try await collection.deleteOne(filter, options: options, session: session) else {
            return .unacknowledgedWrite
        }
        let encoded = try BSONEncoder().encode(result)
        return .rootDocument(encoded)
    }
}

@available(macOS 10.15, *)
struct UnifiedDeleteMany: UnifiedOperationProtocol {
    /// Filter to use for the operation.
    let filter: BSONDocument

    let options: DeleteOptions?

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                DeleteOptions().propertyNames
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case filter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.options = try decoder.singleValueContainer().decode(DeleteOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        guard let result = try await collection.deleteMany(filter, options: self.options) else {
            return .unacknowledgedWrite
        }
        let encoded = try BSONEncoder().encode(result)
        return .rootDocument(encoded)
    }
}

@available(macOS 10.15, *)
struct UnifiedInsertOne: UnifiedOperationProtocol {
    /// Document to insert.
    let document: BSONDocument

    /// Optional identifier for a session entity to use.
    let session: String?

    /// Options to use while executing the operation.
    let options: InsertOneOptions

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case document, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                InsertOneOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.document = try container.decode(BSONDocument.self, forKey: .document)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(InsertOneOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try await collection.insertOne(self.document, options: self.options, session: session) else {
            return .unacknowledgedWrite
        }
        return .rootDocument(try BSONEncoder().encode(result))
    }
}

@available(macOS 10.15, *)
struct UnifiedInsertMany: UnifiedOperationProtocol {
    /// Documents to insert.
    let documents: [BSONDocument]

    /// Optional identifier for a session entity to use.
    let session: String?

    /// Options to use while executing the operation.
    let options: InsertManyOptions

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case documents, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                InsertManyOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.documents = try container.decode([BSONDocument].self, forKey: .documents)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(InsertManyOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try await collection.insertMany(self.documents, options: options, session: session) else {
            return .unacknowledgedWrite
        }
        let encoded = try BSONEncoder().encode(result)
        return .rootDocument(encoded)
    }
}

@available(macOS 10.15, *)
struct UnifiedReplaceOne: UnifiedOperationProtocol {
    /// Filter for the query.
    let filter: BSONDocument

    /// Replacement document.
    let replacement: BSONDocument

    /// Optional identifier for a session entity to use.
    let session: String?

    /// Options to use while executing the operation.
    let options: ReplaceOptions

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, replacement, session
    }

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                ReplaceOptions().propertyNames
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.replacement = try container.decode(BSONDocument.self, forKey: .replacement)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
        self.options = try decoder.singleValueContainer().decode(ReplaceOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        guard let result = try await collection.replaceOne(
            filter: filter,
            replacement: replacement,
            options: options,
            session: session
        ) else {
            return .unacknowledgedWrite
        }
        let encoded = try BSONEncoder().encode(result)
        return .rootDocument(encoded)
    }
}

@available(macOS 10.15, *)
struct UnifiedCountDocuments: UnifiedOperationProtocol {
    /// Filter for the query.
    let filter: BSONDocument

    /// Options for the query.
    let options: CountDocumentsOptions?

    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> {
        Set(Self.CodingKeys.allCases.map { $0.stringValue })
            .union(Set(CountDocumentsOptions.CodingKeys.allCases.map { $0.stringValue }))
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, session
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(CountDocumentsOptions.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let result = try await collection.countDocuments(self.filter, options: self.options, session: session)
        return .bson(BSON(result))
    }
}

@available(macOS 10.15, *)
struct UnifiedEstimatedDocumentCount: UnifiedOperationProtocol {
    let options: EstimatedDocumentCountOptions?

    static var knownArguments: Set<String> {
        Set(EstimatedDocumentCountOptions.CodingKeys.allCases.map { $0.stringValue })
    }

    init(from decoder: Decoder) throws {
        self.options = try decoder.singleValueContainer().decode(EstimatedDocumentCountOptions.self)
    }

    init() {
        self.options = nil
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let result = try await collection.estimatedDocumentCount(options: self.options)
        return .bson(BSON(result))
    }
}

@available(macOS 10.15, *)
struct UnifiedRename: UnifiedOperationProtocol {
    /// Field that defines what the collection is renamed to.
    let to: String

    static var knownArguments: Set<String> {
        ["to"] // explicit argument in renameCollectionOperation
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        _ = try await collection.renamed(to: self.to)

        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedDistinct: UnifiedOperationProtocol {
    /// Field to retrieve distinct values for.
    let fieldName: String

    /// Filter for the query.
    let filter: BSONDocument

    /// Options to use for the operation.
    let options: DistinctOptions?

    /// Optional identifier for a session entity to use.
    let session: String?

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                DistinctOptions.CodingKeys.allCases.map { $0.rawValue }
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case fieldName, filter, session
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fieldName = try container.decode(String.self, forKey: .fieldName)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.options = try decoder.singleValueContainer().decode(DistinctOptions.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let result = try await collection.distinct(
            fieldName: self.fieldName,
            filter: self.filter,
            options: self.options,
            session: session
        )

        return .bson(.array(result))
    }
}

@available(macOS 10.15, *)
struct UnifiedUpdateOne: UnifiedOperationProtocol {
    /// Filter for the query.
    let filter: BSONDocument

    /// Update to perform.
    let updateModel: UpdateModel

    let options: UpdateOptions?

    let session: String?

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                UpdateOptions().propertyNames
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, update, session
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.updateModel = try container.decode(UpdateModel.self, forKey: .update)
        self.options = try decoder.singleValueContainer().decode(UpdateOptions.self)
        self.session = try container.decodeIfPresent(String.self, forKey: .session)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let session = try context.entities.resolveSession(id: self.session)
        let result: UpdateResult?
        switch self.updateModel {
        case let .updateDoc(update):
            result = try await collection.updateOne(
                filter: self.filter,
                update: update,
                options: self.options,
                session: session
            )
        case let .pipeline(pipeline):
            result = try await collection.updateOne(
                filter: self.filter,
                pipeline: pipeline,
                options: self.options,
                session: session
            )
        }
        if let updateResult = result {
            let encoded = try BSONEncoder().encode(updateResult)
            return .rootDocument(encoded)
        } else {
            return .unacknowledgedWrite
        }
    }
}

@available(macOS 10.15, *)
struct UnifiedUpdateMany: UnifiedOperationProtocol {
    /// Filter for the query.
    let filter: BSONDocument

    /// Update to perform.
    let updateModel: UpdateModel

    let options: UpdateOptions?

    static var knownArguments: Set<String> {
        Set(
            CodingKeys.allCases.map { $0.rawValue } +
                UpdateOptions().propertyNames
        )
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case filter, update
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.filter = try container.decode(BSONDocument.self, forKey: .filter)
        self.updateModel = try container.decode(UpdateModel.self, forKey: .update)
        self.options = try decoder.singleValueContainer().decode(UpdateOptions.self)
    }

    func execute(on object: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = try context.entities.getEntity(from: object).asCollection()
        let result: UpdateResult?
        switch self.updateModel {
        case let .updateDoc(update):
            result = try await collection.updateMany(filter: self.filter, update: update, options: self.options)
        case let .pipeline(pipeline):
            result = try await collection.updateMany(filter: self.filter, pipeline: pipeline, options: self.options)
        }
        if let updateResult = result {
            let encoded = try BSONEncoder().encode(updateResult)
            return .rootDocument(encoded)
        } else {
            return .unacknowledgedWrite
        }
    }
}

enum UpdateModel: Decodable {
    case updateDoc(BSONDocument)
    case pipeline([BSONDocument])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let updateDoc = try? container.decode(BSONDocument.self) {
            self = .updateDoc(updateDoc)
        } else if let pipeline = try? container.decode([BSONDocument].self) {
            self = .pipeline(pipeline)
        } else {
            throw DecodingError.typeMismatch(
                UpdateModel.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "update must be document or aggregation pipeline"
                )
            )
        }
    }
}
#endif
