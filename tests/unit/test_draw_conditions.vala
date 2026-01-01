/**
 * test_draw_conditions.vala
 *
 * Unit tests for draw conditions, specifically the 40-move rule and
 * reset conditions (captures, man movement).
 */

using Draughts;

public class TestDrawConditions : Object {

    public static void register_tests() {
        Test.add_func("/draughts/draw_conditions/move_limit_bug_reproduction", test_move_limit_bug_reproduction);
        Test.add_func("/draughts/draw_conditions/man_move_reset", test_man_move_reset);
        Test.add_func("/draughts/draw_conditions/king_move_no_reset", test_king_move_no_reset);
    }

    /**
     * Test confirming that the draw is NOT claimed after 20 moves (40 plies)
     * when the limit is 40 moves.
     */
    static void test_move_limit_bug_reproduction() {
        // Use American Checkers (40 move limit)
        var variant = new GameVariant(DraughtsVariant.AMERICAN);
        var rule_engine = new UnifiedRuleEngine(variant);

        // Create a king vs king endgame state (where move limit applies)
        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, DraughtsPieceType.KING, new BoardPosition(0, 0, 8), 1));
        pieces.add(new GamePiece(PieceColor.BLACK, DraughtsPieceType.KING, new BoardPosition(7, 7, 8), 2));
        
        var state = new DraughtsGameState(pieces, PieceColor.RED, 8);
        
        // Simulate 20 full moves (40 plies) without capture/man-move
        // We need to create a history array.
        // Each "move" in history is a ply.
        var history = new DraughtsMove[40];
        
        for (int i = 0; i < 40; i++) {
            // Create dummy simple moves for kings
            var from = new BoardPosition(0, 0, 8);
            var to = new BoardPosition(1, 1, 8);
            var move = new DraughtsMove(1, from, to, MoveType.SIMPLE, DraughtsPieceType.KING);
            history[i] = move;
        }

        // Check draw condition
        // If bug is present (looping 'limit' times over history), it might check only last 40 items? 
        // Wait, the bug was: if (move_history.length >= move_limit * 2) ... check last move_limit items.
        // For American: limit is 40. 
        // Logic: if (history.length >= 80) check last 40.
        // User says: "Each player moved 20 times (40 moves total)... Declared draw".
        // This means history.length was 40.
        // If the code was: if (history.length >= move_limit) check last move_limit...
        // Then at 40 plies, it triggers. But it should be valid until 80 plies.
        
        var draw_reason = rule_engine.check_draw_conditions(state, history);
        
        // EXPECTATION: Should be null (no draw yet).
        // If bug exists, it might return DrawReason.TIME_LIMIT.
        if (draw_reason != null) {
            print("Bug reproduced: Draw occurred after 40 plies (20 moves).\n");
        } 
        
        assert(draw_reason == null);
        
        // Now simulate 80 plies (40 full moves)
        var history_80 = new DraughtsMove[80];
        for (int i = 0; i < 80; i++) {
            var move = new DraughtsMove(1, new BoardPosition(0,0,8), new BoardPosition(1,1,8), MoveType.SIMPLE, DraughtsPieceType.KING);
            history_80[i] = move;
        }
        
        var draw_reason_80 = rule_engine.check_draw_conditions(state, history_80);
        assert(draw_reason_80 == DrawReason.TIME_LIMIT);
    }

    static void test_man_move_reset() {
        var variant = new GameVariant(DraughtsVariant.AMERICAN);
        var rule_engine = new UnifiedRuleEngine(variant);
        // American limit is 40 moves
        
        // Setup state with a Man
        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, DraughtsPieceType.MAN, new BoardPosition(2, 2, 8), 1));
        var state = new DraughtsGameState(pieces, PieceColor.RED, 8);
        
        // Fill history with 79 simple King moves (should not draw yet)
        // Then add 1 Man move. Total 80 moves (40 each).
        // Since last move was a Man move, it should RESET the counter logic (i.e. not partial count).
        // But more importantly, if we check condition, it should look for captures OR man moves.
        
        var history = new DraughtsMove[80];
        for (int i = 0; i < 79; i++) {
            history[i] = new DraughtsMove(2, new BoardPosition(7,7,8), new BoardPosition(6,6,8), MoveType.SIMPLE, DraughtsPieceType.KING);
        }
        
        // Last move is a MAN move
        history[79] = new DraughtsMove(1, new BoardPosition(2,2,8), new BoardPosition(3,3,8), MoveType.SIMPLE, DraughtsPieceType.MAN);
        
        // Check draw condition
        var draw_reason = rule_engine.check_draw_conditions(state, history);
        
        // EXPECTATION: Should be null because man move should reset the counter.
        // If bug exists, it will likely return DrawReason.TIME_LIMIT because it only checks for captures.
        if (draw_reason != null) {
            print("Bug reproduced: Man move did not reset draw counter.\n");
        }
        
        assert(draw_reason == null);
    }

    static void test_king_move_no_reset() {
        var variant = new GameVariant(DraughtsVariant.AMERICAN);
        var rule_engine = new UnifiedRuleEngine(variant);
        
        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, DraughtsPieceType.KING, new BoardPosition(2, 2, 8), 1));
        var state = new DraughtsGameState(pieces, PieceColor.RED, 8);
        
        var history = new DraughtsMove[80];
        // 80 simple king moves -> should draw
        for (int i = 0; i < 80; i++) {
            history[i] = new DraughtsMove(1, new BoardPosition(0,0,8), new BoardPosition(1,1,8), MoveType.SIMPLE, DraughtsPieceType.KING);
        }
        
        var draw_reason = rule_engine.check_draw_conditions(state, history);
        assert(draw_reason == DrawReason.TIME_LIMIT);
    }
}
