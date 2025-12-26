# LowCode Shortcuts

A Flutter-based app for creating, managing, and executing automation shortcuts from a visual editor, with Android widgets and a native Kotlin execution engine.

Long-term, the project aims to reach feature parity with Apple Shortcuts while staying fast, reliable, and Android-native.

## Features

- **Visual Dashboard**: Drag & drop management for flows, quick launch, and widget pinning.
- **Low-Code Editor**:
  - **Fetch**: HTTP requests with custom headers, body, and method.
  - **Logic**: `If/Else` branching with nested flows.
  - **UI/UX**: Toasts, notifications, and widget view updates.
  - **Expressions**: Variable interpolation, functions, and math for derived values.
- **Native Android Widgets**: Run flows directly from home screen widgets.
- **Smart Logic Engine**: Kotlin `LogicEngine` executes flows off the UI thread.
- **Logs & Debugging**: Per-widget execution logs for tracing and troubleshooting.

## Project Overview

LowCode Shortcuts focuses on fast, reliable automations that are easy to build. The editor keeps flows understandable, while the native engine handles execution so shortcuts run even when the UI is closed. The goal is to make complex automations approachable without sacrificing power.

## Roadmap Direction

- Expand the action library (system intents, files, notifications, and more).
- Improve sharing/export/import of flows.
- Polish the editor UX with better validation and inline feedback.

## Design Language

- Blue-toned palette with a clean, borderless UI.
- Prefer edge-to-edge list items without card borders; use spacing and subtle fills for separation.
- Use light blue-white backgrounds for code/detail blocks.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
