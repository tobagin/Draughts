/**
 * test_game_state.vala
 *
 * Unit tests for the GameState model class.
 * Tests game state creation, validation, piece management, and state transitions.
 */

using Draughts;

public class TestGameState : Object {

    public static void register_tests() {
        Test.add_func("/draughts/gamestate/construction", test_gamestate_construction);
        Test.add_func("/draughts/gamestate/piece_management", test_piece_management);
        Test.add_func("/draughts/gamestate/validation", test_gamestate_validation);
        Test.add_func("/draughts/gamestate/move_application", test_move_application);
        Test.add_func("/draughts/gamestate/player_turns", test_player_turns);
        Test.add_func("/draughts/gamestate/game_status", test_game_status);
        Test.add_func("/draughts/gamestate/cloning", test_gamestate_cloning);
        Test.add_func("/draughts/gamestate/hash_calculation", test_hash_calculation);
    }

    static void test_gamestate_construction() {
        var pieces = new Gee.ArrayList<GamePiece>();
        var red_piece = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(0, 1, 8), 1);
        var black_piece = new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(2, 3, 8), 2);
        pieces.add(red_piece);
        pieces.add(black_piece);

        var game_state = new GameState(pieces, PieceColor.RED, 8);

        assert(game_state.active_player == PieceColor.RED);
        assert(game_state.board_size == 8);
        assert(game_state.pieces.size == 2);
        assert(game_state.move_count == 0);
        assert(game_state.game_status == GameStatus.IN_PROGRESS);
        assert(game_state.last_move == null);
    }

    static void test_piece_management() {
        var pieces = new Gee.ArrayList<GamePiece>();
        var game_state = new GameState(pieces, PieceColor.RED, 8);

        // Test adding pieces
        var piece1 = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 2, 8), 10);
        game_state.add_piece(piece1);
        assert(game_state.pieces.size == 1);
        assert(game_state.get_piece_at(new Position(1, 2, 8)) == piece1);

        // Test removing pieces
        var piece2 = new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(3, 4, 8), 11);
        game_state.add_piece(piece2);
        assert(game_state.pieces.size == 2);

        game_state.remove_piece(piece2);
        assert(game_state.pieces.size == 1);
        assert(game_state.get_piece_at(new Position(3, 4, 8)) == null);

        // Test getting piece by ID
        assert(game_state.get_piece_by_id(10) == piece1);
        assert(game_state.get_piece_by_id(999) == null);
    }

    static void test_gamestate_validation() {
        var pieces = new Gee.ArrayList<GamePiece>();

        // Test valid state
        var piece1 = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 2, 8), 1);
        var piece2 = new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(3, 4, 8), 2);
        pieces.add(piece1);
        pieces.add(piece2);

        var valid_state = new GameState(pieces, PieceColor.RED, 8);
        assert(valid_state.is_valid());

        // Test invalid state - overlapping pieces
        var piece3 = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 2, 8), 3); // Same position as piece1
        pieces.add(piece3);
        var invalid_state = new GameState(pieces, PieceColor.RED, 8);
        assert(!invalid_state.is_valid());

        // Test invalid state - piece on light square
        pieces.clear();
        var invalid_piece = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(0, 0, 8), 4); // Light square
        pieces.add(invalid_piece);
        var invalid_state2 = new GameState(pieces, PieceColor.RED, 8);
        assert(!invalid_state2.is_valid());
    }

    static void test_move_application() {
        var pieces = new Gee.ArrayList<GamePiece>();
        var piece = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 5);
        pieces.add(piece);

        var game_state = new GameState(pieces, PieceColor.RED, 8);

        // Test simple move
        var from_pos = new Position(2, 3, 8);
        var to_pos = new Position(3, 4, 8);
        var move = new Move(5, from_pos, to_pos, MoveType.SIMPLE);

        var new_state = game_state.apply_move(move);

        // Original state should be unchanged
        assert(game_state.get_piece_at(from_pos) == piece);
        assert(game_state.get_piece_at(to_pos) == null);

        // New state should have piece moved
        assert(new_state.get_piece_at(from_pos) == null);
        assert(new_state.get_piece_at(to_pos) != null);
        assert(new_state.get_piece_at(to_pos).id == 5);
        assert(new_state.active_player == PieceColor.BLACK); // Turn switched
        assert(new_state.move_count == 1);
        assert(new_state.last_move.equals(move));
    }

    static void test_player_turns() {
        var pieces = new Gee.ArrayList<GamePiece>();
        var game_state = new GameState(pieces, PieceColor.RED, 8);

        // Test turn switching
        assert(game_state.active_player == PieceColor.RED);

        game_state.switch_active_player();
        assert(game_state.active_player == PieceColor.BLACK);

        game_state.switch_active_player();
        assert(game_state.active_player == PieceColor.RED);

        // Test move count increment
        assert(game_state.move_count == 0);
        game_state.increment_move_count();
        assert(game_state.move_count == 1);
    }

    static void test_game_status() {
        var pieces = new Gee.ArrayList<GamePiece>();
        var game_state = new GameState(pieces, PieceColor.RED, 8);

        // Test initial status
        assert(game_state.game_status == GameStatus.IN_PROGRESS);

        // Test status changes
        game_state.set_game_status(GameStatus.RED_WINS);
        assert(game_state.game_status == GameStatus.RED_WINS);
        assert(game_state.is_game_over());

        game_state.set_game_status(GameStatus.DRAW, DrawReason.STALEMATE);
        assert(game_state.game_status == GameStatus.DRAW);
        assert(game_state.draw_reason == DrawReason.STALEMATE);
        assert(game_state.is_game_over());

        game_state.set_game_status(GameStatus.IN_PROGRESS);
        assert(!game_state.is_game_over());
    }

    static void test_gamestate_cloning() {
        var pieces = new Gee.ArrayList<GamePiece>();
        var piece1 = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(1, 2, 8), 10);
        var piece2 = new GamePiece(PieceColor.BLACK, PieceType.KING, new Position(5, 6, 8), 11);
        pieces.add(piece1);
        pieces.add(piece2);

        var original = new GameState(pieces, PieceColor.BLACK, 8);
        original.set_move_count(5);

        var clone = original.clone();

        // Test that clone has same properties
        assert(clone.active_player == original.active_player);
        assert(clone.board_size == original.board_size);
        assert(clone.move_count == original.move_count);
        assert(clone.game_status == original.game_status);
        assert(clone.pieces.size == original.pieces.size);

        // Test that pieces are cloned, not referenced
        assert(clone.pieces[0] != original.pieces[0]);
        assert(clone.pieces[0].id == original.pieces[0].id);
        assert(clone.pieces[0].color == original.pieces[0].color);

        // Test that modifications to clone don't affect original
        clone.switch_active_player();
        clone.increment_move_count();

        assert(clone.active_player != original.active_player);
        assert(clone.move_count != original.move_count);
    }

    static void test_hash_calculation() {
        var pieces1 = new Gee.ArrayList<GamePiece>();
        var piece1 = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1);
        pieces1.add(piece1);

        var pieces2 = new Gee.ArrayList<GamePiece>();
        var piece2 = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(2, 3, 8), 1);
        pieces2.add(piece2);

        var state1 = new GameState(pieces1, PieceColor.RED, 8);
        var state2 = new GameState(pieces2, PieceColor.RED, 8);

        // Identical states should have same hash
        assert(state1.calculate_board_hash() == state2.calculate_board_hash());

        // Different states should have different hashes
        state2.switch_active_player();
        assert(state1.calculate_board_hash() != state2.calculate_board_hash());

        // Moving a piece should change hash
        var state3 = state1.clone();
        var move = new Move(1, new Position(2, 3, 8), new Position(3, 4, 8), MoveType.SIMPLE);
        var state4 = state3.apply_move(move);
        assert(state1.calculate_board_hash() != state4.calculate_board_hash());
    }

    static void test_piece_counting() {
        var pieces = new Gee.ArrayList<GamePiece>();

        // Add red pieces
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(0, 1, 8), 1));
        pieces.add(new GamePiece(PieceColor.RED, PieceType.MAN, new Position(0, 3, 8), 2));
        pieces.add(new GamePiece(PieceColor.RED, PieceType.KING, new Position(2, 1, 8), 3));

        // Add black pieces
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.MAN, new Position(5, 2, 8), 4));
        pieces.add(new GamePiece(PieceColor.BLACK, PieceType.KING, new Position(7, 4, 8), 5));

        var game_state = new GameState(pieces, PieceColor.RED, 8);

        // Test piece counting
        assert(game_state.count_pieces(PieceColor.RED) == 3);
        assert(game_state.count_pieces(PieceColor.BLACK) == 2);
        assert(game_state.count_pieces(PieceColor.RED, PieceType.MAN) == 2);
        assert(game_state.count_pieces(PieceColor.RED, PieceType.KING) == 1);
        assert(game_state.count_pieces(PieceColor.BLACK, PieceType.MAN) == 1);
        assert(game_state.count_pieces(PieceColor.BLACK, PieceType.KING) == 1);
    }

    static void test_position_queries() {
        var pieces = new Gee.ArrayList<GamePiece>();
        var piece = new GamePiece(PieceColor.RED, PieceType.MAN, new Position(3, 4, 8), 10);
        pieces.add(piece);

        var game_state = new GameState(pieces, PieceColor.RED, 8);

        // Test position occupancy
        assert(game_state.is_position_occupied(new Position(3, 4, 8)));
        assert(!game_state.is_position_occupied(new Position(3, 2, 8)));

        // Test position emptiness
        assert(!game_state.is_position_empty(new Position(3, 4, 8)));
        assert(game_state.is_position_empty(new Position(3, 2, 8)));

        // Test getting all pieces of a color
        var red_pieces = game_state.get_pieces_by_color(PieceColor.RED);
        assert(red_pieces.size == 1);
        assert(red_pieces[0] == piece);

        var black_pieces = game_state.get_pieces_by_color(PieceColor.BLACK);
        assert(black_pieces.size == 0);
    }

    public static int main(string[] args) {
        Test.init(ref args);
        register_tests();
        return Test.run();
    }
}