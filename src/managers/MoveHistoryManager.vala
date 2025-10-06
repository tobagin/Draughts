/**
 * MoveHistoryManager.vala
 *
 * Manages move history for undo/redo functionality in draughts games.
 * Maintains stacks of moves and board states to enable undoing and redoing moves.
 */

using Draughts;

public class Draughts.MoveHistoryManager : Object {
    private Gee.ArrayList<MoveHistoryEntry> move_history;
    private int current_position;
    private bool modified;
    private DraughtsGameState? initial_state;

    // Signals
    public signal void history_changed();
    public signal void move_undone(DraughtsMove move);
    public signal void move_redone(DraughtsMove move);

    public MoveHistoryManager() {
        move_history = new Gee.ArrayList<MoveHistoryEntry>();
        current_position = -1;
        modified = false;
        initial_state = null;
    }

    /**
     * Add a new move to the history
     * This clears any redo history beyond the current position
     */
    public void add_move(DraughtsMove move, DraughtsGameState board_state_before, DraughtsGameState board_state_after) {
        print("MoveHistoryManager.add_move: RECEIVED piece_id=%d from (%d,%d) to (%d,%d)\n",
              move.piece_id, move.from_position.row, move.from_position.col,
              move.to_position.row, move.to_position.col);

        // Store initial state from the first move
        if (move_history.size == 0 && initial_state == null) {
            initial_state = board_state_before.clone();
        }

        // Clear any moves after current position (redo history)
        if (current_position < move_history.size - 1) {
            int start_index = current_position + 1;
            for (int i = move_history.size - 1; i >= start_index; i--) {
                move_history.remove_at(i);
            }
        }

        // Create history entry
        var entry = new MoveHistoryEntry(move, board_state_before, board_state_after);
        move_history.add(entry);
        current_position = move_history.size - 1;

        print("MoveHistoryManager.add_move: STORED at position %d, history_size=%d\n", current_position, move_history.size);
        print("MoveHistoryManager.add_move: VERIFY stored move piece_id=%d from (%d,%d) to (%d,%d)\n",
              entry.move.piece_id, entry.move.from_position.row, entry.move.from_position.col,
              entry.move.to_position.row, entry.move.to_position.col);

        modified = true;

        history_changed();
    }

    /**
     * Undo the last move
     * Returns the board state before the move and the move that was undone
     */
    public UndoRedoResult? undo_move() {
        if (!can_undo()) {
            return null;
        }

        var entry = move_history[current_position];
        current_position--;
        modified = true;

        move_undone(entry.move);
        history_changed();

        return new UndoRedoResult(entry.move, entry.board_state_before);
    }

    /**
     * Undo one full round for vs AI mode (removes 2 moves: player + AI)
     */
    public UndoRedoResult? undo_and_redo_for_ai(int rounds) {
        var logger = Logger.get_default();

        logger.info("MoveHistoryManager: undo_and_redo_for_ai - removing 2 moves");

        if (move_history.size < 2) {
            logger.warning("MoveHistoryManager: Not enough moves to undo");
            return null;
        }

        // Log history BEFORE removal
        logger.info("MoveHistoryManager: BEFORE removal - history_size=%d", move_history.size);
        for (int i = 0; i < move_history.size; i++) {
            var m = move_history[i];
            logger.info("  [%d] from (%d,%d) to (%d,%d)", i,
                       m.move.from_position.row, m.move.from_position.col,
                       m.move.to_position.row, m.move.to_position.col);
        }

        // Remove 2 moves (player + AI)
        move_history.remove_at(move_history.size - 1);
        move_history.remove_at(move_history.size - 1);

        current_position = move_history.size - 1;
        logger.info("MoveHistoryManager: AFTER removal - history_size=%d, current_position=%d",
                   move_history.size, current_position);

        // Log history AFTER removal
        for (int i = 0; i < move_history.size; i++) {
            var m = move_history[i];
            logger.info("  [%d] from (%d,%d) to (%d,%d)", i,
                       m.move.from_position.row, m.move.from_position.col,
                       m.move.to_position.row, m.move.to_position.col);
        }

        // Replay ALL moves from the start to get a clean state
        // If no moves left after removal, we're at the initial state
        DraughtsGameState final_state;

        if (move_history.size == 0) {
            print("\n\n==== UNDO: No moves left, returning to initial game state ====\n\n");
            // No moves left, return the initial game state
            if (initial_state != null) {
                final_state = initial_state.clone();
                logger.info("MoveHistoryManager: Returned to initial game state");
            } else {
                logger.error("MoveHistoryManager: No initial state stored!");
                return null;
            }
        } else {
            final_state = move_history[0].board_state_before.clone();
        }

        // Apply each move in sequence
        print("\n\n==== UNDO REPLAY STARTS - Replaying %d moves ====\n", move_history.size);
        for (int i = 0; i < move_history.size; i++) {
            var move_entry = move_history[i];
            print("  REPLAY move %d: piece_id=%d from (%d,%d) to (%d,%d)\n",
                       i, move_entry.move.piece_id,
                       move_entry.move.from_position.row, move_entry.move.from_position.col,
                       move_entry.move.to_position.row, move_entry.move.to_position.col);
            final_state = final_state.apply_move(move_entry.move);
        }
        print("==== UNDO REPLAY COMPLETE - Final active_player=%s ====\n\n", final_state.active_player.to_string());

        logger.info("MoveHistoryManager: After replay - final active_player=%s, pieces=%d",
                   final_state.active_player.to_string(), final_state.pieces.size);

        modified = true;
        history_changed();

        // If no moves left, return null move
        if (move_history.size == 0 || current_position < 0) {
            logger.warning("MoveHistoryManager: No moves left in history after undo");
            print("\n*** RETURNING INITIAL STATE: pieces=%d, active_player=%s ***\n",
                  final_state.pieces.size, final_state.active_player.to_string());
            return new UndoRedoResult(null, final_state);
        }

        print("\n*** RETURNING STATE AFTER REPLAY: pieces=%d, active_player=%s ***\n",
              final_state.pieces.size, final_state.active_player.to_string());
        return new UndoRedoResult(move_history[current_position].move, final_state);
    }

