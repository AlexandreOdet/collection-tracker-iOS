import Foundation

/// Statistiques calculées à partir d'une liste d'éléments (les éléments supprimés sont ignorés).
struct CollectionStats {
    struct CategoryBreakdown: Identifiable, Equatable {
        let category: CollectionCategory
        let count: Int
        let value: Double
        var id: CollectionCategory { category }
    }

    struct ConditionBreakdown: Identifiable, Equatable {
        let condition: ItemCondition
        let count: Int
        var id: ItemCondition { condition }
    }

    /// Éléments possédés.
    let ownedCount: Int
    let wishlistCount: Int
    /// Somme des prix d'achat des éléments possédés (ceux sans prix comptent pour 0).
    let totalValue: Double
    /// Somme des prix visés des éléments de la liste de souhaits.
    let wishlistBudget: Double
    /// Moyenne des notes des éléments possédés notés ; `nil` si aucun n'est noté.
    let averageRating: Double?
    /// Éléments possédés dont le prix n'est pas renseigné (la valeur totale est alors sous-estimée).
    let missingPriceCount: Int
    /// Toutes les catégories, y compris vides, triées par nombre d'éléments décroissant.
    let byCategory: [CategoryBreakdown]
    /// États présents dans la collection possédée, du meilleur au moins bon.
    let byCondition: [ConditionBreakdown]
    /// Derniers éléments possédés ajoutés.
    let recentlyAdded: [CollectionItem]

    var isEmpty: Bool { ownedCount == 0 && wishlistCount == 0 }

    init(items: [CollectionItem], recentLimit: Int = 5) {
        let live = items.filter { !$0.isDeleted }
        let owned = live.filter { $0.status == .owned }
        let wished = live.filter { $0.status == .wishlist }

        ownedCount = owned.count
        wishlistCount = wished.count
        totalValue = owned.reduce(0) { $0 + ($1.purchasePrice ?? 0) }
        wishlistBudget = wished.reduce(0) { $0 + ($1.purchasePrice ?? 0) }
        missingPriceCount = owned.filter { $0.purchasePrice == nil }.count

        let ratings = owned.compactMap(\.rating)
        averageRating = ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count)

        byCategory = CollectionCategory.allCases
            .map { category in
                let inCategory = owned.filter { $0.category == category }
                return CategoryBreakdown(
                    category: category,
                    count: inCategory.count,
                    value: inCategory.reduce(0) { $0 + ($1.purchasePrice ?? 0) }
                )
            }
            .sorted { $0.count > $1.count }

        byCondition = ItemCondition.allCases.compactMap { condition in
            let count = owned.filter { $0.condition == condition }.count
            return count > 0 ? ConditionBreakdown(condition: condition, count: count) : nil
        }

        recentlyAdded = Array(owned.sorted { $0.createdAt > $1.createdAt }.prefix(recentLimit))
    }
}
