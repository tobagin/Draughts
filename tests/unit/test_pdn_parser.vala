/**
 * test_pdn_parser.vala
 *
 * Unit tests for the PDN (Portable Draughts Notation) parser.
 * Tests header parsing, move notation parsing, and variant detection.
 */

using Draughts;

public class TestPDNParser : Object {

    public static void register_tests() {
        Test.add_func("/draughts/pdn/parser_creation", test_parser_creation);
        Test.add_func("/draughts/pdn/parse_headers", test_parse_headers);
        Test.add_func("/draughts/pdn/parse_moves", test_parse_moves);
        Test.add_func("/draughts/pdn/parse_complete_game", test_parse_complete_game);
        Test.add_func("/draughts/pdn/variant_detection", test_variant_detection);
        Test.add_func("/draughts/pdn/result_parsing", test_result_parsing);
        Test.add_func("/draughts/pdn/position_parsing", test_position_parsing);
        Test.add_func("/draughts/pdn/numeric_notation", test_numeric_notation);
        Test.add_func("/draughts/pdn/malformed_pdn", test_malformed_pdn);
        Test.add_func("/draughts/pdn/empty_file", test_empty_file);
    }

    static void test_parser_creation() {
        var parser = new PDNParser();
        assert(parser != null);
    }

    static void test_parse_headers() {
        var parser = new PDNParser();
        string pdn = """
[Event "Test Tournament"]
[Date "2025.10.22"]
[Red "Player 1"]
[Black "Player 2"]
[Variant "American Checkers"]
[Result "1-0"]
""";

        var game_data = parser.parse(pdn);
        assert(game_data != null);
        assert(game_data.event == "Test Tournament");
        assert(game_data.date == "2025.10.22");
        assert(game_data.red_player == "Player 1");
        assert(game_data.black_player == "Player 2");
        assert(game_data.variant == "American Checkers");
        assert(game_data.result == "1-0");
    }

    static void test_parse_moves() {
        var parser = new PDNParser();
        string pdn = """
[Event "Test Game"]
[Date "2025.10.22"]
[Red "Player 1"]
[Black "Player 2"]
[Variant "American Checkers"]
[Result "1-0"]

1. e3-f4 d6-e5 2. f4xd6 c7-d6 3. g3-f4 1-0
""";

        var game_data = parser.parse(pdn);
        assert(game_data != null);
        assert(game_data.moves_notation != null);
        assert(game_data.moves_notation.length >= 5);

        // Verify move format
        assert(game_data.moves_notation[0] == "e3-f4");
        assert(game_data.moves_notation[1] == "d6-e5");
        assert(game_data.moves_notation[2] == "f4xd6"); // Capture notation
    }

    static void test_parse_complete_game() {
        var parser = new PDNParser();
        string pdn = """
[Event "Championship Match"]
[Site "New York"]
[Date "2025.10.22"]
[Round "1"]
[Red "Alice"]
[Black "Bob"]
[Variant "International Draughts"]
[Result "1/2-1/2"]

1. e3-f4 d6-e5 2. f4xd6 c7xe5 3. g3-f4 e5xg3 4. h2xf4 1/2-1/2
""";

        var game_data = parser.parse(pdn);
        assert(game_data != null);
        assert(game_data.event == "Championship Match");
        assert(game_data.site == "New York");
        assert(game_data.date == "2025.10.22");
        assert(game_data.round == "1");
        assert(game_data.red_player == "Alice");
        assert(game_data.black_player == "Bob");
        assert(game_data.variant == "International Draughts");
        assert(game_data.result == "1/2-1/2");

        // Verify moves parsed
        assert(game_data.moves_notation.length > 0);
    }

    static void test_variant_detection() {
        var parser = new PDNParser();

        // Test various variant names
        assert(parser.get_variant_from_name("American Checkers") == DraughtsVariant.AMERICAN);
        assert(parser.get_variant_from_name("English Checkers") == DraughtsVariant.AMERICAN);
        assert(parser.get_variant_from_name("International Draughts") == DraughtsVariant.INTERNATIONAL);
        assert(parser.get_variant_from_name("Russian Draughts") == DraughtsVariant.RUSSIAN);
        assert(parser.get_variant_from_name("Brazilian Draughts") == DraughtsVariant.BRAZILIAN);
        assert(parser.get_variant_from_name("Italian Draughts") == DraughtsVariant.ITALIAN);
        assert(parser.get_variant_from_name("Spanish Draughts") == DraughtsVariant.SPANISH);
        assert(parser.get_variant_from_name("Czech Draughts") == DraughtsVariant.CZECH);
        assert(parser.get_variant_from_name("Thai Draughts") == DraughtsVariant.THAI);

        // Test case insensitivity
        assert(parser.get_variant_from_name("AMERICAN CHECKERS") == DraughtsVariant.AMERICAN);
        assert(parser.get_variant_from_name("international draughts") == DraughtsVariant.INTERNATIONAL);

        // Test unknown variant defaults to American
        assert(parser.get_variant_from_name("Unknown Variant") == DraughtsVariant.AMERICAN);
    }

