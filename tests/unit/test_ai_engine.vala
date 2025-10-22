/**
 * test_ai_engine.vala
 *
 * Unit tests for the MinimaxAI engine.
 * Tests all difficulty levels, move legality, determinism, and performance.
 */

using Draughts;

public class TestAIEngine : Object {

    public static void register_tests() {
        Test.add_func("/draughts/ai/creation", test_ai_creation);
        Test.add_func("/draughts/ai/difficulty_levels", test_difficulty_levels);
        Test.add_func("/draughts/ai/legal_moves", test_ai_makes_legal_moves);
        Test.add_func("/draughts/ai/beginner_random", test_beginner_moves_are_random);
        Test.add_func("/draughts/ai/easy_prefers_captures", test_easy_prefers_captures);
        Test.add_func("/draughts/ai/difficulty_progression", test_difficulty_progression);
        Test.add_func("/draughts/ai/no_moves_available", test_no_moves_available);
        Test.add_func("/draughts/ai/single_move", test_single_legal_move);
        Test.add_func("/draughts/ai/time_limit", test_time_limit_handling);
        Test.add_func("/draughts/ai/cancellation", test_cancellation);
    }

    static void test_ai_creation() {
        // Test creating AI with different difficulty levels
        var ai_beginner = new MinimaxAI(AIDifficulty.BEGINNER);
        assert(ai_beginner != null);
        assert(ai_beginner.get_difficulty_level() == 1);

        var ai_grandmaster = new MinimaxAI(AIDifficulty.GRANDMASTER);
        assert(ai_grandmaster != null);
        assert(ai_grandmaster.get_difficulty_level() == 10);

        // Test default construction
        var ai_default = new MinimaxAI();
        assert(ai_default != null);
        assert(ai_default.get_difficulty_level() == 3); // MEDIUM = 3
    }

    static void test_difficulty_levels() {
        // Test that all 10 difficulty levels are properly configured
        var difficulties = new AIDifficulty[] {
            AIDifficulty.BEGINNER,
            AIDifficulty.EASY,
            AIDifficulty.MEDIUM,
            AIDifficulty.NOVICE,
            AIDifficulty.INTERMEDIATE,
            AIDifficulty.HARD,
            AIDifficulty.ADVANCED,
            AIDifficulty.EXPERT,
            AIDifficulty.MASTER,
            AIDifficulty.GRANDMASTER
        };

        for (int i = 0; i < difficulties.length; i++) {
            var ai = new MinimaxAI(difficulties[i]);
            assert(ai.get_difficulty_level() == i + 1);
        }
    }

    static void test_ai_makes_legal_moves() {
        // Test that AI at all difficulty levels makes legal moves
        var variant = DraughtsVariant.AMERICAN;
        var rule_engine = create_rule_engine(variant);
        var initial_state = create_initial_state(variant);

        var difficulties = new AIDifficulty[] {
            AIDifficulty.BEGINNER,
            AIDifficulty.EASY,
            AIDifficulty.MEDIUM,
            AIDifficulty.NOVICE,
            AIDifficulty.INTERMEDIATE,
            AIDifficulty.HARD,
            AIDifficulty.ADVANCED,
            AIDifficulty.EXPERT,
            AIDifficulty.MASTER,
            AIDifficulty.GRANDMASTER
        };

        foreach (var difficulty in difficulties) {
            var ai = new MinimaxAI(difficulty);
            var move = ai.calculate_best_move(initial_state, rule_engine, 1000);

            assert(move != null);

            // Verify move is legal
            var legal_moves = rule_engine.generate_legal_moves(initial_state);
            bool found_move = false;
            foreach (var legal_move in legal_moves) {
                if (moves_equal(move, legal_move)) {
                    found_move = true;
                    break;
                }
            }

            assert(found_move);
        }
    }

    static void test_beginner_moves_are_random() {
        // Test that beginner level makes random moves (not always the same)
        var variant = DraughtsVariant.AMERICAN;
        var rule_engine = create_rule_engine(variant);
        var initial_state = create_initial_state(variant);

        var ai = new MinimaxAI(AIDifficulty.BEGINNER);
        var moves = new Gee.ArrayList<DraughtsMove>();

        // Generate 10 moves and see if there's variety
        for (int i = 0; i < 10; i++) {
            var move = ai.calculate_best_move(initial_state, rule_engine, 100);
            assert(move != null);
            moves.add(move);
        }

        // Check that not all moves are identical
        // (There's a small chance all could be the same, but very unlikely)
        bool has_variety = false;
        var first_move = moves[0];
        foreach (var move in moves) {
            if (!moves_equal(move, first_move)) {
                has_variety = true;
                break;
            }
        }

        // With 10 random selections, we should see variety
        // (unless there's only 1 legal move, which we test separately)
        var legal_moves = rule_engine.generate_legal_moves(initial_state);
        if (legal_moves.length > 1) {
            assert(has_variety);
        }
    }

