import MongoSwiftSync
import Nimble
import TestsCommon

/// Protocol describing the behavior of a spec test "operation"
protocol TestOperation: Decodable {
    func execute(on client: MongoClient, sessions: [String: ClientSession]) throws -> TestOperationResult?

    func execute(on database: MongoDatabase, sessions: [String: ClientSession]) throws -> TestOperationResult?

    func execute(
        on collection: MongoCollection<BSONDocument>,
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult?

    func execute(on session: ClientSession) throws -> TestOperationResult?

    func execute<T: SpecTest>(
        on runner: inout T,
        setupClient: MongoClient,
        mongosClients: [ServerAddress: MongoClient],
        sessions: [String: ClientSession]
    ) throws -> TestOperationResult?
}

extension TestOperation {
    func execute(on _: MongoClient, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        throw TestError(message: "\(type(of: self)) cannot execute on a client")
    }

    func execute(on _: MongoDatabase, sessions _: [String: ClientSession]) throws -> TestOperationResult? {
        throw TestError(message: "\(type(of: self)) cannot execute on a database")
    }

    func execute(
        on _: MongoCollection<BSONDocument>,
        sessions _: [String: ClientSession]
    ) throws -> TestOperationResult? {
        throw TestError(message: "\(type(of: self)) cannot execute on a collection")
    }

    func execute(on _: ClientSession) throws -> TestOperationResult? {
        throw TestError(message: "\(type(of: self)) cannot execute on a session")
    }

    func execute<T: SpecTest>(
        on _: inout T,
        setupClient _: MongoClient,
        mongosClients _: [ServerAddress: MongoClient],
        sessions _: [String: ClientSession]
    ) throws -> TestOperationResult? {
        throw TestError(message: "\(type(of: self)) cannot execute on a test runner")
    }
}

/// A enumeration of the different objects a `TestOperation` may be performed against.
enum TestOperationObject: Decodable {
    case client
    case database
    case collection
    case gridfsbucket
    case testRunner
    case session(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "client":
            self = .client
        case "database":
            self = .database
        case "collection":
            self = .collection
        case "gridfsbucket":
            self = .gridfsbucket
        case "testRunner":
            self = .testRunner
        default:
            self = .session(rawValue)
        }
    }
}

/// Struct containing an operation and an expected outcome.
struct TestOperationDescription: Decodable {
    /// The operation to run.
    let operation: AnyTestOperation

    /// The object to perform the operation on.
    let object: TestOperationObject

    /// The return value of the operation, if any.
    let result: TestOperationResult?

    /// Whether the operation should expect an error.
    let error: Bool?

    /// The parameters to pass to the database used for this operation.
    let databaseOptions: MongoDatabaseOptions?

    /// The parameters to pass to the collection used for this operation.
    let collectionOptions: MongoCollectionOptions?

    public enum CodingKeys: String, CodingKey {
        case object, result, error, databaseOptions, collectionOptions
    }

    public init(from decoder: Decoder) throws {
        self.operation = try AnyTestOperation(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.object = try container.decode(TestOperationObject.self, forKey: .object)
        self.result = try container.decodeIfPresent(TestOperationResult.self, forKey: .result)
        self.error = try container.decodeIfPresent(Bool.self, forKey: .error)
        self.databaseOptions = try container.decodeIfPresent(MongoDatabaseOptions.self, forKey: .databaseOptions)
        self.collectionOptions = try container.decodeIfPresent(MongoCollectionOptions.self, forKey: .collectionOptions)
    }

    // swiftlint:disable cyclomatic_complexity

    /// Runs the operation and asserts its results meet the expectation.
    ///
    /// The operation may be mutated over the course of this execution (e.g. by enabling a failpoint), so it
    /// must be passed as an `inout` parameter.
    // swiftlint:disable:next function_parameter_count
    func validateExecution<T: SpecTest>(
        test: inout T,
        setupClient: MongoClient,
        client: MongoClient,
        mongosClients: [ServerAddress: MongoClient],
        dbName: String,
        collName: String?,
        sessions: [String: ClientSession]
    ) throws {
        let database = client.db(dbName, options: self.databaseOptions)
        var collection: MongoCollection<BSONDocument>?

        if let collName = collName {
            collection = database.collection(collName, options: self.collectionOptions)
        }

        do {
            let result: TestOperationResult?
            switch self.object {
            case .client:
                result = try self.operation.op.execute(on: client, sessions: sessions)
            case .database:
                result = try self.operation.op.execute(on: database, sessions: sessions)
            case .collection:
                guard let collection = collection else {
                    throw TestError(message: "got collection object but was not provided a collection")
                }
                result = try self.operation.op.execute(on: collection, sessions: sessions)
            case let .session(sessionName):
                guard let session = sessions[sessionName] else {
                    throw TestError(message: "got session object but was not provided a session")
                }
                result = try self.operation.op.execute(on: session)
            case .testRunner:
                result = try self.operation.op.execute(
                    on: &test,
                    setupClient: setupClient,
                    mongosClients: mongosClients,
                    sessions: sessions
                )
            case .gridfsbucket:
                throw TestError(message: "gridfs tests should be skipped")
            }

            expect(self.error ?? false)
                .to(beFalse(), description: "expected to fail but succeeded with result \(String(describing: result))")
            if let expectedResult = self.result {
                expect(result).to(match(expectedResult))
            }
        } catch {
            if case let .error(expectedErrorResult) = self.result {
                expectedErrorResult.checkErrorResult(error, description: test.description)
            } else {
                expect(self.error ?? false).to(beTrue(), description: "expected no error, got \(error)")
            }
        }
    }

    // swiftlint:enable cyclomatic_complexity
}

/// Wrapper around a `TestOperation.swift` allowing it to be decoded from a spec test.
struct AnyTestOperation: Decodable {
    let op: TestOperation

