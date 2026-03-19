![Swift](https://img.shields.io/badge/swift-F54A2A?&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?&logo=os&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-000000?style=?&logo=os&logoColor=white)
![visionOS](https://img.shields.io/badge/visionOS-000000?style=?&logo=os&logoColor=white)

# Re-Enchanted

Re-Enchanted is a fork of [Enchanted](https://github.com/AugustDev/enchanted) by **Augustinas Malinauskas**, an open-source macOS/iOS/visionOS app for working with locally (and remotely) hosted language models. Re-Enchanted aims to revive, modernise and extend the original project.

Re-Enchanted supports **Ollama** and any **OpenAI-compatible API endpoint** (OpenAI, LM Studio, vLLM, text-generation-webui, etc.), giving you a beautiful native client across all Apple platforms.

## What's New in Re-Enchanted

- Upgraded to **Xcode 16.3** project format and **Swift 5** (with strict concurrency)
- Full **OpenAI-compatible endpoint** support with streaming, vision/image, and model listing
- Updated and modernised all dependencies
- New bundle ID and fresh versioning (1.0.0)
- Maintained by [iTomLab](https://itomlab.co.uk)

## Features

- **Multi-provider support** — Ollama and OpenAI-compatible APIs
- **Vision / Image support** — attach images when using vision-capable models
- **Streaming responses** — real-time token-by-token output
- **Text to Speech** (Read Aloud)
- **Conversation history** included in API calls and stored on-device
- **Dark/Light mode**
- **Markdown support** (tables, lists, code blocks with syntax highlighting)
- **Voice prompts**
- **System prompt** for every conversation
- **Edit messages** or re-submit with a different model
- **macOS Spotlight panel** <kbd>Ctrl</kbd>+<kbd>⌘</kbd>+<kbd>K</kbd>
- Works **offline** with local models

## Requirements

- macOS 14.0+ / iOS 17.0+ / visionOS 1.1+
- Xcode 16.3+
- A running LLM server (Ollama, LM Studio, OpenAI API, or any OpenAI-compatible endpoint)

## Usage

### Option 1: Ollama (default)

1. Install and start [Ollama](https://github.com/jmorganca/ollama) (v0.1.14+)
2. Pull a model: `ollama pull llama3`
3. Open Re-Enchanted and use the default settings (localhost:11434)

### Option 2: OpenAI-compatible endpoint

1. In Settings, switch the **LLM Provider** to "OpenAI"
2. Enter the endpoint URL (e.g. `https://api.openai.com/v1` or `http://localhost:1234/v1` for LM Studio)
3. Enter your API key if required
4. Save — models will be loaded automatically

### Remote access with ngrok

If your LLM server is on a different machine:

```shell
ngrok http 11434 --host-header="localhost:11434"
```

Copy the forwarding URL and paste it into the server URI field in Settings.

## Credits

Re-Enchanted is a fork of **[Enchanted](https://github.com/AugustDev/enchanted)** by **Augustinas Malinauskas**. The original project is licensed under the Apache License 2.0. We are grateful for the excellent foundation.

## License

[Apache License 2.0](LICENSE)

## Contact

For Re-Enchanted: [iTomLab](https://itomlab.co.uk)
Original project: augustinas@subj.org
