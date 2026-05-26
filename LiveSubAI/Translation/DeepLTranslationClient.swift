import Foundation

final class DeepLTranslationClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func translateToEnglish(_ text: String, apiKey: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let host = apiKey.hasSuffix(":fx") ? "api-free.deepl.com" : "api.deepl.com"
        let url = URL(string: "https://\(host)/v2/translate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DeepLTranslateRequest(text: [trimmed], targetLang: "EN-US"))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LiveSubAIError.translationUnavailable("DeepL did not return an HTTP response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw LiveSubAIError.translationUnavailable("DeepL translation failed (\(httpResponse.statusCode))")
        }

        let decoded = try JSONDecoder().decode(DeepLTranslateResponse.self, from: data)
        guard let translated = decoded.translations.first?.text.trimmingCharacters(in: .whitespacesAndNewlines),
              !translated.isEmpty else {
            throw LiveSubAIError.translationUnavailable("DeepL returned an empty translation")
        }
        return translated
    }
}

private struct DeepLTranslateRequest: Encodable {
    let text: [String]
    let targetLang: String

    enum CodingKeys: String, CodingKey {
        case text
        case targetLang = "target_lang"
    }
}

private struct DeepLTranslateResponse: Decodable {
    let translations: [DeepLTranslation]
}

private struct DeepLTranslation: Decodable {
    let text: String
}
