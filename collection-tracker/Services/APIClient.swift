import Foundation

enum APIError: LocalizedError {
    case missingConfiguration
    case insecureURL
    case unauthorized
    case server(Int)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "URL du serveur ou token manquant."
        case .insecureURL: "L'URL doit commencer par https:// (le token ne doit jamais circuler en clair)."
        case .unauthorized: "Token refusé par le serveur."
        case .server(let code): "Erreur serveur (HTTP \(code))."
        case .transport(let error): error.localizedDescription
        }
    }
}

/// Client HTTP minimal : ajoute le token statique dans `Authorization: Bearer <token>`.
struct APIClient {
    static let baseURLKey = "serverBaseURL"

    var baseURL: URL?
    var token: String?
    var session: URLSession = APIClient.makeSession()

    /// Session éphémère : ni cache disque, ni cookies, ni identifiants persistés pour les
    /// réponses de l'API.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    /// Accepte uniquement une URL HTTPS avec un hôte. Le HTTP en clair n'est toléré qu'en debug
    /// et vers la machine locale (simulateur + serveur de dev).
    static func validatedBaseURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              let host = url.host(), !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }

        if scheme == "https" { return url }
        #if DEBUG
        if scheme == "http", ["localhost", "127.0.0.1", "::1"].contains(host) { return url }
        #endif
        return nil
    }

    /// Construit un client à partir de la config persistée (URL en UserDefaults, token en Keychain).
    static func fromStoredConfiguration() -> APIClient {
        let raw = UserDefaults.standard.string(forKey: baseURLKey) ?? ""
        return APIClient(baseURL: validatedBaseURL(raw), token: KeychainTokenStore().load())
    }

    var isConfigured: Bool {
        baseURL != nil && !(token ?? "").isEmpty
    }

    func request(_ path: String, method: String = "GET", query: [URLQueryItem] = []) throws -> URLRequest {
        guard let baseURL, let token, !token.isEmpty else { throw APIError.missingConfiguration }

        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw APIError.missingConfiguration }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    @discardableResult
    func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200..<300: return data
            case 401, 403: throw APIError.unauthorized
            default: throw APIError.server(status)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }

    /// Vérifie URL + token via un endpoint protégé (`/health` restant public).
    func verifyCredentials() async throws {
        _ = try await pull(since: .now)
    }

    func push(_ changes: [SyncedItemDTO]) async throws {
        var req = try request("sync/push", method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try SyncCoding.makeEncoder().encode(PushRequest(changes: changes))
        try await send(req)
    }

    func pull(since: Date?) async throws -> PullResponse {
        var query: [URLQueryItem] = []
        if let since {
            query.append(URLQueryItem(name: "since", value: SyncCoding.string(from: since)))
        }
        let data = try await send(try request("sync/pull", query: query))
        return try SyncCoding.makeDecoder().decode(PullResponse.self, from: data)
    }
}
