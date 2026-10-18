import Foundation
import SwiftData

@Model
final class CollectionItem {
    /// Identifiant stable partagé avec le serveur.
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var category: CollectionCategory
    var reference: String
    var status: OwnershipStatus
    var condition: ItemCondition
    var rating: Int?
    var purchasePrice: Double?
    var acquiredAt: Date?
    var notes: String
    var createdAt: Date

    // Métadonnées de synchronisation.
    /// Horloge locale de la dernière modification (sert à la résolution de conflits côté serveur).
    var updatedAt: Date = Date.now
    /// `true` tant que la modification n'a pas été poussée au serveur.
    var isDirty: Bool = true
    /// Suppression logique : conservée jusqu'à ce que le serveur en ait connaissance.
    var isDeleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        category: CollectionCategory,
        reference: String = "",
        status: OwnershipStatus = .owned,
        condition: ItemCondition = .good,
        rating: Int? = nil,
        purchasePrice: Double? = nil,
        acquiredAt: Date? = nil,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isDirty: Bool = true,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.reference = reference
        self.status = status
        self.condition = condition
        self.rating = rating
        self.purchasePrice = purchasePrice
        self.acquiredAt = acquiredAt
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDirty = isDirty
        self.isDeleted = isDeleted
    }

    /// À appeler après toute modification utilisateur pour qu'elle soit synchronisée.
    func touch() {
        updatedAt = .now
        isDirty = true
    }

    func markDeleted() {
        isDeleted = true
        touch()
    }
}
