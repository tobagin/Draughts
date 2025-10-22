/**
 * BoardSynchronizer.vala
 *
 * Handles synchronization between game state and board widget display.
 * Responsible for:
 * - Converting game state to board representation
 * - Updating board pieces when state changes
 * - Managing board visual state
 */

using Draughts;

public class Draughts.BoardSynchronizer : Object {

    private DraughtsBoard board_widget;
    private Logger logger;

    public BoardSynchronizer(DraughtsBoard board_widget) {
        this.board_widget = board_widget;
        this.logger = Logger.get_default();
    }

    /**
     * Synchronize the board widget to match the game state
     */
    public void sync_to_state(DraughtsGameState state) {
        logger.debug("Synchronizing board to game state");

        // Clear existing pieces from board
        board_widget.clear_board();

        // Add all pieces from current state
        foreach (var piece in state.pieces) {
            var widget_player = convert_color_to_player(piece.color);
            var widget_type = convert_piece_type(piece.piece_type);

            board_widget.add_piece(
                piece.position.row,
                piece.position.col,
                widget_player,
                widget_type
            );
        }

        // Update game state display
        var widget_state = convert_game_status(state.status);
        board_widget.set_game_state(widget_state);

        // Update active player
        var active_player = convert_color_to_player(state.active_player);
        board_widget.set_current_player(active_player);
    }

    /**
     * Update board from a specific historical state
     */
    public void update_from_state(DraughtsGameState state) {
        sync_to_state(state);
    }

    /**
     * Clear all visual indicators on the board
     */
    public void clear_all_indicators() {
        board_widget.clear_playable_pieces();
        board_widget.clear_highlights();
        board_widget.clear_hover_glow();
        board_widget.clear_preview_pieces();
    }

    /**
     * Highlight playable pieces for the current player
     */
    public void highlight_playable_pieces(Gee.HashSet<string> positions) {
        foreach (var pos_key in positions) {
            var parts = pos_key.split(",");
            if (parts.length == 2) {
                int row = int.parse(parts[0]);
                int col = int.parse(parts[1]);
                board_widget.add_playable_piece(row, col);
            }
        }
    }

    /**
     * Highlight possible move destinations
     */
    public void highlight_moves(DraughtsMove[] moves, DraughtsGameState state) {
        foreach (var move in moves) {
            board_widget.add_move_highlight(move.to_position.row, move.to_position.col);

            // Add preview piece if promotion
            if (will_promote(move, state)) {
                var player = convert_color_to_player(state.active_player);
                board_widget.add_preview_piece(
                    move.to_position.row,
                    move.to_position.col,
                    player,
                    PieceType.KING
                );
            }
        }
    }

    /**
     * Highlight a capture path
     */
    public void highlight_capture_path(DraughtsMove move) {
        // Highlight destination
        board_widget.add_move_highlight(move.to_position.row, move.to_position.col);

        // Highlight captured positions
        if (move.captured_positions != null) {
            foreach (var cap_pos in move.captured_positions) {
                board_widget.add_capture_highlight(cap_pos.row, cap_pos.col);
            }
        }
    }

    /**
     * Set the board perspective (which player is at bottom)
     */
    public void set_perspective(PieceColor color) {
        var player = convert_color_to_player(color);
        board_widget.set_player_perspective(player);
    }

    // Conversion helpers

    private Player convert_color_to_player(PieceColor color) {
        return (color == PieceColor.RED) ? Player.RED : Player.BLACK;
    }

    private PieceType convert_piece_type(DraughtsPieceType piece_type) {
        return (piece_type == DraughtsPieceType.KING) ? PieceType.KING : PieceType.MAN;
    }

    private GameState convert_game_status(GameStatus status) {
        switch (status) {
            case GameStatus.IN_PROGRESS:
                return GameState.PLAYING;
            case GameStatus.RED_WINS:
                return GameState.RED_WINS;
            case GameStatus.BLACK_WINS:
                return GameState.BLACK_WINS;
            case GameStatus.DRAW:
                return GameState.DRAW;
            default:
                return GameState.PLAYING;
        }
    }

    private bool will_promote(DraughtsMove move, DraughtsGameState state) {
        var piece = find_piece_in_state(state, move.piece_id);
        if (piece == null || piece.piece_type == DraughtsPieceType.KING) {
            return false;
        }

        int promotion_row = (state.active_player == PieceColor.RED)
            ? state.variant.board_size - 1
            : 0;

        return move.to_position.row == promotion_row;
    }

    private GamePiece? find_piece_in_state(DraughtsGameState state, int piece_id) {
        foreach (var piece in state.pieces) {
            if (piece.id == piece_id) {
                return piece;
            }
        }
        return null;
    }
}
