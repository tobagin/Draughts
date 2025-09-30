/**
 * Position.vala
 *
 * Represents a coordinate position on a draughts board.
 * Handles validation, dark square detection, and position operations.
 */

using Draughts;

public class Draughts.BoardPosition : Object {
    public int row { get; private set; }
    public int col { get; private set; }
    public int board_size { get; private set; }

    public BoardPosition(int row, int col, int board_size) {
        this.row = row;
        this.col = col;
        this.board_size = board_size;
    }

    /**
     * Check if this position is valid on the board
     */
    public bool is_valid() {
        return row >= 0 && row < board_size &&
               col >= 0 && col < board_size;
    }

    /**
     * Check if this position is on a dark square
     * In draughts, pieces can only be placed on dark squares
     */
    public bool is_dark_square() {
        return (row + col) % 2 == 1;
    }

    /**
     * Check if this position equals another position
     */
    public bool equals(BoardPosition other) {
        return this.row == other.row &&
               this.col == other.col &&
               this.board_size == other.board_size;
    }

    /**
     * Calculate distance to another position (diagonal squares)
     */
    public int distance_to(BoardPosition other) {
        return int.max((this.row - other.row).abs(), (this.col - other.col).abs());
    }

    /**
     * Check if this position is diagonal to another position
     */
    public bool is_diagonal_to(BoardPosition other) {
        int row_diff = (this.row - other.row).abs();
        int col_diff = (this.col - other.col).abs();
        return row_diff == col_diff && row_diff > 0;
    }

    /**
     * Get a string representation of this position
     */
    public string to_string() {
        return "BoardPosition(%d,%d)".printf(row, col);
    }

    /**
     * Create a copy of this position
     */
    public BoardPosition copy() {
        return new BoardPosition(row, col, board_size);
    }

    /**
     * Get position shifted by specified row and column offsets
     */
    public BoardPosition get_shifted(int row_offset, int col_offset) {
        return new BoardPosition(row + row_offset, col + col_offset, board_size);
    }

    /**
     * Check if position is on the edge of the board
     */
    public bool is_edge_position() {
        return row == 0 || row == board_size - 1 ||
               col == 0 || col == board_size - 1;
    }

    /**
     * Get algebraic notation for this position (e.g., "a1", "h8")
     */
    public string get_algebraic_notation() {
        char col_char = (char)('a' + col);
        return @"$col_char$(row + 1)";
    }

    /**
     * Create position from algebraic notation
     */
    public static BoardPosition? from_algebraic_notation(string notation, int board_size) {
        if (notation.length < 2) return null;

        char col_char = notation[0];
        if (col_char < 'a' || col_char > 'z') return null;

        int col = col_char - 'a';
        int row;

        try {
            row = int.parse(notation[1:]) - 1;
        } catch (Error e) {
            return null;
        }

        var pos = new BoardPosition(row, col, board_size);
        return pos.is_valid() ? pos : null;
    }
}