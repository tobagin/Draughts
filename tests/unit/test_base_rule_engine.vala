/**
 * test_base_rule_engine.vala
 *
 * Unit tests for the BaseRuleEngine class.
 * Tests common functionality shared across all draughts variants.
 */

using Draughts;

public class TestBaseRuleEngine : Object {

    public static void register_tests() {
        Test.add_func("/draughts/base_rule_engine/initialization", test_initialization);
        Test.add_func("/draughts/base_rule_engine/basic_validation", test_basic_validation);
        Test.add_func("/draughts/base_rule_engine/piece_movement", test_piece_movement);
        Test.add_func("/draughts/base_rule_engine/capture_detection", test_capture_detection);
        Test.add_func("/draughts/base_rule_engine/promotion_logic", test_promotion_logic);
        Test.add_func("/draughts/base_rule_engine/turn_management", test_turn_management);
        Test.add_func("/draughts/base_rule_engine/board_validation", test_board_validation);
    }

    static void test_initialization() {
        var variant = new GameVariant(Variant.AMERICAN);
        var base_engine = new MockBaseRuleEngine(variant);

        assert(base_engine.get_variant().variant == Variant.AMERICAN);
        assert(base_engine.get_variant().board_size == 8);
        assert(base_engine.get_variant().men_can_capture_backwards == false);
    }

