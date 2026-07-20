import Foundation

public enum TranscriptFormatter {
    /// - Parameter mergeSpeakerBlocks: When `true` (and the transcript is diarized),
    ///   srt/vtt cues ignore the usual punctuation/size/duration limits and instead
    ///   span each speaker's full contiguous turn — one cue per uninterrupted block
    ///   of speech from a single speaker, from the first word's start to the last
    ///   word's end. Has no effect on text/json/jsonl, or when not diarized.
    public static func render(
        _ transcript: Transcript,
        as format: OutputFormat,
        mergeSpeakerBlocks: Bool = false
    ) throws -> String {
        let diarized = transcript.words.contains { $0.speaker != nil }
        switch format {
        case .text:
            return renderPlainText(transcript.words, diarized: diarized)
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
            return renderCaptions(transcript.words, style: .srt, diarized: diarized, mergeSpeakerBlocks: mergeSpeakerBlocks)
        case .vtt:
            return "WEBVTT\n\n" + renderCaptions(transcript.words, style: .vtt, diarized: diarized, mergeSpeakerBlocks: mergeSpeakerBlocks)
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
        var speaker: Int? { words.first?.speaker }
    }

    // Plain text is the joined transcript, unless diarization ran — then it
    // groups consecutive same-speaker words into "Speaker N: ..." lines.
    private static func renderPlainText(_ words: [TimedWord], diarized: Bool) -> String {
        guard diarized else {
            return Transcript.join(words.map(\.text)) + "\n"
        }
        var lines: [String] = []
        var current: [TimedWord] = []

        func flush() {
            guard let first = current.first else { return }
            lines.append("\(SpeakerLabel.format(first.speaker)): \(Transcript.join(current.map(\.text)))")
            current = []
        }

        for word in words {
            if let last = current.last, last.speaker != word.speaker {
                flush()
            }
            current.append(word)
        }
        flush()

        return lines.joined(separator: "\n") + "\n"
    }

    private static func renderCaptions(
        _ words: [TimedWord],
        style: CaptionStyle,
        diarized: Bool,
        mergeSpeakerBlocks: Bool
    ) -> String {
        let cues = (mergeSpeakerBlocks && diarized) ? makeSpeakerBlockCues(words) : makeCues(words)
        return cues.enumerated().map { index, cue in
            let timeLine = "\(timestamp(cue.start, style: style)) --> \(timestamp(cue.end, style: style))"
            let text = diarized ? "\(SpeakerLabel.format(cue.speaker)): \(cue.text)" : cue.text
            return "\(index + 1)\n\(timeLine)\n\(text)\n"
        }.joined(separator: "\n")
    }

    // SpeechTranscriber provides word ranges, but those ranges are not reliable
    // pause detection. Form subtitle cues using punctuation and conservative size
    // and duration limits instead. A speaker change always starts a new cue.
    private static func makeCues(_ words: [TimedWord]) -> [Cue] {
        var cues: [Cue] = []
        var current: [TimedWord] = []

        func finishCurrent() {
            guard !current.isEmpty else { return }
            cues.append(Cue(words: current))
            current = []
        }

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
            if let first = current.first, first.speaker != word.speaker {
                finishCurrent()
            }
            current.append(word)
            if shouldFinish(current) {
                finishCurrent()
            }
        }
        finishCurrent()
        return cues
    }

    // One cue per contiguous speaker turn: no punctuation/size/duration split,
    // so a cue's timestamps span the whole uninterrupted block of speech —
    // first word's start to last word's end.
    private static func makeSpeakerBlockCues(_ words: [TimedWord]) -> [Cue] {
        var cues: [Cue] = []
        var current: [TimedWord] = []

        func finishCurrent() {
            guard !current.isEmpty else { return }
            cues.append(Cue(words: current))
            current = []
        }

        for word in words {
            if let first = current.first, first.speaker != word.speaker {
                finishCurrent()
            }
            current.append(word)
        }
        finishCurrent()
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
