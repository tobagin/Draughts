/**
 * test_game_piece.vala
 *
 * Unit tests for the GamePiece model class.
 * Tests piece creation, properties, promotion, and validation.
 */

using Draughts;

public class TestGamePiece : Object {

    public static void register_tests() {
        Test.add_func("/draughts/gamepiece/construction", test_piece_construction);
        Test.add_func("/draughts/gamepiece/validation", test_piece_validation);
        Test.add_func("/draughts/gamepiece/promotion", test_piece_promotion);
        Test.add_func("/draughts/gamepiece/movement_validation", test_movement_validation);
        Test.add_func("/draughts/gamepiece/equality", test_piece_equality);
        Test.add_func("/draughts/gamepiece/cloning", test_piece_cloning);
    }

    static void test_piece_construction() {
        var position = new Position(2, 3, 8);
        var piece = new GamePiece(PieceColor.RED, PieceType.MAN, position, 1);

        assert(piece.color == PieceColor.RED);
        assert(piece.type == PieceType.MAN);
        assert(piece.position.equals(position));
        assert(piece.id == 1);
        assert(!piece.is_promoted);
    }

    static void test_piece_validation() {
        // Test valid piece on dark square
        var dark_position = new Position(1, 2, 8); // Dark square
        var valid_piece = new GamePiece(PieceColor.BLACK, PieceType.MAN, dark_position, 2);
        assert(valid_piece.is_valid());

        // Test invalid piece on light square
        var light_position = new Position(1, 1, 8); // Light square
        var invalid_piece = new GamePiece(PieceColor.BLACK, PieceType.MAN, light_position, 3);
        assert(!invalid_piece.is_valid());

        // Test piece with invalid position (out of bounds)
        var invalid_position = new Position(-1, 2, 8);
        var invalid_piece2 = new GamePiece(PieceColor.RED, PieceType.MAN, invalid_position, 4);
        assert(!invalid_piece2.is_valid());
    }

    static void test_piece_promotion() {
        var position = new Position(2, 3, 8);
        var piece = new GamePiece(PieceColor.RED, PieceType.MAN, position, 5);

        // Initially not promoted
        assert(!piece.is_promoted);
        assert(piece.type == PieceType.MAN);

        // Promote to king
        piece.promote_to_king();

        assert(piece.is_promoted);
        assert(piece.type == PieceType.KING);

        // Cannot promote a king further
        piece.promote_to_king(); // Should not change anything
        assert(piece.type == PieceType.KING);
    }

    static void test_movement_validation() {
        var start_pos = new Position(2, 3, 8);
        var piece = new GamePiece(PieceColor.RED, PieceType.MAN, start_pos, 6);

        // Test valid forward diagonal move for red man
        var forward_pos = new Position(3, 4, 8);
        assert(piece.can_move_to(forward_pos));

        var forward_pos2 = new Position(3, 2, 8);
        assert(piece.can_move_to(forward_pos2));

        // Test invalid backward move for man (not king)
        var backward_pos = new Position(1, 4, 8);
        assert(!piece.can_move_to(backward_pos));

        // Test invalid non-diagonal move
        var non_diagonal = new Position(2, 4, 8);
        assert(!piece.can_move_to(non_diagonal));

        // Test king movement (after promotion)
        piece.promote_to_king();

        // King should be able to move backward
        assert(piece.can_move_to(backward_pos));

        // King should be able to move forward
        assert(piece.can_move_to(forward_pos));
    }

    static void test_piece_equality() {
        var pos1 = new Position(2, 3, 8);
        var pos2 = new Position(2, 3, 8);
        var pos3 = new Position(3, 4, 8);

        var piece1 = new GamePiece(PieceColor.RED, PieceType.MAN, pos1, 7);
        var piece2 = new GamePiece(PieceColor.RED, PieceType.MAN, pos2, 7);
        var piece3 = new GamePiece(PieceColor.BLACK, PieceType.MAN, pos1, 7);
        var piece4 = new GamePiece(PieceColor.RED, PieceType.KING, pos1, 7);
        var piece5 = new GamePiece(PieceColor.RED, PieceType.MAN, pos3, 7);
        var piece6 = new GamePiece(PieceColor.RED, PieceType.MAN, pos1, 8);

        // Test equality (same properties)
        assert(piece1.equals(piece2));

        // Test inequality
        assert(!piece1.equals(piece3)); // Different color
        assert(!piece1.equals(piece4)); // Different type
        assert(!piece1.equals(piece5)); // Different position
        assert(!piece1.equals(piece6)); // Different ID
    }

    static void test_piece_cloning() {
        var position = new Position(2, 3, 8);
        var original = new GamePiece(PieceColor.BLACK, PieceType.MAN, position, 9);

        var clone = original.clone();

        // Clone should have same properties
        assert(clone.color == original.color);
        assert(clone.type == original.type);
        assert(clone.position.equals(original.position));
        assert(clone.id == original.id);
        assert(clone.is_promoted == original.is_promoted);

        // But should be different object
        assert(clone != original);

        // Changes to clone should not affect original
        clone.promote_to_king();
        assert(original.type == PieceType.MAN);
        assert(clone.type == PieceType.KING);
    }

    static void test_piece_movement_rules() {
        // Test Red piece movement direction (moves up the board)
        var red_piece = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 10);

        // Red pieces move toward higher row numbers
        assert(red_piece.get_forward_direction() == 1);

        // Test Black piece movement direction (moves down the board)
        var black_piece = new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(5, 4, 8), 11);

        // Black pieces move toward lower row numbers
        assert(black_piece.get_forward_direction() == -1);
    }

    static void test_piece_capture_validation() {
        var position = new Position(3, 4, 8);
        var red_piece = new GamePiece(PieceColor.RED, PieceType.MAN, position, 12);

        // Test valid capture jump
        var capture_target = new Position(5, 6, 8);
        assert(red_piece.can_capture_to(capture_target));

        // Test invalid capture (too far)
        var too_far = new Position(6, 7, 8);
        assert(!red_piece.can_capture_to(too_far));

        // Test invalid capture (not diagonal)
        var not_diagonal = new Position(5, 4, 8);
        assert(!red_piece.can_capture_to(not_diagonal));
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}