    static void test_basic_validation() {
        var variant = new GameVariant(Variant.INTERNATIONAL);
        var base_engine = new MockBaseRuleEngine(variant);

        // Test valid move validation
        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(3, 4, 10), 1));
        var state = new GameState(pieces, PieceColor.RED, 10);

        var valid_move = new Move(1, new Position(3, 4, 10), new Position(4, 5, 10), MoveType.SIMPLE);
        assert(base_engine.is_basic_move_valid(state, valid_move));

        // Test invalid move - wrong player
        var wrong_player_state = new GameState(pieces, PieceColor.BLACK, 10);
        assert(!base_engine.is_basic_move_valid(wrong_player_state, valid_move));

        // Test invalid move - piece doesn't exist
        var nonexistent_move = new Move(999, new Position(3, 4, 10), new Position(4, 5, 10), MoveType.SIMPLE);
        assert(!base_engine.is_basic_move_valid(state, nonexistent_move));

        // Test invalid move - destination occupied
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(4, 5, 10), 2));
        var occupied_state = new GameState(pieces, PieceColor.RED, 10);
        assert(!base_engine.is_basic_move_valid(occupied_state, valid_move));
    }

    static void test_piece_movement() {
        var variant = new GameVariant(Variant.RUSSIAN);
        var base_engine = new MockBaseRuleEngine(variant);

        // Test man piece movement directions
        var red_man = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(3, 4, 8), 1);
        var forward_directions = base_engine.get_man_movement_directions(red_man);

        assert(forward_directions.length == 2); // Two diagonal forward directions

        // Red moves toward higher row numbers
        bool found_forward_left = false;
        bool found_forward_right = false;
        foreach (var dir in forward_directions) {
            if (dir.row == 1 && dir.col == -1) found_forward_left = true;
            if (dir.row == 1 && dir.col == 1) found_forward_right = true;
        }
        assert(found_forward_left && found_forward_right);

        // Test black man movement
        var black_man = new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(4, 3, 8), 2);
        var black_directions = base_engine.get_man_movement_directions(black_man);

        // Black moves toward lower row numbers
        foreach (var dir in black_directions) {
            assert(dir.row == -1); // Always moving down
        }

        // Test king movement directions
        var king = new GamePiece(PieceColor.RED, PieceType.KING, new Position(4, 5, 8), 3);
        var king_directions = base_engine.get_king_movement_directions(king);

        assert(king_directions.length == 4); // Four diagonal directions
    }

    static void test_capture_detection() {
        var variant = new GameVariant(Variant.ITALIAN);
        var base_engine = new MockBaseRuleEngine(variant);

        var pieces = new Gee.ArrayList<GamePiece>();
        var attacker = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1);
        var victim = new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(3, 4, 8), 2);
        pieces.add(attacker);
        pieces.add(victim);

        var state = new GameState(pieces, PieceColor.RED, 8);

        // Test valid capture
        var capture_move = new Move(1, new Position(2, 3, 8), new Position(4, 5, 8), MoveType.CAPTURE);
        assert(base_engine.is_valid_capture(state, capture_move));

        // Test capture path calculation
        var captured_pieces = base_engine.get_captured_pieces(state, capture_move);
        assert(captured_pieces.length == 1);
        assert(captured_pieces[0] == 2);

        // Test invalid capture - no piece in between
        var invalid_capture = new Move(1, new Position(2, 3, 8), new Position(4, 1, 8), MoveType.CAPTURE);
        assert(!base_engine.is_valid_capture(state, invalid_capture));

        // Test capture of own piece (should be invalid)
        pieces.clear();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 2, 8), 3));
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 4));
        var own_piece_state = new GameState(pieces, PieceColor.RED, 8);

        var own_capture = new Move(3, new Position(1, 2, 8), new Position(3, 4, 8), MoveType.CAPTURE);
        assert(!base_engine.is_valid_capture(own_piece_state, own_capture));
    }

    static void test_promotion_logic() {
        var variant = new GameVariant(Variant.BRAZILIAN);
        var base_engine = new MockBaseRuleEngine(variant);

        // Test red piece promotion (reaches top row)
        var red_piece = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(6, 5, 8), 1);
        var promotion_pos = new Position(7, 6, 8); // Last row for 8x8 board

        assert(base_engine.should_promote(red_piece, promotion_pos));
        assert(!base_engine.should_promote(red_piece, new Position(6, 7, 8))); // Not promotion row

        // Test black piece promotion (reaches bottom row)
        var black_piece = new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(1, 2, 8), 2);
        var black_promotion_pos = new Position(0, 3, 8); // First row for black

        assert(base_engine.should_promote(black_piece, black_promotion_pos));
        assert(!base_engine.should_promote(black_piece, new Position(1, 3, 8))); // Not promotion row

        // Test king pieces don't get promoted again
        var king = new GamePiece(PieceColor.RED, PieceType.KING, new Position(6, 5, 8), 3);
        assert(!base_engine.should_promote(king, promotion_pos));

        // Test promotion for different board sizes
        var variant_10x10 = new GameVariant(Variant.INTERNATIONAL);
        var engine_10x10 = new MockBaseRuleEngine(variant_10x10);

        var red_10x10 = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(8, 5, 10), 4);
        assert(engine_10x10.should_promote(red_10x10, new Position(9, 6, 10))); // Last row
        assert(!engine_10x10.should_promote(red_10x10, new Position(8, 6, 10))); // Not last row
    }

    static void test_turn_management() {
        var variant = new GameVariant(Variant.GERMAN);
        var base_engine = new MockBaseRuleEngine(variant);

        var pieces = new Gee.ArrayList<GamePiece>();
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1));
        var initial_state = new GameState(pieces, PieceColor.RED, 8);

        // Test move execution with turn switching
        var move = new Move(1, new Position(2, 3, 8), new Position(3, 4, 8), MoveType.SIMPLE);
        var result_state = base_engine.execute_move_with_turn_switch(initial_state, move);

        assert(result_state.active_player == PieceColor.BLACK);
        assert(result_state.move_count == initial_state.move_count + 1);
        assert(result_state.last_move != null);
        assert(result_state.last_move.equals(move));

        // Test that original state is unchanged
        assert(initial_state.active_player == PieceColor.RED);
        assert(initial_state.move_count == 0);
    }

    static void test_board_validation() {
        var variant = new GameVariant(Variant.SWEDISH);
        var base_engine = new MockBaseRuleEngine(variant);

        // Test valid board state
        var valid_pieces = new Gee.ArrayList<GamePiece>();
        valid_pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 2, 8), 1));
        valid_pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(6, 5, 8), 2));
        var valid_state = new GameState(valid_pieces, PieceColor.RED, 8);

        assert(base_engine.is_board_state_valid(valid_state));

        // Test invalid board state - overlapping pieces
        var invalid_pieces = new Gee.ArrayList<GamePiece>();
        invalid_pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(3, 4, 8), 3));
        invalid_pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(3, 4, 8), 4)); // Same position
        var invalid_state = new GameState(invalid_pieces, PieceColor.RED, 8);

        assert(!base_engine.is_board_state_valid(invalid_state));

        // Test pieces on wrong squares (light squares)
        var wrong_square_pieces = new Gee.ArrayList<GamePiece>();
        wrong_square_pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 1, 8), 5)); // Light square
        var wrong_square_state = new GameState(wrong_square_pieces, PieceColor.RED, 8);

        assert(!base_engine.is_board_state_valid(wrong_square_state));
    }

    static void test_path_calculation() {
        var variant = new GameVariant(Variant.GOTHIC);
        var base_engine = new MockBaseRuleEngine(variant);

        // Test straight diagonal path
        var from = new Position(1, 2, 8);
        var to = new Position(4, 5, 8);
        var path = base_engine.calculate_path(from, to);

        assert(path.length == 2); // Intermediate positions: (2,3) and (3,4)
        assert(path[0].row == 2 && path[0].col == 3);
        assert(path[1].row == 3 && path[1].col == 4);

        // Test adjacent squares (no intermediate path)
        var adjacent_from = new Position(2, 3, 8);
        var adjacent_to = new Position(3, 4, 8);
        var adjacent_path = base_engine.calculate_path(adjacent_from, adjacent_to);

        assert(adjacent_path.length == 0);

        // Test non-diagonal path (should be empty)
        var non_diagonal_to = new Position(1, 5, 8);
        var non_diagonal_path = base_engine.calculate_path(from, non_diagonal_to);

        assert(non_diagonal_path.length == 0);
    }

    static void test_mandatory_capture_detection() {
        var variant = new GameVariant(Variant.ARMENIAN);
        variant.mandatory_capture = true;
        var base_engine = new MockBaseRuleEngine(variant);

        var pieces = new Gee.ArrayList<GamePiece>();
        var attacker = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1);
        var victim = new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(3, 4, 8), 2);
        pieces.add(attacker);
        pieces.add(victim);

        var state = new GameState(pieces, PieceColor.RED, 8);

        // Test that captures are available
        var available_captures = base_engine.get_available_captures(state);
        assert(available_captures.length > 0);

        // Test that when captures are available, only captures should be legal
        var all_moves = base_engine.generate_legal_moves(state);
        foreach (var move in all_moves) {
            assert(move.is_capture()); // All moves should be captures when mandatory
        }

        // Test state without captures
        var no_capture_pieces = new Gee.ArrayList<GamePiece>();
        no_capture_pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(0, 1, 8), 3));
        var no_capture_state = new GameState(no_capture_pieces, PieceColor.RED, 8);

        var no_captures = base_engine.get_available_captures(no_capture_state);
        assert(no_captures.length == 0);

        var simple_moves = base_engine.generate_legal_moves(no_capture_state);
        foreach (var move in simple_moves) {
            assert(!move.is_capture()); // Should be simple moves when no captures available
        }
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}

