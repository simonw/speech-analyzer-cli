import Foundation

public enum TranscriptFormatter {
    public static func render(_ transcript: Transcript, as format: OutputFormat) throws -> String {
        switch format {
        case .text:
            return transcript.text + "\n"
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            return String(decoding: try encoder.encode(transcript), as: UTF8.self) + "\n"
        case .jsonl:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return try transcript.words.map {
                String(decoding: try encoder.encode($0), as: UTF8.self)
            }.joined(separator: "\n") + (transcript.words.isEmpty ? "" : "\n")
        case .srt:
            return renderCaptions(transcript.words, style: .srt)
        case .vtt:
            return "WEBVTT\n\n" + renderCaptions(transcript.words, style: .vtt)
        }
    }

    private enum CaptionStyle {
        case srt
        case vtt
    }

    private struct Cue {
        var words: [TimedWord]

        var start: Double { words.first?.start ?? 0 }
        var end: Double { words.last?.end ?? start }
        var text: String { Transcript.join(words.map(\.text)) }
    }

    private static func renderCaptions(_ words: [TimedWord], style: CaptionStyle) -> String {
        let cues = makeCues(words)
        return cues.enumerated().map { index, cue in
            let timeLine = "\(timestamp(cue.start, style: style)) --> \(timestamp(cue.end, style: style))"
            return "\(index + 1)\n\(timeLine)\n\(cue.text)\n"
        }.joined(separator: "\n")
    }

    // SpeechTranscriber provides word ranges, but those ranges are not reliable
    // pause detection. Form subtitle cues using punctuation and conservative size
    // and duration limits instead.
    private static func makeCues(_ words: [TimedWord]) -> [Cue] {
        var cues: [Cue] = []
        var current: [TimedWord] = []

        func shouldFinish(_ candidate: [TimedWord]) -> Bool {
            guard let first = candidate.first, let last = candidate.last else { return false }
            let text = Transcript.join(candidate.map(\.text))
            let sentenceEnd = text.last.map { ".!?\u{2026}".contains($0) } ?? false
            return candidate.count >= 12
                || text.count >= 78
                || last.end - first.start >= 7
                || (candidate.count >= 3 && sentenceEnd)
        }

        for word in words {
            current.append(word)
            if shouldFinish(current) {
                cues.append(Cue(words: current))
                current = []
            }
        }

        if !current.isEmpty {
            cues.append(Cue(words: current))
        }
        return cues
    }

    private static func timestamp(_ seconds: Double, style: CaptionStyle) -> String {
        let milliseconds = max(0, Int((seconds * 1_000).rounded()))
        let hours = milliseconds / 3_600_000
        let minutes = (milliseconds / 60_000) % 60
        let secs = (milliseconds / 1_000) % 60
        let millis = milliseconds % 1_000
        let separator = style == .srt ? "," : "."
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, secs, separator, millis)
    }
}
