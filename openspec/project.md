# Project Context

## Purpose

Draughts is a comprehensive draughts (checkers) game for the GNOME desktop environment. The project aims to provide:

- **16 international draughts variants** with authentic rule implementations (American Checkers, International, Russian, Brazilian, Italian, Spanish, Czech, Thai, German, Swedish, Pool, Turkish, Armenian, Gothic, Frisian, and Canadian)
- **Multiple gameplay modes**: Human vs Human (local), Human vs AI (10 difficulty levels), AI vs AI, and **online multiplayer** with real-time synchronization
- **Beautiful, accessible interface** built with modern GNOME technologies (GTK4 + LibAdwaita)
- **Rich features**: Move history, game replay, PDN export, timer modes, sound effects, theme customization, and game statistics
- **Professional quality**: Following GNOME HIG, accessibility standards, and delivering a polished native Linux gaming experience

The goal is to be the definitive draughts application for Linux/GNOME, combining authentic gameplay with modern UX and multiplayer capabilities.

## Tech Stack

### Core Technologies
- **Language**: Vala >= 0.56.0 (compiles to C, provides modern OOP with GObject integration)
- **UI Framework**: GTK4 >= 4.20 (GNOME's modern widget toolkit)
- **UI Components**: LibAdwaita >= 1.8 (GNOME adaptive widgets and design patterns)
- **UI Definition**: Blueprint Compiler (declarative UI syntax, compiles to GTK XML)
- **Build System**: Meson >= 1.9.0 + Ninja (fast, declarative build configuration)
- **Packaging**: Flatpak (sandboxed distribution via Flathub)

### Runtime Dependencies
- **GLib** >= 2.86 (core library, event loop, utilities)
- **GIO** >= 2.86 (I/O, settings, file operations)
- **Gee** >= 0.8 (generic collections for Vala)
- **LibSoup** >= 3.0 (HTTP client, WebSocket for multiplayer)
- **JSON-GLib** >= 1.6 (JSON parsing for network protocol)
- **GStreamer** 1.0 (audio playback for sound effects)

### Development Tools
- **Flatpak Builder** (containerized builds)
- **GSettings/GSchema** (persistent user preferences)
- **GResource** (embedded application resources)
- **i18n/gettext** (internationalization support)

### External Services
- **Multiplayer Server**: Custom Node.js WebSocket relay server
  - Deployed at `draughts.tobagin.eu` (Cloudflare proxied)
  - Handles room management, matchmaking, and game state synchronization
  - Docker containerized with health checks

## Project Conventions

### Code Style

**Vala Style Guidelines (follows GNOME conventions):**

1. **Indentation**: 4 spaces (no tabs)
2. **Braces**: Opening brace on same line
   ```vala
   public void method() {
       // code here
   }
   ```
3. **Naming Conventions**:
   - **Classes**: `PascalCase` (e.g., `GameController`, `MinimaxAI`)
   - **Methods/Functions**: `snake_case` (e.g., `calculate_move`, `get_valid_moves`)
   - **Private fields**: `snake_case` with leading underscore optional
   - **Constants**: `UPPER_SNAKE_CASE` (e.g., `MAX_DEPTH`, `BOARD_SIZE`)
   - **Enums**: `PascalCase` for type, `UPPER_SNAKE_CASE` for values
4. **Documentation**: Use Vala doc comments for public APIs
   ```vala
   /**
    * Calculate the best move for the AI player
    *
    * @param depth Search depth for minimax algorithm
    * @return The optimal move, or null if no valid moves
    */
   public DraughtsMove? calculate_move(int depth) {
   ```
5. **Line Length**: Aim for 100-120 characters maximum
6. **Error Handling**: Use Vala's error types (`throws Error`), not generic exceptions

**Blueprint UI Guidelines:**
- Use Blueprint declarative syntax for all UI definitions (`.blp` files)
- Keep UI logic separate from business logic
- Use proper GTK4/LibAdwaita widgets (prefer Adw widgets when available)
- Follow GNOME HIG (Human Interface Guidelines) for layout, spacing, and interactions
- UI files located in `data/ui/` with subdirectories for `dialogs/` and `widgets/`

### Architecture Patterns

**Layered Architecture:**

```
┌─────────────────────────────────────────┐
│  Presentation Layer (UI)                │
│  - Window.vala, dialogs/, widgets/      │
│  - Blueprint .blp files                  │
└─────────────────────────────────────────┘
           ↓ (events/bindings)
┌─────────────────────────────────────────┐
│  Manager Layer (Coordination)           │
│  - GameSessionManager                    │
│  - SoundManager, SettingsManager         │
│  - GameHistoryManager, MoveHistoryManager│
└─────────────────────────────────────────┘
           ↓ (delegates to)
┌─────────────────────────────────────────┐
│  Service Layer (Business Logic)         │
│  - GameController (local games)          │
│  - MultiplayerGameController             │
│  - UnifiedRuleEngine (game rules)        │
│  - MinimaxAI (AI player)                 │
│  - NetworkClient (multiplayer)           │
└─────────────────────────────────────────┘
           ↓ (operates on)
┌─────────────────────────────────────────┐
│  Model Layer (Data)                     │
│  - Game, GameVariant, GamePiece          │
│  - DraughtsMove, BoardPosition           │
│  - Timer, GameHistory                    │
└─────────────────────────────────────────┘
```

**Key Patterns:**
- **MVC/MVP**: UI widgets (View) → Manager classes (Controller) → Service classes (Model logic)
- **Strategy Pattern**: `IRuleEngine` interface with variant-specific implementations
- **Interface Segregation**: `IAIPlayer`, `IGameController` for pluggable implementations
- **Manager Pattern**: Centralized managers for cross-cutting concerns (sound, settings, history)
- **Observer Pattern**: GObject signals for event-driven communication between layers
- **Factory Pattern**: `GameVariant` creates appropriate rule engines
- **Singleton Pattern**: Managers are typically singleton instances (via static fields)

**Dependency Injection:**
- Pass dependencies via constructor parameters
- Avoid tight coupling between layers
- Controllers receive service interfaces, not concrete implementations

### Testing Strategy

**Current Testing:**
- **Unit Tests**: Located in `tests/unit/`
  - Test individual components: `test_game_piece.vala`, `test_move.vala`, `test_position.vala`
  - Test game logic: `test_move_generation.vala`, `test_base_rule_engine.vala`
  - Test game state: `test_game_state.vala`
- **Contract Tests**: Located in `tests/contract/`
  - Verify interface contracts: `test_rule_engine_interface.vala`
- **Build Integration**: Tests run via Meson test framework

**Testing Approach:**
- Write tests for core game logic (rule engines, move generation, AI evaluation)
- Test edge cases and boundary conditions (board edges, king promotions, forced captures)
- Verify rule variants implement correct game mechanics
- Manual testing for UI interactions and accessibility features
- Flatpak build must succeed before merging changes

**Coverage Expectations:**
- High coverage for game logic (rule engines, move validation)
- Interface contracts must be tested
- UI code tested via manual QA

### Git Workflow

**Branching Strategy:**
- **`master`** branch: Stable releases, production-ready code
- **Feature branches**: `feature/descriptive-name` for new features
- **Bug fix branches**: `fix/issue-description` for bug fixes
- Work on feature branches, merge to master when complete

**Commit Message Format:**
```
type: short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain the what and why, not the how.

- Bullet points are okay
- Use present tense: "Add feature" not "Added feature"
- Reference issues: "Fixes #123" or "Related to #456"
```

**Commit Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `chore:` - Maintenance, version bumps, tooling
- `docs:` - Documentation updates
- `refactor:` - Code refactoring (no behavior change)
- `perf:` - Performance improvements
- `test:` - Test additions or modifications
- `ui:` - UI/UX changes

**Example:**
```
feat: add Fischer increment timer mode

Implement Fischer time control where a fixed increment is added
to the player's clock after each move. This is different from
Bronstein delay which only prevents time from decreasing.

- Add FISCHER_INCREMENT enum to TimerMode
- Update TimerController to handle increment after move
- Add UI toggle in NewGameDialog
- Update timer display to show increment value

Closes #87
```

**Pull Request Process:**
1. Create feature branch from `master`
2. Implement changes with clear commits
3. Test build with `./scripts/build.sh --dev`
4. Push to fork and create PR
5. Describe changes, include screenshots for UI changes
6. Address review feedback
7. Squash commits if requested before merge

## Domain Context

**Draughts/Checkers Domain Knowledge:**

**Game Variants:**
The project implements 16 official draughts variants, each with distinct rules:
- **Board sizes**: 8×8 (most variants), 10×10 (International, Swedish, Frisian), 12×12 (Canadian)
- **Flying Kings**: Some variants (International, Russian) allow kings to move multiple squares
- **Capture Rules**: Variants differ on mandatory captures, longest sequence, backwards captures
- **Promotion**: Pieces promote to kings upon reaching the opposite edge

**Key Game Concepts:**
- **Forced Captures**: If a capture is possible, it must be taken (enforced in most variants)
- **Multi-Jump**: Capturing piece continues if additional captures are available
- **King Promotion**: Pieces become kings (enhanced movement) when reaching far edge
- **PDN (Portable Draughts Notation)**: Standard notation for recording games

**AI Implementation:**
- **Minimax Algorithm**: Search game tree to find optimal moves
- **Alpha-Beta Pruning**: Optimization to reduce search space
- **Position Evaluation**: Heuristic scoring based on material, king advantage, position control
- **Difficulty Levels**: Adjust search depth (1-8 ply) and evaluation complexity

**Multiplayer Protocol:**
- **WebSocket-based**: Persistent connections for real-time gameplay
- **JSON Messages**: Structured protocol for moves, game state, events
- **Room Codes**: 6-character alphanumeric codes for private games
- **Session Persistence**: Automatic reconnection with state restoration
- **Version Checking**: Semantic versioning ensures client/server compatibility

## Important Constraints

### Technical Constraints
- **GNOME Platform**: Must follow GNOME HIG and use platform conventions
- **Flatpak Sandboxing**: Limited filesystem access, network permissions declared
- **GTK4/LibAdwaita**: UI must use adaptive widgets, support mobile/desktop layouts
- **Vala Language**: Limited ecosystem compared to mainstream languages
- **Build Requirements**: Meson + Flatpak build complexity
- **Minimum Screen Size**: 360px width for mobile support

### Design Constraints
- **Accessibility**: MUST support keyboard navigation, screen readers (ATK integration)
- **Adaptive Design**: MUST work on mobile (360px) to desktop screen sizes
- **Dark Mode**: Must respect system theme preference
- **Performance**: UI must maintain 60fps, AI moves within reasonable time (<5s)
- **Offline First**: Core game must work without network (multiplayer is optional feature)

### Business/Distribution Constraints
- **Open Source**: GPL-3.0+ license
- **Flatpak Distribution**: Primary distribution via Flathub
- **No Telemetry**: Privacy-focused, no data collection
- **Self-Hosted Multiplayer**: Server infrastructure managed separately

### Regulatory/Quality Constraints
- **GNOME Circle Eligibility**: Target GNOME Circle application standards
- **AppStream Metadata**: Complete metadata for software centers
- **OARS Content Rating**: Family-friendly, rated for all ages
- **Translations**: Support for internationalization (i18n ready)

## External Dependencies

### Build-Time Dependencies
- **Vala Compiler** >= 0.56.0 - Compiles Vala to C
- **Blueprint Compiler** - Compiles `.blp` UI files to GTK XML
- **Meson Build System** >= 1.9.0 - Build configuration
- **Flatpak Builder** - Creates sandboxed Flatpak packages

### Runtime Dependencies (Flatpak SDK)
- **GNOME Platform** 47 - Base runtime with GTK4, GLib, etc.
- **GStreamer** 1.0 - Audio playback for sound effects
- All core dependencies bundled in Flatpak runtime

### External Services
- **Multiplayer Server** (optional):
  - URL: `wss://draughts.tobagin.eu`
  - Custom Node.js WebSocket relay server
  - Docker containerized, health checks on `/health` endpoint
  - Statistics dashboard at `/stats`
  - **Protocol**: JSON-based messages over WebSocket
  - **Authentication**: None (anonymous gameplay)
  - **Availability**: Best-effort, no SLA

### Resource Files
- **Sound Effects**: OGG format audio files in `data/sounds/`
- **Icons**: SVG source → PNG export (16×16 to 512×512) in `data/icons/`
- **UI Definitions**: Blueprint `.blp` files in `data/ui/`
- **GSchema**: Settings schema in `data/*.gschema.xml.in`
- **Help Documentation**: Mallard XML in `help/`

### Third-Party Libraries
- **Gee Collections**: Generic data structures for Vala (ArrayList, HashMap)
- **LibSoup-3.0**: HTTP client and WebSocket support
- **JSON-GLib**: JSON serialization/deserialization

## Build and Development Commands

### Standard Build Commands
```bash
# Development build (uses Devel manifest, enables debug features)
./scripts/build.sh --dev

# Production build
./scripts/build.sh

# Run development version
flatpak run io.github.tobagin.Draughts.Devel

# Run production version
flatpak run io.github.tobagin.Draughts

# Run tests
meson test -C build

# Clean build
rm -rf build
```

### Project Structure Reference
```
Draughts/
├── data/                      # Application resources
│   ├── ui/                   # Blueprint UI definitions
│   │   ├── dialogs/         # Dialog windows (.blp)
│   │   └── widgets/         # Custom widgets (.blp)
│   ├── sounds/              # Sound effects (.ogg)
│   ├── icons/               # Application icons (SVG/PNG)
│   └── *.xml.in             # Metadata files (desktop, metainfo, gschema)
├── src/                      # Vala source code
│   ├── dialogs/             # Dialog implementations
│   ├── managers/            # Manager classes (SessionManager, SoundManager, etc.)
│   ├── models/              # Data models
│   │   └── draughts/       # Game-specific models (Game, Move, Piece, etc.)
│   ├── services/            # Service classes
│   │   ├── draughts/       # Game logic (RuleEngine, AI, Controller)
│   │   └── network/        # Multiplayer (NetworkClient, Session)
│   ├── utils/               # Utility classes (Logger, ErrorHandler, etc.)
│   ├── widgets/             # Custom widgets (DraughtsBoard, MoveHistory, etc.)
│   ├── Application.vala     # GApplication entry point
│   ├── Window.vala          # Main application window
│   └── Config.vala.in       # Build configuration template
├── packaging/               # Flatpak manifests (.yml)
├── scripts/                 # Build scripts (build.sh)
├── tests/                   # Test suite (unit/, contract/)
├── help/                    # Mallard help documentation
├── openspec/                # OpenSpec project documentation
├── meson.build              # Root build configuration
└── README.md                # Project documentation
```

---

**Last Updated**: 2025-10-21 (Version 2.0.2)
