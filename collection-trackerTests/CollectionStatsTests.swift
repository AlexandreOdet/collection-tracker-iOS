import Foundation
import Testing
@testable import collection_tracker

struct CollectionStatsTests {
    private func item(
        _ name: String,
        _ category: CollectionCategory,
        status: OwnershipStatus = .owned,
        condition: ItemCondition = .good,
        rating: Int? = nil,
        price: Double? = nil,
        createdAt: Date = .now,
        deleted: Bool = false
    ) -> CollectionItem {
        CollectionItem(
            name: name, category: category, status: status, condition: condition,
            rating: rating, purchasePrice: price, createdAt: createdAt, isDeleted: deleted
        )
    }

    @Test func emptyCollection() {
        let stats = CollectionStats(items: [])
        #expect(stats.isEmpty)
        #expect(stats.totalValue == 0)
        #expect(stats.averageRating == nil)
        #expect(stats.byCategory.count == CollectionCategory.allCases.count)
    }

    @Test func countsAndTotalsSeparateOwnedFromWishlist() {
        let stats = CollectionStats(items: [
            item("A", .lego, price: 100),
            item("B", .comic, price: 20),
            item("C", .game, status: .wishlist, price: 60),
        ])
        #expect(stats.ownedCount == 2)
        #expect(stats.wishlistCount == 1)
        #expect(stats.totalValue == 120)
        #expect(stats.wishlistBudget == 60)
    }

    @Test func deletedItemsAreIgnored() {
        let stats = CollectionStats(items: [
            item("A", .lego, price: 100),
            item("B", .lego, price: 50, deleted: true),
        ])
        #expect(stats.ownedCount == 1)
        #expect(stats.totalValue == 100)
    }

    @Test func missingPricesAreCountedNotSummed() {
        let stats = CollectionStats(items: [item("A", .lego, price: 40), item("B", .lego)])
        #expect(stats.totalValue == 40)
        #expect(stats.missingPriceCount == 1)
    }

    @Test func averageRatingIgnoresUnratedItems() throws {
        let stats = CollectionStats(items: [
            item("A", .lego, rating: 5), item("B", .lego, rating: 2), item("C", .lego),
        ])
        #expect(try #require(stats.averageRating) == 3.5)
    }

    @Test func categoriesAreSortedByCount() {
        let stats = CollectionStats(items: [
            item("A", .game), item("B", .comic), item("C", .comic), item("D", .comic, price: 10),
        ])
        #expect(stats.byCategory.first?.category == .comic)
        #expect(stats.byCategory.first?.count == 3)
        #expect(stats.byCategory.first?.value == 10)
        #expect(stats.byCategory.last?.count == 0)
    }

    @Test func conditionsListOnlyPresentOnesInOrder() {
        let stats = CollectionStats(items: [
            item("A", .lego, condition: .poor), item("B", .lego, condition: .new), item("C", .lego, condition: .new),
        ])
        #expect(stats.byCondition.map(\.condition) == [.new, .poor])
        #expect(stats.byCondition.first?.count == 2)
    }

    @Test func recentlyAddedIsNewestFirstAndLimited() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let items = (0..<8).map { item("n\($0)", .lego, createdAt: base.addingTimeInterval(Double($0))) }
        let stats = CollectionStats(items: items, recentLimit: 3)
        #expect(stats.recentlyAdded.map(\.name) == ["n7", "n6", "n5"])
    }
}
