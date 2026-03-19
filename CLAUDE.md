# Re-Enchanted — Project Guide

## Overview

Re-Enchanted is a macOS/iOS/visionOS LLM chat client forked from [Enchanted](https://github.com/AugustDev/enchanted). It supports Ollama and OpenAI-compatible API endpoints.

## Build

- Xcode 16.3+, Swift 5 language mode (strict concurrency: targeted)
- `xcodebuild -project Re-Enchanted.xcodeproj -scheme Re-Enchanted -destination 'platform=macOS' build`
- Bundle ID: `uk.co.itomlab.re-enchanted`

## Architecture

### Data Layer
- **SwiftData** models in `Enchanted/SwiftData/Models/`: LanguageModelSD, ConversationSD, MessageSD, CompletionInstructionSD, PersonaSD, ScreenCaptureSD
- **SwiftDataService** (`Enchanted/Services/SwiftDataService.swift`): actor-based ModelActor, single persistence gateway for all CRUD
- Schema registered in `SwiftDataService.init()`

### State Management
- `@Observable` singleton stores with `.shared` pattern
- **AppStore**: provider settings, reachability, notifications
- **ConversationStore**: conversations, messages, prompt routing (Ollama vs OpenAI)
- **LanguageModelStore**: model list, selection, visibility filtering via `visibleModels`
- **PersonaStore**: persona CRUD and active persona tracking
- **CompletionsStore**: completion instructions for macOS panel
- **MCPStore**: MCP server configs, client connections, tool registry
- **DejaViewStore**: screen capture state, vector search, backend switching

### Services
- **OllamaService**: OllamaKit wrapper
- **OpenAIService**: URLSession-based, SSE streaming, tool calling support
- **MCPClient**: JSON-RPC 2.0 over stdio (Process), macOS only
- **EmbeddingService**: generates embeddings via Ollama or OpenAI
- **ScreenCaptureService**: CGWindowListCreateImage + Vision OCR, macOS only
- **DateParsingService**: natural language time reference parsing
- **VectorStore** protocol with 4 backends: LocalVectorStore, PgVectorStore, ChromaStore, QdrantStore
- **SpeechService/SpeechSynthesizer**: TTS via AVSpeechSynthesizer
- **Clipboard**, **Haptics**, **Throttler**

### UI Structure
- `Chat.swift`: root coordinator, platform branches
- `ChatView_macOS`: NavigationSplitView (sidebar + detail)
- `ChatView_iOS`: SideBarStack layout
- `ChatMessageView`: markdown rendering (MarkdownUI + Splash syntax highlighting), ThinkingView for chain-of-thought
- `ModelSelectorView`: model + persona picker with capability badges
- Settings: provider config, model management, personas, MCP servers, DejaView, chat, app preferences

## Conventions

- **Platform branching**: `#if os(macOS)` / `#if os(iOS)` preprocessor directives
- **Concurrency**: `@MainActor` for UI state, `nonisolated(unsafe)` for SwiftData types crossing actor boundaries, `@unchecked Sendable` on Observable stores
- **Naming**: `*SD` suffix for SwiftData models, `*Store` for state stores, `*Service` for stateless services, `*View` for UI
- **File comments**: header with file name, project name, original author credit where applicable
- **No co-authored commits** on dev branch
- **Commit style**: `feat:`, `fix:`, `docs:` prefixes

## Key Features

- **Personas**: virtual models with custom system prompts (`PersonaSD`)
- **Model Management**: hide/show models, capability badges (vision, thinking)
- **Thinking UI**: collapsible DisclosureGroup with duration timer
- **MCP**: JSON-RPC stdio client for tool server integration
- **DejaView**: screen capture + OCR + vector embedding + time-based search
- **Tool Calling**: OpenAI function calling with tools/tool_choice in requests
- **Conversation Pinning**: pin/unpin conversations to sidebar top
- **Conversation Search**: real-time search by name and message content

## Dependencies

| Package | Min Version | Status | Notes |
|---------|-------------|--------|-------|
| OllamaKit (AugustDev fork) | `main` branch | ⚠️ Stale fork | Upstream `kevinhermawan/OllamaKit` is at 5.0.8+ with tool calling, Swift 6 |
| swift-markdown-ui | 2.4.1 | ✅ Latest | Maintenance mode; successor is `gonzalezreal/textual` |
| Splash | 0.16.0 | ⚠️ Abandoned | No updates for 2+ years; plan replacement |
| ActivityIndicatorView | 1.2.1 | ✅ Stable | |
| Vortex | 1.0.4 | ✅ Stable | |
| KeyboardShortcuts | 2.4.0 | ✅ Active | macOS only, App Store compatible |
| WrappingHStack | 2.2.11 | ✅ Active | visionOS support added |
| swift-async-algorithms | 1.1.3 | ✅ Active (Apple) | Swift 6 compilation fixes |

### Migration Backlog
- **OllamaKit**: Migrate from `AugustDev/OllamaKit` (frozen fork) to `kevinhermawan/OllamaKit` 5.0.8+. Breaking API changes — v5 removed Alamofire, added tool calling + structured output.
- **Splash**: Plan replacement with MarkdownUI built-in highlighting or `Highlightr`.
