/**
 * BoardValidator.vala
 *
 * Validates board positions and move legality.
 */

using Draughts;

public class Draughts.BoardValidator : Object {
    public static bool is_position_valid(BoardPosition position, int board_size) {
        return position.is_valid();
    }

    public static bool is_dark_square(BoardPosition position) {
        return position.is_dark_square();
    }
}