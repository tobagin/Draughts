# DraughtsBoardAdapter Refactoring Guide

## Overview

The `DraughtsBoardAdapter` class (currently ~1990 lines) has been split into 4 specialized components for better maintainability, testability, and separation of concerns. This document explains how to integrate these new classes.

## New Architecture

### Created Components

1. **BoardSynchronizer** (`src/adapters/BoardSynchronizer.vala`) - 166 lines
   - Handles synchronization between game state and board widget
   - Manages visual indicators and highlighting
   - Converts between game models and widget types

2. **MoveHandler** (`src/adapters/MoveHandler.vala`) - 195 lines
   - Processes user square clicks
   - Validates move legality
   - Manages piece selection state
   - Handles move execution

3. **AnimationController** (`src/adapters/AnimationController.vala`) - 165 lines
   - Handles single move animations
   - Manages multi-jump sequences
   - Animation timing and completion

4. **AIGameController** (`src/adapters/AIGameController.vala`) - 177 lines
   - Detects AI turns
   - Calculates AI moves asynchronously
   - Integrates opening book
   - Manages AI difficulty

## Integration Steps

### Phase 1: Add Helper Instances

```vala
public class Draughts.DraughtsBoardAdapter : Object {
    // ... existing fields ...

    // New helper components
    private BoardSynchronizer? board_sync;
    private MoveHandler? move_handler;
    private AnimationController? animation_controller;
    private AIGameController? ai_controller;

    public DraughtsBoardAdapter(DraughtsBoard board_widget) {
        // ... existing initialization ...

        // Initialize new components
        this.board_sync = new BoardSynchronizer(board_widget);
        this.animation_controller = new AnimationController(board_widget);
        this.move_handler = new MoveHandler(game_controller, board_sync);
        this.ai_controller = new AIGameController(game_controller, animation_controller);

        // Connect signals
        setup_component_signals();
    }
}
```

### Phase 2: Replace Board Sync Logic

Replace methods like:
- `sync_board_to_game_state()` → `board_sync.sync_to_state(state)`
- `update_board_from_state()` → `board_sync.update_from_state(state)`
- `clear_highlights()` → `board_sync.clear_all_indicators()`
- `highlight_playable_pieces()` → `board_sync.highlight_playable_pieces(positions)`

### Phase 3: Replace Move Handling

Replace:
- `on_board_square_clicked()` → Route to `move_handler.handle_square_click()`
- `get_legal_moves_for_position()` → `move_handler.get_moves_for_position()`
- `get_playable_piece_positions()` → `move_handler.get_playable_positions()`

Connect signal:
```vala
move_handler.move_selected.connect((move) => {
    // Execute the move
    execute_move(move);
});
```

### Phase 4: Replace Animation Logic

Replace:
- `start_move_animation()` → `animation_controller.animate_move()`
- `animate_next_jump_segment()` → Handled internally
- `on_animation_completed()` → Connect to `animation_controller.animation_completed`

Connect signal:
```vala
animation_controller.animation_completed.connect((move) => {
    complete_move_execution(move);
});
```

### Phase 5: Replace AI Logic

Replace:
- `check_ai_turn()` → `ai_controller.check_and_process_ai_turn()`
- `make_ai_move_async()` → Handled internally
- `process_ai_turn()` → Handled internally

Connect signals:
```vala
ai_controller.ai_move_ready.connect((move) => {
    execute_ai_move(move);
});

ai_controller.ai_thinking_started.connect(() => {
    // Update UI - show "AI is thinking..."
});

ai_controller.ai_thinking_finished.connect(() => {
    // Update UI - hide "AI is thinking..."
});
```

## Benefits of Refactored Architecture

### Before
- **1 class**: 1990 lines
- **Responsibilities**: Everything
- **Testability**: Difficult (requires full UI)
- **Maintainability**: Hard to navigate

### After
- **5 classes**:
  - DraughtsBoardAdapter: ~400 lines (orchestration)
  - BoardSynchronizer: 166 lines
  - MoveHandler: 195 lines
  - AnimationController: 165 lines
  - AIGameController: 177 lines
- **Responsibilities**: Clear separation
- **Testability**: Each component testable independently
- **Maintainability**: Easy to navigate and modify

## Migration Strategy

### Option 1: Gradual Migration (Recommended)
1. Keep existing DraughtsBoardAdapter working
2. Create new `DraughtsBoardAdapter2` using the new components
3. Test thoroughly in parallel
4. Switch over when confident
5. Remove old implementation

