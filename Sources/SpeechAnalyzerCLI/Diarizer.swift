@preconcurrency import AVFoundation
import Foundation
import SpeakerKit
import SpeechAnalyzerCore

/// A speaker turn — who spoke during a time window — from diarization.
struct SpeakerTurn: Sendable, Equatable {
    let speaker: Int
    let start: Double
    let end: Double
}

/// On-device speaker diarization ("who spoke when") via SpeakerKit (pyannote).
///
/// Runs fully on-device; the pyannote models download from Hugging Face on
/// first use, then cache.
enum Diarizer {
    static func diarize(audioURL: URL) async throws -> [SpeakerTurn] {
        let samples = try loadSamples(from: audioURL)

        let speakerKit: SpeakerKit
        do {
            speakerKit = try await SpeakerKit()
        } catch {
            throw CLIError.failure("Speaker models failed to load: \(error.localizedDescription)")
        }

        let result: DiarizationResult
        do {
            result = try await speakerKit.diarize(audioArray: samples)
        } catch {
            throw CLIError.failure("Diarization failed: \(error.localizedDescription)")
        }

        return result.segments.map { segment in
            SpeakerTurn(
                speaker: segment.speaker.speakerId ?? -1,
                start: Double(segment.startTime),
                end: Double(segment.endTime)
            )
        }
    }

    /// Applies speaker labels to an existing transcript's words, in place of a fresh array.
    ///
    /// Each word is assigned the speaker whose turn overlaps it most. Words with
    /// no overlapping turn are left unassigned (`speaker == nil`).
    static func label(_ words: [TimedWord], with turns: [SpeakerTurn]) -> [TimedWord] {
        words.map { word in
            TimedWord(
                start: word.start,
                end: word.end,
                text: word.text,
                confidence: word.confidence,
                speaker: bestSpeaker(start: word.start, end: word.end, turns: turns)
            )
        }
    }

    /// Picks the speaker turn with the greatest temporal overlap of `[start, end]`.
    static func bestSpeaker(start: Double, end: Double, turns: [SpeakerTurn]) -> Int? {
        var best: Int?
        var bestOverlap = 0.0
        for turn in turns {
            let overlap = min(end, turn.end) - max(start, turn.start)
            if overlap > bestOverlap {
                bestOverlap = overlap
                best = turn.speaker
            }
        }
        return best
    }

    /// Loads an audio file as mono 16 kHz `Float` samples, the format pyannote /
    /// SpeakerKit expects.
    private static func loadSamples(from url: URL) throws -> [Float] {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw CLIError.failure("The audio could not be loaded: \(error.localizedDescription)")
        }

        let sourceFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw CLIError.failure("Could not create 16 kHz mono format.")
        }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw CLIError.failure("Empty or unreadable audio.")
        }
        do {
            try file.read(into: sourceBuffer)
        } catch {
            throw CLIError.failure("The audio could not be loaded: \(error.localizedDescription)")
        }

        // Already mono 16 kHz Float — read channel data directly.
        if sourceFormat.sampleRate == 16_000,
           sourceFormat.channelCount == 1,
           sourceFormat.commonFormat == .pcmFormatFloat32,
           let channel = sourceBuffer.floatChannelData {
            return Array(UnsafeBufferPointer(start: channel[0], count: Int(sourceBuffer.frameLength)))
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw CLIError.failure("Could not create audio converter.")
        }

        let ratio = 16_000.0 / sourceFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 16_000
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else {
            throw CLIError.failure("Could not allocate output buffer.")
        }

        let consumed = ConsumedFlag()
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, statusPointer in
            if consumed.value {
                statusPointer.pointee = .noDataNow
                return nil
            }
            consumed.value = true
            statusPointer.pointee = .haveData
            return sourceBuffer
        }
        if let conversionError {
            throw CLIError.failure("The audio could not be loaded: \(conversionError.localizedDescription)")
        }
        guard let channel = outputBuffer.floatChannelData else {
            throw CLIError.failure("Conversion produced no samples.")
        }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(outputBuffer.frameLength)))
    }
}

/// A single-shot flag for the `AVAudioConverter` input block, which the converter
/// invokes synchronously on one thread despite not being provably `Sendable`.
private final class ConsumedFlag: @unchecked Sendable {
    var value = false
}