    static void test_easy_prefers_captures() {
        // Test that EASY level prefers captures when available
        var variant = DraughtsVariant.AMERICAN;
        var rule_engine = create_rule_engine(variant);

        // Create a state with a capture available
        var state_with_capture = create_state_with_capture(variant);
        var ai = new MinimaxAI(AIDifficulty.EASY);

        // Run multiple times to ensure consistency
        for (int i = 0; i < 5; i++) {
            var move = ai.calculate_best_move(state_with_capture, rule_engine, 100);
            assert(move != null);
            assert(move.is_capture()); // Should always prefer capture
        }
    }

    static void test_difficulty_progression() {
        // Test that higher difficulty levels make better moves
        // This is hard to test precisely, but we can verify they use search
        var variant = DraughtsVariant.AMERICAN;
        var rule_engine = create_rule_engine(variant);
        var complex_state = create_complex_state(variant);

        var ai_beginner = new MinimaxAI(AIDifficulty.BEGINNER);
        var ai_expert = new MinimaxAI(AIDifficulty.EXPERT);

        var beginner_move = ai_beginner.calculate_best_move(complex_state, rule_engine, 100);
        var expert_move = ai_expert.calculate_best_move(complex_state, rule_engine, 2000);

        assert(beginner_move != null);
        assert(expert_move != null);

        // Both should be legal moves
        var legal_moves = rule_engine.generate_legal_moves(complex_state);
        assert(is_move_in_list(beginner_move, legal_moves));
        assert(is_move_in_list(expert_move, legal_moves));

        // We can't guarantee they're different, but both should be valid
    }

    static void test_no_moves_available() {
        // Test AI behavior when no moves are available
        var variant = DraughtsVariant.AMERICAN;
        var rule_engine = create_rule_engine(variant);

        // Create a state with no legal moves (game over)
        var no_moves_state = create_state_with_no_moves(variant);

        var ai = new MinimaxAI(AIDifficulty.MEDIUM);
        var move = ai.calculate_best_move(no_moves_state, rule_engine, 1000);

        // Should return null when no moves available
        assert(move == null);
    }

    static void test_single_legal_move() {
        // Test that AI handles case with only one legal move efficiently
        var variant = DraughtsVariant.AMERICAN;
        var rule_engine = create_rule_engine(variant);
        var state_one_move = create_state_with_one_move(variant);

        var ai = new MinimaxAI(AIDifficulty.GRANDMASTER);

        // Should return quickly even for grandmaster
        int64 start_time = GLib.get_monotonic_time();
        var move = ai.calculate_best_move(state_one_move, rule_engine, 10000);
        int64 end_time = GLib.get_monotonic_time();
        int64 elapsed_ms = (end_time - start_time) / 1000;

        assert(move != null);
        // Should be very fast (< 100ms) when only one move
        assert(elapsed_ms < 100);
    }

    static void test_time_limit_handling() {
        // Test that AI respects time limits
        var variant = DraughtsVariant.AMERICAN;
        var rule_engine = create_rule_engine(variant);
        var complex_state = create_complex_state(variant);

        var ai = new MinimaxAI(AIDifficulty.GRANDMASTER);

        // Set a very short time limit
        uint time_limit = 50; // 50ms
        int64 start_time = GLib.get_monotonic_time();
        var move = ai.calculate_best_move(complex_state, rule_engine, time_limit);
        int64 end_time = GLib.get_monotonic_time();
        int64 elapsed_ms = (end_time - start_time) / 1000;

        assert(move != null);
        // Should complete within reasonable time of the limit
        // (allow some overhead, but should be close)
        assert(elapsed_ms < time_limit + 100);
    }

