import CLibMongoC

/// Options to use when executing a `createCollection` command on a `MongoDatabase`.
public struct CreateCollectionOptions: Codable, CodingStrategyProvider {
    /// Indicates whether this will be a capped collection.
    public var capped: Bool?

    /// Specifies the default collation for the collection.
    public var collation: BSONDocument?

    // swiftlint:disable redundant_optional_initialization
    // to get synthesized decodable conformance for the struct, these strategies need default values.

    /// Specifies the `DataCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `Data`s already stored in this collection can be
    /// decoded using this strategy.
    public var dataCodingStrategy: DataCodingStrategy? = nil

    /// Specifies the `DateCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `Date`s already stored in this collection can be
    /// decoded using this strategy.
    public var dateCodingStrategy: DateCodingStrategy? = nil

    /// Number of seconds after which old time series data should be deleted.
    public var expireAfterSeconds: Int?

    /// Specify a default configuration for indexes created on this collection.
    public var indexOptionDefaults: BSONDocument?

    /// Maximum number of documents allowed in the collection (if capped).
    public var max: Int?

    /// An array consisting of aggregation pipeline stages. When used with `viewOn`, will create the view by applying
    /// this pipeline to the source collection or view.
    public var pipeline: [BSONDocument]?

    /// Maximum size, in bytes, of this collection (if capped).
    public var size: Int?

    /// Specifies storage engine configuration for this collection.
    public var storageEngine: BSONDocument?

    /// The options used for creating a time series collection. This feature is only available on MongoDB 5.0+.
    public var timeseries: TimeseriesOptions?

    /// Specifies the `UUIDCodingStrategy` to use for BSON encoding/decoding operations performed by this collection.
    /// It is the responsibility of the user to ensure that any `UUID`s already stored in this collection can be
    /// decoded using this strategy.
    public var uuidCodingStrategy: UUIDCodingStrategy? = nil

    // swiftlint:enable redundant_optional_initialization

    /// Determines whether to error on invalid documents or just warn about the violations but allow invalid documents
    /// to be inserted.
    public var validationAction: String?

    /// Determines how strictly MongoDB applies the validation rules to existing documents during an update.
    public var validationLevel: String?

    /// What validator should be used for the collection.
    public var validator: BSONDocument?

    /// The name of the source collection or view from which to create the view.
    public var viewOn: String?

    /// A write concern to use when executing this command. To set a read or write concern for the collection itself,
    /// retrieve the collection using `MongoDatabase.collection`.
    public var writeConcern: WriteConcern?

    private enum CodingKeys: String, CodingKey {
        case capped, size, max, storageEngine, validator, validationLevel, validationAction,
             indexOptionDefaults, viewOn, pipeline, collation, writeConcern, timeseries, expireAfterSeconds
    }

    /// Convenience initializer allowing any/all parameters to be omitted or optional.
    public init(
        capped: Bool? = nil,
        collation: BSONDocument? = nil,
        dataCodingStrategy: DataCodingStrategy? = nil,
        dateCodingStrategy: DateCodingStrategy? = nil,
        expireAfterSeconds: Int? = nil,
        indexOptionDefaults: BSONDocument? = nil,
        max: Int? = nil,
        pipeline: [BSONDocument]? = nil,
        size: Int? = nil,
        storageEngine: BSONDocument? = nil,
        timeseries: TimeseriesOptions? = nil,
        uuidCodingStrategy: UUIDCodingStrategy? = nil,
        validationAction: String? = nil,
        validationLevel: String? = nil,
        validator: BSONDocument? = nil,
        viewOn: String? = nil,
        writeConcern: WriteConcern? = nil
    ) {
        self.capped = capped
        self.collation = collation
        self.dataCodingStrategy = dataCodingStrategy
        self.dateCodingStrategy = dateCodingStrategy
        self.indexOptionDefaults = indexOptionDefaults
        self.max = max
        self.pipeline = pipeline
        self.size = size
        self.storageEngine = storageEngine
        self.uuidCodingStrategy = uuidCodingStrategy
        self.validationAction = validationAction
        self.validationLevel = validationLevel
        self.validator = validator
        self.viewOn = viewOn
        self.writeConcern = writeConcern
        self.timeseries = timeseries
        self.expireAfterSeconds = expireAfterSeconds
    }
}

/// The options to use when creating a time series collection.
public struct TimeseriesOptions: Codable {
    /// Name of the top-level field to be used for time. Inserted documents must have this field, and the field must
    /// be of the BSON UTC datetime type.
    public var timeField: String

    /// Name of the top-level field describing the series. This field is used to group related data and may be of any
    /// BSON type except array. This name must not be the same as the `timeField` or `_id`.
    public var metaField: String?

    /// The units used to describe the expected interval between subsequent measurements for a time series
    /// collection. Defaults to `Granularity.seconds` if unset.
    public var granularity: Granularity?

    /// The units used to describe the expected interval between subsequent measurements for a time series collection.
    public struct Granularity: RawRepresentable, Codable {
        public static let seconds = Granularity("seconds")
        public static let minutes = Granularity("minutes")
        public static let hours = Granularity("hours")

        /// For an unknown value. For forwards compatibility, no error will be thrown when an unknown value is
        /// provided.
        public static func other(_ value: String) -> Granularity {
            Granularity(value)
        }

        public var rawValue: String

        public init?(rawValue: String) { self.rawValue = rawValue }
        internal init(_ value: String) { self.rawValue = value }
    }

    private enum CodingKeys: String, CodingKey {
        case timeField, metaField, granularity
    }
}

// An operation corresponding to a `createCollection` command on a database.
internal struct CreateCollectionOperation<T: Codable>: Operation {
    private let database: MongoDatabase
    private let name: String
    private let type: T.Type
    private let options: CreateCollectionOptions?

    internal init(database: MongoDatabase, name: String, type: T.Type, options: CreateCollectionOptions?) {
        self.database = database
        self.name = name
        self.type = type
        self.options = options
    }

    internal func execute(using connection: Connection, session: ClientSession?) throws -> MongoCollection<T> {
        let opts = try encodeOptions(options: self.options, session: session)
        var error = bson_error_t()

        try self.database.withMongocDatabase(from: connection) { dbPtr in
            try withOptionalBSONPointer(to: opts) { optsPtr in
                guard let collection = mongoc_database_create_collection(dbPtr, self.name, optsPtr, &error) else {
                    throw extractMongoError(error: error)
                }
                mongoc_collection_destroy(collection)
            }
        }

        let collectionOptions = MongoCollectionOptions(
            dataCodingStrategy: self.options?.dataCodingStrategy,
            dateCodingStrategy: self.options?.dateCodingStrategy,
            uuidCodingStrategy: self.options?.uuidCodingStrategy
        )

        return MongoCollection(
            name: self.name,
            database: self.database,
            eventLoop: self.database.eventLoop,
            options: collectionOptions
        )
    }
}
