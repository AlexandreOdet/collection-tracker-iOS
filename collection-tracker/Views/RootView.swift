import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Collection", systemImage: "square.grid.2x2.fill") { CollectionListView() }
            Tab("Statistiques", systemImage: "chart.pie.fill") { StatsView() }
        }
    }
}
