# Phase 1: Data Model Design

## Core Game Entities

### GameVariant
**Purpose**: Defines rules and characteristics for each of the 16 draughts variants
**Fields**:
- `id` (string): Unique identifier (e.g., "international", "american", "russian")
- `display_name` (string): Human-readable name ("International Draughts")
- `board_size` (int): 8, 10, or 12 squares per side
- `men_can_capture_backwards` (bool): Whether regular pieces can capture backwards
- `kings_can_fly` (bool): Whether kings can move multiple squares
- `mandatory_capture` (bool): Whether captures must be taken when available
- `capture_priority` (enum): LONGEST_SEQUENCE, MOST_PIECES, CHOICE
- `promotion_row` (int): Row where pieces promote to kings
- `starting_position` (string): FEN-like notation for initial setup

**Relationships**:
- One-to-many with Game instances
- Contains variant-specific rule configurations

**Validation Rules**:
- `board_size` must be 8, 10, or 12
- `promotion_row` must be valid for board size
- `starting_position` must match board dimensions

### GamePiece
**Purpose**: Represents individual checkers on the board
**Fields**:
- `color` (enum): RED, BLACK (or LIGHT, DARK)
- `type` (enum): MAN, KING
- `position` (Position): Current board coordinates
- `id` (int): Unique piece identifier

**Relationships**:
- Belongs to a GameState
- References Position for location

**Validation Rules**:
- Position must be on dark squares only
- King type only valid after promotion
- Color must match player assignment

### Position
**Purpose**: Represents coordinates on the game board
**Fields**:
- `row` (int): 0-based row index from bottom
- `col` (int): 0-based column index from left
- `board_size` (int): Size context for validation

**Validation Rules**:
- `row` and `col` must be within board bounds
- Must represent a dark square (row + col is odd)
- Coordinates must be accessible for piece type

### Move
**Purpose**: Represents a player action (simple move or capture sequence)
**Fields**:
- `piece_id` (int): ID of piece being moved
- `from_position` (Position): Starting position
- `to_position` (Position): Ending position
- `captured_pieces` (array<int>): IDs of pieces removed
- `promoted` (bool): Whether move resulted in promotion
- `move_type` (enum): SIMPLE, CAPTURE, MULTI_CAPTURE
- `timestamp` (DateTime): When move was made

**Relationships**:
- Belongs to a Game
- References GamePiece by ID
- Contains Position objects

**Validation Rules**:
- `from_position` must contain the specified piece
- `to_position` must be empty and reachable
- Captured pieces must be opponent pieces
- Move must be legal per variant rules

### GameState
**Purpose**: Complete snapshot of current game position
**Fields**:
- `pieces` (array<GamePiece>): All pieces currently on board
- `active_player` (enum): RED, BLACK
- `move_count` (int): Number of half-moves played
- `last_move` (Move?): Previous move for undo functionality
- `game_status` (enum): IN_PROGRESS, RED_WINS, BLACK_WINS, DRAW
- `draw_reason` (enum?): STALEMATE, REPETITION, INSUFFICIENT_MATERIAL
- `board_hash` (string): Position hash for repetition detection

**Relationships**:
- Belongs to a Game
- Contains multiple GamePiece objects
- References last Move

**Validation Rules**:
- Piece positions must not overlap
- Active player must have legal moves (unless game over)
- Move count must be non-negative
- Board hash must be computed correctly

### Game
**Purpose**: Complete game session with metadata and history
**Fields**:
- `id` (string): Unique game identifier
- `variant` (GameVariant): Rules being used
- `red_player` (Player): Red/light pieces player
- `black_player` (Player): Black/dark pieces player
- `current_state` (GameState): Current position
- `timer_red` (Timer?): Red player's time control
- `timer_black` (Timer?): Black player's time control
- `created_at` (DateTime): Game start time
- `finished_at` (DateTime?): Game end time
- `result` (enum?): RED_WINS, BLACK_WINS, DRAW, ONGOING

**Relationships**:
- References GameVariant for rules
- Contains two Player objects
- Contains GameState for current position
- Contains Timer objects for time control

**Validation Rules**:
- Variant must be one of 16 supported types
- Players must be assigned different colors
- Game cannot finish before it starts
- Timer configuration must match variant requirements

### Player
**Purpose**: Represents a game participant (human or AI)
**Fields**:
- `id` (string): Unique player identifier
- `type` (enum): HUMAN, AI
- `name` (string): Display name
- `ai_difficulty` (int?): 1-8+ for AI players
- `color` (enum): RED, BLACK
- `time_used` (Duration): Total time consumed this game

**Relationships**:
- Belongs to a Game
- May have associated Timer

**Validation Rules**:
- AI players must have valid difficulty level (1-8+)
- Human players should not have AI difficulty set
- Name must not be empty
- Color assignment must be unique per game

### Timer
**Purpose**: Manages time controls for timed games
**Fields**:
- `mode` (enum): UNTIMED, COUNTDOWN, FISCHER, DELAY
- `base_time` (Duration): Initial time allocation
- `increment` (Duration): Time added per move (Fischer)
- `delay` (Duration): Grace period before clock starts (delay)
- `time_remaining` (Duration): Current time left
- `is_running` (bool): Whether timer is currently active
- `last_started` (DateTime?): When current timing period began

**Relationships**:
- Belongs to a Player in a Game
- May reference timing configuration presets

**Validation Rules**:
- Base time must be positive for timed modes
- Increment/delay must be non-negative
- Time remaining cannot exceed reasonable bounds
- Timer state must be consistent with game state

## State Transitions

### Game Flow States
```
SETUP → IN_PROGRESS → [RED_WINS | BLACK_WINS | DRAW]
```

### Move Validation Pipeline
```
Input Move → Piece Validation → Path Validation → Capture Validation →
Rule Validation → State Update → Win/Draw Check → Next Turn
```

### AI Decision Process
```
Game State → Move Generation → Position Evaluation →
Minimax Search → Best Move Selection → Move Execution
```

## Data Persistence Strategy

### Required Persistence
- **Game Preferences**: Stored in GSettings
- **AI Configuration**: Stored in GSettings
- **Current Game State**: In-memory only
- **Last Move**: In-memory for undo functionality

### Optional Persistence
- **Game History**: Could be added for replay features
- **AI Learning Data**: Not required for initial implementation
- **Tournament Records**: Future enhancement possibility

## Performance Considerations

### Memory Usage
- Game state kept minimal for 60fps UI updates
- Piece arrays pre-allocated for board size
- Move generation uses object pooling
- Position calculations cached where beneficial

### Computational Efficiency
- Board representation optimized for move generation
- Hash tables for position lookup and repetition detection
- Bitwise operations for capture detection
- Lazy evaluation for expensive game state properties

## Validation Architecture

### Validation Layers
1. **Syntax Validation**: Data type and range checking
2. **Semantic Validation**: Business rule enforcement
3. **Cross-Entity Validation**: Relationship consistency
4. **Game Rule Validation**: Variant-specific rule checking

### Error Handling Strategy
- Validation errors return structured error objects
- Invalid moves rejected with explanatory messages
- Game state corruption triggers automatic recovery
- AI calculation errors fall back to simpler algorithms