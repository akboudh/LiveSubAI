import Foundation

struct DeepgramTranscriptParser {
    func parse(_ json: String) -> TranscriptEvent? {
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            guard let transcript = response.channel?.alternatives.first?.transcript,
                  !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            if response.isFinal == true || response.speechFinal == true {
                return .final(transcript)
            }
            return .partial(transcript)
        } catch {
            return nil
        }
    }
}

private struct DeepgramResponse: Decodable {
    let isFinal: Bool?
    let speechFinal: Bool?
    let channel: DeepgramChannel?

    enum CodingKeys: String, CodingKey {
        case isFinal = "is_final"
        case speechFinal = "speech_final"
        case channel
    }
}

private struct DeepgramChannel: Decodable {
    let alternatives: [DeepgramAlternative]
}

private struct DeepgramAlternative: Decodable {
    let transcript: String
}
