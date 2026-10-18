import Foundation

enum CollectionCategory: String, Codable, CaseIterable, Identifiable {
    case lego, comic, game

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lego: "Lego"
        case .comic: "BD / Comics"
        case .game: "Jeux vidéo"
        }
    }

    var systemImage: String {
        switch self {
        case .lego: "cube.fill"
        case .comic: "book.closed.fill"
        case .game: "gamecontroller.fill"
        }
    }

    /// Libellé de l'identifiant propre à chaque catégorie.
    var referenceLabel: String {
        switch self {
        case .lego: "N° de set"
        case .comic: "ISBN"
        case .game: "Plateforme"
        }
    }
}

enum ItemCondition: String, Codable, CaseIterable, Identifiable {
    case new, likeNew, good, fair, poor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: "Neuf"
        case .likeNew: "Comme neuf"
        case .good: "Bon état"
        case .fair: "Correct"
        case .poor: "Abîmé"
        }
    }
}

enum OwnershipStatus: String, Codable, CaseIterable, Identifiable {
    case owned, wishlist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .owned: "Possédé"
        case .wishlist: "Liste de souhaits"
        }
    }
}