    static void test_result_parsing() {
        var parser = new PDNParser();

        // Test various result formats
        assert(parser.parse_result("1-0") == GameStatus.RED_WINS);
        assert(parser.parse_result("0-1") == GameStatus.BLACK_WINS);
        assert(parser.parse_result("1/2-1/2") == GameStatus.DRAW);
        assert(parser.parse_result("*") == GameStatus.IN_PROGRESS);

        // Test text formats
        assert(parser.parse_result("Red wins") == GameStatus.RED_WINS);
        assert(parser.parse_result("White wins") == GameStatus.RED_WINS);
        assert(parser.parse_result("Black wins") == GameStatus.BLACK_WINS);
        assert(parser.parse_result("Draw") == GameStatus.DRAW);

        // Test case insensitivity
        assert(parser.parse_result("RED WINS") == GameStatus.RED_WINS);
        assert(parser.parse_result("draw") == GameStatus.DRAW);
    }

    static void test_position_parsing() {
        var parser = new PDNParser();

        // Test algebraic notation on 8x8 board
        var pos_e3 = parser.parse_position("e3", 8);
        assert(pos_e3 != null);
        assert(pos_e3.col == 4); // 'e' is 5th column (0-indexed = 4)
        assert(pos_e3.row == 5); // Row 3 from bottom = row 5 from top (8-3)

        var pos_a1 = parser.parse_position("a1", 8);
        assert(pos_a1 != null);
        assert(pos_a1.col == 0);
        assert(pos_a1.row == 7); // Bottom row

        var pos_h8 = parser.parse_position("h8", 8);
        assert(pos_h8 != null);
        assert(pos_h8.col == 7);
        assert(pos_h8.row == 0); // Top row

        // Test invalid notation
        var invalid_pos = parser.parse_position("z9", 8);
        assert(invalid_pos == null);
    }

    static void test_numeric_notation() {
        var parser = new PDNParser();

        // Test numeric notation on 10x10 board (International draughts)
        var pos_1 = parser.parse_position("1", 10);
        assert(pos_1 != null);

        var pos_32 = parser.parse_position("32", 10);
        assert(pos_32 != null);

        var pos_50 = parser.parse_position("50", 10);
        assert(pos_50 != null);

        // Test invalid square numbers
        var invalid_pos = parser.parse_position("51", 10); // Out of range
        assert(invalid_pos == null);

        var invalid_pos2 = parser.parse_position("0", 10); // Invalid square
        assert(invalid_pos2 == null);
    }

    static void test_malformed_pdn() {
        var parser = new PDNParser();

        // Test PDN with malformed headers
        string malformed_pdn = """
[Event Test Tournament]
[Date 2025.10.22]
Some random text
[Result "1-0"]
""";

        var game_data = parser.parse(malformed_pdn);
        assert(game_data != null); // Should still parse what it can
        assert(game_data.result == "1-0"); // Well-formed headers should parse
    }

    static void test_empty_file() {
        var parser = new PDNParser();

        // Test empty PDN
        string empty_pdn = "";
        var game_data = parser.parse(empty_pdn);
        assert(game_data != null); // Should return valid but empty game data
        assert(game_data.moves_notation.length == 0);

        // Test whitespace-only PDN
        string whitespace_pdn = "   \n\n  \t  \n";
        var game_data2 = parser.parse(whitespace_pdn);
        assert(game_data2 != null);
        assert(game_data2.moves_notation.length == 0);
    }

    static void test_alternative_header_names() {
        var parser = new PDNParser();

        // Test that "White" is accepted as synonym for "Red"
        string pdn = """
[Event "Test Game"]
[White "Player 1"]
[Black "Player 2"]
[Variant "American Checkers"]
[Result "1-0"]
""";

        var game_data = parser.parse(pdn);
        assert(game_data != null);
        assert(game_data.red_player == "Player 1"); // White should map to Red
        assert(game_data.black_player == "Player 2");
    }

    static void test_metadata_storage() {
        var parser = new PDNParser();

        // Test that unknown headers are stored in metadata
        string pdn = """
[Event "Test Game"]
[TimeControl "5+0"]
[ECO "A00"]
[Opening "Test Opening"]
[Annotator "John Doe"]
[Result "1-0"]
""";

        var game_data = parser.parse(pdn);
        assert(game_data != null);
        assert(game_data.event == "Test Game");
        assert(game_data.result == "1-0");

        // Check metadata
        assert(game_data.metadata.has_key("TimeControl"));
        assert(game_data.metadata["TimeControl"] == "5+0");
        assert(game_data.metadata.has_key("ECO"));
        assert(game_data.metadata.has_key("Opening"));
        assert(game_data.metadata.has_key("Annotator"));
    }

    static void test_move_notation_variants() {
        var parser = new PDNParser();

        // Test different move notation styles
        string pdn = """
[Event "Test"]
[Result "*"]

1. e3-f4 d6-e5 2. f4xd6 c7:e5 3. g3-f4 *
""";

        var game_data = parser.parse(pdn);
        assert(game_data != null);
        assert(game_data.moves_notation.length >= 4);

        // Both 'x' and ':' should be recognized as captures
        bool has_x_capture = false;
        bool has_colon_capture = false;

        foreach (var move in game_data.moves_notation) {
            if (move.contains("x")) has_x_capture = true;
            if (move.contains(":")) has_colon_capture = true;
        }

        assert(has_x_capture || has_colon_capture);
    }

    static void test_multiline_moves() {
        var parser = new PDNParser();

        // Test moves split across multiple lines
        string pdn = """
[Event "Test"]
[Result "*"]

1. e3-f4 d6-e5
2. f4xd6 c7-d6
3. g3-f4 *
""";

        var game_data = parser.parse(pdn);
        assert(game_data != null);
        assert(game_data.moves_notation.length >= 5);
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}
