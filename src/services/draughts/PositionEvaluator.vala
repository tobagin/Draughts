/**
 * PositionEvaluator.vala
 *
 * Evaluates board positions for AI decision making using advanced heuristics.
 *
 * This evaluator considers multiple factors:
 * - Material counting (pieces and kings)
 * - King advancement evaluation
 * - Center control scoring
 * - Mobility evaluation
 * - Piece safety assessment
 * - Back row defense
 * - Promotion potential
 */

using Draughts;

public class Draughts.PositionEvaluator : Object {

    // Evaluation weights for different factors
    private const int PIECE_VALUE = 100;
    private const int KING_VALUE = 150;
    private const int KING_MOBILITY_BONUS = 50;
    private const int ADVANCEMENT_VALUE = 3;
    private const int PROMOTION_IMMINENT_BONUS = 20;
    private const int BACK_ROW_DEFENSE_VALUE = 10;
    private const int CENTER_CONTROL_VALUE = 2;
    private const int WIN_SCORE = 100000;
    private const int LOSE_SCORE = -100000;

    private int board_size;

    /**
     * Evaluates a position from the perspective of the specified color.
     *
     * @param state The game state to evaluate
     * @param color The color from whose perspective to evaluate
     * @return A score where positive values favor the specified color
     */
    public double evaluate(DraughtsGameState state, PieceColor color) {
        this.board_size = state.variant.board_size;

        int score = 0;
        int my_pieces = 0;
        int enemy_pieces = 0;
        int my_kings = 0;
        int enemy_kings = 0;
        int my_back_row = 0;
        int enemy_back_row = 0;

        // Evaluate each piece on the board
        foreach (var piece in state.pieces) {
            if (piece.color == color) {
                my_pieces++;
                score += evaluate_piece(piece, color, true);

                if (piece.piece_type == DraughtsPieceType.KING) {
                    my_kings++;
                }

                // Back row defense
                if (is_back_row(piece.position, color)) {
                    my_back_row++;
                }
            } else {
                enemy_pieces++;
                score -= evaluate_piece(piece, piece.color, false);

                if (piece.piece_type == DraughtsPieceType.KING) {
                    enemy_kings++;
                }

                // Enemy back row
                if (is_back_row(piece.position, piece.color)) {
                    enemy_back_row++;
                }
            }
        }

        // Material evaluation (most important factor)
        score += (my_pieces - enemy_pieces) * PIECE_VALUE;
        score += (my_kings - enemy_kings) * KING_VALUE;

        // Back row defense bonus (helps protect against early attacks)
        score += (my_back_row - enemy_back_row) * BACK_ROW_DEFENSE_VALUE;

        // Win/loss detection
        if (enemy_pieces == 0) {
            return WIN_SCORE;
        }
        if (my_pieces == 0) {
            return LOSE_SCORE;
        }

        return (double) score;
    }

    /**
     * Evaluates a single piece's contribution to the position.
     */
    private int evaluate_piece(DraughtsPiece piece, PieceColor piece_color, bool is_my_piece) {
        int score = 0;

        if (piece.piece_type == DraughtsPieceType.KING) {
            // Kings are valuable and have high mobility
            score += KING_MOBILITY_BONUS;
        } else {
            // Regular pieces: evaluate advancement toward promotion
            int advancement = calculate_advancement(piece.position, piece_color);
            score += advancement * ADVANCEMENT_VALUE;

            // Bonus for being close to promotion (within 2 rows)
            if (advancement >= board_size - 2) {
                score += PROMOTION_IMMINENT_BONUS;
            }
        }

        // Center control bonus
        int center_dist = calculate_center_distance(piece.position);
        if (center_dist <= 2) {
            score += (3 - center_dist) * CENTER_CONTROL_VALUE;
        }

        return score;
    }

    /**
     * Calculates how far a piece has advanced toward promotion.
     */
    private int calculate_advancement(BoardPosition pos, PieceColor color) {
        if (color == PieceColor.RED) {
            return pos.row;
        } else {
            return board_size - 1 - pos.row;
        }
    }

    /**
     * Checks if a piece is on the back row.
     */
    private bool is_back_row(BoardPosition pos, PieceColor color) {
        if (color == PieceColor.RED) {
            return pos.row == 0;
        } else {
            return pos.row == board_size - 1;
        }
    }

    /**
     * Calculates Manhattan distance from the center of the board.
     */
    private int calculate_center_distance(BoardPosition pos) {
        int center = board_size / 2;
        int dx = (pos.row - center).abs();
        int dy = (pos.col - center).abs();
        return dx + dy;
    }

    /**
     * Evaluates mobility (number of legal moves available).
     * This is a more expensive calculation and should be used selectively.
     */
    public int evaluate_mobility(DraughtsGameState state, IRuleEngine rule_engine, PieceColor color) {
        var moves = rule_engine.generate_legal_moves(state);
        return moves.length;
    }

    /**
     * Evaluates piece safety by checking if pieces can be captured.
     * This is an expensive calculation and should be used selectively.
     */
    public int evaluate_piece_safety(DraughtsGameState state, IRuleEngine rule_engine, PieceColor color) {
        int safety_score = 0;

        // Count pieces that are potentially vulnerable
        // This is a simplified heuristic
        foreach (var piece in state.pieces) {
            if (piece.color == color) {
                if (is_edge_position(piece.position)) {
                    safety_score -= 5; // Edge pieces are more vulnerable
                } else if (is_corner_position(piece.position)) {
                    safety_score += 10; // Corner pieces are safer
                }
            }
        }

        return safety_score;
    }

    /**
     * Checks if a position is on the edge of the board.
     */
    private bool is_edge_position(BoardPosition pos) {
        return pos.row == 0 || pos.row == board_size - 1 ||
               pos.col == 0 || pos.col == board_size - 1;
    }

    /**
     * Checks if a position is in a corner of the board.
     */
    private bool is_corner_position(BoardPosition pos) {
        return (pos.row == 0 || pos.row == board_size - 1) &&
               (pos.col == 0 || pos.col == board_size - 1);
    }
}
