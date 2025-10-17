# Zulip Call Kit

A Flutter plugin for implementing video and audio calling functionality using Jitsi Meet, with customizable UI and support for iOS CallKit integration.

## Features

- 🎥 **Video & Audio Calls** - Support for both video and audio-only calls via Jitsi Meet
- 📱 **Native Integrations** - iOS CallKit and Android notifications
- 🎨 **Customizable UI** - Pre-built screens that can be themed
- 🔌 **Backend Adapter Pattern** - Easy integration with any backend API
- 📡 **Real-time Events** - WebSocket event handling for call state changes
- 📋 **Call History** - Track and display past calls

## Architecture

The plugin uses a clean architecture with three main layers:

1. **Core Layer**: Models, adapters, repository, and services
2. **UI Layer**: Screens and widgets for call interface
3. **Platform Layer**: iOS and Android specific integrations

## Usage

See the main Zulip app for integration examples using `ZulipCallAdapter`.

## License

Apache License 2.0 - See LICENSE file in the root of the Zulip Flutter project.
