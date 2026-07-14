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