    /**
     * Undo multiple moves at once and remove them permanently from history
     * Used for undoing a full round in vs AI mode (player move + AI move)
     * Returns the board state before the moves
     */
    public UndoRedoResult? undo_multiple_moves(int moves_to_remove) {
        var logger = Logger.get_default();

        logger.info("MoveHistoryManager: undo_multiple_moves called with moves_to_remove=%d, current_position=%d, history_size=%d",
                    moves_to_remove, current_position, move_history.size);

        if (moves_to_remove <= 0 || current_position < 0) {
            logger.warning("MoveHistoryManager: Cannot remove %d moves (current_position=%d)", moves_to_remove, current_position);
            return null;
        }

        // Check we have enough moves in history to remove
        if (moves_to_remove > move_history.size) {
            logger.warning("MoveHistoryManager: Cannot remove %d moves (history_size=%d)", moves_to_remove, move_history.size);
            return null;
        }

        // Get the state we want to return to
        // We want the state BEFORE the first move we're REMOVING
        // If we're at position 3 and removing 2 moves, the first move to remove is at position 2
        // We want board_state_before of position 2
        int first_removed_position = current_position - moves_to_remove + 1;
        logger.info("MoveHistoryManager: first_removed_position=%d, current_position=%d, moves_to_remove=%d",
                   first_removed_position, current_position, moves_to_remove);

        DraughtsGameState? target_state = null;

        if (first_removed_position > 0 && first_removed_position < move_history.size) {
            // Use the state BEFORE the first move we're removing
            var entry = move_history[first_removed_position];
            target_state = entry.board_state_before;
            logger.info("MoveHistoryManager: Using board_state_before from position %d", first_removed_position);
            logger.info("  Move at position %d: from (%d,%d) to (%d,%d)",
                       first_removed_position,
                       entry.move.from_position.row, entry.move.from_position.col,
                       entry.move.to_position.row, entry.move.to_position.col);
            logger.info("  board_state_before.active_player=%s", entry.board_state_before.active_player.to_string());
            logger.info("  board_state_after.active_player=%s", entry.board_state_after.active_player.to_string());
            logger.info("  target_state.active_player=%s", target_state.active_player.to_string());
        } else if (first_removed_position == 0 && move_history.size > 0) {
            // First move to remove is at position 0, go back to game start
            target_state = move_history[0].board_state_before;
            logger.info("MoveHistoryManager: Using board_state_before from position 0 (game start), active_player=%s",
                       target_state.active_player.to_string());
        } else {
            logger.warning("MoveHistoryManager: Invalid first_removed_position=%d", first_removed_position);
            return null;
        }

        // Remove the moves permanently from history
        logger.info("MoveHistoryManager: Removing %d moves from history", moves_to_remove);
        for (int i = 0; i < moves_to_remove; i++) {
            if (move_history.size > 0) {
                move_history.remove_at(move_history.size - 1);
            }
        }

        // Recalculate current_position based on new history size
        // current_position should point to the last move in history, or -1 if empty
        current_position = move_history.size - 1;
        logger.info("MoveHistoryManager: After undo - current_position=%d, new history_size=%d", current_position, move_history.size);
        modified = true;
        history_changed();

        // Return a dummy move with the target state
        var dummy_move = new DraughtsMove(0, new BoardPosition(0, 0, 8), new BoardPosition(0, 0, 8), MoveType.SIMPLE);
        return new UndoRedoResult(dummy_move, target_state);
    }

