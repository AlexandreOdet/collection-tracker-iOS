import SwiftUI

struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(APIClient.baseURLKey) private var baseURL = ""
    @State private var token = ""
    @State private var state: ConnectionState = .idle

    private let store = KeychainTokenStore()

    private var urlIsInsecureOrInvalid: Bool {
        !baseURL.isEmpty && APIClient.validatedBaseURL(baseURL) == nil
    }

    private enum ConnectionState: Equatable {
        case idle, testing, success, failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Serveur") {
                    TextField("https://mon-serveur.exemple", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    if urlIsInsecureOrInvalid {
                        Label("L'URL doit commencer par https://", systemImage: "lock.slash.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    SecureField("Token d'accès", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Button("Tester la connexion", action: testConnection)
                        .disabled(baseURL.isEmpty || urlIsInsecureOrInvalid || token.isEmpty || state == .testing)
                    statusRow
                }

                Section {
                    Button("Se déconnecter", role: .destructive) {
                        store.delete()
                        SyncService.resetCheckpoint()
                        token = ""
                        state = .idle
                    }
                }
            }
            .navigationTitle("Synchronisation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { persist(); dismiss() }
                }
            }
            .onAppear { token = store.load() ?? "" }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch state {
        case .idle: EmptyView()
        case .testing: ProgressView()
        case .success: Label("Connexion réussie", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure(let message): Label(message, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private func persist() {
        // Une URL non HTTPS n'est jamais conservée : le client la rejetterait de toute façon.
        if urlIsInsecureOrInvalid { baseURL = "" }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { store.delete() } else { try? store.save(trimmed) }
    }

    private func testConnection() {
        persist()
        state = .testing
        Task {
            do {
                try await APIClient.fromStoredConfiguration().verifyCredentials()
                state = .success
            } catch {
                state = .failure(error.localizedDescription)
            }
        }
    }
}

#Preview { ServerSettingsView() }
