/**
 * test_pdn_parser.vala
 *
 * Unit tests for the PDNParser utility class.
 * Tests parsing of moves, tags, and square conversion.
 */

using Draughts;

public class TestPDNParser : Object {

    public static void register_tests() {
        Test.add_func("/draughts/pdn/square_to_position", test_square_to_position);
        Test.add_func("/draughts/pdn/position_to_square", test_position_to_square);
        Test.add_func("/draughts/pdn/parse_move_string", test_parse_move_string);
    }

    static void test_position_to_square() {
        // Standard 8x8 Board
        // (0, 1) -> 1
        var pos1 = new BoardPosition(0, 1, 8);
        assert(PDNParser.position_to_square(pos1, 8) == 1);
        
        // (0, 7) -> 4
        var pos4 = new BoardPosition(0, 7, 8);
        assert(PDNParser.position_to_square(pos4, 8) == 4);
        
        // (1, 0) -> 5
        var pos5 = new BoardPosition(1, 0, 8);
        assert(PDNParser.position_to_square(pos5, 8) == 5);
        
        // (7, 6) -> 32
        var pos32 = new BoardPosition(7, 6, 8);
        assert(PDNParser.position_to_square(pos32, 8) == 32);
        
        // Test different board size (10x10) - International
        // Rows have 5 squares.
        // Row 0: 1,2,3,4,5
        // Row 1: 6,7,8,9,10
        // (0, 1) -> 1
        var pos1_10 = new BoardPosition(0, 1, 10);
        assert(PDNParser.position_to_square(pos1_10, 10) == 1);
        
        // (1, 0) -> 6
        var pos6_10 = new BoardPosition(1, 0, 10);
        assert(PDNParser.position_to_square(pos6_10, 10) == 6);
        
        // Last square 50 -> (9, 8)
        var pos50 = new BoardPosition(9, 8, 10);
        assert(PDNParser.position_to_square(pos50, 10) == 50);
    }

    static void test_square_to_position() {
        // Standard 8x8 Board (American Checkers)
        // Row 0 (top, black side): Squares 1, 2, 3, 4
        // 1 -> (0, 1), 2 -> (0, 3), 3 -> (0, 5), 4 -> (0, 7)
        var pos1 = PDNParser.square_to_position(1, 8);
        assert(pos1 != null);
        assert(pos1.row == 0);
        assert(pos1.col == 1); // Offset 1 (odd columns)

        var pos2 = PDNParser.square_to_position(2, 8);
        assert(pos2 != null);
        assert(pos2.row == 0);
        assert(pos2.col == 3);

        // Row 1: Squares 5, 6, 7, 8
        // 5 -> (1, 0), 6 -> (1, 2), 7 -> (1, 4), 8 -> (1, 6)
        var pos5 = PDNParser.square_to_position(5, 8);
        assert(pos5 != null);
        assert(pos5.row == 1);
        assert(pos5.col == 0); // Offset 0 (even columns)

        // Last square 32 (bottom-right) -> (7, 6)
        var pos32 = PDNParser.square_to_position(32, 8);
        assert(pos32 != null);
        assert(pos32.row == 7);
        assert(pos32.col == 6);

        // Invalid squares
        assert(PDNParser.square_to_position(0, 8) == null);
        // assert(PDNParser.square_to_position(33, 8) == null); // Depends on board size logic
    }

    static void test_parse_move_string() {
        // Simple move
        var move1 = PDNParser.parse_move_string("11-15");
        assert(move1 != null);
        assert(move1.from_sq == 11);
        assert(move1.to_sq == 15);
        assert(!move1.is_capture);

        // Capture move
        var move2 = PDNParser.parse_move_string("24x19");
        assert(move2 != null);
        assert(move2.from_sq == 24);
        assert(move2.to_sq == 19);
        assert(move2.is_capture);

        // Invalid format
        assert(PDNParser.parse_move_string("invalid") == null);
        assert(PDNParser.parse_move_string("11-15-18") == null); // Parser currently expects only 2 parts
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}
