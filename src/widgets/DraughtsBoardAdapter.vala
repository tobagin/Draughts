/**
 * DraughtsBoardAdapter.vala
 *
 * Adapter class that bridges the existing DraughtsBoard widget
 * with the new comprehensive draughts game engine.
 * Handles conversion between old and new data models.
 */

using Draughts;

public class Draughts.DraughtsBoardAdapter : Object {
    private DraughtsBoard board_widget;
    private Game? current_game;
    private IGameController? game_controller;
    private GameVariant? current_variant;
    private Logger logger;
    private bool ai_move_in_progress = false;
    private bool is_viewing_history = false;  // Track if we're viewing history
    private int current_view_position = -1;   // Track which position we're viewing

    // Animation state
    private bool is_animating = false;
    private DraughtsMove? pending_move = null;
    private bool pending_move_is_ai = false;
    private DraughtsMove[]? multi_jump_sequence = null;
    private int multi_jump_index = 0;

    // Signal for game events
    public signal void game_state_changed(DraughtsGameState new_state);
    public signal void move_made(DraughtsMove move);
    public signal void game_finished(GameStatus result);

    public DraughtsBoardAdapter(DraughtsBoard board_widget) {
        this.logger = Logger.get_default();
        this.board_widget = board_widget;

        // Initialize default variant (American Checkers)
        this.current_variant = new GameVariant(DraughtsVariant.AMERICAN);

        // Create game controller
        this.game_controller = new GameController();

        // Set board widget to external mode so we handle moves
        board_widget.set_external_mode(true);

        // Connect signals
        setup_signals();
    }

    private void setup_signals() {
        // Connect game controller signals
        if (game_controller != null) {
            game_controller.game_state_changed.connect(on_engine_state_changed);
            game_controller.game_finished.connect(on_engine_game_finished);
        }

        // Connect board widget signals for user interactions
        board_widget.square_clicked.connect(on_board_square_clicked);
        board_widget.animation_completed.connect(on_animation_completed);
    }

    /**
     * Start a new game with the specified variant
     */
    public void start_new_game(DraughtsVariant variant) {
        var red_player = GamePlayer.create_default_human(PieceColor.RED);
        var black_player = GamePlayer.create_default_human(PieceColor.BLACK);

        current_variant = new GameVariant(variant);
        current_game = game_controller.start_new_game(current_variant, red_player, black_player, null);

        // DEBUG: Print ruleset configuration
        logger.debug("=== STARTING NEW GAME ===");
        logger.debug("Variant: %s (%s)", variant.to_string(), current_variant.display_name);
        logger.debug("Board size: %dx%d", current_variant.board_size, current_variant.board_size);
        logger.debug("Kings can fly: %s", current_variant.kings_can_fly.to_string());
        logger.debug("Men can capture backwards: %s", current_variant.men_can_capture_backwards.to_string());
        logger.debug("Mandatory capture: %s", current_variant.mandatory_capture.to_string());
        logger.debug("Capture priority: %s", current_variant.capture_priority.to_string());
        logger.debug("========================");

        // Update the board widget to match the game state
        sync_board_to_game_state();

        // Set board perspective (always RED for 2-player games)
        board_widget.set_player_perspective(Player.RED);
    }

    /**
     * Start a new game with the specified variant and player configuration
     */
    public void start_new_game_with_mode(DraughtsVariant variant, bool is_human_vs_ai) {
        var red_player = GamePlayer.create_default_human(PieceColor.RED);
        GamePlayer black_player;

        if (is_human_vs_ai) {
            // Get AI difficulty from settings
            var settings_manager = SettingsManager.get_instance();
            var ai_difficulty = settings_manager.get_ai_difficulty();
            logger.debug("DraughtsBoardAdapter: Retrieved AI difficulty from settings: %s", ai_difficulty.to_string());
            black_player = GamePlayer.create_default_ai(PieceColor.BLACK, ai_difficulty);
        } else {
            black_player = GamePlayer.create_default_human(PieceColor.BLACK);
        }

        current_variant = new GameVariant(variant);
        current_game = game_controller.start_new_game(current_variant, red_player, black_player, null);

        // DEBUG: Print ruleset configuration
        logger.debug("=== STARTING NEW GAME WITH MODE ===");
        logger.debug("Variant: %s (%s)", variant.to_string(), current_variant.display_name);
        logger.debug("Board size: %dx%d", current_variant.board_size, current_variant.board_size);
        logger.debug("Red Player: %s", red_player.player_type.to_string());
        logger.debug("Black Player: %s%s", black_player.player_type.to_string(),
            black_player.player_type == PlayerType.AI ? @" (Difficulty: $(black_player.ai_difficulty.to_string()))" : "");
        logger.debug("Kings can fly: %s", current_variant.kings_can_fly.to_string());
        logger.debug("Men can capture backwards: %s", current_variant.men_can_capture_backwards.to_string());
        logger.debug("Mandatory capture: %s", current_variant.mandatory_capture.to_string());
        logger.debug("Capture priority: %s", current_variant.capture_priority.to_string());
        logger.debug("===================================");

        // Update the board widget to match the game state
        sync_board_to_game_state();

        // Set board perspective (always RED for human vs AI with black AI)
        board_widget.set_player_perspective(Player.RED);

        // Check if the first player (red) is AI and should make the opening move
        check_ai_turn();
    }

    /**
     * Start a new game with full configuration including time limits
     */
    public void start_new_game_with_configuration(
        DraughtsVariant variant,
        bool is_human_vs_ai,
        PieceColor human_color,
        AIDifficulty ai_difficulty,
        bool use_time_limit,
        int minutes_per_side,
        int increment_seconds,
        string clock_type
    ) {
        GamePlayer red_player;
        GamePlayer black_player;

        if (is_human_vs_ai) {
            // Configure players based on human color selection
            if (human_color == PieceColor.RED) {
                red_player = GamePlayer.create_default_human(PieceColor.RED);
                black_player = GamePlayer.create_default_ai(PieceColor.BLACK, ai_difficulty);
            } else {
                red_player = GamePlayer.create_default_ai(PieceColor.RED, ai_difficulty);
                black_player = GamePlayer.create_default_human(PieceColor.BLACK);
            }
        } else {
            // Both players are human
            red_player = GamePlayer.create_default_human(PieceColor.RED);
            black_player = GamePlayer.create_default_human(PieceColor.BLACK);
        }

        // Configure time control if enabled
        Timer? timer_config = null;
        if (use_time_limit) {
            TimeSpan base_time = TimeSpan.SECOND * (minutes_per_side * 60);
            TimeSpan increment_time = TimeSpan.SECOND * increment_seconds;

            if (clock_type == "Fischer") {
                timer_config = new Timer.fischer(base_time, increment_time);
            } else {
                // Bronstein uses delay mode
                timer_config = new Timer.with_delay(base_time, increment_time);
            }
        }

        current_variant = new GameVariant(variant);
        current_game = game_controller.start_new_game(current_variant, red_player, black_player, timer_config);

        // DEBUG: Print game configuration
        logger.debug("=== STARTING NEW GAME WITH FULL CONFIGURATION ===");
        logger.debug("Variant: %s (%s)", variant.to_string(), current_variant.display_name);
        logger.debug("Board size: %dx%d", current_variant.board_size, current_variant.board_size);
        logger.debug("Red Player: %s%s", red_player.player_type.to_string(),
            red_player.player_type == PlayerType.AI ? @" (Difficulty: $(red_player.ai_difficulty.to_string()))" : "");
        logger.debug("Black Player: %s%s", black_player.player_type.to_string(),
            black_player.player_type == PlayerType.AI ? @" (Difficulty: $(black_player.ai_difficulty.to_string()))" : "");
        logger.debug("Time Control: %s", use_time_limit ? @"$minutes_per_side min + $increment_seconds sec ($clock_type)" : "None");
        logger.debug("Kings can fly: %s", current_variant.kings_can_fly.to_string());
        logger.debug("Men can capture backwards: %s", current_variant.men_can_capture_backwards.to_string());
        logger.debug("Mandatory capture: %s", current_variant.mandatory_capture.to_string());
        logger.debug("Capture priority: %s", current_variant.capture_priority.to_string());
        logger.debug("================================================");

        // Update the board widget to match the game state
        sync_board_to_game_state();

        // Set board perspective based on human player color
        if (is_human_vs_ai) {
            Player perspective = (human_color == PieceColor.RED) ? Player.RED : Player.BLACK;
            board_widget.set_player_perspective(perspective);
        } else {
            // For human vs human, default to RED
            board_widget.set_player_perspective(Player.RED);
        }

        // Check if the first player (red) is AI and should make the opening move
        check_ai_turn();
    }

