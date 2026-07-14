import Darwin
import Foundation
import SpeechAnalyzerCore

@main
struct SpeechAnalyzerCommand {
    static func main() async {
        do {
            let arguments = try Arguments.parse(Array(CommandLine.arguments.dropFirst()))

            if arguments.listLocales {
                print((await AppleTranscriber.availableLocales()).joined(separator: "\n"))
                return
            }

            let transcript = try await AppleTranscriber.transcribe(
                path: arguments.inputPath!,
                requestedLocale: arguments.locale
            )
            let rendered = try TranscriptFormatter.render(transcript, as: arguments.format)

            if let outputPath = arguments.outputPath {
                try rendered.write(
                    to: URL(fileURLWithPath: outputPath),
                    atomically: true,
                    encoding: .utf8
                )
            } else {
                FileHandle.standardOutput.write(Data(rendered.utf8))
            }
        } catch CLIError.help {
            print(Arguments.usage)
        } catch CLIError.version {
            print("speech-analyzer 0.1.0")
        } catch let error as CLIError {
            fputs("Error: \(error)\n\n\(Arguments.usage)\n", stderr)
            Darwin.exit(2)
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            Darwin.exit(1)
        }
    }
}
