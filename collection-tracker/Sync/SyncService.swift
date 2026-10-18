import Foundation
import Observation
import SwiftData

/// Synchronisation push puis pull avec le serveur (last write wins sur `updatedAt`).
@MainActor
@Observable
final class SyncService {
    enum Status: Equatable {
        case idle
        case syncing
        case succeeded(Date)
        case failed(String)
    }

    private(set) var status: Status = .idle

    var isSyncing: Bool { status == .syncing }

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let clientProvider: @MainActor () -> APIClient

    private static let pushBatchSize = 100
    private static let checkpointKey = "lastSyncServerTime"

    init(context: ModelContext, clientProvider: @escaping @MainActor () -> APIClient = APIClient.fromStoredConfiguration) {
        self.context = context
        self.clientProvider = clientProvider
    }

    /// À appeler quand l'utilisateur change de serveur ou se déconnecte.
    static func resetCheckpoint() {
        UserDefaults.standard.removeObject(forKey: checkpointKey)
    }

    private var checkpoint: Date? {
        get { UserDefaults.standard.object(forKey: Self.checkpointKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.checkpointKey) }
    }

    func sync() async {
        guard !isSyncing else { return }
        let client = clientProvider()
        // Sans serveur configuré, l'app fonctionne en local : rien à signaler.
        guard client.isConfigured else { return }

        status = .syncing
        do {
            try await pushLocalChanges(using: client)
            try await pullRemoteChanges(using: client)
            status = .succeeded(.now)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Push

    private func pushLocalChanges(using client: APIClient) async throws {
        let dirty = try context.fetch(
            FetchDescriptor<CollectionItem>(predicate: #Predicate { $0.isDirty })
        )
        guard !dirty.isEmpty else { return }

        let snapshots = dirty.map { (item: $0, dto: $0.makeDTO()) }
        // Le serveur refuse les lots trop gros (max 200) : on envoie par paquets.
        for batch in stride(from: 0, to: snapshots.count, by: Self.pushBatchSize) {
            let end = min(batch + Self.pushBatchSize, snapshots.count)
            try await client.push(snapshots[batch..<end].map(\.dto))
        }

        // Pendant l'attente réseau, l'utilisateur a pu modifier un élément : on ne le marque
        // propre que si son `updatedAt` n'a pas bougé.
        for (item, dto) in snapshots where item.updatedAt == dto.updatedAt {
            if item.isDeleted {
                context.delete(item)
            } else {
                item.isDirty = false
            }
        }
        try context.save()
    }

    // MARK: - Pull

    private func pullRemoteChanges(using client: APIClient) async throws {
        // Léger chevauchement : le merge est idempotent, et évite de rater un élément
        // à cause de l'arrondi à la milliseconde.
        let since = checkpoint.map { $0.addingTimeInterval(-2) }
        let response = try await client.pull(since: since)

        for dto in response.items {
            try merge(dto)
        }
        try context.save()
        checkpoint = response.serverTime
    }

    private func merge(_ dto: SyncedItemDTO) throws {
        let id = dto.id
        let local = try context.fetch(
            FetchDescriptor<CollectionItem>(predicate: #Predicate { $0.id == id })
        ).first

        if let local {
            // Local plus récent ou identique (dont nos propres écritures renvoyées) : on garde.
            guard dto.updatedAt > local.updatedAt else { return }
            if dto.isDeleted {
                context.delete(local)
            } else {
                local.apply(dto)
            }
        } else if !dto.isDeleted, let created = CollectionItem(dto: dto) {
            context.insert(created)
        }
    }
}
