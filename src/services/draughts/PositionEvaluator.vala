/**
 * PositionEvaluator.vala
 *
 * Evaluates board positions for AI decision making.
 * Provides a score representing the advantage of the given color.
 * Positive score means advantage for 'color', negative means disadvantage.
 */

using Draughts;
using Gee;

public class Draughts.PositionEvaluator : Object {

    // Weights
    private const double MATERIAL_WEIGHT = 1.0;
    private const double POSITIONAL_WEIGHT = 0.5;
    private const double KING_WEIGHT = 3.0; // King is worth 3 men
    private const double BACK_ROW_WEIGHT = 0.25;
    private const double CENTER_WEIGHT = 0.15;
    private const double ADVANCEMENT_WEIGHT = 0.1;

    /**
     * Evaluate the state from the perspective of the given color.
     */
    public double evaluate(DraughtsGameState state, PieceColor color, IRuleEngine? rule_engine = null) {
        if (state.is_game_over()) {
            if (state.game_status == GameStatus.DRAW) return 0.0;
            if (state.game_status == GameStatus.RED_WINS && color == PieceColor.RED) return 10000.0;
            if (state.game_status == GameStatus.BLACK_WINS && color == PieceColor.BLACK) return 10000.0;
            return -10000.0; // Loss
        }

        double material_score = evaluate_material(state, color);
        double positional_score = evaluate_positional(state, color);
        double safety_score = evaluate_safety(state, color);
        
        // Mobility can be expensive, use sparingly or if rule_engine provided
        double mobility_score = 0.0;
        if (rule_engine != null) {
             // mobility_score = evaluate_mobility(state, color, rule_engine);
        }

        return (material_score * MATERIAL_WEIGHT) + 
               (positional_score * POSITIONAL_WEIGHT) + 
               safety_score;
    }

    private double evaluate_material(DraughtsGameState state, PieceColor color) {
        double score = 0.0;
        foreach (var piece in state.pieces) {
            double value = (piece.piece_type == DraughtsPieceType.KING) ? KING_WEIGHT : 1.0;
            if (piece.color == color) {
                score += value;
            } else {
                score -= value;
            }
        }
        return score;
    }

    private double evaluate_positional(DraughtsGameState state, PieceColor color) {
        double score = 0.0;
        int board_size = state.board_size;
        int center_min = board_size / 2 - 1;
        int center_max = board_size / 2;

        foreach (var piece in state.pieces) {
            if (piece.color != color && piece.color != get_opponent_color(color)) continue;

            double piece_score = 0.0;
            int row = piece.position.row;
            int col = piece.position.col;

            // Center Control
            if (col >= center_min && col <= center_max) {
                 if (row >= center_min && row <= center_max) {
                     piece_score += CENTER_WEIGHT;
                 } else {
                     piece_score += CENTER_WEIGHT * 0.5; // Near center
                 }
            }

            // Advancement (for Men only)
            if (piece.piece_type == DraughtsPieceType.MAN) {
                int advance_rows = (piece.color == PieceColor.RED) ? row : (board_size - 1 - row);
                piece_score += advance_rows * ADVANCEMENT_WEIGHT;
            }

            if (piece.color == color) {
                score += piece_score;
            } else {
                score -= piece_score;
            }
        }
        return score;
    }

    private double evaluate_safety(DraughtsGameState state, PieceColor color) {
        double score = 0.0;
        int board_size = state.board_size;

        foreach (var piece in state.pieces) {
            // minimal safety check: Back row
            bool is_back_row = false;
            if (piece.color == PieceColor.RED && piece.position.row == 0) is_back_row = true;
            if (piece.color == PieceColor.BLACK && piece.position.row == board_size - 1) is_back_row = true;

            if (is_back_row) {
                if (piece.color == color) score += BACK_ROW_WEIGHT;
                else score -= BACK_ROW_WEIGHT;
            }
        }
        return score;
    }

    private PieceColor get_opponent_color(PieceColor color) {
        return (color == PieceColor.RED) ? PieceColor.BLACK : PieceColor.RED;
    }
}