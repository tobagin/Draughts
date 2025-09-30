/**
 * GamePiece.vala
 *
 * Represents an individual piece in a draughts game.
 * Handles piece properties, movement validation, and promotion logic.
 */

using Draughts;

public class Draughts.GamePiece : Object {
    public PieceColor color { get; private set; }
    public DraughtsPieceType piece_type { get; private set; }
    public BoardPosition position { get; set; }
    public int id { get; private set; }
    public bool is_promoted { get; private set; }

    public GamePiece(PieceColor color, DraughtsPieceType type, BoardPosition position, int id) {
        this.color = color;
        this.piece_type = type;
        this.position = position;
        this.id = id;
        this.is_promoted = (piece_type == DraughtsPieceType.KING);
    }

    /**
     * Check if this piece is valid (on a dark square and valid position)
     */
    public bool is_valid() {
        return position.is_valid() && position.is_dark_square();
    }

    /**
     * Promote this piece to a king
     */
    public void promote_to_king() {
        if (piece_type == DraughtsPieceType.MAN) {
            piece_type = DraughtsPieceType.KING;
            is_promoted = true;
        }
    }

    /**
     * Check if this piece can move to the specified position
     */
    public bool can_move_to(BoardPosition destination) {
        if (!destination.is_valid() || !destination.is_dark_square()) {
            return false;
        }

        if (!position.is_diagonal_to(destination)) {
            return false;
        }

        int distance = position.distance_to(destination);

        // Simple move (1 square)
        if (distance == 1) {
            return can_move_in_direction(destination);
        }

        // For longer distances, only kings can make such moves (flying kings)
        // or it could be a capture move (distance 2 for regular capture)
        return piece_type == DraughtsPieceType.KING || distance == 2;
    }

    /**
     * Check if this piece can capture to the specified position
     */
    public bool can_capture_to(BoardPosition destination) {
        if (!destination.is_valid() || !destination.is_dark_square()) {
            return false;
        }

        if (!position.is_diagonal_to(destination)) {
            return false;
        }

        int distance = position.distance_to(destination);

        // Regular capture is distance 2 (jump over one piece)
        if (distance == 2) {
            return can_move_in_direction(destination);
        }

        // Kings might be able to make longer captures (flying kings)
        return piece_type == DraughtsPieceType.KING && distance > 2;
    }

    /**
     * Get the forward direction for this piece color
     */
    public int get_forward_direction() {
        // Red pieces move toward higher row numbers (up the board)
        // Black pieces move toward lower row numbers (down the board)
        return (color == PieceColor.RED) ? 1 : -1;
    }

    /**
     * Check if this piece can move in the direction of the destination
     */
    private bool can_move_in_direction(BoardPosition destination) {
        int row_diff = destination.row - position.row;
        int forward_dir = get_forward_direction();

        // Kings can move in any direction
        if (piece_type == DraughtsPieceType.KING) {
            return true;
        }

        // Men can only move forward (unless capturing backward is allowed by variant)
        return row_diff * forward_dir > 0;
    }

    /**
     * Check if this piece equals another piece
     */
    public bool equals(GamePiece other) {
        return this.id == other.id &&
               this.color == other.color &&
               this.piece_type == other.piece_type &&
               this.position.equals(other.position);
    }

    /**
     * Create a copy of this piece
     */
    public GamePiece clone() {
        var copy = new GamePiece(color, piece_type, position.copy(), id);
        copy.is_promoted = this.is_promoted;
        return copy;
    }

    /**
     * Move this piece to a new position
     */
    public void move_to(BoardPosition new_position) {
        this.position = new_position;
    }

    /**
     * Get string representation of this piece
     */
    public string to_string() {
        string color_str = (color == PieceColor.RED) ? "Red" : "Black";
        string type_str = (piece_type == DraughtsPieceType.KING) ? "King" : "Man";
        return @"$color_str $type_str at $(position.to_string())";
    }

    /**
     * Get unicode symbol for this piece (for display)
     */
    public string get_unicode_symbol() {
        if (color == PieceColor.RED) {
            return (piece_type == DraughtsPieceType.KING) ? "♛" : "●";
        } else {
            return (piece_type == DraughtsPieceType.KING) ? "♕" : "○";
        }
    }

    /**
     * Check if this piece is on the promotion row for its color
     */
    public bool is_on_promotion_row() {
        if (color == PieceColor.RED) {
            return position.row == position.board_size - 1;
        } else {
            return position.row == 0;
        }
    }

    /**
     * Get all possible directions this piece can move
     */
    public Direction?[] get_movement_directions() {
        var directions = new Gee.ArrayList<Direction?>();

        if (piece_type == DraughtsPieceType.KING) {
            // Kings can move in all four diagonal directions
            directions.add(Direction(1, 1));   // Northeast
            directions.add(Direction(1, -1));  // Northwest
            directions.add(Direction(-1, 1));  // Southeast
            directions.add(Direction(-1, -1)); // Southwest
        } else {
            // Men can only move forward diagonally
            int forward_dir = get_forward_direction();
            directions.add(Direction(forward_dir, 1));  // Forward-right
            directions.add(Direction(forward_dir, -1)); // Forward-left
        }

        return directions.to_array();
    }

    /**
     * Check if this piece can capture backward (variant-specific)
     */
    public bool can_capture_backward() {
        // Kings can always capture backward
        // Men capturing backward depends on the variant rules
        return piece_type == DraughtsPieceType.KING;
    }
}

/**
 * Helper struct for movement directions
 */
public struct Direction {
    public int row;
    public int col;

    public Direction(int row, int col) {
        this.row = row;
        this.col = col;
    }
}