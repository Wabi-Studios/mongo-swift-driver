import MongoSwift

/// An extension of `MongoCollection` encapsulating index management capabilities.
extension MongoCollection {
    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - keys: a `Document` specifing the keys for the index
     *   - indexOptions: Optional `IndexOptions` to use for the index
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: The name of the created index.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the write.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the index specification or options.
     */
    @discardableResult
    public func createIndex(
        _ keys: BSONDocument,
        indexOptions: IndexOptions? = nil,
        options: CreateIndexOptions? = nil,
        session: ClientSession? = nil
    ) throws -> String {
        try self.asyncColl.createIndex(
            keys,
            indexOptions: indexOptions,
            options: options,
            session: session?.asyncSession
        )
        .wait()
    }

    /**
     * Creates an index over the collection for the provided keys with the provided options.
     *
     * - Parameters:
     *   - model: An `IndexModel` representing the keys and options for the index
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: The name of the created index.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the write.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the index specification or options.
     */
    @discardableResult
    public func createIndex(
        _ model: IndexModel,
        options: CreateIndexOptions? = nil,
        session: ClientSession? = nil
    ) throws -> String {
        try self.asyncColl.createIndex(model, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Creates multiple indexes in the collection.
     *
     * - Parameters:
     *   - models: An `[IndexModel]` specifying the indexes to create
     *   - options: Optional `CreateIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: An `[String]` containing the names of all the indexes that were created.
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the write.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the index specifications or options.
     */
    @discardableResult
    public func createIndexes(
        _ models: [IndexModel],
        options: CreateIndexOptions? = nil,
        session: ClientSession? = nil
    ) throws -> [String] {
        try self.asyncColl.createIndexes(models, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Drops a single index from the collection by the index name.
     *
     * - Parameters:
     *   - name: The name of the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `EncodingError` if an error occurs while encoding the options.
     */
    public func dropIndex(
        _ name: String,
        options: DropIndexOptions? = nil,
        session: ClientSession? = nil
    ) throws {
        try self.asyncColl.dropIndex(name, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Attempts to drop a single index from the collection given the keys describing it.
     *
     * - Parameters:
     *   - keys: a `Document` containing the keys for the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options.
     */
    public func dropIndex(
        _ keys: BSONDocument,
        options: DropIndexOptions? = nil,
        session: ClientSession? = nil
    ) throws {
        try self.asyncColl.dropIndex(keys, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Attempts to drop a single index from the collection given an `IndexModel` describing it.
     *
     * - Parameters:
     *   - model: An `IndexModel` describing the index to drop
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options.
     */
    public func dropIndex(
        _ model: IndexModel,
        options: DropIndexOptions? = nil,
        session: ClientSession? = nil
    ) throws {
        try self.asyncColl.dropIndex(model, options: options, session: session?.asyncSession).wait()
    }

    /**
     * Drops all indexes in the collection.
     *
     * - Parameters:
     *   - options: Optional `DropIndexOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Throws:
     *   - `MongoError.WriteError` if an error occurs while performing the command.
     *   - `MongoError.CommandError` if an error occurs that prevents the command from executing.
     *   - `MongoError.InvalidArgumentError` if the options passed in form an invalid combination.
     *   - `MongoError.LogicError` if the provided session is inactive.
     *   - `EncodingError` if an error occurs while encoding the options.
     */
    public func dropIndexes(
        options: DropIndexOptions? = nil,
        session: ClientSession? = nil
    ) throws {
        try self.asyncColl.dropIndexes(options: options, session: session?.asyncSession).wait()
    }

    /**
     * Retrieves a list of the indexes currently on this collection.
     *
     * - Parameters:
     *   - options: Optional `ListIndexesOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `MongoCursor` over the `IndexModel`s.
     *
     * - Throws: `MongoError.LogicError` if the provided session is inactive.
     */
    public func listIndexes(
        options: ListIndexesOptions? = nil,
        session: ClientSession? = nil
    ) throws -> MongoCursor<IndexModel> {
        let asyncCursor = try self.asyncColl.listIndexes(options: options, session: session?.asyncSession).wait()
        return MongoCursor(wrapping: asyncCursor, client: self.client)
    }

    /**
     * Retrieves a list of names of the indexes currently on this collection.
     *
     * - Parameters:
     *   - options: Optional `ListIndexesOptions` to use for the command
     *   - session: Optional `ClientSession` to use when executing this command
     *
     * - Returns: A `MongoCursor` over the index names.
     *
     * - Throws: `MongoError.LogicError` if the provided session is inactive.
     */
    public func listIndexNames(
        options: ListIndexesOptions? = nil,
        session: ClientSession? = nil
    ) throws -> [String] {
        try self.asyncColl.listIndexNames(options: options, session: session?.asyncSession).wait()
    }
}
