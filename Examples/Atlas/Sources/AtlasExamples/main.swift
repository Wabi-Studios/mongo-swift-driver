import Foundation
import MongoSwift
import NIO

/// Atlas connection string examples
/// Please include the above imports in the snippets.

func scramExample() throws {
    // START SCRAM EXAMPLE HERE
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    let client = try MongoClient(
        "mongodb+srv://<user>:<password>@<host>/<dbname>?retryWrites=true&w=majority",
        using: elg
    )
    defer {
        try? client.syncClose()
        cleanupMongoSwift()
        try? elg.syncShutdownGracefully()
    }

    let db = client.db("library")
    let collection = db.collection("books")
    // do something with collection
    // END SCRAM EXAMPLE HERE
}

func x509Example() throws {
    // START x509 EXAMPLE HERE
    let elg = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    let options = MongoClientOptions(
        credential: MongoCredential(mechanism: .mongodbX509),
        tlsCAFile: URL(string: "/path/to/cert"),
        tlsCertificateKeyFile: URL(string: "/path/to/cert")
    )
    let client = try MongoClient(
        "mongodb+srv://<host>/<dbname>?retryWrites=true&w=majority",
        using: elg,
        options: options
    )
    defer {
        try? client.syncClose()
        cleanupMongoSwift()
        try? elg.syncShutdownGracefully()
    }

    let db = client.db("library")
    let collection = db.collection("books")
    // do something with collection
    // END x509 EXAMPLE HERE
}