    static void test_cancellation() {
        // Test that AI can be cancelled
        var variant = DraughtsVariant.AMERICAN;
        var rule_engine = create_rule_engine(variant);
        var complex_state = create_complex_state(variant);

        var ai = new MinimaxAI(AIDifficulty.GRANDMASTER);

        // Start calculation in a separate thread (simulated by immediate cancel)
        assert(!ai.is_thinking());

        // Note: Full threading test would require actual async execution
        // For now, just verify the interface exists and can be called
        ai.cancel_calculation();
    }

    // Helper methods

    static IRuleEngine create_rule_engine(DraughtsVariant variant) {
        return new UnifiedRuleEngine(variant);
    }

    static DraughtsGameState create_initial_state(DraughtsVariant variant) {
        return DraughtsGameState.create_initial_state(variant);
    }

    static DraughtsGameState create_state_with_capture(DraughtsVariant variant) {
        // Create a simple state where a capture is available
        var pieces = new Gee.ArrayList<DraughtsPiece>();

        // Red piece that can capture
        pieces.add(new DraughtsPiece(1, new BoardPosition(3, 2, 8), PieceColor.RED, DraughtsPieceType.MAN));

        // Black piece to be captured
        pieces.add(new DraughtsPiece(2, new BoardPosition(4, 3, 8), PieceColor.BLACK, DraughtsPieceType.MAN));

        // Some other pieces
        pieces.add(new DraughtsPiece(3, new BoardPosition(6, 5, 8), PieceColor.BLACK, DraughtsPieceType.MAN));

        return new DraughtsGameState(pieces, PieceColor.RED, variant);
    }

    static DraughtsGameState create_complex_state(DraughtsVariant variant) {
        // Create a mid-game state with multiple options
        var pieces = new Gee.ArrayList<DraughtsPiece>();

        // Red pieces
        pieces.add(new DraughtsPiece(1, new BoardPosition(2, 1, 8), PieceColor.RED, DraughtsPieceType.MAN));
        pieces.add(new DraughtsPiece(2, new BoardPosition(3, 2, 8), PieceColor.RED, DraughtsPieceType.MAN));
        pieces.add(new DraughtsPiece(3, new BoardPosition(4, 3, 8), PieceColor.RED, DraughtsPieceType.KING));

        // Black pieces
        pieces.add(new DraughtsPiece(4, new BoardPosition(5, 4, 8), PieceColor.BLACK, DraughtsPieceType.MAN));
        pieces.add(new DraughtsPiece(5, new BoardPosition(6, 5, 8), PieceColor.BLACK, DraughtsPieceType.MAN));
        pieces.add(new DraughtsPiece(6, new BoardPosition(5, 2, 8), PieceColor.BLACK, DraughtsPieceType.KING));

        return new DraughtsGameState(pieces, PieceColor.RED, variant);
    }

    static DraughtsGameState create_state_with_no_moves(DraughtsVariant variant) {
        // Create a state where the current player has no legal moves
        var pieces = new Gee.ArrayList<DraughtsPiece>();

        // Only black pieces (Red has no pieces = no moves)
        pieces.add(new DraughtsPiece(1, new BoardPosition(5, 4, 8), PieceColor.BLACK, DraughtsPieceType.MAN));
        pieces.add(new DraughtsPiece(2, new BoardPosition(6, 5, 8), PieceColor.BLACK, DraughtsPieceType.MAN));

        return new DraughtsGameState(pieces, PieceColor.RED, variant);
    }

    static DraughtsGameState create_state_with_one_move(DraughtsVariant variant) {
        // Create a state where only one move is legal
        var pieces = new Gee.ArrayList<DraughtsPiece>();

        // Red piece with only one legal move
        pieces.add(new DraughtsPiece(1, new BoardPosition(2, 1, 8), PieceColor.RED, DraughtsPieceType.MAN));

        // Black pieces blocking most moves
        pieces.add(new DraughtsPiece(2, new BoardPosition(3, 0, 8), PieceColor.BLACK, DraughtsPieceType.MAN));
        pieces.add(new DraughtsPiece(3, new BoardPosition(6, 5, 8), PieceColor.BLACK, DraughtsPieceType.MAN));

        return new DraughtsGameState(pieces, PieceColor.RED, variant);
    }

    static bool moves_equal(DraughtsMove move1, DraughtsMove move2) {
        return move1.from_position.equals(move2.from_position) &&
               move1.to_position.equals(move2.to_position);
    }

    static bool is_move_in_list(DraughtsMove move, DraughtsMove[] moves) {
        foreach (var m in moves) {
            if (moves_equal(move, m)) {
                return true;
            }
        }
        return false;
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}