    /**
     * Handle moves from the board widget clicks
     */
    public bool handle_board_move(int from_row, int from_col, int to_row, int to_col) {

        if (current_game == null) {
            return false;
        }

        try {
            // Convert board coordinates to our engine's position system
            var from_pos = new BoardPosition(from_row, from_col, current_variant.board_size);
            var to_pos = new BoardPosition(to_row, to_col, current_variant.board_size);

            // Get current game state
            var current_state = game_controller.get_current_state();

            var piece = find_piece_at_position(current_state, from_pos);

            if (piece == null) {
                return false;
            }

            // Ensure it's the correct player's turn
            if (piece.color != current_state.active_player) {
                return false;
            }

            // Find the legal move that matches this from/to position
            var game = game_controller.get_current_game();
            var rule_engine = game.variant.create_rule_engine();
            var legal_moves = rule_engine.generate_legal_moves(current_state);

            DraughtsMove? matching_move = null;
            foreach (var move in legal_moves) {
                if (move.piece_id == piece.id &&
                    move.from_position.equals(from_pos) &&
                    move.to_position.equals(to_pos)) {
                    matching_move = move;
                    break;
                }
            }

            if (matching_move == null) {
                return false;
            }

            // Start animation and store move for completion after animation
            start_move_animation(matching_move);
            return true;

        } catch (Error e) {
            warning("Error handling board move: %s", e.message);
        }

        return false;
    }

    /**
     * Sync the visual board widget with the current game engine state
     */
    private void sync_board_to_game_state() {
        if (current_game == null) {
            return;
        }

        var current_state = game_controller.get_current_state();
        print("\n==== ADAPTER: sync_board_to_game_state called ====\n");
        print("Active player: %s\n", current_state.active_player.to_string());
        print("Pieces (showing piece 12 only):\n");
        foreach (var piece in current_state.pieces) {
            if (piece.id == 12) {
                print("  Piece ID %d %s at (%d,%d)\n", piece.id, piece.color.to_string(),
                      piece.position.row, piece.position.col);
            }
        }
        print("====================================\n\n");

        // Clear the board widget's state
        board_widget.clear_board();

        // Set each piece from our comprehensive system to the widget's format
        foreach (var piece in current_state.pieces) {
            var widget_piece_type = convert_piece_to_widget_type(piece);
            board_widget.set_piece_at(piece.position.row, piece.position.col, widget_piece_type);
        }

        // Update current player
        var current_player = convert_color_to_player(current_state.active_player);
        board_widget.set_current_player(current_player);

        // Update game state
        var widget_game_state = convert_game_status_to_widget_state(current_state.game_status);
        board_widget.set_game_state(widget_game_state);

        // Trigger the board widget to redraw
        board_widget.update_board_display();

        // Highlight playable pieces for the current player
        // Use a small delay to ensure the board is fully updated
        Idle.add(() => {
            highlight_playable_pieces();
            return false;
        });
    }

    /**
     * Find a game piece at the specified position
     */
    private GamePiece? find_piece_at_position(DraughtsGameState state, BoardPosition pos) {
        foreach (var piece in state.pieces) {
            if (piece.position.equals(pos)) {
                return piece;
            }
        }
        return null;
    }

    /**
     * Convert our engine's piece color to board widget player enum
     */
    private Draughts.Player convert_color_to_player(PieceColor color) {
        switch (color) {
            case PieceColor.RED:
                return Draughts.Player.RED;
            case PieceColor.BLACK:
                return Draughts.Player.BLACK;
            default:
                return Draughts.Player.RED;
        }
    }

    /**
     * Convert our engine's piece to board widget piece type
     */
    private Draughts.PieceType convert_piece_to_widget_type(GamePiece piece) {
        if (piece.color == PieceColor.RED) {
            return piece.piece_type == DraughtsPieceType.KING ?
                Draughts.PieceType.RED_KING : Draughts.PieceType.RED_REGULAR;
        } else {
            return piece.piece_type == DraughtsPieceType.KING ?
                Draughts.PieceType.BLACK_KING : Draughts.PieceType.BLACK_REGULAR;
        }
    }

    /**
     * Convert our engine's game status to widget game state
     */
    private Draughts.GameState convert_game_status_to_widget_state(GameStatus status) {
        switch (status) {
            case GameStatus.RED_WIN:
                return Draughts.GameState.RED_WINS;
            case GameStatus.BLACK_WIN:
                return Draughts.GameState.BLACK_WINS;
            case GameStatus.DRAW:
                return Draughts.GameState.DRAW;
            case GameStatus.IN_PROGRESS:
            case GameStatus.ACTIVE:
                return Draughts.GameState.PLAYING;
            default:
                return Draughts.GameState.WAITING; // For NOT_STARTED and other states
        }
    }

    /**
     * Handle animation completion
     */
    private void on_animation_completed() {
        logger.debug("Animation completed");
        is_animating = false;

        // Check if we're in a multi-jump sequence
        if (multi_jump_sequence != null) {
            multi_jump_index++;

            // If there are more segments to animate, continue
            if (multi_jump_index < multi_jump_sequence.length) {
                is_animating = true;
                animate_next_jump_segment();
                return;
            }

            // All segments animated, clear the sequence and proceed with move completion
            logger.debug("Multi-jump animation complete");
            multi_jump_sequence = null;
            multi_jump_index = 0;
        }

        // If we have a pending move, complete it now
        if (pending_move != null) {
            var move = pending_move;
            bool was_ai_move = pending_move_is_ai;
            pending_move = null;
            pending_move_is_ai = false;

            if (was_ai_move) {
                complete_ai_move_execution(move);
            } else {
                complete_move_execution(move);
            }
        }
    }

    /**
     * Handle clicks from the board widget
     */
    private Position? selected_square = null;
    private BoardPosition? multi_capture_position = null;  // Position of piece that must continue capturing
    private int64 last_click_time = 0;
    private int last_click_row = -1;
    private int last_click_col = -1;

