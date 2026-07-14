# speech-analyzer-cli

A small macOS command-line interface for Apple's on-device `SpeechAnalyzer`
and `SpeechTranscriber` APIs. It transcribes prerecorded audio and can emit
plain text, word-level JSON, JSONL, SubRip, or WebVTT.

## Requirements

- macOS 26 or later
- Apple silicon supported by `SpeechTranscriber`
- Xcode 26 or the matching Command Line Tools
- A network connection the first time each language model is installed

## Build and install

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

This builds a background application bundle beneath `~/.local/libexec` and
links its executable as `~/.local/bin/speech-analyzer`. The bundle supplies the
privacy metadata macOS needs when requesting Speech Recognition permission.

If necessary, add this to your shell configuration:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

The first transcription should prompt for Speech Recognition permission. The
audio itself is transcribed on-device. A language model may be downloaded and
installed into system-managed storage before the first transcription.

## Usage

```bash
speech-analyzer interview.m4a
speech-analyzer --locale en-GB --format json interview.m4a
speech-analyzer --format jsonl interview.wav > words.jsonl
speech-analyzer --format srt --output interview.srt interview.m4a
speech-analyzer --format vtt --output interview.vtt interview.m4a
speech-analyzer --list-locales
```

JSON contains the input path, selected locale, complete text, and an array of
word objects:

```json
{
  "file": "/path/to/interview.m4a",
  "locale": "en-US",
  "text": "Hello from SpeechAnalyzer.",
  "words": [
    {"start": 0.42, "end": 0.81, "text": "Hello", "confidence": 0.94}
  ]
}
```

`jsonl` writes one word object per line. Confidence is omitted by Swift's
`Codable` encoder when Apple does not supply it.

SRT and WebVTT cues are grouped using sentence punctuation plus conservative
word-count, character-count, and duration limits. SpeechTranscriber's word
ranges are useful for playback synchronization, but should not be interpreted
as precise forced-alignment boundaries around silence.

## Development

```bash
swift test
swift run speech-analyzer --help
```

The formatting code lives in the platform-independent `SpeechAnalyzerCore`
target. Actual transcription can only be built and exercised on macOS 26 with
Apple's Speech framework.

## Troubleshooting

If permission was denied, enable the tool under **System Settings → Privacy &
Security → Speech Recognition**.

The installer uses an ad-hoc signature. Rebuilding may cause macOS to ask for
permission again. For a stable development installation, sign the app bundle
with an Apple Development certificate instead.

If a locale is rejected, compare it with:

```bash
speech-analyzer --list-locales
```

Locale matching currently uses exact, case-insensitive BCP-47 identifiers.
