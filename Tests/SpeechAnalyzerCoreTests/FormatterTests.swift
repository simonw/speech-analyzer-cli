import Testing
@testable import SpeechAnalyzerCore

@Test func joinsPunctuationCorrectly() {
    #expect(Transcript.join(["Hello", ",", "world", "!"]) == "Hello, world!")
    #expect(Transcript.join(["(", "testing", ")"]) == "(testing)")
}

@Test func rendersJSONL() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [TimedWord(start: 1.25, end: 1.75, text: "Hello", confidence: 0.9)]
    )
    let output = try TranscriptFormatter.render(transcript, as: .jsonl)
    #expect(output.contains("\"start\":1.25"))
    #expect(output.contains("\"text\":\"Hello\""))
}

@Test func rendersSRTWithSentenceCues() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [
            TimedWord(start: 1.0, end: 1.4, text: "One"),
            TimedWord(start: 1.4, end: 1.8, text: "two"),
            TimedWord(start: 1.8, end: 2.2, text: "three."),
            TimedWord(start: 3.0, end: 3.4, text: "Next")
        ]
    )
    let output = try TranscriptFormatter.render(transcript, as: .srt)
    #expect(output.contains("00:00:01,000 --> 00:00:02,200"))
    #expect(output.contains("One two three."))
    #expect(output.contains("00:00:03,000 --> 00:00:03,400"))
}

@Test func rendersWebVTTHeaderAndDotMilliseconds() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [TimedWord(start: 0, end: 1.234, text: "Test")]
    )
    let output = try TranscriptFormatter.render(transcript, as: .vtt)
    #expect(output.hasPrefix("WEBVTT\n\n"))
    #expect(output.contains("00:00:00.000 --> 00:00:01.234"))
}

@Test func rendersWebVTTWithSpeakerPrefixAndBreaksCuesOnSpeakerChange() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [
            TimedWord(start: 0.0, end: 0.4, text: "Hello", speaker: 0),
            TimedWord(start: 0.4, end: 0.8, text: "there.", speaker: 0),
            TimedWord(start: 1.0, end: 1.4, text: "Hi", speaker: 1),
            TimedWord(start: 1.4, end: 1.8, text: "back.", speaker: 1)
        ]
    )
    let output = try TranscriptFormatter.render(transcript, as: .vtt)
    #expect(output.contains("SPEAKER 1: Hello there."))
    #expect(output.contains("SPEAKER 2: Hi back."))
    // Cues break on speaker change even mid-sentence, so this is two cues.
    #expect(output.contains("1\n00:00:00.000"))
    #expect(output.contains("2\n00:00:01.000"))
}

@Test func rendersSRTWithSpeakerPrefix() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [
            TimedWord(start: 0.0, end: 0.4, text: "Hello.", speaker: 0),
            TimedWord(start: 1.0, end: 1.4, text: "Hi.", speaker: nil)
        ]
    )
    let output = try TranscriptFormatter.render(transcript, as: .srt)
    #expect(output.contains("SPEAKER 1: Hello."))
    #expect(output.contains("UNKNOWN: Hi."))
}

@Test func rendersTextGroupedBySpeakerWhenDiarized() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [
            TimedWord(start: 0.0, end: 0.4, text: "Hello", speaker: 0),
            TimedWord(start: 0.4, end: 0.8, text: "there.", speaker: 0),
            TimedWord(start: 1.0, end: 1.4, text: "Hi", speaker: 1),
            TimedWord(start: 1.4, end: 1.8, text: "back.", speaker: 1)
        ]
    )
    let output = try TranscriptFormatter.render(transcript, as: .text)
    #expect(output == "SPEAKER 1: Hello there.\nSPEAKER 2: Hi back.\n")
}

@Test func rendersPlainTextWhenNotDiarized() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [
            TimedWord(start: 0.0, end: 0.4, text: "Hello"),
            TimedWord(start: 0.4, end: 0.8, text: "there.")
        ]
    )
    let output = try TranscriptFormatter.render(transcript, as: .text)
    #expect(output == "Hello there.\n")
}

@Test func speakerBlocksMergeContiguousSameSpeakerCuesAcrossSentences() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [
            // Two sentences from speaker 0 — normally two cues (sentence-end split).
            TimedWord(start: 0.0, end: 0.4, text: "Hello", speaker: 0),
            TimedWord(start: 0.4, end: 0.8, text: "there", speaker: 0),
            TimedWord(start: 0.8, end: 1.2, text: "today.", speaker: 0),
            TimedWord(start: 1.2, end: 1.6, text: "How", speaker: 0),
            TimedWord(start: 1.6, end: 2.0, text: "are", speaker: 0),
            TimedWord(start: 2.0, end: 2.4, text: "you", speaker: 0),
            TimedWord(start: 2.4, end: 2.8, text: "doing?", speaker: 0),
            // Speaker change always starts a new cue, block mode or not.
            TimedWord(start: 3.0, end: 3.4, text: "Great,", speaker: 1),
            TimedWord(start: 3.4, end: 3.8, text: "thanks", speaker: 1),
            TimedWord(start: 3.8, end: 4.2, text: "for", speaker: 1),
            TimedWord(start: 4.2, end: 4.6, text: "asking.", speaker: 1)
        ]
    )

    // Without --speaker-blocks: sentence-end heuristic splits speaker 0 into two cues.
    let normal = try TranscriptFormatter.render(transcript, as: .vtt)
    #expect(normal.contains("SPEAKER 1: Hello there today."))
    #expect(normal.contains("SPEAKER 1: How are you doing?"))
    #expect(normal.contains("SPEAKER 2: Great, thanks for asking."))

    // With --speaker-blocks: speaker 0's whole turn merges into one cue spanning
    // the first word's start to the last word's end.
    let blocked = try TranscriptFormatter.render(transcript, as: .vtt, mergeSpeakerBlocks: true)
    #expect(blocked.contains("SPEAKER 1: Hello there today. How are you doing?"))
    #expect(blocked.contains("00:00:00.000 --> 00:00:02.800"))
    #expect(blocked.contains("SPEAKER 2: Great, thanks for asking."))
    #expect(blocked.contains("00:00:03.000 --> 00:00:04.600"))
    // Only two cues total: one per speaker turn.
    #expect(blocked.components(separatedBy: " --> ").count - 1 == 2)
}

@Test func speakerBlocksHasNoEffectWhenNotDiarized() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [
            TimedWord(start: 0.0, end: 0.4, text: "One"),
            TimedWord(start: 0.4, end: 0.8, text: "two"),
            TimedWord(start: 0.8, end: 1.2, text: "three.")
        ]
    )
    let withoutBlocks = try TranscriptFormatter.render(transcript, as: .vtt)
    let withBlocks = try TranscriptFormatter.render(transcript, as: .vtt, mergeSpeakerBlocks: true)
    #expect(withoutBlocks == withBlocks)
}

@Test func jsonlOmitsSpeakerWhenAbsentAndIncludesItWhenPresent() throws {
    let transcript = Transcript(
        file: "/tmp/test.wav",
        locale: "en-US",
        words: [
            TimedWord(start: 0, end: 0.4, text: "Hello", speaker: 0),
            TimedWord(start: 0.4, end: 0.8, text: "there.")
        ]
    )
    let output = try TranscriptFormatter.render(transcript, as: .jsonl)
    #expect(output.contains("\"speaker\":0"))
    let lines = output.split(separator: "\n")
    #expect(!lines[1].contains("speaker"))
}
