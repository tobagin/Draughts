/**
 * test_rule_engine_interface.vala
 *
 * Contract tests for the IRuleEngine interface.
 * Tests that rule engine implementations conform to the expected interface behavior.
 */

using Draughts;

public class TestRuleEngineInterface : Object {

    public static void register_tests() {
        Test.add_func("/draughts/contracts/rule_engine/interface_compliance", test_interface_compliance);
        Test.add_func("/draughts/contracts/rule_engine/move_generation", test_move_generation_contract);
        Test.add_func("/draughts/contracts/rule_engine/move_validation", test_move_validation_contract);
        Test.add_func("/draughts/contracts/rule_engine/move_execution", test_move_execution_contract);
        Test.add_func("/draughts/contracts/rule_engine/game_result", test_game_result_contract);
        Test.add_func("/draughts/contracts/rule_engine/draw_detection", test_draw_detection_contract);
    }

    static void test_interface_compliance() {
        // This test ensures that rule engine implementations properly implement the interface
        // We'll use a mock rule engine for testing

        var mock_engine = new MockRuleEngine(Variant.AMERICAN);

        // Test that interface methods are callable and return expected types
        var variant = mock_engine.get_variant();
        assert(variant.get_id() == "american");

        // Test that methods don't throw unexpected exceptions when called with valid inputs
        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1));
        var game_state = new GameState(pieces, PieceColor.RED, 8);

        try {
            var moves = mock_engine.generate_legal_moves(game_state);
            assert(moves != null);
        } catch (Error e) {
            assert_not_reached();
        }
    }

    static void test_move_generation_contract() {
        var mock_engine = new MockRuleEngine(Variant.INTERNATIONAL);

        // Test with empty board
        var empty_pieces = new Gee.ArrayList<GamePiece>();
        var empty_state = new GameState(empty_pieces, PieceColor.RED, 10);
        var empty_moves = mock_engine.generate_legal_moves(empty_state);
        assert(empty_moves.length == 0);

        // Test with single piece
        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(3, 4, 10), 1));
        var single_piece_state = new GameState(pieces, PieceColor.RED, 10);
        var single_piece_moves = mock_engine.generate_legal_moves(single_piece_state);

        // Should return some moves for a valid piece
        assert(single_piece_moves.length > 0);

        // All returned moves should be valid
        foreach (var move in single_piece_moves) {
            assert(move.is_valid());
            assert(mock_engine.is_move_legal(single_piece_state, move));
        }
    }

    static void test_move_validation_contract() {
        var mock_engine = new MockRuleEngine(Variant.RUSSIAN);

        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(4, 5, 8), 10));
        var game_state = new GameState(pieces, PieceColor.BLACK, 8);

        // Test valid move
        var valid_move = new Move(10, new Position(4, 5, 8), new Position(5, 6, 8), MoveType.SIMPLE);
        assert(mock_engine.is_move_legal(game_state, valid_move));

        // Test invalid move (wrong piece)
        var invalid_move1 = new Move(999, new Position(4, 5, 8), new Position(5, 6, 8), MoveType.SIMPLE);
        assert(!mock_engine.is_move_legal(game_state, invalid_move1));

        // Test invalid move (wrong turn)
        var wrong_turn_state = new GameState(pieces, PieceColor.RED, 8);
        assert(!mock_engine.is_move_legal(wrong_turn_state, valid_move));

        // Test move validation consistency
        var generated_moves = mock_engine.generate_legal_moves(game_state);
        foreach (var move in generated_moves) {
            assert(mock_engine.is_move_legal(game_state, move));
        }
    }

    static void test_move_execution_contract() {
        var mock_engine = new MockRuleEngine(Variant.ITALIAN);

        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 2, 8), 5));
        var initial_state = new GameState(pieces, PieceColor.RED, 8);

        var move = new Move(5, new Position(1, 2, 8), new Position(2, 3, 8), MoveType.SIMPLE);

        try {
            var result_state = mock_engine.execute_move(initial_state, move);

            // Original state should be unchanged
            assert(initial_state.get_piece_at(new Position(1, 2, 8)) != null);
            assert(initial_state.get_piece_at(new Position(2, 3, 8)) == null);

            // Result state should have move applied
            assert(result_state.get_piece_at(new Position(1, 2, 8)) == null);
            assert(result_state.get_piece_at(new Position(2, 3, 8)) != null);

            // Turn should be switched
            assert(result_state.active_player != initial_state.active_player);

            // Move count should be incremented
            assert(result_state.move_count == initial_state.move_count + 1);

        } catch (Error e) {
            assert_not_reached();
        }

        // Test that illegal moves throw errors
        var illegal_move = new Move(999, new Position(0, 0, 8), new Position(1, 1, 8), MoveType.SIMPLE);
        try {
            mock_engine.execute_move(initial_state, illegal_move);
            assert_not_reached(); // Should have thrown an error
        } catch (Error e) {
            // Expected behavior
        }
    }

    static void test_game_result_contract() {
        var mock_engine = new MockRuleEngine(Variant.SPANISH);

        // Test game in progress
        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1));
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(5, 6, 8), 2));
        var active_game = new GameState(pieces, PieceColor.RED, 8);

        var result = mock_engine.check_game_result(active_game);
        assert(result == GameStatus.IN_PROGRESS);

        // Test game with no pieces for one side (should be a win)
        var red_only = new Gee.ArrayList<GamePiece>();
        red_only.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 2, 8), 3));
        var red_wins_state = new GameState(red_only, PieceColor.BLACK, 8);

        var red_wins = mock_engine.check_game_result(red_wins_state);
        assert(red_wins == GameStatus.RED_WINS);

        // Test result consistency
        var result2 = mock_engine.check_game_result(active_game);
        assert(result == result2); // Should be deterministic
    }

    static void test_draw_detection_contract() {
        var mock_engine = new MockRuleEngine(Variant.CZECH);

        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.KING, new Position(0, 1, 8), 1));
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.KING, new Position(7, 6, 8), 2));
        var draw_candidate_state = new GameState(pieces, PieceColor.RED, 8);

        // Test with no move history (should not be a draw by repetition)
        var empty_history = new Move[0];
        var draw_reason = mock_engine.check_draw_conditions(draw_candidate_state, empty_history);

        // Draw detection should return null for no draw, or a valid DrawReason
        if (draw_reason != null) {
            assert(draw_reason in DrawReason.all());
        }

        // Test that draw detection is consistent
        var draw_reason2 = mock_engine.check_draw_conditions(draw_candidate_state, empty_history);
        assert(draw_reason == draw_reason2);

        // Test with repetitive move history
        var repetitive_moves = create_repetitive_move_history();
        var repetition_draw = mock_engine.check_draw_conditions(draw_candidate_state, repetitive_moves);

        // If repetition is detected, it should be the correct reason
        if (repetition_draw == DrawReason.REPETITION) {
            // This is expected behavior
        }
    }

    static Move[] create_repetitive_move_history() {
        // Create a history of moves that repeat the same position
        var moves = new Gee.ArrayList<Move>();

        for (int i = 0; i < 6; i++) {
            if (i % 2 == 0) {
                moves.add(new Move(1, new Position(0, 1, 8), new Position(1, 2, 8), MoveType.SIMPLE));
            } else {
                moves.add(new Move(1, new Position(1, 2, 8), new Position(0, 1, 8), MoveType.SIMPLE));
            }
        }

        return moves.to_array();
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}