    private void on_board_square_clicked(int row, int col) {

        // Debounce duplicate clicks - ignore clicks on same square within 100ms
        int64 current_time = get_monotonic_time();
        if (last_click_row == row && last_click_col == col &&
            (current_time - last_click_time) < 100000) { // 100ms in microseconds
            return;
        }

        last_click_time = current_time;
        last_click_row = row;
        last_click_col = col;

        // Block clicks during animation
        if (is_animating) {
            logger.debug("Ignoring click while animation in progress");
            return;
        }

        // Don't allow moves when viewing history
        if (is_viewing_history) {
            logger.debug("Ignoring click while viewing history");
            return;
        }

        if (!is_human_turn()) {
            return; // Ignore clicks during AI turn
        }

        var clicked_pos = new BoardPosition(row, col, current_variant.board_size);

        if (selected_square == null) {
            // First click - try to select a piece
            var current_state = game_controller.get_current_state();
            var piece = find_piece_at_position(current_state, clicked_pos);

            // Check if we're in a multi-capture sequence
            if (multi_capture_position != null) {
                // Only allow selecting the piece that must continue capturing
                if (clicked_pos.equals(multi_capture_position)) {
                    selected_square = Position(row, col);
                    highlight_capture_moves(row, col);
                    logger.debug("Multi-capture mode: selected capturing piece at (%d,%d)", row, col);
                } else {
                    logger.debug("Multi-capture mode: can only select piece at (%d,%d)",
                          multi_capture_position.row, multi_capture_position.col);
                }
            } else if (piece != null && piece.color == current_state.active_player) {
                // Normal piece selection
                selected_square = Position(row, col);
                highlight_possible_moves(row, col);
            } else {
                // Invalid piece selection
            }
        } else {
            // Second click - check if it's the same square (deselect) or different square (move)
            if (selected_square.row == row && selected_square.col == col) {
                // Clicking on the same square - deselect the piece
                selected_square = null;
                clear_highlights();
                return;
            }

            // Second click on different square - try to execute move
            bool move_executed = handle_board_move(selected_square.row, selected_square.col, row, col);

            if (move_executed) {
                // Check if we're in a multi-capture sequence
                if (multi_capture_position != null) {
                    // Multi-capture continues - keep the piece selected at its new position
                    selected_square = Position(multi_capture_position.row, multi_capture_position.col);
                    highlight_capture_moves(multi_capture_position.row, multi_capture_position.col);
                    logger.debug("Multi-capture continues: piece now at (%d,%d) must capture again",
                          multi_capture_position.row, multi_capture_position.col);
                } else {
                    // Normal move or multi-capture sequence ended - clear selection
                    selected_square = null;
                    clear_highlights();

                    // Process AI turn if it's now the AI's turn
                    process_ai_turn.begin();
                }
            } else {
                // Try to select a new piece
                var current_state = game_controller.get_current_state();
                var piece = find_piece_at_position(current_state, clicked_pos);

                if (piece != null && piece.color == current_state.active_player) {
                    // Valid new piece selection
                    selected_square = Position(row, col);
                    highlight_possible_moves(row, col);
                } else {
                    // Invalid click - clear selection
                    selected_square = null;
                    clear_highlights();
                }
            }
        }
    }

    // Helper struct for compatibility with existing code
    private struct Position {
        public int row;
        public int col;

        public Position(int row, int col) {
            this.row = row;
            this.col = col;
        }
    }

    /**
     * Handle state changes from the game engine
     */
    private void on_engine_state_changed(DraughtsGameState new_state, DraughtsMove? last_move) {
        print("\n#### on_engine_state_changed CALLED - active_player=%s ####\n", new_state.active_player.to_string());

        // Update current_game reference in case it changed (e.g., during reconnection)
        if (game_controller != null) {
            current_game = game_controller.get_current_game();
        }

        sync_board_to_game_state();
        game_state_changed(new_state);
        print("#### on_engine_state_changed DONE ####\n\n");
    }

    /**
     * Handle game completion from the game engine
     */
    private void on_engine_game_finished(GameStatus result, string reason) {
        game_finished(result);
    }

    /**
     * Get available variants for the UI
     */
    public GameVariant[] get_available_variants() {
        return GameVariant.get_all_variants();
    }

    /**
     * Set the current variant and restart the game
     */
    public void set_variant(DraughtsVariant variant) {
        start_new_game(variant);

        // Update board widget settings
        string variant_id = current_variant.id;
        board_widget.set_game_rules(variant_id);
    }

    /**
     * Get current game state for UI updates
     */
    public DraughtsGameState? get_current_state() {
        if (game_controller != null) {
            return game_controller.get_current_state();
        }
        return null;
    }

    /**
     * Reset the current game
     */
    public void reset_game() {
        if (current_variant != null) {
            start_new_game(current_variant.variant);
        }
    }

    /**
     * Switch to multiplayer mode with the given controller
     */
    public void set_multiplayer_controller(MultiplayerGameController multiplayer_controller) {
        // Disconnect signals from old controller
        if (game_controller != null) {
            game_controller.game_state_changed.disconnect(on_engine_state_changed);
            game_controller.game_finished.disconnect(on_engine_game_finished);
        }

        // Set new controller
        game_controller = multiplayer_controller;
        current_game = multiplayer_controller.get_current_game();

        // Get the variant from the multiplayer game
        if (current_game != null) {
            current_variant = current_game.variant;

            // Update board widget for the correct variant and board size
            board_widget.set_board_size(current_variant.board_size);
            board_widget.set_game_rules(current_variant.id);

            logger.info("Multiplayer game variant: %s (%dx%d)",
                       current_variant.display_name,
                       current_variant.board_size,
                       current_variant.board_size);
        }

        // Connect signals
        game_controller.game_state_changed.connect(on_engine_state_changed);
        game_controller.game_finished.connect(on_engine_game_finished);

        // Set board perspective based on local player color
        PieceColor local_color = multiplayer_controller.get_local_player_color();
        Player perspective = (local_color == PieceColor.RED) ? Player.RED : Player.BLACK;
        board_widget.set_player_perspective(perspective);

        // Update the board to show the current game state
        sync_board_to_game_state();

        logger.info("Switched to multiplayer mode, perspective: %s", perspective.to_string());
    }

    /**
     * Get all legal moves for the current player
     */
    public Gee.ArrayList<DraughtsMove> get_legal_moves() {
        var legal_moves = new Gee.ArrayList<DraughtsMove>();

        if (game_controller == null) {
            return legal_moves;
        }

        var current_game = game_controller.get_current_game();
        if (current_game != null) {
            var all_moves = current_game.get_legal_moves();
            foreach (var move in all_moves) {
                legal_moves.add(move);
            }
        }

        return legal_moves;
    }

    /**
     * Get legal moves for a piece at the specified position
     */
    public Gee.ArrayList<DraughtsMove> get_legal_moves_for_position(int row, int col) {
        var legal_moves = new Gee.ArrayList<DraughtsMove>();

        if (game_controller == null) {
            return legal_moves;
        }

        var current_state = game_controller.get_current_state();
        if (current_state == null) {
            return legal_moves;
        }

        // Find the piece at this position
        var clicked_pos = new BoardPosition(row, col, current_variant.board_size);
        var piece = find_piece_at_position(current_state, clicked_pos);

        if (piece == null || piece.color != current_state.active_player) {
            return legal_moves; // No piece or not the current player's piece
        }

        // Get current game and its rule engine
        var current_game = game_controller.get_current_game();
        if (current_game == null) {
            return legal_moves;
        }

        // Generate all legal moves for the current state
        var all_legal_moves = current_game.get_legal_moves();

        // Filter moves for this specific piece position
        foreach (var move in all_legal_moves) {
            if (move.from_position.row == row && move.from_position.col == col) {
                legal_moves.add(move);
            }
        }

        return legal_moves;
    }

