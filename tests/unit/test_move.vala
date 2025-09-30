/**
 * test_move.vala
 *
 * Unit tests for the Move model class.
 * Tests move creation, validation, capture sequences, and move properties.
 */

using Draughts;

public class TestMove : Object {

    public static void register_tests() {
        Test.add_func("/draughts/move/construction", test_move_construction);
        Test.add_func("/draughts/move/simple_move", test_simple_move);
        Test.add_func("/draughts/move/capture_move", test_capture_move);
        Test.add_func("/draughts/move/multi_capture", test_multi_capture_move);
        Test.add_func("/draughts/move/promotion_move", test_promotion_move);
        Test.add_func("/draughts/move/validation", test_move_validation);
        Test.add_func("/draughts/move/equality", test_move_equality);
        Test.add_func("/draughts/move/notation", test_move_notation);
    }

    static void test_move_construction() {
        var from_pos = new Position(2, 3, 8);
        var to_pos = new Position(3, 4, 8);
        var move = new Move(1, from_pos, to_pos, MoveType.SIMPLE);

        assert(move.piece_id == 1);
        assert(move.from_position.equals(from_pos));
        assert(move.to_position.equals(to_pos));
        assert(move.move_type == MoveType.SIMPLE);
        assert(!move.promoted);
        assert(move.captured_pieces.length == 0);
    }

    static void test_simple_move() {
        var from_pos = new Position(2, 1, 8);
        var to_pos = new Position(3, 2, 8);
        var move = new Move(5, from_pos, to_pos, MoveType.SIMPLE);

        assert(move.is_simple_move());
        assert(!move.is_capture());
        assert(!move.is_multi_capture());
        assert(move.get_distance() == 1);
        assert(move.is_diagonal());
    }

    static void test_capture_move() {
        var from_pos = new Position(2, 3, 8);
        var to_pos = new Position(4, 5, 8);
        var captured_pieces = new int[] { 10 };
        var move = new Move.with_captures(7, from_pos, to_pos, captured_pieces);

        assert(move.is_capture());
        assert(!move.is_simple_move());
        assert(!move.is_multi_capture());
        assert(move.move_type == MoveType.CAPTURE);
        assert(move.captured_pieces.length == 1);
        assert(move.captured_pieces[0] == 10);
        assert(move.get_distance() == 2); // Capture jump
    }

    static void test_multi_capture_move() {
        var from_pos = new Position(1, 2, 8);
        var to_pos = new Position(5, 6, 8);
        var captured_pieces = new int[] { 15, 16, 17 };
        var move = new Move.with_captures(8, from_pos, to_pos, captured_pieces);

        assert(move.is_multi_capture());
        assert(move.is_capture());
        assert(!move.is_simple_move());
        assert(move.move_type == MoveType.MULTI_CAPTURE);
        assert(move.captured_pieces.length == 3);
        assert(15 in move.captured_pieces);
        assert(16 in move.captured_pieces);
        assert(17 in move.captured_pieces);
    }

    static void test_promotion_move() {
        // Red piece reaching top row (row 7 on 8x8 board)
        var from_pos = new Position(6, 5, 8);
        var to_pos = new Position(7, 6, 8);
        var move = new Move(12, from_pos, to_pos, MoveType.SIMPLE);

        // Set promotion manually (would be set by game logic)
        move.promoted = true;

        assert(move.promoted);
        assert(move.results_in_promotion());
    }

    static void test_move_validation() {
        // Test valid diagonal move
        var valid_from = new Position(2, 3, 8);
        var valid_to = new Position(3, 4, 8);
        var valid_move = new Move(20, valid_from, valid_to, MoveType.SIMPLE);
        assert(valid_move.is_valid());

        // Test invalid non-diagonal move
        var invalid_to = new Position(2, 4, 8); // Same row
        var invalid_move = new Move(21, valid_from, invalid_to, MoveType.SIMPLE);
        assert(!invalid_move.is_valid());

        // Test invalid position (out of bounds)
        var invalid_from = new Position(-1, 3, 8);
        var invalid_move2 = new Move(22, invalid_from, valid_to, MoveType.SIMPLE);
        assert(!invalid_move2.is_valid());

        // Test move to same position
        var same_pos_move = new Move(23, valid_from, valid_from, MoveType.SIMPLE);
        assert(!same_pos_move.is_valid());
    }

