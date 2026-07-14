import Foundation

public struct TimedWord: Codable, Equatable, Sendable {
    public let start: Double
    public let end: Double
    public let text: String
    public let confidence: Double?

    public init(start: Double, end: Double, text: String, confidence: Double? = nil) {
        self.start = start
        self.end = end
        self.text = text
        self.confidence = confidence
    }
}

public struct Transcript: Codable, Equatable, Sendable {
    public let file: String
    public let locale: String
    public let text: String
    public let words: [TimedWord]

    public init(file: String, locale: String, words: [TimedWord]) {
        self.file = file
        self.locale = locale
        self.words = words
        self.text = Transcript.join(words.map(\.text))
    }

    public static func join(_ pieces: [String]) -> String {
        pieces.reduce(into: "") { output, piece in
            let piece = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !piece.isEmpty else { return }
            guard !output.isEmpty else {
                output = piece
                return
            }

            if piece.first.map(Self.isClosingPunctuation) == true {
                output += piece
            } else if output.last.map(Self.isOpeningPunctuation) == true {
                output += piece
            } else {
                output += " " + piece
            }
        }
    }

    private static func isClosingPunctuation(_ character: Character) -> Bool {
        ",.!?;:%)]}\u{201D}\u{2019}".contains(character)
    }

    private static func isOpeningPunctuation(_ character: Character) -> Bool {
        "([\u{201C}\u{2018}".contains(character)
    }
}

public enum OutputFormat: String, CaseIterable, Sendable {
    case text
    case json
    case jsonl
    case srt
    case vtt
}