    /**
     * Get only capture moves available for a piece at a specific position
     */
    public DraughtsMove[] get_capture_moves_for_piece_position(BoardPosition position) {
        var capture_moves = new Gee.ArrayList<DraughtsMove>();

        if (game_controller == null) {
            return capture_moves.to_array();
        }

        var current_state = game_controller.get_current_state();
        if (current_state == null) {
            return capture_moves.to_array();
        }

        // Find the piece at this position
        var piece = find_piece_at_position(current_state, position);
        if (piece == null || piece.color != current_state.active_player) {
            return capture_moves.to_array(); // No piece or not the current player's piece
        }

        // Get current game and its rule engine
        var current_game = game_controller.get_current_game();
        if (current_game == null) {
            return capture_moves.to_array();
        }

        // Get all legal moves for the current state
        var all_legal_moves = current_game.get_legal_moves();

        // Filter to only capture moves from this specific piece position
        foreach (var move in all_legal_moves) {
            if (move.from_position.equals(position) && move.is_capture()) {
                capture_moves.add(move);
            }
        }

        return capture_moves.to_array();
    }

    /**
     * Highlight only capture moves for a piece on the board widget (for multi-capture sequences)
     */
    public void highlight_capture_moves(int row, int col) {
        var position = new BoardPosition(row, col, current_variant.board_size);
        var capture_moves = get_capture_moves_for_piece_position(position);

        // Clear previous highlights and previews
        board_widget.clear_highlights();
        board_widget.clear_preview_pieces();

        // Highlight the selected piece
        board_widget.highlight_square(row, col, "selected");

        // Get the piece being moved
        var current_state = game_controller.get_current_state();
        var moving_piece = current_state.get_piece_at(position);

        if (moving_piece == null) {
            return;
        }

        // Show translucent preview pieces at destination squares
        foreach (var move in capture_moves) {
            // Determine which piece type to show (regular or king)
            PieceType preview_type;

            // Check if this move will promote the piece
            bool will_promote = move.promoted || will_promote_at_position(moving_piece, move.to_position);

            if (will_promote) {
                // Show king preview
                preview_type = moving_piece.color == PieceColor.RED ?
                    PieceType.RED_KING : PieceType.BLACK_KING;
            } else {
                // Show regular piece preview
                preview_type = moving_piece.color == PieceColor.RED ?
                    PieceType.RED_REGULAR : PieceType.BLACK_REGULAR;
            }

            board_widget.set_preview_piece(move.to_position.row, move.to_position.col, preview_type);
        }
    }

    /**
     * Highlight the path of a multi-capture move, including intermediate landing squares
     */
    private void highlight_capture_path(DraughtsMove move) {
        // For multi-capture moves, we need to calculate the intermediate steps
        // This is a simplified approach - in a real implementation, we might need
        // more sophisticated path calculation based on the captured pieces positions

        var from_row = move.from_position.row;
        var from_col = move.from_position.col;
        var to_row = move.to_position.row;
        var to_col = move.to_position.col;

        // Calculate direction vectors
        int row_direction = (to_row > from_row) ? 1 : -1;
        int col_direction = (to_col > from_col) ? 1 : -1;

        // Calculate intermediate positions (every 2 squares in the direction)
        int current_row = from_row;
        int current_col = from_col;

        while (current_row != to_row && current_col != to_col) {
            // Move 2 squares (jump over captured piece)
            current_row += (2 * row_direction);
            current_col += (2 * col_direction);

            // If this isn't the final destination, highlight it as an intermediate step
            if (current_row != to_row || current_col != to_col) {
                if (current_row >= 0 && current_row < current_variant.board_size &&
                    current_col >= 0 && current_col < current_variant.board_size) {
                    board_widget.highlight_square(current_row, current_col, "possible");
                }
            }
        }
    }

    /**
     * Show preview pieces for possible moves
     */
    public void highlight_possible_moves(int row, int col) {
        var legal_moves = get_legal_moves_for_position(row, col);

        // Clear previous highlights and previews
        board_widget.clear_highlights();
        board_widget.clear_preview_pieces();

        // Highlight the selected piece square
        board_widget.highlight_square(row, col, "selected");

        // Get the piece being moved
        var current_state = game_controller.get_current_state();
        var moving_piece = current_state.get_piece_at(new BoardPosition(row, col, current_variant.board_size));

        if (moving_piece == null) {
            return;
        }

        // Show translucent preview pieces at destination squares
        foreach (var move in legal_moves) {
            // Determine which piece type to show (regular or king)
            PieceType preview_type;

            // Check if this move will promote the piece
            bool will_promote = move.promoted || will_promote_at_position(moving_piece, move.to_position);

            if (will_promote) {
                // Show king preview
                preview_type = moving_piece.color == PieceColor.RED ?
                    PieceType.RED_KING : PieceType.BLACK_KING;
            } else {
                // Show regular piece preview
                preview_type = moving_piece.color == PieceColor.RED ?
                    PieceType.RED_REGULAR : PieceType.BLACK_REGULAR;
            }

            board_widget.set_preview_piece(move.to_position.row, move.to_position.col, preview_type);
        }
    }

    /**
     * Check if a piece will promote when moved to the given position
     */
    private bool will_promote_at_position(GamePiece piece, BoardPosition pos) {
        if (piece.piece_type != DraughtsPieceType.MAN) {
            return false; // Already a king
        }

        // Check if destination is on promotion row
        if (piece.color == PieceColor.RED && pos.row == 0) {
            return true; // Red promotes at row 0
        } else if (piece.color == PieceColor.BLACK && pos.row == current_variant.board_size - 1) {
            return true; // Black promotes at last row
        }

        return false;
    }

    /**
     * Clear all move highlights and restore playable piece highlighting
     */
    public void clear_highlights() {
        board_widget.clear_highlights();

        // Restore playable piece highlighting after clearing
        Idle.add(() => {
            highlight_playable_pieces();
            return false;
        });
    }

    /**
     * Get set of playable piece positions for the current player
     */
    public Gee.HashSet<string> get_playable_piece_positions() {
        var playable_positions = new Gee.HashSet<string>();

        if (game_controller == null) {
            return playable_positions;
        }

        var current_state = game_controller.get_current_state();
        if (current_state == null) {
            return playable_positions;
        }

        var current_game = game_controller.get_current_game();
        if (current_game == null) {
            return playable_positions;
        }

        // Get all legal moves for the current player
        var all_legal_moves = current_game.get_legal_moves();

        // Find all unique piece positions that have legal moves
        foreach (var move in all_legal_moves) {
            var position_key = @"$(move.from_position.row),$(move.from_position.col)";
            playable_positions.add(position_key);
        }

        return playable_positions;
    }

    /**
     * Highlight all playable pieces with blue glow
     */
    public void highlight_playable_pieces() {
        // In multiplayer, only highlight if it's the local player's turn
        if (game_controller is MultiplayerGameController) {
            var multiplayer_controller = (MultiplayerGameController) game_controller;
            var current_state = game_controller.get_current_state();
            var local_color = multiplayer_controller.get_local_player_color();

            // Only highlight if it's the local player's turn
            if (current_state.active_player != local_color) {
                board_widget.set_playable_pieces(new Gee.HashSet<string>());
                return;
            }
        }

        var playable_positions = get_playable_piece_positions();
        board_widget.set_playable_pieces(playable_positions);
    }

