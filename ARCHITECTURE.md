# Draughts Architecture Documentation

This document describes the architecture, design patterns, and key components of the Draughts application.

## Table of Contents

- [Overview](#overview)
- [Technology Stack](#technology-stack)
- [Architecture Layers](#architecture-layers)
- [Core Components](#core-components)
- [Data Flow](#data-flow)
- [Design Patterns](#design-patterns)
- [Key Systems](#key-systems)

## Overview

Draughts is a comprehensive checkers/draughts game built using modern GNOME technologies. The application follows a layered architecture with clear separation of concerns between UI, business logic, and data management.

### Design Principles

1. **Separation of Concerns**: UI, game logic, and data are clearly separated
2. **Single Responsibility**: Each class has a focused, well-defined purpose
3. **Dependency Injection**: Components receive dependencies rather than creating them
4. **Observer Pattern**: UI updates reactively to game state changes
5. **Immutability**: Game states are immutable for reliable undo/redo

## Technology Stack

### Core Technologies

- **Language**: Vala (compiles to C)
- **UI Framework**: GTK4 + LibAdwaita
- **UI Definition**: Blueprint (declarative syntax)
- **Build System**: Meson + Ninja
- **Audio**: GStreamer 1.0
- **Packaging**: Flatpak
- **Version Control**: Git

### Dependencies

```
gtk4 >= 4.20
libadwaita-1 >= 1.8
glib-2.0 >= 2.86
gio-2.0 >= 2.86
gee-0.8 >= 0.8
json-glib-1.0
gstreamer-1.0
```

## Architecture Layers

```
┌─────────────────────────────────────────────┐
│           Presentation Layer                │
│  (GTK4 Widgets, LibAdwaita, Blueprint)     │
│  • Window, Dialogs, Custom Widgets         │
└─────────────────────────────────────────────┘
                    ↓↑
┌─────────────────────────────────────────────┐
│          Application Layer                  │
│  (Managers, Controllers, Adapters)          │
│  • SettingsManager, SoundManager            │
│  • GameController, TimerController          │
└─────────────────────────────────────────────┘
                    ↓↑
┌─────────────────────────────────────────────┐
│           Business Logic Layer              │
│  (Models, Services, Rule Engines)           │
│  • Game, GameState, GameVariant             │
│  • UnifiedRuleEngine, MoveGenerator         │
│  • MinimaxAI, PositionEvaluator            │
└─────────────────────────────────────────────┘
                    ↓↑
┌─────────────────────────────────────────────┐
│            Data Layer                       │
│  (Persistence, Resources)                   │
│  • GSettings (configuration)                │
│  • GResources (embedded assets)             │
│  • GameHistory (JSON persistence)           │
└─────────────────────────────────────────────┘
```

## Core Components

### Application Entry Point

**Application.vala**
- Main application class extending `Adw.Application`
- Manages application lifecycle
- Registers actions and keyboard shortcuts
- Handles file opening (PDN files)

**Window.vala**
- Main window extending `Adw.ApplicationWindow`
- Coordinates UI components
- Manages game session
- Handles menu actions and dialogs

### Models (src/models/draughts/)

**Game.vala**
- Central game state machine
- Manages current game session
- Coordinates between components
- Emits signals for state changes

**GameVariant.vala**
- Encapsulates variant-specific rules
- Configures board size, capture rules, king movement
- Factory for creating rule engines
- Supports 16 international variants

**DraughtsGameState.vala**
- Immutable snapshot of game state
- Contains piece positions, turn, captured pieces
- Used for undo/redo and game history

**GamePiece.vala**
- Represents a single piece
- Properties: color, type (man/king), position, ID

**DraughtsMove.vala**
- Represents a single move
- Properties: from/to positions, capture flag, promotion flag
- Validation and serialization

### Services (src/services/draughts/)

**UnifiedRuleEngine.vala**
- Implements `IRuleEngine` interface
- Validates moves according to variant rules
- Generates legal moves
- Checks win/draw conditions
- Handles multi-capture sequences

**MoveGenerator.vala**
- Generates all legal moves for a position
- Considers captures, regular moves, king movement
- Enforces mandatory capture rules

**MinimaxAI.vala**
- Implements `IAIPlayer` interface
- Minimax algorithm with alpha-beta pruning
- Configurable search depth
- Uses `PositionEvaluator` for position scoring

**PositionEvaluator.vala**
- Evaluates board positions
- Considers: material, king value, center control, mobility
- Adjusts evaluation for game phase

**GameController.vala**
- Implements `IGameController` interface
- Orchestrates game flow
- Handles player turns (human/AI)
- Manages move execution and validation

### Managers (src/managers/)

**SettingsManager.vala**
- Singleton wrapping GSettings
- Type-safe access to preferences
- Manages theme, variant, AI difficulty, etc.
- Emits change signals

**SoundManager.vala**
- Singleton managing audio playback
- GStreamer-based sound engine
- Sound effect cache
- Respects user preferences

**GameHistoryManager.vala**
- Persists game history to JSON
- Manages game records
- Provides query interface

**MoveHistoryManager.vala**
- Tracks move sequence
- Enables undo/redo
- Manages game state snapshots

### Widgets (src/widgets/)

**DraughtsBoard.vala**
- Custom GTK DrawingArea widget
- Renders game board
- Handles mouse/touch input
- Displays piece positions

**DraughtsBoardAdapter.vala**
- Adapts game model to board widget
- Handles user interactions
- Manages piece selection
- Coordinates with GameController

**BoardRenderer.vala**
- Cairo-based rendering engine
- Draws board squares, pieces, highlights
- Handles themes and piece styles
- Animation system

**GameControls.vala**
- Control panel widget
- Undo/redo buttons
- Turn indicator
- Status display

**MoveHistory.vala**
- Displays move list
- Scrollable list of notation
- Click to jump to position

**TimerDisplay.vala**
- Shows remaining time
- Supports multiple timer modes
- Visual warnings

### Dialogs (src/dialogs/)

**NewGameDialog.vala**
- Start new game configuration
- Variant selection
- Player type selection
- AI difficulty

**GamePreferences.vala**
- In-game settings
- Quick access to common options
- Variant switcher

**Preferences.vala**
- Full preferences dialog
- Board themes, piece styles
- Sound settings
- Behavior options

**HelpDialog.vala**
- In-app help system (F1)
- Getting Started, Variants, Keyboard shortcuts
- Tabbed interface with ViewStack

**WelcomeDialog.vala**
- First-run welcome screen
- Feature highlights
- Quick start guide

**GameEndDialog.vala**
- Game over notification
- Statistics display
- Rematch/new game options

**VariantSelector.vala**
- Browse and select variants
- Detailed variant information
- Preview features

## Data Flow

### Move Execution Flow

```
User Click
    ↓
DraughtsBoard (mouse event)
    ↓
DraughtsBoardAdapter (interaction logic)
    ↓
GameController.make_move()
    ↓
UnifiedRuleEngine.is_move_legal()
    ↓
Game.apply_move() → new GameState
    ↓
Signal: state_changed
    ↓
┌──────────────────────────┐
│ DraughtsBoardAdapter     │ → Update board display
│ MoveHistory              │ → Update move list
│ GameControls             │ → Update turn indicator
│ SoundManager             │ → Play move sound
└──────────────────────────┘
```

### AI Move Flow

```
GameController.process_ai_turn()
    ↓
MinimaxAI.get_best_move()
    ↓
Minimax search with alpha-beta pruning
    ↓
For each position:
  - MoveGenerator.generate_legal_moves()
  - PositionEvaluator.evaluate_position()
    ↓
Return best move
    ↓
GameController.make_move()
    ↓
[Same as User Move Flow]
```

## Design Patterns

### Singleton Pattern

Used for managers that should have single instance:
- `SettingsManager`
- `SoundManager`
- `Logger`

```vala
public class SettingsManager : Object {
    private static SettingsManager? instance;

    public static SettingsManager get_instance() {
        if (instance == null) {
            instance = new SettingsManager();
        }
        return instance;
    }

    private SettingsManager() { }
}
```

### Strategy Pattern

Rule engines implement `IRuleEngine` interface:
```vala
public interface IRuleEngine : Object {
    public abstract bool is_move_legal(GameState state, Move move);
    public abstract ArrayList<Move> generate_legal_moves(GameState state);
    public abstract WinCondition check_win_condition(GameState state);
}
```

Different variants use same interface with variant-specific logic.

### Observer Pattern

Components observe game state changes via signals:
```vala
public class Game : Object {
    public signal void state_changed(GameState new_state);
    public signal void game_over(WinCondition result);

    private void apply_move(Move move) {
        current_state = calculate_new_state(move);
        state_changed(current_state);
    }
}
```

### Factory Pattern

GameVariant creates appropriate rule engines:
```vala
public IRuleEngine create_rule_engine() {
    return new UnifiedRuleEngine(this);
}
```

### Adapter Pattern

`DraughtsBoardAdapter` adapts game model to UI widget:
- Translates UI events to game actions
- Converts game state to visual representation
- Handles coordinate transformations

### Command Pattern

Move history uses command pattern for undo/redo:
- Each move is a command
- Commands stored in history stack
- Undo reverses to previous state
- Redo reapplies command

## Key Systems

### Game State Management

**Immutable States**
- GameState is immutable
- New state created for each move
- Enables reliable undo/redo
- Simplifies concurrency

**State Transitions**
```
Initial State
    ↓
Apply Move → New State
    ↓
Store in History
    ↓
Check Win Condition
    ↓
Update UI
```

### AI System

**Minimax with Alpha-Beta Pruning**
```
function minimax(state, depth, alpha, beta, maximizing):
    if depth == 0 or game_over:
        return evaluate_position(state)

    if maximizing:
        for each move in legal_moves:
            score = minimax(new_state, depth-1, alpha, beta, false)
            alpha = max(alpha, score)
            if beta <= alpha:
                break  # Beta cutoff
        return alpha
    else:
        for each move in legal_moves:
            score = minimax(new_state, depth-1, alpha, beta, true)
            beta = min(beta, score)
            if beta <= alpha:
                break  # Alpha cutoff
        return beta
```

**Position Evaluation**
```
score = (material_score * 100) +
        (king_bonus * 50) +
        (center_control * 10) +
        (mobility * 5)
```

### Rendering System

**Cairo-based Rendering**
1. Clear canvas
2. Draw board squares
3. Draw coordinate labels
4. Draw pieces
5. Draw highlights (valid moves, selection)
6. Draw animations (if active)

**Animation System**
- 60 FPS update loop
- Cubic easing function
- Interpolation between positions
- Smooth piece movement

### Sound System

**GStreamer Pipeline**
```
playbin element
    ↓
Set URI to sound resource
    ↓
Set state to PLAYING
    ↓
Automatic cleanup on completion
```

**Sound Events**
- Move (regular/capture/promotion)
- Game start/end
- Timer warning
- Illegal move
- Undo/redo

### Settings Persistence

**GSettings Schema**
- Organized hierarchically
- Type-safe access
- Automatic persistence
- Change notifications

```xml
<schema id="io.github.tobagin.Draughts">
  <key name="board-theme" type="s">
    <default>"classic"</default>
  </key>
  <key name="ai-difficulty" type="i">
    <default>5</default>
  </key>
</schema>
```

## File Format Support

### PDN (Portable Draughts Notation)

**Export Format**
```
[Event "Casual Game"]
[Site "Draughts 1.0"]
[Date "2025.09.30"]
[White "Player 1"]
[Black "Player 2"]
[Result "2-0"]
[GameType "21"]

1. 11-15 23-19
2. 8-11 22-17
*
```

**MIME Type Registration**
- Type: `application/x-pdn`
- Extensions: `.pdn`, `.PDN`
- Icon: Application icon
- Opens in replay dialog

## Performance Considerations

### Optimization Strategies

1. **AI Search**
   - Alpha-beta pruning reduces search space
   - Move ordering improves cutoff rate
   - Depth limited by difficulty level

2. **Rendering**
   - Double buffering for smooth display
   - Only redraw when state changes
   - Offscreen surface caching

3. **Memory**
   - Object pooling for moves
   - Efficient data structures (ArrayList, HashMap)
   - Minimal allocations in hot paths

4. **State Management**
   - Immutable states prevent bugs
   - Copy-on-write for efficiency
   - Lazy evaluation where possible

## Testing Strategy

### Unit Tests
- Model validation
- Rule engine correctness
- AI move generation
- Utility functions

### Integration Tests
- Game controller flow
- UI interaction sequences
- Settings persistence
- File I/O operations

### Manual Testing
- All 16 variants playable
- AI at each difficulty level
- Keyboard navigation
- Accessibility features
- Theme switching

## Future Architecture Considerations

### Extensibility Points

1. **New Variants**
   - Add enum to DraughtsVariant
   - Configure rules in GameVariant
   - Add to variant selector

2. **New AI Algorithms**
   - Implement IAIPlayer interface
   - Register in AIDifficultyManager
   - Add to preferences

3. **Network Play**
   - Extract IGameController interface
   - Implement NetworkGameController
   - Add matchmaking service
   - Serialize game state

4. **PDN Import**
   - Implement PDN parser
   - Create GameHistoryRecord from PDN
   - Load into replay dialog

5. **Opening Books**
   - Create opening database
   - Query before AI search
   - Fallback to minimax

## Build System

### Meson Configuration

```python
project('draughts', 'vala', 'c',
  version : '1.0.0',
  license : 'GPL-3.0+',
  meson_version : '>= 1.9.0'
)
```

### Build Profiles

- **development**: Debug symbols, verbose logging, dev app ID
- **default**: Optimized, release app ID

### Flatpak Integration

- Self-contained runtime
- Sandboxed execution
- Permission system
- Automatic updates

## Conclusion

This architecture provides:
- **Maintainability**: Clear structure, separation of concerns
- **Extensibility**: Interfaces, patterns enable additions
- **Performance**: Optimized algorithms, efficient rendering
- **Reliability**: Immutable state, comprehensive testing
- **User Experience**: Smooth animations, responsive UI

For implementation details, see the source code and inline documentation.