    /**
     * Redo the next move
     * Returns the board state after the move and the move that was redone
     */
    public UndoRedoResult? redo_move() {
        if (!can_redo()) {
            return null;
        }

        current_position++;
        var entry = move_history[current_position];
        modified = true;

        move_redone(entry.move);
        history_changed();

        return new UndoRedoResult(entry.move, entry.board_state_after);
    }

    /**
     * Check if undo is possible
     */
    public bool can_undo() {
        return current_position >= 0;
    }

    /**
     * Check if redo is possible
     */
    public bool can_redo() {
        return current_position < move_history.size - 1;
    }

    /**
     * Get the number of moves that can be undone
     */
    public int get_undo_count() {
        return current_position + 1;
    }

    /**
     * Get the number of moves that can be redone
     */
    public int get_redo_count() {
        return move_history.size - current_position - 1;
    }

    /**
     * Get the current move (last move made)
     */
    public DraughtsMove? get_current_move() {
        if (current_position >= 0 && current_position < move_history.size) {
            return move_history[current_position].move;
        }
        return null;
    }

    /**
     * Get the next move (for redo)
     */
    public DraughtsMove? get_next_move() {
        if (current_position + 1 < move_history.size) {
            return move_history[current_position + 1].move;
        }
        return null;
    }

    /**
     * Get the board state at a specific position in history (for viewing, not modifying)
     * Position 0 = game start, position N = after N moves
     * Returns null if position is invalid
     */
    public DraughtsGameState? get_state_at_position(int position) {
        // Position -1 means game start (before any moves)
        if (position == -1) {
            if (move_history.size > 0) {
                return move_history[0].board_state_before;
            }
            return null;
        }

        // Position 0 to N means after that move
        if (position >= 0 && position < move_history.size) {
            return move_history[position].board_state_after;
        }

        return null;
    }

    /**
     * Get the current position in history
     */
    public int get_current_position() {
        return current_position;
    }

    /**
     * Check if we're at the latest position (not viewing history)
     */
    public bool is_at_latest_position() {
        return current_position == move_history.size - 1;
    }

    /**
     * Clear all history
     */
    public void clear() {
        move_history.clear();
        current_position = -1;
        modified = true;
        history_changed();
    }

    /**
     * Get all moves in history up to current position
     */
    public Gee.List<DraughtsMove> get_moves() {
        var moves = new Gee.ArrayList<DraughtsMove>();
        for (int i = 0; i <= current_position; i++) {
            if (i < move_history.size) {
                moves.add(move_history[i].move);
            }
        }
        return moves;
    }

    /**
     * Get the total number of moves in history
     */
    public int get_total_moves() {
        return current_position + 1;
    }

    /**
     * Get the full size of the history (including redo moves)
     */
    public int get_history_size() {
        return move_history.size;
    }

    /**
     * Check if history has been modified since last save
     */
    public bool has_been_modified() {
        return modified;
    }

    /**
     * Mark history as saved
     */
    public void mark_as_saved() {
        modified = false;
    }

    /**
     * Get move at specific position
     */
    public DraughtsMove? get_move_at_position(int position) {
        if (position >= 0 && position < move_history.size) {
            return move_history[position].move;
        }
        return null;
    }

    /**
     * Get board state at specific position
     */
    public DraughtsGameState? get_board_state_at_position(int position) {
        if (position >= 0 && position < move_history.size) {
            return move_history[position].board_state_after;
        }
        return null;
    }

    /**
     * Jump to a specific position in history
     */
    public DraughtsGameState? jump_to_position(int position) {
        if (position < -1 || position >= move_history.size) {
            return null;
        }

        current_position = position;
        modified = true;
        history_changed();

        if (position == -1) {
            // Return to initial state (before any moves)
            return null;
        }

        return move_history[position].board_state_after;
    }

    /**
     * Get the board state at the current position
     */
    public DraughtsGameState? get_current_board_state() {
        if (current_position >= 0 && current_position < move_history.size) {
            return move_history[current_position].board_state_after;
        }
        return null;
    }
}

/**
 * Entry in the move history containing move and board states
 */
public class MoveHistoryEntry : Object {
    public DraughtsMove move { get; private set; }
    public DraughtsGameState board_state_before { get; private set; }
    public DraughtsGameState board_state_after { get; private set; }

    public MoveHistoryEntry(DraughtsMove move, DraughtsGameState board_state_before, DraughtsGameState board_state_after) {
        this.move = move;
        this.board_state_before = board_state_before;
        this.board_state_after = board_state_after;
    }
}

/**
 * Result of undo/redo operation
 */
public class UndoRedoResult : Object {
    public DraughtsMove? move { get; private set; }
    public DraughtsGameState board_state { get; private set; }

    public UndoRedoResult(DraughtsMove? move, DraughtsGameState board_state) {
        this.move = move;
        this.board_state = board_state;
    }
}