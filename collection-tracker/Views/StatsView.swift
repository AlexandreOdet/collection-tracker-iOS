import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(filter: #Predicate<CollectionItem> { $0.isDeleted == false })
    private var items: [CollectionItem]

    private var stats: CollectionStats { CollectionStats(items: items) }

    var body: some View {
        NavigationStack {
            let snapshot = stats
            ScrollView {
                if snapshot.isEmpty {
                    ContentUnavailableView(
                        "Pas encore de statistiques",
                        systemImage: "chart.pie",
                        description: Text("Ajoute des éléments à ta collection pour les voir ici.")
                    )
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 16) {
                        summaryGrid(snapshot)
                        if snapshot.ownedCount > 0 {
                            categoryChart(snapshot)
                            conditionChart(snapshot)
                            recentSection(snapshot)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistiques")
        }
    }

    // MARK: - Sections

    private func summaryGrid(_ stats: CollectionStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Possédés", value: "\(stats.ownedCount)", systemImage: "checkmark.seal.fill", tint: .green)
            StatTile(title: "Liste de souhaits", value: "\(stats.wishlistCount)", systemImage: "heart.fill", tint: .pink)
            StatTile(
                title: "Valeur investie",
                value: stats.totalValue.formatted(.currency(code: "EUR").precision(.fractionLength(0))),
                systemImage: "eurosign.circle.fill",
                tint: .blue,
                footnote: stats.missingPriceCount > 0 ? "\(stats.missingPriceCount) sans prix" : nil
            )
            StatTile(
                title: "Budget souhaits",
                value: stats.wishlistBudget.formatted(.currency(code: "EUR").precision(.fractionLength(0))),
                systemImage: "cart.fill",
                tint: .orange
            )
            if let average = stats.averageRating {
                StatTile(
                    title: "Note moyenne",
                    value: average.formatted(.number.precision(.fractionLength(1))) + " / 5",
                    systemImage: "star.fill",
                    tint: .yellow
                )
            }
        }
    }

    private func categoryChart(_ stats: CollectionStats) -> some View {
        let populated = stats.byCategory.filter { $0.count > 0 }
        return Card(title: "Répartition par catégorie") {
            Chart(populated) { entry in
                SectorMark(angle: .value("Éléments", entry.count), innerRadius: .ratio(0.55), angularInset: 2)
                    .foregroundStyle(by: .value("Catégorie", entry.category.title))
                    .cornerRadius(4)
            }
            .frame(height: 180)

            ForEach(stats.byCategory) { entry in
                HStack {
                    Label(entry.category.title, systemImage: entry.category.systemImage)
                    Spacer()
                    Text("\(entry.count)").bold()
                    Text(entry.value.formatted(.currency(code: "EUR").precision(.fractionLength(0))))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 70, alignment: .trailing)
                }
                .font(.subheadline)
            }
        }
    }

    private func conditionChart(_ stats: CollectionStats) -> some View {
        Card(title: "État des éléments") {
            Chart(stats.byCondition) { entry in
                BarMark(x: .value("Éléments", entry.count), y: .value("État", entry.condition.title))
                    .annotation(position: .trailing) { Text("\(entry.count)").font(.caption) }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(stats.byCondition.count) * 36 + 8)
        }
    }

    private func recentSection(_ stats: CollectionStats) -> some View {
        Card(title: "Derniers ajouts") {
            ForEach(stats.recentlyAdded) { item in
                HStack {
                    Image(systemName: item.category.systemImage).foregroundStyle(.tint).frame(width: 24)
                    Text(item.name).lineLimit(1)
                    Spacer()
                    Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let footnote {
                Text(footnote).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    let container = try! ModelContainer(
        for: CollectionItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    for (i, category) in CollectionCategory.allCases.enumerated() {
        for j in 0...(i + 1) {
            container.mainContext.insert(CollectionItem(
                name: "\(category.title) \(j + 1)", category: category,
                condition: j.isMultiple(of: 2) ? .new : .good,
                rating: 3 + (j % 3), purchasePrice: Double(20 + j * 15)
            ))
        }
    }
    container.mainContext.insert(CollectionItem(name: "Souhait", category: .lego, status: .wishlist, purchasePrice: 99))
    return StatsView().modelContainer(container)
}
