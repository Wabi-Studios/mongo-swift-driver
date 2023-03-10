#if compiler(>=5.5.2) && canImport(_Concurrency)
@testable import MongoSwift
import Nimble
import TestsCommon
import XCTest

@available(macOS 10.15, *)
struct UnifiedFailPoint: UnifiedOperationProtocol {
    /// The failpoint to set.
    let failPoint: FailPoint

    /// The client entity to use for setting the failpoint.
    let client: String

    /// Optional name of a session entity to use for setting the failpoint.
    let session: String?

    static var knownArguments: Set<String> {
        ["failPoint", "client", "session"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let testClient = try context.entities.getEntity(id: self.client).asTestClient()
        let session = try context.entities.resolveSession(id: self.session)
        let opts = RunCommandOptions(readPreference: .primary)
        let fpGuard = try await self.failPoint.enable(using: testClient.client, options: opts, session: session)
        context.enabledFailPoints.append(fpGuard)
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedAssertCollectionExists: UnifiedOperationProtocol {
    /// The collection name.
    let collectionName: String

    /// The name of the database
    let databaseName: String

    static var knownArguments: Set<String> {
        ["collectionName", "databaseName"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let db = context.internalClient.anyClient.db(self.databaseName)
        let listNames = try await db.listCollectionNames()
        expect(listNames).to(
            contain(self.collectionName),
            description: "Expected db \(self.databaseName) to contain collection \(self.collectionName)." +
                " Path: \(context.path)"
        )
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedAssertCollectionNotExists: UnifiedOperationProtocol {
    /// The collection name.
    let collectionName: String

    /// The name of the database.
    let databaseName: String

    static var knownArguments: Set<String> {
        ["collectionName", "databaseName"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let db = context.internalClient.anyClient.db(self.databaseName)
        let listNames = try await db.listCollectionNames()
        expect(listNames).toNot(
            contain(self.collectionName),
            description: "Expected db \(self.databaseName) to not contain collection \(self.collectionName)." +
                " Path: \(context.path)"
        )
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedAssertIndexExists: UnifiedOperationProtocol {
    /// The collection name.
    let collectionName: String

    /// The name of the database.
    let databaseName: String

    /// The name of the index.
    let indexName: String

    static var knownArguments: Set<String> {
        ["collectionName", "databaseName", "indexName"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = context.internalClient.anyClient.db(self.databaseName).collection(self.collectionName)
        let listIndexes = try await collection.listIndexNames()
        expect(listIndexes).to(
            contain(self.indexName),
            description: "Expected collection \(collection.namespace) to have index \(self.indexName)."
                + " Path: \(context.path)"
        )
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedAssertIndexNotExists: UnifiedOperationProtocol {
    /// The collection name.
    let collectionName: String

    /// The name of the database to look for the collection in.
    let databaseName: String

    /// The name of the index.
    let indexName: String

    static var knownArguments: Set<String> {
        ["collectionName", "databaseName", "indexName"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let collection = context.internalClient.anyClient.db(self.databaseName).collection(self.collectionName)
        let listNames = try await collection.listIndexNames()
        expect(listNames).toNot(
            contain(self.indexName),
            description: "Expected collection \(collection.namespace) to not have index \(self.indexName)."
                + " Path: \(context.path)"
        )
        return .none
    }
}

@available(macOS 10.15, *)
struct AssertSessionNotDirty: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(id: self.session).asSession()
        expect(session.isDirty())
            .to(beFalse(), description: "Session \(self.session) should not be dirty. Path: \(context.path)")
        return .none
    }
}

@available(macOS 10.15, *)
struct AssertSessionDirty: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(id: self.session).asSession()
        expect(session.isDirty())
            .to(beTrue(), description: "Session \(self.session) should be dirty. Path: \(context.path)")
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedAssertSessionPinned: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(id: self.session).asSession()
        expect(session.isPinned)
            .to(beTrue(), description: "Session \(self.session) unexpectedly unpinned. Path: \(context.path)")
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedAssertSessionUnpinned: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    static var knownArguments: Set<String> {
        ["session"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(id: self.session).asSession()
        expect(session.isPinned)
            .to(beFalse(), description: "Session \(self.session) unexpectedly pinned. Path: \(context.path)")
        return .none
    }
}

@available(macOS 10.15, *)
struct UnifiedAssertSessionTransactionState: UnifiedOperationProtocol {
    /// The session entity to perform the assertion on.
    let session: String

    /// The expected transaction state.
    let state: MongoSwift.ClientSession.TransactionState

    static var knownArguments: Set<String> {
        ["session", "state"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(id: self.session).asSession()
        let actualState = session.transactionState
        expect(actualState).to(equal(self.state), description: "Session had unexpected transaction state")
        return .none
    }
}

@available(macOS 10.15, *)
struct AssertDifferentLsidOnLastTwoCommands: UnifiedOperationProtocol {
    /// Identifier for the client to perform the assertion on.
    let client: String

    static var knownArguments: Set<String> {
        ["client"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let client = try context.entities.getEntity(id: self.client).asTestClient()
        makeLsidAssertion(client: client, same: false, context: context)
        return .none
    }
}

@available(macOS 10.15, *)
struct AssertSameLsidOnLastTwoCommands: UnifiedOperationProtocol {
    /// Identifier for the client to perform the assertion on.
    let client: String

    static var knownArguments: Set<String> {
        ["client"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let client = try context.entities.getEntity(id: self.client).asTestClient()
        makeLsidAssertion(client: client, same: true, context: context)
        return .none
    }
}

func makeLsidAssertion(client: UnifiedTestClient, same: Bool, context: Context) {
    let lastTwoEvents = Array(client.commandMonitor.events.compactMap { $0.commandStartedValue }.suffix(2))
    expect(lastTwoEvents.count).to(
        equal(2),
        description: "Expected client to have at least two command started events. Path: \(context.path)"
    )

    let command1 = lastTwoEvents[0].command
    let command2 = lastTwoEvents[1].command

    expect(command1["lsid"]).toNot(beNil(), description: "Expected command to have lsid. Path: \(context.path)")
    let lsid1 = command1["lsid"]!

    expect(command2["lsid"]).toNot(beNil(), description: "Expected command to have lsid. Path: \(context.path)")
    let lsid2 = command2["lsid"]!

    if same {
        expect(lsid1).to(equal(lsid2), description: "lsids for last two commands did not match. Path: \(context.path)")
    } else {
        expect(lsid1).toNot(
            equal(lsid2),
            description: "lsids for last two commands unexpectedly matched. Path: \(context.path)"
        )
    }
}

@available(macOS 10.15, *)
struct UnifiedTargetedFailPoint: UnifiedOperationProtocol {
    /// The failpoint to set.
    let failPoint: FailPoint

    /// Identifier for the session entity with which to set the fail point.
    let session: String

    static var knownArguments: Set<String> {
        ["failPoint", "session"]
    }

    func execute(on _: UnifiedOperation.Object, context: Context) async throws -> UnifiedOperationResult {
        let session = try context.entities.getEntity(id: self.session).asSession()
        // The mongos on which to set the fail point is determined by the session argument (after resolution to a
        // session entity). Test runners MUST error if the session is not pinned to a mongos server at the time this
        // operation is executed.
        guard session.pinnedServerAddress != nil else {
            XCTFail("Session \(self.session) unexpectedly not pinned to a mongos. Path: \(context.path)")
            return .none
        }
        let mongosClients = try context.internalClient.asMongosClients()
        guard let clientForPinnedMongos = mongosClients[session.pinnedServerAddress!] else {
            throw TestError(message: "Unexpectedly missing client for mongos \(session.pinnedServerAddress!)")
        }
        let fpGuard = try await self.failPoint.enable(using: clientForPinnedMongos)
        // add to context's list of enabled failpoints to ensure we disable it later.
        context.enabledFailPoints.append(fpGuard)
        return .none
    }
}
#endif