    private enum CodingKeys: String, CodingKey {
        case name, arguments, commandName = "command_name"
    }

    // swiftlint:disable:next cyclomatic_complexity
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let opName = try container.decode(String.self, forKey: .name)

        switch opName {
        case "aggregate":
            self.op = try container.decode(Aggregate.self, forKey: .arguments)
        case "countDocuments":
            self.op = try container.decode(CountDocuments.self, forKey: .arguments)
        case "estimatedDocumentCount":
            self.op = EstimatedDocumentCount()
        case "distinct":
            self.op = try container.decode(Distinct.self, forKey: .arguments)
        case "find":
            self.op = try container.decode(Find.self, forKey: .arguments)
        case "findOne":
            self.op = try container.decode(FindOne.self, forKey: .arguments)
        case "updateOne":
            self.op = try container.decode(UpdateOne.self, forKey: .arguments)
        case "updateMany":
            self.op = try container.decode(UpdateMany.self, forKey: .arguments)
        case "insertOne":
            self.op = try container.decode(InsertOne.self, forKey: .arguments)
        case "insertMany":
            self.op = try container.decode(InsertMany.self, forKey: .arguments)
        case "deleteOne":
            self.op = try container.decode(DeleteOne.self, forKey: .arguments)
        case "deleteMany":
            self.op = try container.decode(DeleteMany.self, forKey: .arguments)
        case "bulkWrite":
            self.op = try container.decode(BulkWrite.self, forKey: .arguments)
        case "findOneAndDelete":
            self.op = try container.decode(FindOneAndDelete.self, forKey: .arguments)
        case "findOneAndReplace":
            self.op = try container.decode(FindOneAndReplace.self, forKey: .arguments)
        case "findOneAndUpdate":
            self.op = try container.decode(FindOneAndUpdate.self, forKey: .arguments)
        case "replaceOne":
            self.op = try container.decode(ReplaceOne.self, forKey: .arguments)
        case "rename":
            self.op = try container.decode(RenameCollection.self, forKey: .arguments)
        case "startTransaction":
            self.op = (try container.decodeIfPresent(StartTransaction.self, forKey: .arguments)) ?? StartTransaction()
        case "createCollection":
            self.op = try container.decode(CreateCollection.self, forKey: .arguments)
        case "dropCollection":
            self.op = try container.decode(DropCollection.self, forKey: .arguments)
        case "createIndex":
            self.op = try container.decode(CreateIndex.self, forKey: .arguments)
        case "runCommand":
            let commandName = try container.decode(String.self, forKey: .commandName)
            self.op = try container.decode(RunCommand.self, forKey: .arguments).withCommandName(commandName)
        case "assertCollectionExists":
            self.op = try container.decode(AssertCollectionExists.self, forKey: .arguments)
        case "assertCollectionNotExists":
            self.op = try container.decode(AssertCollectionNotExists.self, forKey: .arguments)
        case "assertIndexExists":
            self.op = try container.decode(AssertIndexExists.self, forKey: .arguments)
        case "assertIndexNotExists":
            self.op = try container.decode(AssertIndexNotExists.self, forKey: .arguments)
        case "assertSessionPinned":
            self.op = try container.decode(AssertSessionPinned.self, forKey: .arguments)
        case "assertSessionUnpinned":
            self.op = try container.decode(AssertSessionUnpinned.self, forKey: .arguments)
        case "assertSessionTransactionState":
            self.op = try container.decode(AssertSessionTransactionState.self, forKey: .arguments)
        case "targetedFailPoint":
            self.op = try container.decode(TargetedFailPoint.self, forKey: .arguments)
        case "drop":
            self.op = Drop()
        case "listDatabaseNames":
            self.op = ListDatabaseNames()
        case "listDatabases":
            self.op = ListDatabases()
        case "listDatabaseObjects":
            self.op = ListMongoDatabases()
        case "listIndexes":
            self.op = ListIndexes()
        case "listIndexNames":
            self.op = ListIndexNames()
        case "listCollections":
            self.op = ListCollections()
        case "listCollectionObjects":
            self.op = ListMongoCollections()
        case "listCollectionNames":
            self.op = ListCollectionNames()
        case "watch":
            self.op = Watch()
        case "commitTransaction":
            self.op = CommitTransaction()
        case "abortTransaction":
            self.op = AbortTransaction()
        case "mapReduce", "download_by_name", "download", "count":
            self.op = NotImplemented(name: opName)
        default:
            throw TestError(message: "unsupported op name \(opName)")
        }
    }
}

/// Dummy `TestOperation` that can be used in place of an unimplemented one (e.g. findOne)
struct NotImplemented: TestOperation {
    internal let name: String
}