    /**
     * Check if it's the human player's turn
     */
    public bool is_human_turn() {
        if (current_game == null) {
            return false;
        }

        var current_state = game_controller.get_current_state();

        // Get the current player based on active player color
        GamePlayer current_player;
        if (current_state.active_player == PieceColor.RED) {
            current_player = current_game.red_player;
        } else {
            current_player = current_game.black_player;
        }

        return current_player.is_human();
    }

    /**
     * Trigger AI move if it's the AI's turn
     */
    public async void process_ai_turn() {
        if (current_game == null || is_human_turn()) {
            return;
        }

        // AI move processing is handled by check_ai_turn() which calls make_ai_move()
        // This method is kept for API compatibility but the actual AI logic
        // is in check_ai_turn() to ensure immediate response to game events
        check_ai_turn();
    }

    /**
     * Undo the last move if possible
     */
    public bool undo_last_move() {
        if (game_controller != null) {
            bool success = game_controller.undo_last_move();
            if (success) {
                sync_board_to_game_state();
                return true;
            }
        }
        return false;
    }

    /**
     * Redo the last undone move if possible
     */
    public bool redo_last_move() {
        if (game_controller != null) {
            bool success = game_controller.redo_last_move();
            if (success) {
                sync_board_to_game_state();
                return true;
            }
        }
        return false;
    }

    /**
     * Check if undo is available
     */
    public bool can_undo() {
        if (game_controller != null) {
            return game_controller.can_undo();
        }
        return false;
    }

    /**
     * Check if redo is available
     */
    public bool can_redo() {
        if (game_controller != null) {
            return game_controller.can_redo();
        }
        return false;
    }

    /**
     * Get the game controller
     */
    public IGameController? get_controller() {
        return game_controller;
    }

    /**
     * Get current game variant
     */
    public GameVariant? get_current_variant() {
        return current_variant;
    }

    /**
     * Get game statistics
     */
    public GameStats? get_game_statistics() {
        var current_state = get_current_state();
        if (current_state != null) {
            return current_state.get_statistics();
        }
        return null;
    }

    /**
     * Get the full game session statistics including move history and duration
     */
    public GameSessionStats? get_full_game_statistics() {
        if (current_game != null) {
            return current_game.get_statistics();
        }
        return null;
    }

    /**
     * Get the current game instance
     */
    public Game? get_current_game() {
        return current_game;
    }

    /**
     * Start animation for a player move
     */
    private void start_move_animation(DraughtsMove move) {
        is_animating = true;
        pending_move = move;
        pending_move_is_ai = false;

        // Check if this is a multi-jump that needs to be animated in segments
        if (move.is_multi_capture()) {
            // Calculate all jump segments
            var segments = calculate_jump_segments(move);
            if (segments.length > 1) {
                multi_jump_sequence = segments;
                multi_jump_index = 0;
                animate_next_jump_segment();
                return;
            }
        }

        // Single jump or simple move - animate directly
        animate_single_move(move.from_position.row, move.from_position.col,
                           move.to_position.row, move.to_position.col, move);
    }

    /**
     * Calculate individual jump segments for multi-jump moves
     */
    private DraughtsMove[] calculate_jump_segments(DraughtsMove move) {
        var segments = new Gee.ArrayList<DraughtsMove>();

        int from_row = move.from_position.row;
        int from_col = move.from_position.col;
        int to_row = move.to_position.row;
        int to_col = move.to_position.col;

        // Calculate direction
        int row_dir = to_row > from_row ? 1 : -1;
        int col_dir = to_col > from_col ? 1 : -1;

        // Calculate number of jumps (each jump is 2 squares)
        int row_dist = (to_row - from_row).abs();
        int num_jumps = row_dist / 2;

        // Create a segment for each jump
        int current_row = from_row;
        int current_col = from_col;

        for (int i = 0; i < num_jumps; i++) {
            int next_row = current_row + (row_dir * 2);
            int next_col = current_col + (col_dir * 2);

            var from_pos = new BoardPosition(current_row, current_col, current_variant.board_size);
            var to_pos = new BoardPosition(next_row, next_col, current_variant.board_size);

            // Create a simple capture move for this segment
            var segment = new DraughtsMove.with_captures(move.piece_id, from_pos, to_pos, new int[1]);
            segments.add(segment);

            current_row = next_row;
            current_col = next_col;
        }

        return segments.to_array();
    }

    /**
     * Animate the next segment in a multi-jump sequence
     */
    private void animate_next_jump_segment() {
        if (multi_jump_sequence == null || multi_jump_index >= multi_jump_sequence.length) {
            multi_jump_sequence = null;
            multi_jump_index = 0;
            return;
        }

        var segment = multi_jump_sequence[multi_jump_index];
        animate_single_move(segment.from_position.row, segment.from_position.col,
                           segment.to_position.row, segment.to_position.col, segment);
    }

    /**
     * Animate a single move or jump segment
     */
    private void animate_single_move(int from_row, int from_col, int to_row, int to_col, DraughtsMove move) {
        // Collect captured pieces positions
        // For captures, the captured piece is between from and to position
        Draughts.Position[]? captured_positions = null;
        if (move.is_capture()) {
            // Calculate position of captured piece (middle point between from and to)
            int row_dir = to_row > from_row ? 1 : -1;
            int col_dir = to_col > from_col ? 1 : -1;
            int cap_row = from_row + row_dir;
            int cap_col = from_col + col_dir;

            captured_positions = new Draughts.Position[1];
            captured_positions[0] = Draughts.Position(cap_row, cap_col);
        }

        // Start the animation
        board_widget.animate_move(from_row, from_col, to_row, to_col, captured_positions);
    }

    /**
     * Start animation for an AI move
     */
    private void start_ai_move_animation(DraughtsMove move) {
        is_animating = true;
        pending_move = move;
        pending_move_is_ai = true;

        // Check if this is a multi-jump that needs to be animated in segments
        if (move.is_multi_capture()) {
            // Calculate all jump segments
            var segments = calculate_jump_segments(move);
            if (segments.length > 1) {
                multi_jump_sequence = segments;
                multi_jump_index = 0;
                animate_next_jump_segment();
                return;
            }
        }

        // Single jump or simple move - animate directly
        animate_single_move(move.from_position.row, move.from_position.col,
                           move.to_position.row, move.to_position.col, move);
    }

