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

    // Signals
    public signal void history_changed();
    public signal void move_undone(DraughtsMove move);
    public signal void move_redone(DraughtsMove move);

    public MoveHistoryManager() {
        move_history = new Gee.ArrayList<MoveHistoryEntry>();
        current_position = -1;
        modified = false;
    }

    /**
     * Add a new move to the history
     * This clears any redo history beyond the current position
     */
    public void add_move(DraughtsMove move, DraughtsGameState board_state_before, DraughtsGameState board_state_after) {
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
    public DraughtsMove move { get; private set; }
    public DraughtsGameState board_state { get; private set; }

    public UndoRedoResult(DraughtsMove move, DraughtsGameState board_state) {
        this.move = move;
        this.board_state = board_state;
    }
}