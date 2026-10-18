import Foundation

extension CollectionItem {
    func makeDTO() -> SyncedItemDTO {
        let attributes = ItemAttributes(
            reference: reference.isEmpty ? nil : reference,
            condition: condition.rawValue,
            purchasePrice: purchasePrice,
            acquiredAt: acquiredAt
        )
        return SyncedItemDTO(
            id: id,
            title: name,
            type: category.rawValue,
            status: status.rawValue,
            rating: rating,
            notes: notes,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            attributesJSON: SyncCoding.encodeAttributes(attributes)
        )
    }

    /// Crée un élément local depuis le serveur. Renvoie `nil` si la catégorie ou le statut
    /// sont inconnus (donnée écrite par une version plus récente de l'app).
    convenience init?(dto: SyncedItemDTO) {
        guard let category = CollectionCategory(rawValue: dto.type),
              let status = OwnershipStatus(rawValue: dto.status) else { return nil }
        let attributes = SyncCoding.decodeAttributes(dto.attributesJSON)
        self.init(
            id: dto.id,
            name: dto.title,
            category: category,
            reference: attributes.reference ?? "",
            status: status,
            condition: attributes.condition.flatMap(ItemCondition.init(rawValue:)) ?? .good,
            rating: dto.rating,
            purchasePrice: attributes.purchasePrice,
            acquiredAt: attributes.acquiredAt,
            notes: dto.notes,
            updatedAt: dto.updatedAt,
            isDirty: false,
            isDeleted: dto.isDeleted
        )
    }

    /// Applique une version serveur plus récente. Renvoie `false` si elle est inexploitable.
    @discardableResult
    func apply(_ dto: SyncedItemDTO) -> Bool {
        guard let category = CollectionCategory(rawValue: dto.type),
              let status = OwnershipStatus(rawValue: dto.status) else { return false }
        let attributes = SyncCoding.decodeAttributes(dto.attributesJSON)
        self.name = dto.title
        self.category = category
        self.status = status
        self.rating = dto.rating
        self.notes = dto.notes
        self.reference = attributes.reference ?? ""
        self.condition = attributes.condition.flatMap(ItemCondition.init(rawValue:)) ?? .good
        self.purchasePrice = attributes.purchasePrice
        self.acquiredAt = attributes.acquiredAt
        self.updatedAt = dto.updatedAt
        self.isDeleted = dto.isDeleted
        self.isDirty = false
        return true
    }
}
