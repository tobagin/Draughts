/**
 * test_move_generation.vala
 *
 * Unit tests for move generation algorithms.
 * Tests that legal moves are correctly generated for different game states.
 */

using Draughts;

public class TestMoveGeneration : Object {

    public static void register_tests() {
        Test.add_func("/draughts/move_generation/simple_moves", test_simple_move_generation);
        Test.add_func("/draughts/move_generation/capture_moves", test_capture_move_generation);
        Test.add_func("/draughts/move_generation/king_moves", test_king_move_generation);
        Test.add_func("/draughts/move_generation/mandatory_captures", test_mandatory_capture_priority);
        Test.add_func("/draughts/move_generation/no_moves_available", test_no_legal_moves);
    }

    static void test_simple_move_generation() {
        // This test will fail until MoveGenerator is implemented
        var generator = new MoveGenerator();

        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1));
        var state = new GameState(pieces, PieceColor.RED, 8);

        var moves = generator.generate_simple_moves(state);

        // A man piece should have up to 2 forward diagonal moves
        assert(moves.length <= 2);

        foreach (var move in moves) {
            assert(move.move_type == MoveType.SIMPLE);
            assert(move.piece_id == 1);
            assert(!move.is_capture());
        }
    }

    static void test_capture_move_generation() {
        var generator = new MoveGenerator();

        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1));
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(3, 4, 8), 2));
        var state = new GameState(pieces, PieceColor.RED, 8);

        var captures = generator.generate_capture_moves(state);

        assert(captures.length > 0);

        foreach (var capture in captures) {
            assert(capture.is_capture());
            assert(capture.captured_pieces.length > 0);
        }
    }

    static void test_king_move_generation() {
        var generator = new MoveGenerator();

        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.KING, new Position(4, 5, 8), 1));
        var state = new GameState(pieces, PieceColor.RED, 8);

        var moves = generator.generate_moves_for_piece(state, pieces[0]);

        // King should have more movement options than a man
        assert(moves.length > 2);
    }

    static void test_mandatory_capture_priority() {
        var generator = new MoveGenerator();

        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1));
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(3, 4, 8), 2));
        var state = new GameState(pieces, PieceColor.RED, 8);

        var all_moves = generator.generate_all_legal_moves(state, true); // mandatory captures

        // When captures are available and mandatory, only captures should be returned
        foreach (var move in all_moves) {
            assert(move.is_capture());
        }
    }

    static void test_no_legal_moves() {
        var generator = new MoveGenerator();

        // Create state with no legal moves (blocked piece)
        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(0, 1, 8), 1));
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(1, 0, 8), 2));
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(1, 2, 8), 3));
        var state = new GameState(pieces, PieceColor.RED, 8);

        var moves = generator.generate_all_legal_moves(state, false);

        assert(moves.length == 0);
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}