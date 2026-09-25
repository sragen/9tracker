import Foundation

/// DeepSeek chat client. OpenAI-compatible REST format (see PRD §5).
/// API key comes from Keychain — never hardcode, never log the request body.
struct DeepSeekClient {
    struct Message: Codable {
        let role: String   // "system" | "user" | "assistant"
        let content: String
    }

    private struct ChatRequest: Encodable {
        let model = "deepseek-chat"
        let messages: [Message]
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String }
            let message: Msg
        }
        let choices: [Choice]
    }

    func send(messages: [Message]) async throws -> String {
        guard let apiKey = try KeychainStore.read(.deepSeekAPIKey) else {
            throw URLError(.userAuthenticationRequired)
        }

        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ChatRequest(messages: messages))

        let response = try await APIClient.send(request, decodeAs: ChatResponse.self)
        guard let text = response.choices.first?.message.content else {
            throw URLError(.cannotParseResponse)
        }
        return text
    }
}
