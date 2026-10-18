import SwiftUI
import SwiftData

struct CollectionListView: View {
    @Environment(SyncService.self) private var sync
    @Query(
        filter: #Predicate<CollectionItem> { $0.isDeleted == false },
        sort: \CollectionItem.createdAt,
        order: .reverse
    ) private var items: [CollectionItem]

    @State private var selectedCategory: CollectionCategory?
    @State private var searchText = ""
    @State private var showingNewItem = false
    @State private var showingSettings = false

    private var filteredItems: [CollectionItem] {
        items.filter { item in
            (selectedCategory == nil || item.category == selectedCategory)
                && (searchText.isEmpty
                    || item.name.localizedCaseInsensitiveContains(searchText)
                    || item.reference.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Catégorie", selection: $selectedCategory) {
                        Text("Tout").tag(CollectionCategory?.none)
                        ForEach(CollectionCategory.allCases) { category in
                            Text(category.title).tag(CollectionCategory?.some(category))
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                ForEach(filteredItems) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        CollectionRow(item: item)
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "Collection vide" : "Aucun résultat",
                        systemImage: "tray",
                        description: Text(searchText.isEmpty ? "Ajoute ton premier élément avec le bouton +." : "Essaie une autre recherche.")
                    )
                }
            }
            .navigationTitle("Ma collection")
            .searchable(text: $searchText, prompt: "Nom ou référence")
            .refreshable { await sync.sync() }
            .task { await sync.sync() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Label("Synchronisation", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if sync.isSyncing {
                        ProgressView()
                    } else if case .failed(let message) = sync.status {
                        Button { showingSettings = true } label: {
                            Label(message, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        }
                        .tint(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewItem = true } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) { ServerSettingsView() }
            .sheet(isPresented: $showingNewItem, onDismiss: { Task { await sync.sync() } }) {
                ItemEditorView(item: nil, defaultCategory: selectedCategory ?? .lego)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { filteredItems[$0] }
        withAnimation { toDelete.forEach { $0.markDeleted() } }
        Task { await sync.sync() }
    }
}

private struct CollectionRow: View {
    let item: CollectionItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.systemImage)
                .frame(width: 32)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.headline)
                HStack(spacing: 6) {
                    if !item.reference.isEmpty { Text(item.reference) }
                    Text(item.condition.title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if item.status == .wishlist {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: CollectionItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return CollectionListView()
        .modelContainer(container)
        .environment(SyncService(context: container.mainContext))
}