    static void test_move_equality() {
        var from_pos = new Position(1, 2, 8);
        var to_pos = new Position(2, 3, 8);
        var captured = new int[] { 5 };

        var move1 = new Move.with_captures(10, from_pos, to_pos, captured);
        var move2 = new Move.with_captures(10, from_pos, to_pos, captured);
        var move3 = new Move.with_captures(11, from_pos, to_pos, captured); // Different piece
        var move4 = new Move(10, from_pos, to_pos, MoveType.SIMPLE); // No captures

        // Test equality
        assert(move1.equals(move2));

        // Test inequality
        assert(!move1.equals(move3)); // Different piece ID
        assert(!move1.equals(move4)); // Different captures
    }

    static void test_move_notation() {
        var from_pos = new Position(2, 3, 8);
        var to_pos = new Position(3, 4, 8);

        // Simple move notation
        var simple_move = new Move(25, from_pos, to_pos, MoveType.SIMPLE);
        string notation = simple_move.to_algebraic_notation();
        assert(notation.contains("3-4") || notation.contains("24-35")); // Different notation styles

        // Capture move notation
        var capture_to = new Position(4, 5, 8);
        var captured = new int[] { 30 };
        var capture_move = new Move.with_captures(26, from_pos, capture_to, captured);
        string capture_notation = capture_move.to_algebraic_notation();
        assert(capture_notation.contains("x")); // Capture symbol
    }

    static void test_move_path_calculation() {
        var from_pos = new Position(1, 2, 8);
        var to_pos = new Position(4, 5, 8);
        var move = new Move(27, from_pos, to_pos, MoveType.CAPTURE);

        // Get intermediate positions
        Position[] path = move.get_path();
        assert(path.length > 0);

        // Path should not include start and end positions
        foreach (var pos in path) {
            assert(!pos.equals(from_pos));
            assert(!pos.equals(to_pos));
        }

        // For this specific move, should pass through (2,3) and (3,4)
        bool found_middle = false;
        foreach (var pos in path) {
            if (pos.row == 2 && pos.col == 3) {
                found_middle = true;
                break;
            }
        }
        assert(found_middle);
    }

    static void test_move_undo_info() {
        var from_pos = new Position(3, 4, 8);
        var to_pos = new Position(5, 6, 8);
        var captured = new int[] { 40, 41 };
        var move = new Move.with_captures(35, from_pos, to_pos, captured);

        // Test undo information storage
        var undo_info = move.create_undo_info();
        assert(undo_info != null);
        assert(undo_info.original_position.equals(from_pos));
        assert(undo_info.captured_piece_ids.length == 2);
        assert(40 in undo_info.captured_piece_ids);
        assert(41 in undo_info.captured_piece_ids);
    }

    static void test_move_timing() {
        var from_pos = new Position(0, 1, 8);
        var to_pos = new Position(1, 2, 8);
        var move = new Move(50, from_pos, to_pos, MoveType.SIMPLE);

        // Test timestamp setting
        var before_time = new DateTime.now_utc();
        move.set_timestamp();
        var after_time = new DateTime.now_utc();

        assert(move.timestamp != null);
        assert(move.timestamp.compare(before_time) >= 0);
        assert(move.timestamp.compare(after_time) <= 0);

        // Test move duration calculation
        Thread.usleep(1000); // 1ms delay
        var duration = move.get_duration_since_timestamp();
        assert(duration >= 0);
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}