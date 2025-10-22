/**
 * MoveHandler.vala
 *
 * Handles user move input and validation.
 * Responsible for:
 * - Processing square clicks
 * - Validating move legality
 * - Managing piece selection state
 * - Handling multi-jump sequences
 */

using Draughts;

public class Draughts.MoveHandler : Object {

    private IGameController game_controller;
    private BoardSynchronizer synchronizer;
    private Logger logger;

    // Selection state
    private BoardPosition? selected_position = null;
    private DraughtsMove[]? available_moves_for_selection = null;

    // Signals
    public signal void move_selected(DraughtsMove move);
    public signal void selection_changed(BoardPosition? position);

    public MoveHandler(IGameController game_controller, BoardSynchronizer synchronizer) {
        this.game_controller = game_controller;
        this.synchronizer = synchronizer;
        this.logger = Logger.get_default();
    }

    /**
     * Handle a square click from the user
     */
    public void handle_square_click(int row, int col, DraughtsGameState state) {
        var clicked_pos = new BoardPosition(row, col, state.variant.board_size);

        logger.debug("Square clicked: (%d, %d)", row, col);

        // Check if this is a destination square for the selected piece
        if (selected_position != null && available_moves_for_selection != null) {
            var move = find_move_to_destination(clicked_pos);
            if (move != null) {
                logger.debug("Valid move selected");
                execute_move(move);
                return;
            }
        }

        // Check if clicking a new piece to select
        var piece = find_piece_at_position(state, clicked_pos);
        if (piece != null && piece.color == state.active_player) {
            select_piece(clicked_pos, state);
        } else {
            // Deselect if clicking empty square or opponent piece
            clear_selection();
        }
    }

    /**
     * Select a piece and show its available moves
     */
    private void select_piece(BoardPosition position, DraughtsGameState state) {
        logger.debug("Selecting piece at (%d, %d)", position.row, position.col);

        // Get legal moves for this piece
        var all_moves = game_controller.get_legal_moves(state);
        var piece_moves = new Gee.ArrayList<DraughtsMove>();

        foreach (var move in all_moves) {
            if (move.from_position.equals(position)) {
                piece_moves.add(move);
            }
        }

        if (piece_moves.size == 0) {
            logger.debug("No legal moves for this piece");
            clear_selection();
            return;
        }

        // Update selection state
        selected_position = position;
        available_moves_for_selection = piece_moves.to_array();

        // Update board display
        synchronizer.clear_all_indicators();

        // Check if these are capture moves
        bool has_captures = false;
        foreach (var move in available_moves_for_selection) {
            if (move.is_capture()) {
                has_captures = true;
                break;
            }
        }

        // Highlight appropriately
        if (has_captures) {
            // For captures, show the capture paths
            foreach (var move in available_moves_for_selection) {
                synchronizer.highlight_capture_path(move);
            }
        } else {
            // For regular moves, just show destinations
            synchronizer.highlight_moves(available_moves_for_selection, state);
        }

        selection_changed(selected_position);
    }

    /**
     * Clear the current selection
     */
    public void clear_selection() {
        selected_position = null;
        available_moves_for_selection = null;
        synchronizer.clear_all_indicators();
        selection_changed(null);
    }

    /**
     * Find a move that goes to the specified destination
     */
    private DraughtsMove? find_move_to_destination(BoardPosition destination) {
        if (available_moves_for_selection == null) {
            return null;
        }

        foreach (var move in available_moves_for_selection) {
            if (move.to_position.equals(destination)) {
                return move;
            }
        }

        return null;
    }

    /**
     * Execute the selected move
     */
    private void execute_move(DraughtsMove move) {
        logger.info("Executing move: %s", move.to_algebraic_notation());

        clear_selection();
        move_selected(move);
    }

    /**
     * Get legal moves for a specific position
     */
    public DraughtsMove[] get_moves_for_position(BoardPosition position, DraughtsGameState state) {
        var all_moves = game_controller.get_legal_moves(state);
        var piece_moves = new Gee.ArrayList<DraughtsMove>();

        foreach (var move in all_moves) {
            if (move.from_position.equals(position)) {
                piece_moves.add(move);
            }
        }

        return piece_moves.to_array();
    }

    /**
     * Get all positions that have playable pieces
     */
    public Gee.HashSet<string> get_playable_positions(DraughtsGameState state) {
        var positions = new Gee.HashSet<string>();
        var legal_moves = game_controller.get_legal_moves(state);

        foreach (var move in legal_moves) {
            string key = @"$(move.from_position.row),$(move.from_position.col)";
            positions.add(key);
        }

        return positions;
    }

    /**
     * Check if a move is legal
     */
    public bool is_move_legal(DraughtsMove move, DraughtsGameState state) {
        var legal_moves = game_controller.get_legal_moves(state);

        foreach (var legal_move in legal_moves) {
            if (moves_equal(move, legal_move)) {
                return true;
            }
        }

        return false;
    }

    // Helper methods

    private GamePiece? find_piece_at_position(DraughtsGameState state, BoardPosition pos) {
        foreach (var piece in state.pieces) {
            if (piece.position.equals(pos)) {
                return piece;
            }
        }
        return null;
    }

    private bool moves_equal(DraughtsMove m1, DraughtsMove m2) {
        return m1.from_position.equals(m2.from_position) &&
               m1.to_position.equals(m2.to_position);
    }
}