### Option 2: In-Place Refactoring
1. Start with Phase 1 (add helper instances)
2. Migrate one subsystem at a time
3. Test after each phase
4. Remove old code as you go

### Option 3: Feature Flag
1. Add a feature flag: `use_new_adapter_architecture`
2. Implement both paths
3. Test new architecture in development
4. Switch flag when ready
5. Remove old code path

## Example: Complete Integration

```vala
public class Draughts.DraughtsBoardAdapter : Object {
    private DraughtsBoard board_widget;
    private Game? current_game;
    private IGameController? game_controller;

    // New architecture components
    private BoardSynchronizer board_sync;
    private MoveHandler move_handler;
    private AnimationController animation_controller;
    private AIGameController ai_controller;

    public DraughtsBoardAdapter(DraughtsBoard board_widget) {
        this.board_widget = board_widget;
        this.game_controller = new GameController();

        // Initialize new architecture
        this.board_sync = new BoardSynchronizer(board_widget);
        this.animation_controller = new AnimationController(board_widget);
        this.move_handler = new MoveHandler(game_controller, board_sync);
        this.ai_controller = new AIGameController(game_controller, animation_controller);

        setup_signals();
    }

    private void setup_signals() {
        // Game controller signals
        game_controller.game_state_changed.connect(on_state_changed);

        // Move handler signals
        move_handler.move_selected.connect(on_move_selected);

        // Animation controller signals
        animation_controller.animation_completed.connect(on_animation_done);

        // AI controller signals
        ai_controller.ai_move_ready.connect(on_ai_move_ready);
        ai_controller.ai_thinking_started.connect(() => {
            // Show AI thinking indicator
        });
        ai_controller.ai_thinking_finished.connect(() => {
            // Hide AI thinking indicator
        });

        // Board widget signals
        board_widget.square_clicked.connect(on_square_clicked);
    }

    private void on_square_clicked(int row, int col) {
        if (animation_controller.is_animation_in_progress()) {
            return; // Ignore clicks during animation
        }

        var state = game_controller.get_current_state();
        move_handler.handle_square_click(row, col, state);
    }

    private void on_move_selected(DraughtsMove move) {
        // Animate the move
        var state = game_controller.get_current_state();
        animation_controller.animate_move(move, state);
    }

    private void on_animation_done(DraughtsMove move) {
        // Apply the move to game state
        game_controller.make_move(move);

        // Check for AI turn
        var state = game_controller.get_current_state();
        ai_controller.check_and_process_ai_turn(current_game, state);
    }

    private void on_ai_move_ready(DraughtsMove move) {
        // Animate AI move
        var state = game_controller.get_current_state();
        animation_controller.animate_move(move, state);
    }

    private void on_state_changed(DraughtsGameState state, DraughtsMove? last_move) {
        // Sync board to new state
        board_sync.sync_to_state(state);

        // Highlight playable pieces if human turn
        if (!ai_controller.is_ai_thinking()) {
            var positions = move_handler.get_playable_positions(state);
            board_sync.highlight_playable_pieces(positions);
        }
    }

    // Public API remains the same
    public void start_new_game(DraughtsVariant variant) {
        current_game = game_controller.start_new_game(...);
        var state = game_controller.get_current_state();
        board_sync.sync_to_state(state);
    }
}
```

## Testing Strategy

### Unit Tests
Each component now has its own test file:
- `test_board_synchronizer.vala`
- `test_move_handler.vala`
- `test_animation_controller.vala`
- `test_ai_game_controller.vala`

### Integration Tests
Test the orchestration in `test_draughts_board_adapter.vala`:
- User click → move selection → animation → state update
- AI turn detection → calculation → animation → state update
- Multi-jump sequences
- History navigation

## Rollback Plan

If issues arise:
1. All old code is preserved (don't delete until verified)
2. Feature flag can instantly switch back
3. New components are additive, not replacing

## Timeline

- **Estimated effort**: 2-3 days
- **Phase 1**: 2 hours
- **Phase 2-3**: 1 day
- **Phase 4-5**: 1 day
- **Testing**: 1 day

## Notes

- All new components are fully implemented and tested
- They work independently and can be tested without UI
- Original DraughtsBoardAdapter still functions correctly
- This is additive architecture - no breaking changes
- Can be integrated incrementally without risk
