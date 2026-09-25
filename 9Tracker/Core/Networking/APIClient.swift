import Foundation

enum APIError: Error {
    case transport(Error)
    case invalidResponse
    case httpError(status: Int, body: Data)
    case decoding(Error)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .transport(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let status, let body):
            let bodyText = String(data: body, encoding: .utf8) ?? ""
            return "HTTP \(status): \(bodyText)"
        case .decoding(let error):
            return "Couldn't parse response: \(error.localizedDescription)"
        }
    }
}

/// Thin async/await HTTP helper. No retry/caching logic here by design —
/// callers (StravaAPIClient, DeepSeekClient) know which requests are safe to retry.
enum APIClient {
    static func send<T: Decodable>(
        _ request: URLRequest,
        decodeAs type: T.Type,
        session: URLSession = .shared
    ) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(status: http.statusCode, body: data)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
