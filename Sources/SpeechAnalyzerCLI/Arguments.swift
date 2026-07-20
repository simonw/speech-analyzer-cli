import Foundation
import SpeechAnalyzerCore

struct Arguments {
    let inputPath: String?
    let locale: String
    let format: OutputFormat
    let outputPath: String?
    let listLocales: Bool
    let diarize: Bool
    let speakerBlocks: Bool

    static let usage = """
    Usage: speech-analyzer [options] AUDIO_FILE

    Transcribe an audio file locally using Apple's SpeechAnalyzer framework.

    Options:
      -l, --locale LOCALE      BCP-47 locale, such as en-US (default: en-US)
      -f, --format FORMAT      text, json, jsonl, srt, or vtt (default: text)
      -o, --output PATH        Write to PATH instead of standard output
          --diarize            Label speakers using on-device diarization
                                (adds "SPEAKER N: " prefixes to vtt/srt/text,
                                and a "speaker" field to json/jsonl)
          --speaker-blocks      With --diarize and srt/vtt, merge each
                                speaker's contiguous turn into one cue instead
                                of splitting on sentence/size limits. Requires
                                --diarize.
          --list-locales       List SpeechTranscriber locales available to download
      -h, --help               Show this help
          --version            Show the version
    """

    static func parse(_ raw: [String]) throws -> Arguments {
        var inputPath: String?
        var locale = "en-US"
        var format: OutputFormat = .text
        var outputPath: String?
        var listLocales = false
        var diarize = false
        var speakerBlocks = false
        var index = 0

        func value(after option: String) throws -> String {
            let next = index + 1
            guard next < raw.count else {
                throw CLIError.usage("Missing value for \(option)")
            }
            index = next
            return raw[next]
        }

        while index < raw.count {
            let argument = raw[index]
            switch argument {
            case "-h", "--help":
                throw CLIError.help
            case "--version":
                throw CLIError.version
            case "--list-locales":
                listLocales = true
            case "--diarize":
                diarize = true
            case "--speaker-blocks":
                speakerBlocks = true
            case "-l", "--locale":
                locale = try value(after: argument)
            case "-f", "--format":
                let value = try value(after: argument)
                guard let parsed = OutputFormat(rawValue: value) else {
                    throw CLIError.usage("Unknown format '\(value)'")
                }
                format = parsed
            case "-o", "--output":
                outputPath = try value(after: argument)
            default:
                if argument.hasPrefix("-") {
                    throw CLIError.usage("Unknown option '\(argument)'")
                }
                guard inputPath == nil else {
                    throw CLIError.usage("Only one audio file can be transcribed at a time")
                }
                inputPath = argument
            }
            index += 1
        }

        if !listLocales && inputPath == nil {
            throw CLIError.usage("Missing AUDIO_FILE")
        }
        if speakerBlocks && !diarize {
            throw CLIError.usage("--speaker-blocks requires --diarize")
        }

        return Arguments(
            inputPath: inputPath,
            locale: locale,
            format: format,
            outputPath: outputPath,
            listLocales: listLocales,
            diarize: diarize,
            speakerBlocks: speakerBlocks
        )
    }
}

enum CLIError: Error, CustomStringConvertible {
    case help
    case version
    case usage(String)
    case failure(String)

    var description: String {
        switch self {
        case .help:
            return Arguments.usage
        case .version:
            return "speech-analyzer 0.1.0"
        case .usage(let message), .failure(let message):
            return message
        }
    }
}
