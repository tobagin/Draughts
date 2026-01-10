/**
 * OpeningBook.vala
 *
 * Provides opening moves for the AI to improve early game play.
 */

using Draughts;
using Gee;

public class Draughts.OpeningBook : Object {

    private HashMap<string, DraughtsMove> openings;

    public OpeningBook() {
        openings = new HashMap<string, DraughtsMove>();
        initialize_openings();
    }

    /**
     * Get a move from the opening book if available.
     * Returns null if no opening move is found for the current state.
     */
    public DraughtsMove? get_move(DraughtsGameState state) {
        // Simple hash: detecting board state by piece positions
        // Ideally we would use FEN or PDN but for this simple book, a custom string key is fine
        string key = generate_state_key(state);
        
        if (openings.has_key(key)) {
            return openings.get(key);
        }
        return null;
    }

    private void initialize_openings() {
        // Standard American Checkers Starting Position (8x8)
        // Red moves first.
        // Red pieces: rows 0,1,2.
        // Black pieces: rows 5,6,7.
        // Valid squares are "dark" squares.
        // (0,1), (0,3), (0,5), (0,7)
        // (1,0), (1,2), (1,4), (1,6)
        // (2,1), (2,3), (2,5), (2,7)
        // ... same logic for black at 5,6,7
        
        string start_key = generate_key_from_setup(8, PieceColor.RED);
        
        // Classic Move: 9-14 (in 1-32 notation)
        // In coordinates: (2,1) -> (3,2)
        // Wait, 9-14 is (2,1) to (3,2) ? 
        // 9 is row 2, col 1. 14 is row 3, col 2. (0-indexed squares 0-31)
        // Let's us (2,1) -> (3,0) or (3,2).
        // Let's pick a valid move: (2,1) -> (3,2) (9-14)
        // This is "Old Faithful" opening.
        
        // We need to create a dummy move object.
        // Ideally we'd have the move objects pre-generated or valid, but here we just return data.
        // The move needs 'from' and 'to' positions.
        var start_move = new DraughtsMove(
            0, // Dummy piece ID
            new BoardPosition(2, 1, 8),
            new BoardPosition(3, 2, 8),
            MoveType.SIMPLE
        );
        
        openings.set(start_key, start_move);
    }
    
    // Helper to generate key for standard setup without full game state object
    private string generate_key_from_setup(int size, PieceColor active_color) {
        StringBuilder sb = new StringBuilder();
        sb.append(active_color == PieceColor.RED ? "R:" : "B:");
        
        string[] grid = new string[size * size];
        for (int i = 0; i < size * size; i++) grid[i] = ".";
        
        // Place Red pieces (Standard 8x8)
        // Row 0: 1, 3, 5, 7
        // Row 1: 0, 2, 4, 6
        // Row 2: 1, 3, 5, 7
        int[] red_rows = {0, 1, 2};
        foreach (int r in red_rows) {
            for (int c = 0; c < size; c++) {
                if ((r % 2 == 0 && c % 2 != 0) || (r % 2 != 0 && c % 2 == 0)) {
                   grid[r * size + c] = "r";
                }
            }
        }
        
        // Place Black pieces
        // Row 5: 0, 2, 4, 6
        // Row 6: 1, 3, 5, 7
        // Row 7: 0, 2, 4, 6
        int[] black_rows = {5, 6, 7};
        foreach (int r in black_rows) {
            for (int c = 0; c < size; c++) {
                if ((r % 2 == 0 && c % 2 != 0) || (r % 2 != 0 && c % 2 == 0)) {
                   grid[r * size + c] = "b";
                }
            }
        }
        
        for (int i = 0; i < grid.length; i++) {
            sb.append(grid[i]);
        }
        return sb.str;
    }
    
    // Convert board to a string representation for key usage
    private string generate_state_key(DraughtsGameState state) {
        StringBuilder sb = new StringBuilder();
        sb.append(state.active_player == PieceColor.RED ? "R:" : "B:");
        
        // Create an 8x8 representation (assuming standard size for now, but dynamic is better)
        int size = state.board_size;
        string[] grid = new string[size * size];
        for (int i = 0; i < size * size; i++) grid[i] = ".";
        
        foreach (var piece in state.pieces) {
            int idx = piece.position.row * size + piece.position.col;
            if (idx >= 0 && idx < grid.length) {
                string p = piece.color == PieceColor.RED ? "r" : "b";
                if (piece.piece_type == DraughtsPieceType.KING) p = p.up();
                grid[idx] = p;
            }
        }
        
        for (int i = 0; i < grid.length; i++) {
            sb.append(grid[i]);
        }
        
        return sb.str;
    }
    
    public void add_opening(DraughtsGameState state, DraughtsMove move) {
        string key = generate_state_key(state);
        openings.set(key, move);
    }
}
