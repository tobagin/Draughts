/**
 * GameState.vala
 *
 * Represents the complete state of a draughts game at any point in time.
 * Handles piece management, move application, and state validation.
 */

using Draughts;

public class Draughts.DraughtsGameState : Object {
    public Gee.ArrayList<GamePiece> pieces { get; private set; }
    public PieceColor active_player { get; private set; }
    public int move_count;
    public DraughtsMove? last_move { get; private set; }
    public GameStatus game_status;
    public DrawReason? draw_reason;
    public int board_size { get; private set; }
    private string? _board_hash;

    public DraughtsGameState(Gee.ArrayList<GamePiece> pieces, PieceColor active_player, int board_size) {
        this.pieces = new Gee.ArrayList<GamePiece>();
        foreach (var piece in pieces) {
            this.pieces.add(piece.clone());
        }
        this.active_player = active_player;
        this.board_size = board_size;
        this.move_count = 0;
        this.last_move = null;
        this.game_status = GameStatus.IN_PROGRESS;
        this.draw_reason = null;
        this._board_hash = null;
    }

    /**
     * Add a piece to the game state
     */
    public void add_piece(GamePiece piece) {
        pieces.add(piece);
        invalidate_hash();
    }

    /**
     * Remove a piece from the game state
     */
    public void remove_piece(GamePiece piece) {
        pieces.remove(piece);
        invalidate_hash();
    }

    /**
     * Get piece at specified position
     */
    public GamePiece? get_piece_at(BoardPosition position) {
        foreach (var piece in pieces) {
            if (piece.position.equals(position)) {
                return piece;
            }
        }
        return null;
    }

    /**
     * Get piece by ID
     */
    public GamePiece? get_piece_by_id(int id) {
        foreach (var piece in pieces) {
            if (piece.id == id) {
                return piece;
            }
        }
        return null;
    }

    /**
     * Check if position is occupied
     */
    public bool is_position_occupied(BoardPosition position) {
        return get_piece_at(position) != null;
    }

    /**
     * Check if position is empty
     */
    public bool is_position_empty(BoardPosition position) {
        return get_piece_at(position) == null;
    }

    /**
     * Get all pieces of specified color
     */
    public Gee.ArrayList<GamePiece> get_pieces_by_color(PieceColor color) {
        var result = new Gee.ArrayList<GamePiece>();
        foreach (var piece in pieces) {
            if (piece.color == color) {
                result.add(piece);
            }
        }
        return result;
    }

    /**
     * Count pieces of specified color and optionally type
     */
    public int count_pieces(PieceColor color, DraughtsPieceType? type = null) {
        int count = 0;
        foreach (var piece in pieces) {
            if (piece.color == color && (type == null || piece.piece_type == type)) {
                count++;
            }
        }
        return count;
    }

    /**
     * Switch the active player
     */
    public void switch_active_player() {
        active_player = active_player.get_opposite();
    }

    /**
     * Increment the move count
     */
    public void increment_move_count() {
        move_count++;
    }

    /**
     * Set move count to specific value
     */
    public void set_move_count(int count) {
        move_count = count;
    }

    /**
     * Set game status
     */
    public void set_game_status(GameStatus status, DrawReason? reason = null) {
        game_status = status;
        draw_reason = reason;
    }

    /**
     * Check if game is over
     */
    public bool is_game_over() {
        return game_status != GameStatus.IN_PROGRESS;
    }

    /**
     * Apply a move and return new game state
     */
    public DraughtsGameState apply_move(DraughtsMove move) {
        var new_state = this.clone();

        // Get the piece being moved
        var moving_piece = new_state.get_piece_by_id(move.piece_id);
        if (moving_piece == null) {
            warning("Piece with ID %d not found", move.piece_id);
            foreach (var p in new_state.pieces) {
            }
            return new_state;
        }

        // Remove captured pieces
        foreach (int captured_id in move.captured_pieces) {
            var captured_piece = new_state.get_piece_by_id(captured_id);
            if (captured_piece != null) {
                new_state.remove_piece(captured_piece);
            }
        }

        // Move the piece
        moving_piece.move_to(move.to_position);

        // Handle promotion
        if (move.promoted) {
            var logger = Logger.get_default();
            logger.debug("=== PIECE PROMOTION ===");
            logger.debug("Promoting piece at (%d,%d) to KING", moving_piece.position.row, moving_piece.position.col);
            logger.debug("Color: %s", moving_piece.color.to_string());
            logger.debug("======================");
            moving_piece.promote_to_king();
        }

        // Update game state
        new_state.switch_active_player();
        new_state.increment_move_count();
        new_state.last_move = move.clone();

        return new_state;
    }