    /**
     * Complete player move execution after animation finishes
     */
    private void complete_move_execution(DraughtsMove move) {
        // Execute the move in the game engine
        bool success = game_controller.make_move(move);

        if (success) {
            sync_board_to_game_state();
            move_made(move);

            // Check for sequential multi-capture after a capture move
            if (move.is_capture()) {
                // Check if the move resulted in promotion by examining the piece after the move
                var new_state = game_controller.get_current_state();
                var moved_piece = new_state.get_piece_at(move.to_position);
                bool piece_was_promoted = move.promoted ||
                                         (moved_piece != null && moved_piece.piece_type == DraughtsPieceType.KING);

                // If the move resulted in promotion, the turn ends immediately
                if (piece_was_promoted) {
                    multi_capture_position = null;
                    logger.debug("UI: Piece promoted during capture - turn ends");
                } else {
                    if (moved_piece != null) {
                        // Check if this piece can capture more from its new position
                        var additional_captures = get_capture_moves_for_piece_position(move.to_position);
                        if (additional_captures.length > 0) {
                            multi_capture_position = move.to_position;
                            logger.debug("UI: Sequential capture detected - keeping piece selected at (%d,%d)",
                                  move.to_position.row, move.to_position.col);

                            // Automatically highlight the piece and its possible next captures
                            selected_square = Position(move.to_position.row, move.to_position.col);
                            highlight_capture_moves(move.to_position.row, move.to_position.col);
                        } else {
                            multi_capture_position = null;
                        }
                    } else {
                        multi_capture_position = null;
                    }
                }
            } else {
                multi_capture_position = null;
            }

            // Check if game is over (skip for multiplayer - server will notify)
            if (!(game_controller is MultiplayerGameController)) {
                var new_state = game_controller.get_current_state();
                if (new_state.is_game_over()) {
                    game_finished(new_state.game_status);
                } else {
                    // Check if it's now an AI player's turn
                    check_ai_turn();
                }
            } else {
                // For multiplayer, just check if we need to wait for opponent
                // Game end will be signaled by the server
                check_ai_turn(); // This won't do anything for multiplayer, but keeps the logic consistent
            }
        } else {
            logger.warning("Failed to execute move from (%d,%d) to (%d,%d)",
                move.from_position.row, move.from_position.col,
                move.to_position.row, move.to_position.col);
        }
    }

    /**
     * Complete AI move execution after animation finishes
     */
    private void complete_ai_move_execution(DraughtsMove move) {
        // Execute the move in the game engine
        bool success = game_controller.make_move(move);

        if (success) {
            sync_board_to_game_state();
            move_made(move);

            // Check if game is over (skip for multiplayer - server will notify)
            if (!(game_controller is MultiplayerGameController)) {
                var new_state = game_controller.get_current_state();
                if (new_state.is_game_over()) {
                    game_finished(new_state.game_status);
                } else {
                    // Check for another AI turn (in case both players are AI)
                    check_ai_turn();
                }
            } else {
                // For multiplayer, game end will be signaled by the server
                check_ai_turn(); // This won't do anything for multiplayer
            }
        } else {
            logger.warning("AI move rejected by game engine: from (%d,%d) to (%d,%d)",
                move.from_position.row, move.from_position.col,
                move.to_position.row, move.to_position.col);
            // Reset AI flag and sync to restore correct state
            ai_move_in_progress = false;
            sync_board_to_game_state();
        }
    }

    /**
     * Check if it's an AI player's turn and make their move
     */
    private void check_ai_turn() {
        if (current_game == null || ai_move_in_progress) {
            return;
        }

        var current_state = game_controller.get_current_state();
        var active_player = current_state.active_player;

        // Get the current player object
        GamePlayer current_player_obj = null;
        if (active_player == PieceColor.RED) {
            current_player_obj = current_game.red_player;
        } else {
            current_player_obj = current_game.black_player;
        }

        // If current player is AI, make their move
        if (current_player_obj != null && current_player_obj.is_ai()) {
            ai_move_in_progress = true;

            // Run AI thinking in a background thread
            make_ai_move_async.begin();
        }
    }

    /**
     * Make an AI move asynchronously on a background thread
     */
    private async void make_ai_move_async() {
        if (current_game == null) {
            ai_move_in_progress = false;
            return;
        }

        // Capture all needed data for the background thread
        var current_state = game_controller.get_current_state();
        var game = game_controller.get_current_game();
        var rule_engine = game.variant.create_rule_engine();
        var legal_moves = rule_engine.generate_legal_moves(current_state);

        if (legal_moves.length == 0) {
            ai_move_in_progress = false;
            return;
        }

        // Get the AI player and their difficulty
        var active_player = current_state.active_player;
        GamePlayer? ai_player = null;
        if (active_player == PieceColor.RED) {
            ai_player = current_game.red_player;
        } else {
            ai_player = current_game.black_player;
        }

        AIDifficulty difficulty = AIDifficulty.MEDIUM;
        if (ai_player != null && ai_player.is_ai()) {
            difficulty = ai_player.ai_difficulty;
        }

        // Move the AI thinking to a background thread
        DraughtsMove? selected_move = null;
        SourceFunc callback = make_ai_move_async.callback;

        new Thread<void*>(null, () => {
            // This runs in a background thread - no UI operations allowed here
            selected_move = select_ai_move_by_difficulty(legal_moves, current_state, rule_engine, difficulty);
            Idle.add((owned) callback);
            return null;
        });

        yield;

        // Back on main thread now
        if (selected_move == null) {
            // Fallback to random if something went wrong
            var random_index = Random.int_range(0, legal_moves.length);
            selected_move = legal_moves[random_index];
        }

        // Reset the flag
        ai_move_in_progress = false;

        // Start animation for AI move
        start_ai_move_animation(selected_move);
    }

    /**
     * Select an AI move based on difficulty level
     */
    private DraughtsMove select_ai_move_by_difficulty(DraughtsMove[] legal_moves, DraughtsGameState state, IRuleEngine rule_engine, AIDifficulty difficulty) {
        switch (difficulty) {
            case AIDifficulty.BEGINNER:
                return select_beginner_move(legal_moves);

            case AIDifficulty.EASY:
                return select_easy_move(legal_moves, state);

            case AIDifficulty.MEDIUM:
                return select_medium_move(legal_moves, state);

            case AIDifficulty.NOVICE:
                return select_novice_move(legal_moves, state);

            case AIDifficulty.INTERMEDIATE:
                return select_intermediate_move(legal_moves, state, rule_engine);

            case AIDifficulty.HARD:
                return select_hard_move(legal_moves, state, rule_engine);

            case AIDifficulty.ADVANCED:
                return select_advanced_move(legal_moves, state, rule_engine);

            case AIDifficulty.EXPERT:
                return select_expert_move(legal_moves, state, rule_engine);

            case AIDifficulty.MASTER:
                return select_master_move(legal_moves, state, rule_engine);

            case AIDifficulty.GRANDMASTER:
                return select_grandmaster_move(legal_moves, state, rule_engine);

            default:
                return select_medium_move(legal_moves, state);
        }
    }

    /**
     * BEGINNER (Level 1): Completely random moves
     */
    private DraughtsMove select_beginner_move(DraughtsMove[] legal_moves) {
        var random_index = Random.int_range(0, legal_moves.length);
        return legal_moves[random_index];
    }

    /**
     * EASY (Level 2): Prefer captures if available, otherwise random
     */
    private DraughtsMove select_easy_move(DraughtsMove[] legal_moves, DraughtsGameState state) {
        var capture_moves = new Gee.ArrayList<DraughtsMove>();

        foreach (var move in legal_moves) {
            if (move.is_capture()) {
                capture_moves.add(move);
            }
        }

        if (capture_moves.size > 0) {
            var random_index = Random.int_range(0, capture_moves.size);
            return capture_moves[random_index];
        } else {
            return select_beginner_move(legal_moves);
        }
    }

