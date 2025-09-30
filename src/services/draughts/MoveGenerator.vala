/**
 * MoveGenerator.vala
 *
 * Generates legal moves for draughts pieces.
 */

using Draughts;

public class Draughts.MoveGenerator : Object {
    public DraughtsMove[] generate_simple_moves(DraughtsGameState state) {
        return new DraughtsMove[0]; // Stub implementation
    }

    public DraughtsMove[] generate_capture_moves(DraughtsGameState state) {
        return new DraughtsMove[0]; // Stub implementation
    }

    public DraughtsMove[] generate_moves_for_piece(DraughtsGameState state, GamePiece piece) {
        return new DraughtsMove[0]; // Stub implementation
    }

    public DraughtsMove[] generate_all_legal_moves(DraughtsGameState state, bool mandatory_captures) {
        return new DraughtsMove[0]; // Stub implementation
    }
}