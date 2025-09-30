/**
 * test_position.vala
 *
 * Unit tests for the Position model class.
 * Tests coordinate validation, dark square checking, and position operations.
 */

using Draughts;

public class TestPosition : Object {

    public static void register_tests() {
        Test.add_func("/draughts/position/construction", test_position_construction);
        Test.add_func("/draughts/position/validation", test_position_validation);
        Test.add_func("/draughts/position/dark_squares", test_dark_square_validation);
        Test.add_func("/draughts/position/board_bounds", test_board_bounds);
        Test.add_func("/draughts/position/equality", test_position_equality);
        Test.add_func("/draughts/position/to_string", test_position_string);
    }

    static void test_position_construction() {
        // Test valid position creation
        var pos = new Position(3, 4, 8);
        assert(pos.row == 3);
        assert(pos.col == 4);
        assert(pos.board_size == 8);
    }

    static void test_position_validation() {
        // Test valid positions
        var valid_pos = new Position(1, 2, 8);
        assert(valid_pos.is_valid());

        // Test invalid positions - negative coordinates
        var invalid_pos1 = new Position(-1, 2, 8);
        assert(!invalid_pos1.is_valid());

        var invalid_pos2 = new Position(1, -1, 8);
        assert(!invalid_pos2.is_valid());

        // Test invalid positions - out of bounds
        var invalid_pos3 = new Position(8, 2, 8); // Row 8 is out of bounds for 8x8
        assert(!invalid_pos3.is_valid());

        var invalid_pos4 = new Position(2, 8, 8); // Col 8 is out of bounds for 8x8
        assert(!invalid_pos4.is_valid());
    }

    static void test_dark_square_validation() {
        // In draughts, pieces can only be on dark squares
        // For 8x8 board, dark squares have (row + col) % 2 == 1

        // Test dark squares (valid for pieces)
        var dark_pos1 = new Position(0, 1, 8);
        assert(dark_pos1.is_dark_square());

        var dark_pos2 = new Position(1, 0, 8);
        assert(dark_pos2.is_dark_square());

        var dark_pos3 = new Position(2, 3, 8);
        assert(dark_pos3.is_dark_square());

        // Test light squares (invalid for pieces)
        var light_pos1 = new Position(0, 0, 8);
        assert(!light_pos1.is_dark_square());

        var light_pos2 = new Position(1, 1, 8);
        assert(!light_pos2.is_dark_square());

        var light_pos3 = new Position(2, 2, 8);
        assert(!light_pos3.is_dark_square());
    }

    static void test_board_bounds() {
        // Test 8x8 board bounds
        var pos_8x8_valid = new Position(7, 7, 8);
        assert(pos_8x8_valid.is_valid());

        var pos_8x8_invalid = new Position(8, 8, 8);
        assert(!pos_8x8_invalid.is_valid());

        // Test 10x10 board bounds
        var pos_10x10_valid = new Position(9, 9, 10);
        assert(pos_10x10_valid.is_valid());

        var pos_10x10_invalid = new Position(10, 10, 10);
        assert(!pos_10x10_invalid.is_valid());

        // Test 12x12 board bounds
        var pos_12x12_valid = new Position(11, 11, 12);
        assert(pos_12x12_valid.is_valid());

        var pos_12x12_invalid = new Position(12, 12, 12);
        assert(!pos_12x12_invalid.is_valid());
    }

    static void test_position_equality() {
        var pos1 = new Position(3, 4, 8);
        var pos2 = new Position(3, 4, 8);
        var pos3 = new Position(3, 5, 8);
        var pos4 = new Position(4, 4, 8);
        var pos5 = new Position(3, 4, 10);

        // Test equality
        assert(pos1.equals(pos2));
        assert(pos2.equals(pos1));

        // Test inequality
        assert(!pos1.equals(pos3)); // Different column
        assert(!pos1.equals(pos4)); // Different row
        assert(!pos1.equals(pos5)); // Different board size
    }

    static void test_position_string() {
        var pos = new Position(3, 4, 8);
        string str = pos.to_string();

        // Should contain coordinate information
        assert(str.contains("3"));
        assert(str.contains("4"));

        // Should be in readable format
        assert(str.length > 0);
    }

    static void test_distance_calculation() {
        var pos1 = new Position(0, 1, 8);
        var pos2 = new Position(2, 3, 8);

        // Distance should be calculated correctly
        int distance = pos1.distance_to(pos2);
        assert(distance == 2); // 2 squares diagonally

        // Distance to self should be 0
        assert(pos1.distance_to(pos1) == 0);

        // Test adjacent squares
        var adjacent_pos = new Position(1, 2, 8);
        assert(pos1.distance_to(adjacent_pos) == 1);
    }

    static void test_diagonal_relationship() {
        var pos1 = new Position(0, 1, 8);
        var pos2 = new Position(2, 3, 8);
        var pos3 = new Position(1, 3, 8);

        // Test diagonal positions
        assert(pos1.is_diagonal_to(pos2));
        assert(pos2.is_diagonal_to(pos1));

        // Test non-diagonal positions
        assert(!pos1.is_diagonal_to(pos3));
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}