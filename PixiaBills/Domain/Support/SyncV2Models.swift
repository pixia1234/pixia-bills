import Foundation

enum SyncV2EntityType: String, Codable {
    case transaction
    case category
    case account
    case budget
    case transfer
    case recurring
}

enum SyncV2Operation: String, Codable {
    case upsert
    case delete
}

struct SyncV2Event: Codable, Identifiable, Equatable {
    let id: UUID
    let deviceId: String
    let createdAt: Date
    let entityType: SyncV2EntityType
    let operation: SyncV2Operation
    let entityId: UUID
    let baseUpdatedAt: Date?
    let entityUpdatedAt: Date
    let payload: Data?
    let payloadHash: String?
    let deletedAt: Date?

    init(
        id: UUID = UUID(),
        deviceId: String,
        createdAt: Date,
        entityType: SyncV2EntityType,
        operation: SyncV2Operation,
        entityId: UUID,
        baseUpdatedAt: Date?,
        entityUpdatedAt: Date,
        payload: Data? = nil,
        payloadHash: String? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.deviceId = deviceId
        self.createdAt = createdAt
        self.entityType = entityType
        self.operation = operation
        self.entityId = entityId
        self.baseUpdatedAt = baseUpdatedAt
        self.entityUpdatedAt = entityUpdatedAt
        self.payload = payload
        self.payloadHash = payloadHash
        self.deletedAt = deletedAt
    }
}

struct SyncV2Changeset: Codable, Equatable {
    let protocolVersion: Int
    let sequence: Int
    let deviceId: String
    let createdAt: Date
    let digest: String
    let changes: [SyncV2Event]
}

struct SyncV2Index: Codable, Equatable {
    let protocolVersion: Int
    let latestSequence: Int
    let updatedAt: Date
    let changesetFileNames: [String]

    init(
        protocolVersion: Int = 2,
        latestSequence: Int,
        updatedAt: Date,
        changesetFileNames: [String]
    ) {
        self.protocolVersion = protocolVersion
        self.latestSequence = latestSequence
        self.updatedAt = updatedAt
        self.changesetFileNames = changesetFileNames
    }
}

enum SyncV2ConflictResolution: String, Codable {
    case useLocal
    case useRemote
}

struct SyncV2Conflict: Identifiable, Codable, Equatable {
    let id: UUID
    let detectedAt: Date
    let entityType: SyncV2EntityType
    let entityId: UUID
    let remoteEvent: SyncV2Event
    let localPayload: Data?
    let localUpdatedAt: Date?
    let localDeletedAt: Date?

    init(
        id: UUID = UUID(),
        detectedAt: Date,
        entityType: SyncV2EntityType,
        entityId: UUID,
        remoteEvent: SyncV2Event,
        localPayload: Data?,
        localUpdatedAt: Date?,
        localDeletedAt: Date?
    ) {
        self.id = id
        self.detectedAt = detectedAt
        self.entityType = entityType
        self.entityId = entityId
        self.remoteEvent = remoteEvent
        self.localPayload = localPayload
        self.localUpdatedAt = localUpdatedAt
        self.localDeletedAt = localDeletedAt
    }
}
