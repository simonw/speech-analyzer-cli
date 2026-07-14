import AVFoundation
import CoreMedia
import Foundation
import Speech
import SpeechAnalyzerCore

enum AppleTranscriber {
    static func availableLocales() async -> [String] {
        await SpeechTranscriber.supportedLocales
            .map { $0.identifier(.bcp47) }
            .sorted()
    }

    static func transcribe(path: String, requestedLocale: String) async throws -> Transcript {
        let fileURL = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CLIError.failure("Audio file does not exist: \(fileURL.path)")
        }

        try await authorizeSpeechRecognition()

        let locales = await SpeechTranscriber.supportedLocales
        let requested = Locale(identifier: requestedLocale)
        let requestedIdentifier = requested.identifier(.bcp47)
        guard let locale = locales.first(where: {
            $0.identifier(.bcp47).caseInsensitiveCompare(requestedIdentifier) == .orderedSame
        }) else {
            throw CLIError.failure(
                "SpeechTranscriber does not support \(requestedIdentifier) on this Mac. "
                + "Run speech-analyzer --list-locales to see supported locales."
            )
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        )

        if let installation = try await AssetInventory.assetInstallationRequest(
            supporting: [transcriber]
        ) {
            try await installation.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: fileURL)

        let collector = Task { () throws -> [TimedWord] in
            var words: [TimedWord] = []
            for try await result in transcriber.results {
                guard result.isFinal else { continue }
                for run in result.text.runs {
                    guard let range = run.audioTimeRange else { continue }
                    let text = String(result.text[run.range].characters)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }

                    let start = CMTimeGetSeconds(range.start)
                    let duration = CMTimeGetSeconds(range.duration)
                    words.append(TimedWord(
                        start: start,
                        end: start + duration,
                        text: text,
                        confidence: run.transcriptionConfidence.map { Double($0) }
                    ))
                }
            }
            return words
        }

        do {
            if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            let words = try await collector.value
            return Transcript(
                file: fileURL.path,
                locale: locale.identifier(.bcp47),
                words: words
            )
        } catch {
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            throw error
        }
    }

    private static func authorizeSpeechRecognition() async throws {
        let status: SFSpeechRecognizerAuthorizationStatus
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { result in
                    continuation.resume(returning: result)
                }
            }
        } else {
            status = SFSpeechRecognizer.authorizationStatus()
        }

        switch status {
        case .authorized:
            return
        case .denied:
            throw CLIError.failure(
                "Speech recognition permission was denied. Enable it in System Settings > Privacy & Security > Speech Recognition."
            )
        case .restricted:
            throw CLIError.failure("Speech recognition is restricted on this Mac.")
        case .notDetermined:
            throw CLIError.failure("Speech recognition permission was not granted.")
        @unknown default:
            throw CLIError.failure("Unknown speech recognition authorization status.")
        }
    }
}