    /**
     * MEDIUM (Level 3): Prefer captures, avoid obvious traps
     */
    private DraughtsMove select_medium_move(DraughtsMove[] legal_moves, DraughtsGameState state) {
        var capture_moves = new Gee.ArrayList<DraughtsMove>();
        var safe_moves = new Gee.ArrayList<DraughtsMove>();

        foreach (var move in legal_moves) {
            if (move.is_capture()) {
                capture_moves.add(move);
            }

            // Simple safety check: avoid moves to edge if possible
            if (move.to_position.row != 0 && move.to_position.row != 7 &&
                move.to_position.col != 0 && move.to_position.col != 7) {
                safe_moves.add(move);
            }
        }

        // Prefer captures first
        if (capture_moves.size > 0) {
            var random_index = Random.int_range(0, capture_moves.size);
            return capture_moves[random_index];
        }

        // Then prefer safe moves
        if (safe_moves.size > 0) {
            var random_index = Random.int_range(0, safe_moves.size);
            return safe_moves[random_index];
        }

        return select_beginner_move(legal_moves);
    }

    /**
     * NOVICE (Level 4): Basic positional awareness
     */
    private DraughtsMove select_novice_move(DraughtsMove[] legal_moves, DraughtsGameState state) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();

        foreach (var move in legal_moves) {
            int score = 0;

            // Prioritize captures
            if (move.is_capture()) {
                score += 100;
            }

            // Advance pieces toward promotion
            if (state.active_player == PieceColor.RED) {
                if (move.to_position.row > move.from_position.row) {
                    score += 10;
                }
            } else {
                if (move.to_position.row < move.from_position.row) {
                    score += 10;
                }
            }

            // Prefer center control
            var center_distance = calculate_center_distance(move.to_position);
            score += (8 - center_distance);

            scored_moves.add(ScoredMove() { move = move, score = score });
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * INTERMEDIATE (Level 5): Look ahead 1 move
     */
    private DraughtsMove select_intermediate_move(DraughtsMove[] legal_moves, DraughtsGameState state, IRuleEngine rule_engine) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();
        var ai_color = state.active_player;

        foreach (var move in legal_moves) {
            int score = evaluate_move_with_lookahead(move, state, rule_engine, 1, ai_color);
            scored_moves.add(ScoredMove() { move = move, score = score });
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * HARD (Level 6): Look ahead 2 moves
     */
    private DraughtsMove select_hard_move(DraughtsMove[] legal_moves, DraughtsGameState state, IRuleEngine rule_engine) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();
        var ai_color = state.active_player;

        foreach (var move in legal_moves) {
            int score = evaluate_move_with_lookahead(move, state, rule_engine, 2, ai_color);
            scored_moves.add(ScoredMove() { move = move, score = score });
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * ADVANCED (Level 7): Look ahead 3 moves
     */
    private DraughtsMove select_advanced_move(DraughtsMove[] legal_moves, DraughtsGameState state, IRuleEngine rule_engine) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();
        var ai_color = state.active_player;

        foreach (var move in legal_moves) {
            int score = evaluate_move_with_lookahead(move, state, rule_engine, 3, ai_color);
            scored_moves.add(ScoredMove() { move = move, score = score });
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * EXPERT (Level 8): Look ahead 4 moves with position evaluation
     */
    private DraughtsMove select_expert_move(DraughtsMove[] legal_moves, DraughtsGameState state, IRuleEngine rule_engine) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();
        var ai_color = state.active_player;

        foreach (var move in legal_moves) {
            int score = evaluate_move_with_lookahead(move, state, rule_engine, 4, ai_color);
            scored_moves.add(ScoredMove() { move = move, score = score });
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * MASTER (Level 9): Look ahead 5 moves with advanced evaluation
     */
    private DraughtsMove select_master_move(DraughtsMove[] legal_moves, DraughtsGameState state, IRuleEngine rule_engine) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();
        var ai_color = state.active_player;

        foreach (var move in legal_moves) {
            int score = evaluate_move_with_lookahead(move, state, rule_engine, 5, ai_color);
            scored_moves.add(ScoredMove() { move = move, score = score });
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * GRANDMASTER (Level 10): Look ahead 7+ moves with comprehensive evaluation
     */
    private DraughtsMove select_grandmaster_move(DraughtsMove[] legal_moves, DraughtsGameState state, IRuleEngine rule_engine) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();
        var ai_color = state.active_player;

        foreach (var move in legal_moves) {
            int score = evaluate_move_with_lookahead(move, state, rule_engine, 7, ai_color);
            scored_moves.add(ScoredMove() { move = move, score = score });
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * Helper struct for scoring moves
     */
    private struct ScoredMove {
        DraughtsMove move;
        int score;
    }

    /**
     * Calculate distance from center of board
     */
    private int calculate_center_distance(BoardPosition pos) {
        int center = current_variant.board_size / 2;
        int dx = (pos.row - center).abs();
        int dy = (pos.col - center).abs();
        return dx + dy;
    }

    /**
     * Select the best move from scored moves (with some randomness for same scores)
     */
    private DraughtsMove select_best_scored_move(Gee.ArrayList<ScoredMove?> scored_moves) {
        // This method should never be called with empty moves
        // but let's handle it gracefully
        if (scored_moves.size == 0) {
            logger.debug("Error: No moves to select from! This should not happen.");
            // Return the first element anyway (will cause error, but at least it's explicit)
            assert(false); // This will fail in debug mode
        }

        // Find the highest score
        int max_score = int.MIN;
        foreach (var scored_move in scored_moves) {
            if (scored_move.score > max_score) {
                max_score = scored_move.score;
            }
        }

        // Collect all moves with the highest score
        var best_moves = new Gee.ArrayList<DraughtsMove>();
        foreach (var scored_move in scored_moves) {
            if (scored_move.score == max_score) {
                best_moves.add(scored_move.move);
            }
        }

        // Randomly select among the best moves to add some variety
        var random_index = Random.int_range(0, best_moves.size);
        return best_moves[random_index];
    }

    /**
     * Evaluate a move with lookahead using minimax algorithm
     */
    private int evaluate_move_with_lookahead(DraughtsMove move, DraughtsGameState state, IRuleEngine rule_engine, int depth, PieceColor ai_color) {
        if (depth == 0) {
            // Simple evaluation for low depths
            return evaluate_simple_move(move, state, rule_engine, ai_color);
        }

        // Apply the move to get new state
        var new_state = state.apply_move(move);

        // Use minimax to evaluate this position
        int score = minimax(new_state, rule_engine, depth - 1, int.MIN, int.MAX, false, ai_color);

        return score;
    }

    /**
     * Minimax algorithm with alpha-beta pruning
     */
    private int minimax(DraughtsGameState state, IRuleEngine rule_engine, int depth, int alpha, int beta, bool maximizing, PieceColor ai_color) {
        // Terminal conditions
        if (depth == 0 || state.is_game_over()) {
            return evaluate_position(state, ai_color);
        }

        var legal_moves = rule_engine.generate_legal_moves(state);

        if (legal_moves.length == 0) {
            // No moves available - game over
            return evaluate_position(state, ai_color);
        }

        if (maximizing) {
            int max_eval = int.MIN;
            foreach (var move in legal_moves) {
                var new_state = state.apply_move(move);
                int eval = minimax(new_state, rule_engine, depth - 1, alpha, beta, false, ai_color);
                max_eval = int.max(max_eval, eval);
                alpha = int.max(alpha, eval);
                if (beta <= alpha) {
                    break; // Alpha-beta pruning
                }
            }
            return max_eval;
        } else {
            int min_eval = int.MAX;
            foreach (var move in legal_moves) {
                var new_state = state.apply_move(move);
                int eval = minimax(new_state, rule_engine, depth - 1, alpha, beta, true, ai_color);
                min_eval = int.min(min_eval, eval);
                beta = int.min(beta, eval);
                if (beta <= alpha) {
                    break; // Alpha-beta pruning
                }
            }
            return min_eval;
        }
    }

    /**
     * Simple move evaluation without lookahead
     */
    private int evaluate_simple_move(DraughtsMove move, DraughtsGameState state, IRuleEngine rule_engine, PieceColor ai_color) {
        int base_score = evaluate_position(state, ai_color);
        int move_score = 0;

        if (move.is_capture()) {
            move_score += 100;
        }

        // Promotion bonus
        if (move.promoted) {
            move_score += 50;
        }

        // Advance toward promotion
        if (state.active_player == PieceColor.RED) {
            move_score += (move.to_position.row - move.from_position.row) * 5;
        } else {
            move_score += (move.from_position.row - move.to_position.row) * 5;
        }

        // Center control bonus
        var center_distance = calculate_center_distance(move.to_position);
        move_score += (8 - center_distance) * 2;

        return base_score + move_score;
    }


    /**
     * Evaluate the current position with advanced heuristics from AI's perspective
     */
    private int evaluate_position(DraughtsGameState state, PieceColor ai_color) {
        int score = 0;
        int my_pieces = 0;
        int enemy_pieces = 0;
        int my_kings = 0;
        int enemy_kings = 0;
        int my_back_row = 0;
        int enemy_back_row = 0;

        foreach (var piece in state.pieces) {
            if (piece.color == ai_color) {
                my_pieces++;
                if (piece.piece_type == DraughtsPieceType.KING) {
                    my_kings++;
                    // Kings get bonus for mobility
                    score += 50;
                } else {
                    // Regular pieces get bonus for advancement
                    int advancement = (ai_color == PieceColor.RED)
                        ? piece.position.row
                        : (current_variant.board_size - 1 - piece.position.row);
                    score += advancement * 3;

                    // Bonus for being close to promotion
                    if (advancement >= current_variant.board_size - 2) {
                        score += 20;
                    }
                }

                // Back row defense (important in endgame)
                if ((ai_color == PieceColor.RED && piece.position.row == 0) ||
                    (ai_color == PieceColor.BLACK && piece.position.row == current_variant.board_size - 1)) {
                    my_back_row++;
                }

                // Center control bonus
                int center_dist = calculate_center_distance(piece.position);
                if (center_dist <= 2) {
                    score += (3 - center_dist) * 2;
                }
            } else {
                enemy_pieces++;
                if (piece.piece_type == DraughtsPieceType.KING) {
                    enemy_kings++;
                    score -= 50;
                } else {
                    int advancement = (piece.color == PieceColor.RED)
                        ? piece.position.row
                        : (current_variant.board_size - 1 - piece.position.row);
                    score -= advancement * 3;

                    if (advancement >= current_variant.board_size - 2) {
                        score -= 20;
                    }
                }

                if ((piece.color == PieceColor.RED && piece.position.row == 0) ||
                    (piece.color == PieceColor.BLACK && piece.position.row == current_variant.board_size - 1)) {
                    enemy_back_row++;
                }
            }
        }

        // Material evaluation (piece count is most important)
        score += (my_pieces - enemy_pieces) * 100;
        score += (my_kings - enemy_kings) * 150;

        // Back row defense bonus
        score += (my_back_row - enemy_back_row) * 10;

        // Win/loss detection
        if (enemy_pieces == 0) {
            return 100000; // Winning position
        }
        if (my_pieces == 0) {
            return -100000; // Losing position
        }

        return score;
    }

    /**
     * View history at a specific position (read-only, doesn't modify game state)
     * Position -1 = game start, 0+ = after that move
     */
    public bool view_history_at_position(int position) {
        if (game_controller == null) {
            return false;
        }

        var state = game_controller.view_history_at_position(position);
        if (state != null) {
            int actual_current_pos = game_controller.get_history_position();

            // Check if we're viewing the actual current position
            if (position >= actual_current_pos) {
                // We're at the current position, return to normal mode
                return_to_current_position();
                return true;
            }

            // We're viewing a historical position
            is_viewing_history = true;
            current_view_position = position;
            // Display the historical state on the board
            update_board_from_state(state);
            // Clear all visual indicators when viewing history
            board_widget.clear_playable_pieces();
            board_widget.clear_highlights();
            board_widget.clear_hover_glow();
            board_widget.clear_preview_pieces();
            logger.info("Viewing history at position %d", position);
            return true;
        }
        return false;
    }

    /**
     * Return to the current (latest) position
     */
    public void return_to_current_position() {
        if (is_viewing_history) {
            is_viewing_history = false;
            current_view_position = -1;
            // Display current game state
            sync_board_to_game_state();
            logger.info("Returned to current position");
        }
    }

    /**
     * Check if we're currently viewing history
     */
    public bool get_is_viewing_history() {
        return is_viewing_history;
    }

    /**
     * Check if it's currently AI's turn or AI is thinking
     */
    public bool is_ai_turn() {
        if (ai_move_in_progress) {
            return true;
        }

        if (current_game == null || game_controller == null) {
            return false;
        }

        var current_state = game_controller.get_current_state();
        var active_player = current_state.active_player;

        GamePlayer? player = null;
        if (active_player == PieceColor.RED) {
            player = current_game.red_player;
        } else if (active_player == PieceColor.BLACK) {
            player = current_game.black_player;
        }

        return player != null && player.is_ai();
    }

    /**
     * Check if we're at the latest position
     */
    public bool is_at_current_position() {
        if (game_controller == null) {
            return true;
        }
        return !is_viewing_history && game_controller.is_at_latest_position();
    }

    /**
     * Get the total number of positions in history (including game start)
     * Returns: number of moves + 1 (for game start position)
     */
    public int get_history_size() {
        if (game_controller == null) {
            return 0;
        }
        // +1 to include the initial game start position
        return game_controller.get_history_size() + 1;
    }

    /**
     * Get the current viewing position (-1 = game start, 0+ = after move)
     */
    public int get_current_viewing_position() {
        if (is_viewing_history) {
            return current_view_position;
        }
        // If not viewing history, we're at the latest position
        if (game_controller != null) {
            return game_controller.get_history_position();
        }
        return -1;
    }

    /**
     * Get the actual current game position (not the viewing position)
     */
    public int get_actual_current_position() {
        if (game_controller != null) {
            return game_controller.get_history_position();
        }
        return -1;
    }

    /**
     * Helper method to update board from a game state
     */
    private void update_board_from_state(DraughtsGameState state) {
        // Clear the board
        board_widget.clear_board();

        // Place all pieces from the state
        foreach (var piece in state.pieces) {
            // Map piece type
            PieceType board_piece_type;
            if (piece.piece_type == DraughtsPieceType.MAN) {
                board_piece_type = piece.color == PieceColor.RED ? PieceType.RED_REGULAR : PieceType.BLACK_REGULAR;
            } else {
                board_piece_type = piece.color == PieceColor.RED ? PieceType.RED_KING : PieceType.BLACK_KING;
            }

            board_widget.set_piece_at(piece.position.row, piece.position.col, board_piece_type);
        }
    }
}