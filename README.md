![Swift](https://img.shields.io/badge/swift-F54A2A?&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?&logo=os&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-000000?style=?&logo=os&logoColor=white)
![visionOS](https://img.shields.io/badge/visionOS-000000?style=?&logo=os&logoColor=white)

# Re-Enchanted

Re-Enchanted is a fork of [Enchanted](https://github.com/AugustDev/enchanted) by **Augustinas Malinauskas**, an open-source macOS/iOS/visionOS app for chatting with locally and remotely hosted language models. Re-Enchanted revives, modernises, and extends the original project with powerful new features.

## Features

### Multi-Provider Support
- **Ollama** — connect to any Ollama server
- **OpenAI-compatible APIs** — works with OpenAI, LM Studio, vLLM, text-generation-webui, and any OpenAI-compatible endpoint
- Streaming responses with real-time token output

### Personas
Create virtual models backed by a real model with a custom system prompt. E.g., "Code Reviewer" wraps your preferred model with a code review system prompt. Personas appear in the model picker alongside real models.

### Model Management
- **Capability badges** — see at a glance which models support vision (eye icon) and chain-of-thought reasoning (brain icon)
- **Hide models** — toggle visibility to hide embedding models and unused models from the selector
- Auto-detection of vision and thinking capabilities

### Thinking/Reasoning UI
- Collapsible chain-of-thought display with live duration timer
- Auto-collapses when reasoning is complete ("Thought for 12s")
- Pulsing brain icon while streaming, secondary styled content with accent border

### DejaView (Screen Recall)
Capture screenshots on a timer, OCR the text with Apple Vision, embed into a vector database, and search with natural language:
- "What was I looking at yesterday when I saw that error?"
- Time-based filtering: "last 2 hours", "last Tuesday", "this morning"
- **4 vector store backends**: Local (in-memory cosine similarity), pgvector, ChromaDB, Qdrant
- Configurable capture interval and backend

### MCP (Model Context Protocol) & Tool Use
- **MCP Client** — launch and communicate with MCP tool servers via stdio
- **OpenAI function calling** — tools parameter in chat completion requests
- Tool call display inline in chat with collapsible details
- MCP server management in Settings

### Rich Chat Experience
- Markdown rendering with syntax-highlighted code blocks
- Code block copy button with checkmark feedback
- Image attachments with vision model support
- Text-to-speech (Read Aloud)
- Voice prompts via speech recognition
- Conversation history stored on-device
- Dark/Light/System appearance modes
- macOS Spotlight panel (Ctrl+Cmd+K)

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| Cmd+N | New conversation |
| Cmd+/ | Focus message input |
| Cmd+E | Export chat to clipboard |
| Cmd+, | Open Settings |
| Cmd+Option+S | Toggle sidebar |
| Cmd+V | Paste text or image |
| Ctrl+Cmd+K | Open panel window |

## Requirements

- macOS 14.0+ / iOS 17.0+ / visionOS 1.1+
- Xcode 16.3+
- A running LLM server

## Usage

### Ollama (default)
1. Install [Ollama](https://github.com/jmorganca/ollama) and pull a model
2. Open Re-Enchanted — default connects to localhost:11434

### OpenAI-compatible endpoint
1. Settings → Provider → OpenAI
2. Enter endpoint URL and API key
3. Save — models load automatically

### DejaView
1. Settings → DejaView → enable capture
2. Choose vector store backend (Local works out of the box)
3. Use Cmd+Shift+D to open DejaView search

### MCP Servers
1. Settings → MCP Servers → Add Server
2. Enter command and arguments (e.g., `npx @modelcontextprotocol/server-filesystem /tmp`)
3. Click Connect All

## Credits

Re-Enchanted is a fork of **[Enchanted](https://github.com/AugustDev/enchanted)** by **Augustinas Malinauskas**. Licensed under Apache 2.0.

## License

[Apache License 2.0](LICENSE)

## Contact

- Re-Enchanted: [iTomLab](https://itomlab.co.uk)
- Original project: augustinas@subj.org