    /**
     * Check if this game state is valid
     */
    public bool is_valid() {
        // Check for overlapping pieces
        for (int i = 0; i < pieces.size; i++) {
            for (int j = i + 1; j < pieces.size; j++) {
                if (pieces[i].position.equals(pieces[j].position)) {
                    return false;
                }
            }
        }

        // Check that all pieces are on valid dark squares
        foreach (var piece in pieces) {
            if (!piece.is_valid()) {
                return false;
            }
        }

        return true;
    }

    /**
     * Create a copy of this game state
     */
    public DraughtsGameState clone() {
        var cloned_pieces = new Gee.ArrayList<GamePiece>();
        foreach (var piece in pieces) {
            cloned_pieces.add(piece.clone());
        }

        var clone = new DraughtsGameState(cloned_pieces, active_player, board_size);
        clone.move_count = this.move_count;
        clone.game_status = this.game_status;
        clone.draw_reason = this.draw_reason;
        if (this.last_move != null) {
            clone.last_move = this.last_move.clone();
        }

        return clone;
    }

    /**
     * Calculate hash for position (for repetition detection)
     */
    public string calculate_board_hash() {
        if (_board_hash != null) {
            return _board_hash;
        }

        var hash_builder = new StringBuilder();

        // Sort pieces by position for consistent hashing
        var sorted_pieces = new Gee.ArrayList<GamePiece>();
        sorted_pieces.add_all(pieces);
        sorted_pieces.sort((a, b) => {
            if (a.position.row != b.position.row) {
                return a.position.row - b.position.row;
            }
            return a.position.col - b.position.col;
        });

        // Build hash from piece positions and types
        foreach (var piece in sorted_pieces) {
            hash_builder.append(@"$(piece.color)$(piece.piece_type)$(piece.position.row)$(piece.position.col)");
        }

        // Include active player in hash
        hash_builder.append(active_player.to_string());

        _board_hash = Checksum.compute_for_string(ChecksumType.MD5, hash_builder.str);
        return _board_hash;
    }

    /**
     * Invalidate cached hash
     */
    private void invalidate_hash() {
        _board_hash = null;
    }

    /**
     * Get string representation of the game state
     */
    public string to_string() {
        var str = new StringBuilder();
        str.append("DraughtsGameState: %s to move, Move %d\n".printf(active_player.to_string(), move_count));
        str.append(@"Status: $(game_status)");
        if (draw_reason != null) {
            str.append(@" ($(draw_reason))");
        }
        str.append("\nPieces:\n");

        foreach (var piece in pieces) {
            str.append(@"  $(piece.to_string())\n");
        }

        return str.str;
    }

    /**
     * Get a visual representation of the board
     */
    public string get_board_visual() {
        var visual = new StringBuilder();

        for (int row = board_size - 1; row >= 0; row--) {
            visual.append(@"$(row + 1) ");

            for (int col = 0; col < board_size; col++) {
                var pos = new BoardPosition(row, col, board_size);
                var piece = get_piece_at(pos);

                if (piece != null) {
                    visual.append(piece.get_unicode_symbol());
                } else if (pos.is_dark_square()) {
                    visual.append("·");
                } else {
                    visual.append(" ");
                }

                visual.append(" ");
            }

            visual.append("\n");
        }

        visual.append("  ");
        for (int col = 0; col < board_size; col++) {
            visual.append(@"$((char)('a' + col)) ");
        }
        visual.append("\n");

        return visual.str;
    }

    /**
     * Check if there are any legal moves for the active player
     */
    public bool has_legal_moves() {
        // This will be implemented when we have the rule engines
        // For now, just check if the player has pieces
        return count_pieces(active_player) > 0;
    }

    /**
     * Get game statistics
     */
    public GameStats get_statistics() {
        return new GameStats(
            count_pieces(PieceColor.RED),
            count_pieces(PieceColor.BLACK),
            count_pieces(PieceColor.RED, DraughtsPieceType.KING),
            count_pieces(PieceColor.BLACK, DraughtsPieceType.KING),
            move_count
        );
    }
}

/**
 * Game statistics structure
 */
public class GameStats : Object {
    public int red_pieces { get; private set; }
    public int black_pieces { get; private set; }
    public int red_kings { get; private set; }
    public int black_kings { get; private set; }
    public int total_moves { get; private set; }

    // Alternative property names for compatibility
    public int red_piece_count { get { return red_pieces; } }
    public int black_piece_count { get { return black_pieces; } }
    public int red_king_count { get { return red_kings; } }
    public int black_king_count { get { return black_kings; } }

    public GameStats(int red_pieces, int black_pieces, int red_kings, int black_kings, int move_count) {
        this.red_pieces = red_pieces;
        this.black_pieces = black_pieces;
        this.red_kings = red_kings;
        this.black_kings = black_kings;
        this.total_moves = move_count;
    }
}