/**
 * Mock implementation of BaseRuleEngine for testing
 */
public class MockBaseRuleEngine : BaseRuleEngine {

    public MockBaseRuleEngine(GameVariant variant) {
        base(variant);
    }

    // Expose protected methods for testing
    public new bool is_basic_move_valid(GameState state, Move move) {
        return base.is_basic_move_valid(state, move);
    }

    public new Direction[] get_man_movement_directions(GamePiece piece) {
        return base.get_man_movement_directions(piece);
    }

    public new Direction[] get_king_movement_directions(GamePiece piece) {
        return base.get_king_movement_directions(piece);
    }

    public new bool is_valid_capture(GameState state, Move move) {
        return base.is_valid_capture(state, move);
    }

    public new int[] get_captured_pieces(GameState state, Move move) {
        return base.get_captured_pieces(state, move);
    }

    public new bool should_promote(GamePiece piece, Position destination) {
        return base.should_promote(piece, destination);
    }

    public new GameState execute_move_with_turn_switch(GameState state, Move move) {
        return base.execute_move_with_turn_switch(state, move);
    }

    public new bool is_board_state_valid(GameState state) {
        return base.is_board_state_valid(state);
    }

    public new Position[] calculate_path(Position from, Position to) {
        return base.calculate_path(from, to);
    }

    public new Move[] get_available_captures(GameState state) {
        return base.get_available_captures(state);
    }

    // Required implementations for abstract methods
    public override Move[] generate_legal_moves(GameState state) {
        if (variant.mandatory_capture) {
            var captures = get_available_captures(state);
            if (captures.length > 0) {
                return captures;
            }
        }

        return generate_simple_moves(state);
    }

    private Move[] generate_simple_moves(GameState state) {
        var moves = new Gee.ArrayList<Move>();
        var pieces = state.get_pieces_by_color(state.active_player);

        foreach (var piece in pieces) {
            var directions = (piece.type == PieceType.MAN) ?
                get_man_movement_directions(piece) :
                get_king_movement_directions(piece);

            foreach (var dir in directions) {
                var new_row = piece.position.row + dir.row;
                var new_col = piece.position.col + dir.col;

                if (new_row >= 0 && new_row < state.board_size &&
                    new_col >= 0 && new_col < state.board_size) {

                    var new_pos = new Position(new_row, new_col, state.board_size);
                    if (new_pos.is_dark_square() && state.is_position_empty(new_pos)) {
                        moves.add(new Move(piece.id, piece.position, new_pos, MoveType.SIMPLE));
                    }
                }
            }
        }

        return moves.to_array();
    }
}

/**
 * Helper struct for movement directions
 */
public struct Direction {
    public int row;
    public int col;

    public Direction(int row, int col) {
        this.row = row;
        this.col = col;
    }
}