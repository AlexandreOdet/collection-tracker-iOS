import SwiftUI
import SwiftData

struct ItemEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let item: CollectionItem?

    @State private var name: String
    @State private var category: CollectionCategory
    @State private var reference: String
    @State private var status: OwnershipStatus
    @State private var condition: ItemCondition
    @State private var rating: Int?
    @State private var price: Double?
    @State private var hasAcquisitionDate: Bool
    @State private var acquiredAt: Date
    @State private var notes: String

    init(item: CollectionItem?, defaultCategory: CollectionCategory) {
        self.item = item
        _name = State(initialValue: item?.name ?? "")
        _category = State(initialValue: item?.category ?? defaultCategory)
        _reference = State(initialValue: item?.reference ?? "")
        _status = State(initialValue: item?.status ?? .owned)
        _condition = State(initialValue: item?.condition ?? .good)
        _rating = State(initialValue: item?.rating)
        _price = State(initialValue: item?.purchasePrice)
        _hasAcquisitionDate = State(initialValue: item?.acquiredAt != nil)
        _acquiredAt = State(initialValue: item?.acquiredAt ?? .now)
        _notes = State(initialValue: item?.notes ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom", text: $name)
                    Picker("Catégorie", selection: $category) {
                        ForEach(CollectionCategory.allCases) { Text($0.title).tag($0) }
                    }
                    TextField(category.referenceLabel, text: $reference)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Détails") {
                    Picker("Statut", selection: $status) {
                        ForEach(OwnershipStatus.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("État", selection: $condition) {
                        ForEach(ItemCondition.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Note", selection: $rating) {
                        Text("—").tag(Int?.none)
                        ForEach(1...5, id: \.self) { Text("\($0) ★").tag(Int?.some($0)) }
                    }
                    TextField("Prix d'achat", value: $price, format: .currency(code: "EUR"))
                        .keyboardType(.decimalPad)
                    Toggle("Date d'acquisition", isOn: $hasAcquisitionDate)
                    if hasAcquisitionDate {
                        DatePicker("Acquis le", selection: $acquiredAt, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
            }
            .navigationTitle(item == nil ? "Nouvel élément" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        // Limites alignées sur la validation du serveur (titre 200, notes 10 000, référence 100).
        let trimmedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        let target = item ?? CollectionItem(name: trimmedName, category: category)
        target.name = trimmedName
        target.category = category
        target.reference = String(reference.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        target.status = status
        target.condition = condition
        target.rating = rating
        target.purchasePrice = price
        target.acquiredAt = hasAcquisitionDate ? acquiredAt : nil
        target.notes = String(notes.prefix(10_000))
        target.touch()
        if item == nil { modelContext.insert(target) }
        dismiss()
    }
}

#Preview {
    ItemEditorView(item: nil, defaultCategory: .lego)
        .modelContainer(for: CollectionItem.self, inMemory: true)
}
