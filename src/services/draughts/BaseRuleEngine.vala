/**
 * BaseRuleEngine.vala
 *
 * Base implementation providing common functionality for all draughts variants.
 * DraughtsVariant-specific engines extend this class and override specific behaviors.
 */

using Draughts;

public abstract class Draughts.BaseRuleEngine : Object, IRuleEngine {
    protected GameVariant variant;
    protected Logger logger;

    protected BaseRuleEngine(GameVariant variant) {
        this.variant = variant;
        this.logger = Logger.get_default();
    }

    public GameVariant get_variant() {
        return variant;
    }

    // Abstract methods that must be implemented by variant-specific engines
    public abstract DraughtsMove[] generate_legal_moves(DraughtsGameState state);
    public abstract bool is_move_legal(DraughtsGameState state, DraughtsMove move);
    public abstract DraughtsGameState execute_move(DraughtsGameState state, DraughtsMove move) throws Error;
    public abstract GameStatus check_game_result(DraughtsGameState state);
    public abstract DrawReason? check_draw_conditions(DraughtsGameState state, DraughtsMove[] move_history);

    // Common utility methods that can be used by all variants

    /**
     * Check if a move is within board bounds
     */
    protected bool is_position_on_board(BoardPosition position) {
        return position.row >= 0 && position.row < variant.board_size &&
               position.col >= 0 && position.col < variant.board_size;
    }

    /**
     * Check if both positions are on dark squares (draughts only played on dark squares)
     */
    protected bool are_positions_on_dark_squares(BoardPosition from, BoardPosition to) {
        return from.is_dark_square() && to.is_dark_square();
    }

    /**
     * Check if move is diagonal
     */
    protected bool is_diagonal_move(BoardPosition from, BoardPosition to) {
        int row_diff = (to.row - from.row).abs();
        int col_diff = (to.col - from.col).abs();
        return row_diff == col_diff && row_diff > 0;
    }

    /**
     * Check if destination square is empty
     */
    protected bool is_destination_empty(DraughtsGameState state, BoardPosition to) {
        return state.get_piece_at(to) == null;
    }

    /**
     * Check if piece belongs to active player
     */
    protected bool is_piece_owned_by_active_player(DraughtsGameState state, GamePiece piece) {
        return piece.color == state.active_player;
    }

    /**
     * Get direction of movement (1 for forward, -1 for backward)
     */
    protected int get_move_direction(PieceColor color, BoardPosition from, BoardPosition to) {
        int row_diff = to.row - from.row;
        if (color == PieceColor.RED) {
            return row_diff < 0 ? 1 : -1; // Red moves toward black side (decreasing rows)
        } else {
            return row_diff > 0 ? 1 : -1; // Black moves toward red side (increasing rows)
        }
    }

    /**
     * Check if move is forward for regular pieces
     */
    protected bool is_forward_move(PieceColor color, BoardPosition from, BoardPosition to) {
        if (color == PieceColor.RED) {
            return to.row < from.row; // Red moves toward black side (decreasing row numbers)
        } else {
            return to.row > from.row; // Black moves toward red side (increasing row numbers)
        }
    }

    /**
     * Get squares between two positions (for capture validation)
     */
    protected Gee.ArrayList<BoardPosition> get_squares_between(BoardPosition from, BoardPosition to) {
        var squares = new Gee.ArrayList<BoardPosition>();

        int row_step = (to.row > from.row) ? 1 : -1;
        int col_step = (to.col > from.col) ? 1 : -1;

        logger.debug("SqBetween (%d,%d)->(%d,%d):", from.row, from.col, to.row, to.col);

        int current_row = from.row + row_step;
        int current_col = from.col + col_step;

        while (current_row != to.row && current_col != to.col) {
            var pos = new BoardPosition(current_row, current_col, variant.board_size);
            squares.add(pos);
            logger.debug(" (%d,%d)", current_row, current_col);
            current_row += row_step;
            current_col += col_step;
        }

        logger.debug(" = %d squares", squares.size);

        return squares;
    }

    /**
     * Find captured pieces in a move
     */
    protected Gee.ArrayList<GamePiece> find_captured_pieces(DraughtsGameState state, BoardPosition from, BoardPosition to) {
        var captured = new Gee.ArrayList<GamePiece>();
        var squares_between = get_squares_between(from, to);
        var moving_piece = state.get_piece_at(from);

        logger.debug("FindCaptures %s@(%d,%d):", moving_piece != null ? moving_piece.color.to_string() : "null", from.row, from.col);

        if (moving_piece == null) {
            logger.debug(" none");
            return captured;
        }

        foreach (var square in squares_between) {
            var piece = state.get_piece_at(square);
            if (piece != null && piece.color != moving_piece.color) {
                logger.debug(" +%s%s@(%d,%d)", piece.color.to_string().substring(0,1), piece.piece_type.to_string().substring(0,1), square.row, square.col);
                captured.add(piece);
            }
        }

        logger.debug(" = %d", captured.size);

        return captured;
    }

    /**
     * Check if regular piece should be promoted (reached opposite end)
     */
    protected bool should_promote_piece(GamePiece piece, BoardPosition to) {
        if (piece.piece_type == DraughtsPieceType.KING) {
            return false; // Already a king
        }

        if (piece.color == PieceColor.RED) {
            return to.row == 0; // Red promotes when reaching black's side (bottom row)
        } else {
            return to.row == variant.board_size - 1; // Black promotes when reaching red's side (top row)
        }
    }

    /**
     * Basic move validation that applies to all variants
     */
    protected bool is_basic_move_valid(DraughtsGameState state, DraughtsMove move) {
        // Check if piece exists and belongs to active player
        var piece = state.get_piece_by_id(move.piece_id);
        if (piece == null || !is_piece_owned_by_active_player(state, piece)) {
            return false;
        }

        // Check if positions are on board
        if (!is_position_on_board(move.from_position) || !is_position_on_board(move.to_position)) {
            return false;
        }

        // Check if positions are on dark squares
        if (!are_positions_on_dark_squares(move.from_position, move.to_position)) {
            return false;
        }

        // Check if move is diagonal
        if (!is_diagonal_move(move.from_position, move.to_position)) {
            return false;
        }

        // Check if destination is empty
        if (!is_destination_empty(state, move.to_position)) {
            return false;
        }

        return true;
    }
}