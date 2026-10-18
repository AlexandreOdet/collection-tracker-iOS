import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var sync

    let item: CollectionItem

    @State private var showingEditor = false
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: item.category.systemImage)
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                    Text(item.name)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    HStack(spacing: 8) {
                        Badge(text: item.category.title)
                        Badge(text: item.status.title, tint: item.status == .wishlist ? .pink : .green)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Informations") {
                if !item.reference.isEmpty {
                    LabeledContent(item.category.referenceLabel, value: item.reference)
                }
                LabeledContent("État", value: item.condition.title)
                if let rating = item.rating {
                    LabeledContent("Note") {
                        Text(String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating))
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("\(rating) sur 5")
                    }
                }
                if let price = item.purchasePrice {
                    LabeledContent(
                        item.status == .wishlist ? "Prix visé" : "Prix d'achat",
                        value: price.formatted(.currency(code: "EUR"))
                    )
                }
                if let acquiredAt = item.acquiredAt {
                    LabeledContent("Acquis le", value: acquiredAt.formatted(date: .long, time: .omitted))
                }
            }

            if !item.notes.isEmpty {
                Section("Notes") {
                    Text(item.notes)
                }
            }

            Section("Suivi") {
                LabeledContent("Ajouté le", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Modifié le", value: item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                if item.isDirty {
                    Label("En attente de synchronisation", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Supprimer", role: .destructive) { confirmingDelete = true }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: { Task { await sync.sync() } }) {
            ItemEditorView(item: item, defaultCategory: item.category)
        }
        .confirmationDialog("Supprimer « \(item.name) » ?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                item.markDeleted()
                dismiss()
                Task { await sync.sync() }
            }
        }
    }
}

private struct Badge: View {
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