/**
 * Mock implementation of IRuleEngine for testing
 */
public class MockRuleEngine : Object, IRuleEngine {
    private GameVariant variant;

    public MockRuleEngine(Variant variant_type) {
        this.variant = new GameVariant(variant_type);
    }

    public GameVariant get_variant() {
        return variant;
    }

    public Move[] generate_legal_moves(GameState state) {
        var moves = new Gee.ArrayList<Move>();

        // Simple mock implementation - generate basic forward moves
        var pieces = state.get_pieces_by_color(state.active_player);
        foreach (var piece in pieces) {
            var forward_dir = (piece.color == PieceColor.RED) ? 1 : -1;

            // Try moving diagonally forward
            var new_row = piece.position.row + forward_dir;
            if (new_row >= 0 && new_row < state.board_size) {
                for (int col_dir = -1; col_dir <= 1; col_dir += 2) {
                    var new_col = piece.position.col + col_dir;
                    if (new_col >= 0 && new_col < state.board_size) {
                        var new_pos = new Position(new_row, new_col, state.board_size);
                        if (new_pos.is_dark_square() && state.is_position_empty(new_pos)) {
                            moves.add(new Move(piece.id, piece.position, new_pos, MoveType.SIMPLE));
                        }
                    }
                }
            }
        }

        return moves.to_array();
    }

    public bool is_move_legal(GameState state, Move move) {
        // Basic validation
        var piece = state.get_piece_by_id(move.piece_id);
        if (piece == null) return false;
        if (piece.color != state.active_player) return false;
        if (!move.is_valid()) return false;
        if (!state.is_position_empty(move.to_position)) return false;

        return true;
    }

    public GameState execute_move(GameState state, Move move) throws Error {
        if (!is_move_legal(state, move)) {
            throw new IOError.INVALID_ARGUMENT("Illegal move");
        }

        return state.apply_move(move);
    }

    public GameStatus check_game_result(GameState state) {
        var red_count = state.count_pieces(PieceColor.RED);
        var black_count = state.count_pieces(PieceColor.BLACK);

        if (red_count == 0) return GameStatus.BLACK_WINS;
        if (black_count == 0) return GameStatus.RED_WINS;

        // Check if current player has legal moves
        var legal_moves = generate_legal_moves(state);
        if (legal_moves.length == 0) {
            return (state.active_player == PieceColor.RED) ? GameStatus.BLACK_WINS : GameStatus.RED_WINS;
        }

        return GameStatus.IN_PROGRESS;
    }

    public DrawReason? check_draw_conditions(GameState state, Move[] move_history) {
        // Simple mock implementation
        if (move_history.length >= 6) {
            // Check for simple repetition pattern
            if (move_history.length >= 4) {
                var last_move = move_history[move_history.length - 1];
                var fourth_last = move_history[move_history.length - 4];

                if (last_move.from_position.equals(fourth_last.to_position) &&
                    last_move.to_position.equals(fourth_last.from_position)) {
                    return DrawReason.REPETITION;
                }
            }
        }

        // Check insufficient material
        var red_count = state.count_pieces(PieceColor.RED);
        var black_count = state.count_pieces(PieceColor.BLACK);

        if (red_count == 1 && black_count == 1) {
            var red_pieces = state.get_pieces_by_color(PieceColor.RED);
            var black_pieces = state.get_pieces_by_color(PieceColor.BLACK);

            if (red_pieces[0].type == PieceType.KING && black_pieces[0].type == PieceType.KING) {
                return DrawReason.INSUFFICIENT_MATERIAL;
            }
        }

        return null;
    }
}