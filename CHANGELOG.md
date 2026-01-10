# Changelog

All notable changes to Draughts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-01-10

### 🚀 Added
- **Position Evaluator**: Implemented sophisticated board evaluation service considering material, positional advantage, and piece safety.
- **Opening Book**: Added opening book service with "Old Faithful" opening to guide AI in early game.
- **AI Integration**: AI now utilizes position evaluator and opening book for significantly stronger gameplay.
- **✨ New Icons**: Fresh new application icons (Thanks to @oiimrosabel).

### 🛠️ Fixed
- **Build System**: Resolved various compilation warnings and errors in `Window.vala` and `OpeningBook.vala`.
- **UI**: Fixed deprecation warnings for `Adw.MessageDialog` and `Gtk.show_uri`.
- **International Draughts**: Enabled backward capture functionality.

## [2.0.3] - 2025-10-21

### ✨ Added
- **Russian Translation**: Added comprehensive Russian localization (Thanks to @ma12vlad).

### 📝 Changed
- Updated credits in About dialog to include new contributors.

## [2.0.2] - 2025-10-21

### 🧹 Changed
- Removed deprecated `.specify` directory and tools.
- Performed general code cleanup and maintenance.

## [2.0.0] - 2025-10-15

### 🌟 Added
- **Online Multiplayer**: Real-time play against global opponents.
- **Room System**: Matchmaking with 6-character room codes.
- **Session Persistence**: Automatic reconnection and state synchronization.
- **WebSocket Backend**: Robust Node.js server with keepalive and error handling.

## [1.0.0] - 2025-09-30

### 🎉 Initial Release
- **16 Variants**: Support for all major international draughts variants.
- **AI System**: Minimax-based AI with 10 difficulty levels.
- **Game Modes**: Human vs Human, Human vs AI, AI vs AI.
- **Modern UI**: Built with GTK4 and LibAdwaita.
- **Sound & Accessibility**: Full audio feedback and screen reader support.
