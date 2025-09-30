/**
 * Move.vala
 *
 * Represents a move in a draughts game.
 * Handles simple moves, captures, multi-captures, and move validation.
 */

using Draughts;

public class Draughts.DraughtsMove : Object {
    public int piece_id { get; private set; }
    public BoardPosition from_position { get; private set; }
    public BoardPosition to_position { get; private set; }
    public int[] captured_pieces { get; private set; }
    public bool promoted { get; set; }
    public MoveType move_type { get; private set; }
    public DateTime? timestamp;

    // Alternative property names for compatibility
    public bool is_promotion { get { return promoted; } }
    public TimeSpan time_taken { get; set; default = 0; }

    /**
     * Create a simple move
     */
    public DraughtsMove(int piece_id, BoardPosition from_position, BoardPosition to_position, MoveType move_type) {
        this.piece_id = piece_id;
        this.from_position = from_position;
        this.to_position = to_position;
        this.move_type = move_type;
        this.captured_pieces = new int[0];
        this.promoted = false;
        this.timestamp = null;
    }

    /**
     * Create a move with captures
     */
    public DraughtsMove.with_captures(int piece_id, BoardPosition from_position, BoardPosition to_position, int[] captured_pieces) {
        this.piece_id = piece_id;
        this.from_position = from_position;
        this.to_position = to_position;
        this.captured_pieces = captured_pieces;
        this.promoted = false;
        this.timestamp = null;

        // Determine move type based on number of captures
        if (captured_pieces.length == 0) {
            this.move_type = MoveType.SIMPLE;
        } else if (captured_pieces.length == 1) {
            this.move_type = MoveType.CAPTURE;
        } else {
            this.move_type = MoveType.MULTI_CAPTURE;
        }
    }

    /**
     * Check if this is a simple move (no captures)
     */
    public bool is_simple_move() {
        return move_type == MoveType.SIMPLE;
    }

    /**
     * Check if this is a capture move
     */
    public bool is_capture() {
        return move_type == MoveType.CAPTURE || move_type == MoveType.MULTI_CAPTURE;
    }

    /**
     * Check if this is a multi-capture move
     */
    public bool is_multi_capture() {
        return move_type == MoveType.MULTI_CAPTURE;
    }

    /**
     * Get the distance of this move in squares
     */
    public int get_distance() {
        return from_position.distance_to(to_position);
    }

    /**
     * Check if this move is diagonal
     */
    public bool is_diagonal() {
        return from_position.is_diagonal_to(to_position);
    }

    /**
     * Check if this move is valid (basic validation)
     */
    public bool is_valid() {
        // Basic position validation
        if (!from_position.is_valid() || !to_position.is_valid()) {
            return false;
        }

        // Cannot move to same position
        if (from_position.equals(to_position)) {
            return false;
        }

        // Must be diagonal move
        if (!is_diagonal()) {
            return false;
        }

        // Destination must be on dark square
        if (!to_position.is_dark_square()) {
            return false;
        }

        return true;
    }

    /**
     * Check if this move results in promotion
     */
    public bool results_in_promotion() {
        return promoted;
    }

    /**
     * Check if this move equals another move
     */
    public bool equals(DraughtsMove other) {
        if (this.piece_id != other.piece_id) return false;
        if (!this.from_position.equals(other.from_position)) return false;
        if (!this.to_position.equals(other.to_position)) return false;
        if (this.move_type != other.move_type) return false;

        // Compare captured pieces
        if (this.captured_pieces.length != other.captured_pieces.length) return false;
        for (int i = 0; i < this.captured_pieces.length; i++) {
            if (this.captured_pieces[i] != other.captured_pieces[i]) return false;
        }

        return true;
    }

    /**
     * Get algebraic notation for this move
     */
    public string to_algebraic_notation() {
        string from_notation = from_position.get_algebraic_notation();
        string to_notation = to_position.get_algebraic_notation();

        if (is_capture()) {
            return @"$(from_notation)x$(to_notation)";
        } else {
            return @"$(from_notation)-$(to_notation)";
        }
    }

    /**
     * Get the path between from and to positions (intermediate squares)
     */
    public BoardPosition[] get_path() {
        var path = new Gee.ArrayList<BoardPosition>();

        int row_step = (to_position.row > from_position.row) ? 1 : -1;
        int col_step = (to_position.col > from_position.col) ? 1 : -1;

        int current_row = from_position.row + row_step;
        int current_col = from_position.col + col_step;

        while (current_row != to_position.row && current_col != to_position.col) {
            path.add(new BoardPosition(current_row, current_col, from_position.board_size));
            current_row += row_step;
            current_col += col_step;
        }

        return path.to_array();
    }

    /**
     * Set timestamp for this move
     */
    public void set_timestamp() {
        this.timestamp = new DateTime.now_utc();
    }

    /**
     * Get duration since timestamp was set
     */
    public TimeSpan get_duration_since_timestamp() {
        if (timestamp == null) return 0;
        return new DateTime.now_utc().difference(timestamp);
    }

    /**
     * Create undo information for this move
     */
    public MoveUndoInfo create_undo_info() {
        return new MoveUndoInfo(from_position.copy(), captured_pieces, promoted);
    }

    /**
     * Get string representation of this move
     */
    public string to_string() {
        string move_str = to_algebraic_notation();

        if (promoted) {
            move_str += "=K"; // Promotion to king
        }

        if (captured_pieces.length > 0) {
            move_str += @" (captures $(captured_pieces.length))";
        }

        return move_str;
    }

    /**
     * Create a copy of this move
     */
    public DraughtsMove clone() {
        var copy = new DraughtsMove.with_captures(piece_id, from_position.copy(), to_position.copy(), captured_pieces);
        copy.promoted = this.promoted;
        copy.move_type = this.move_type;
        if (this.timestamp != null) {
            copy.timestamp = new DateTime.from_unix_utc(this.timestamp.to_unix());
        }
        return copy;
    }

    /**
     * Check if this move is a backward move for the given piece color
     */
    public bool is_backward_move(PieceColor piece_color) {
        int row_diff = to_position.row - from_position.row;
        int forward_direction = (piece_color == PieceColor.RED) ? 1 : -1;
        return row_diff * forward_direction < 0;
    }

    /**
     * Get the intermediate position for a capture move (position of captured piece)
     */
    public BoardPosition? get_capture_position() {
        if (!is_capture() || get_distance() != 2) {
            return null;
        }

        int mid_row = (from_position.row + to_position.row) / 2;
        int mid_col = (from_position.col + to_position.col) / 2;

        return new BoardPosition(mid_row, mid_col, from_position.board_size);
    }
}

/**
 * Information needed to undo a move
 */
public class MoveUndoInfo : Object {
    public BoardPosition original_position { get; private set; }
    public int[] captured_piece_ids;
    public bool was_promotion { get; private set; }

    public MoveUndoInfo(BoardPosition original_position, int[] captured_piece_ids, bool was_promotion) {
        this.original_position = original_position;
        this.captured_piece_ids = captured_piece_ids;
        this.was_promotion = was_promotion;
    }
}