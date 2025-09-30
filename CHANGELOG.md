# Changelog

All notable changes to Draughts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-09-30

### Added
- **16 International Game Variants**
  - American Checkers (8×8) - North American standard rules
  - International Draughts (10×10) - World championship variant with flying kings
  - Russian Draughts (8×8) - Flying kings with longest sequence rule
  - Brazilian Draughts (8×8) - International rules on 8×8 board
  - Italian Draughts (8×8) - Traditional Italian rules, men cannot capture kings
  - Spanish Draughts (8×8) - Unique backward capture rules for men
  - Czech Draughts (8×8) - Central European variant with flying kings
  - Thai Draughts (8×8) - Southeast Asian variant
  - German Draughts (8×8) - Similar to Russian variant
  - Swedish Draughts (10×10) - Scandinavian variant
  - Pool Checkers (8×8) - American variant with optional rules
  - Turkish Draughts (8×8) - Orthogonal movement variant
  - Armenian Draughts (8×8) - Middle Eastern variant
  - Gothic Draughts (8×8) - Medieval European rules
  - Frisian Draughts (10×10) - Dutch regional variant
  - Canadian Draughts (12×12) - Largest board variant with 30 pieces per side

- **AI System**
  - 10 difficulty levels: Beginner, Novice, Easy, Intermediate, Advanced, Expert, Master, Grandmaster, World Class, Legendary
  - Minimax algorithm with alpha-beta pruning for efficient move evaluation
  - Advanced position evaluation considering material, king value, center control, and mobility
  - Adjustable search depth based on difficulty level (1-8 ply)

- **Game Modes**
  - Human vs Human - Play with friends locally
  - Human vs AI - Challenge the computer
  - AI vs AI - Watch computer players compete

- **Sound System**
  - Complete audio feedback for game events
  - Move sounds with distinct tones for regular moves, captures, and promotions
  - Game start and end sounds
  - Timer warning sounds
  - Illegal move feedback
  - Undo/redo audio cues
  - Settings to enable/disable sound effects

- **Game Export**
  - PDN (Portable Draughts Notation) export
  - Numeric square notation standard for all variants
  - Complete game metadata (players, variant, date)
  - Move history with capture notation
  - Game result tracking

- **Customization Options**
  - Four piece styles: Plastic (default), Wood, Metal, Bottle Cap
  - Five board themes: Classic, Wood, Green, Blue, High Contrast
  - Dark mode support following system theme
  - Customizable preferences

- **User Interface**
  - Modern GTK4 and LibAdwaita design
  - Smooth animations for piece movements
  - Visual feedback for valid moves and captures
  - Responsive layout adapting to window size
  - Toast notifications for game events

- **Help and Documentation**
  - Comprehensive in-app help system (F1)
  - Getting Started guide
  - Detailed variant descriptions and rules
  - Keyboard shortcuts reference
  - First-run welcome dialog

- **Game Features**
  - Complete move history with unlimited undo/redo
  - Game history tracking across sessions
  - Timer support with configurable time controls
  - Keyboard navigation support
  - Screen reader accessibility

- **Accessibility**
  - Full keyboard navigation
  - Screen reader support with descriptive announcements
  - High contrast board theme
  - Accessible UI controls following GNOME HIG

### Technical Improvements
- Built with GTK4 and LibAdwaita for modern GNOME integration
- Vala programming language for performance and maintainability
- Blueprint declarative UI syntax
- GStreamer 1.0 for audio playback
- Flatpak packaging for easy distribution
- Comprehensive icon set (16x16 through 512x512)
- Complete AppStream metadata for software centers

### Quality
- Replaced all debug print() statements with structured logging
- Fixed AI gameplay logic for proper turn handling
- Implemented proper game state validation
- Complete rules implementation for all 16 variants
- Extensive testing across different board sizes

### Known Limitations
- No online multiplayer (planned for future release)
- No game analysis features (planned for future release)
- No opening book or endgame tablebases
- Limited to local play only

## [Unreleased]
- Future features will be documented here

---

**Full Changelog**: https://github.com/tobagin/Draughts/releases/tag/v1.0.0
