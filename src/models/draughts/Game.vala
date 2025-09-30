/**
 * Game.vala
 *
 * Represents a complete draughts game session.
 * Manages players, game state, timers, and game history.
 */

using Draughts;

public class Draughts.Game : Object {
    public string id { get; private set; }
    public GameVariant variant { get; private set; }
    public GamePlayer red_player { get; private set; }
    public GamePlayer black_player { get; private set; }
    public DraughtsGameState current_state { get; private set; }
    public Timer? timer_red { get; private set; }
    public Timer? timer_black { get; private set; }
    public DateTime created_at { get; private set; }
    public DateTime? finished_at { get; private set; }
    public GameStatus result { get; private set; }

    private Gee.ArrayList<DraughtsGameState> _state_history;
    private bool _is_paused;
    private IRuleEngine rule_engine;
    private MoveHistoryManager move_history_manager;
    private SoundManager sound_manager;

    /**
     * Create a new game
     */
    public Game(string id, GameVariant variant, GamePlayer red_player, GamePlayer black_player) {
        this.id = id;
        this.variant = variant;
        this.red_player = red_player;
        this.black_player = black_player;
        this.created_at = new DateTime.now_utc();
        this.finished_at = null;
        this.result = GameStatus.IN_PROGRESS;
        this._state_history = new Gee.ArrayList<DraughtsGameState>();
        this._is_paused = false;
        this.rule_engine = variant.create_rule_engine();
        this.move_history_manager = new MoveHistoryManager();
        this.sound_manager = SoundManager.get_instance();

        // Ensure players have correct colors
        this.red_player.color = PieceColor.RED;
        this.black_player.color = PieceColor.BLACK;

        // Create initial game state
        var initial_pieces = variant.create_initial_setup();
        this.current_state = new DraughtsGameState(initial_pieces, PieceColor.RED, variant.board_size);
        this._state_history.add(current_state.clone());

        // Initialize timers
        this.timer_red = null;
        this.timer_black = null;
    }

    /**
     * Set timer configuration for the game
     */
    public void set_timers(Timer? red_timer, Timer? black_timer) {
        this.timer_red = red_timer?.clone();
        this.timer_black = black_timer?.clone();
    }

    /**
     * Get the player whose turn it is
     */
    public GamePlayer get_active_player() {
        return (current_state.active_player == PieceColor.RED) ? red_player : black_player;
    }

    /**
     * Get the opposing player
     */
    public GamePlayer get_opposing_player() {
        return (current_state.active_player == PieceColor.RED) ? black_player : red_player;
    }

    /**
     * Get timer for active player
     */
    public Timer? get_active_timer() {
        return (current_state.active_player == PieceColor.RED) ? timer_red : timer_black;
    }

    /**
     * Get timer for opposing player
     */
    public Timer? get_opposing_timer() {
        return (current_state.active_player == PieceColor.RED) ? timer_black : timer_red;
    }

    /**
     * Make a move in the game
     */
    public bool make_move(DraughtsMove move) {
        if (is_game_over() || _is_paused) {
            return false;
        }

        // Validate move using rule engine
        if (!rule_engine.is_move_legal(current_state, move)) {
            var logger = Logger.get_default();
            logger.debug("MOVE VALIDATION FAILED: Move is not legal according to rule engine");
            sound_manager.play_sound(SoundEffect.ILLEGAL_MOVE);
            return false;
        }

        // Stop active player's timer and add increment if applicable
        var active_timer = get_active_timer();
        if (active_timer != null) {
            var elapsed = active_timer.stop();
            get_active_player().add_time_used(elapsed);

            // Add Fischer increment
            active_timer.add_increment();

            // Check for time expiration
            if (active_timer.is_time_expired()) {
                end_game_by_time();
                return true;
            }
        }

        // Apply the move
        var previous_state = current_state.clone();
        var new_state = current_state.apply_move(move);

        // Detect if piece was promoted to king
        bool is_promotion = false;
        var piece_before = previous_state.get_piece_at(move.from_position);
        var piece_after = new_state.get_piece_at(move.to_position);
        if (piece_before != null && piece_after != null &&
            piece_before.piece_type == DraughtsPieceType.MAN &&
            piece_after.piece_type == DraughtsPieceType.KING) {
            is_promotion = true;
        }

        current_state = new_state;
        _state_history.add(current_state.clone());

        // Play appropriate sound effect
        sound_manager.play_move_sound(move, move.is_capture(), is_promotion);

        // Add move to history manager for undo/redo functionality
        move_history_manager.add_move(move, previous_state, current_state.clone());

        // Check for sequential multi-capture after a capture move
        bool should_continue_capturing = false;
        if (move.is_capture()) {
            // Get the piece that just moved
            var moved_piece = current_state.get_piece_at(move.to_position);
            if (moved_piece != null) {
                // IMPORTANT: apply_move() already switched active player, but we need to check
                // if the piece that just moved (which belongs to the previous active player)
                // can continue capturing. We need to temporarily switch back to check captures
                // for the correct player.
                current_state.switch_active_player(); // Switch back to the moving player
                var additional_captures = get_capture_moves_for_piece(moved_piece);
                if (additional_captures.length > 0) {
                    should_continue_capturing = true;
                    // Keep the active player as the capturing player (don't switch back)
                    var logger = Logger.get_default();
                    logger.debug("Sequential capture available: piece at (%d,%d) can continue capturing",
                          move.to_position.row, move.to_position.col);
                } else {
                    // No additional captures, switch back to the opponent's turn
                    current_state.switch_active_player();
                }
            }
        }

        // Only switch players if not continuing a multi-capture sequence
        if (!should_continue_capturing) {
            // Start opposing player's timer
            var opposing_timer = get_opposing_timer();
            if (opposing_timer != null) {
                opposing_timer.start();
            }
        } else {
            // Keep the same player's timer running for the continuation
            var logger = Logger.get_default();
            logger.debug("Multi-capture sequence continues - same player must capture again");
        }

        // Check for game end conditions
        check_game_end_conditions();

        return true;
    }

    /**
     * Undo the last move (if available)
     */
    public bool undo_last_move() {
        if (!move_history_manager.can_undo() || is_game_over()) {
            return false;
        }

        var undo_result = move_history_manager.undo_move();
        if (undo_result == null) {
            return false;
        }

        // Update current state to the previous state
        current_state = undo_result.board_state.clone();

        // Update the state history for backwards compatibility
        if (_state_history.size > 1) {
            _state_history.remove_at(_state_history.size - 1);
        }

        // Reset timers to previous state (simplified - doesn't account for time already used)
        if (timer_red != null) {
            timer_red.stop();
        }
        if (timer_black != null) {
            timer_black.stop();
        }

        // Play undo sound
        sound_manager.play_sound(SoundEffect.UNDO);

        return true;
    }

    /**
     * Redo the next move (if available)
     */
    public bool redo_last_move() {
        if (!move_history_manager.can_redo() || is_game_over()) {
            return false;
        }

        var redo_result = move_history_manager.redo_move();
        if (redo_result == null) {
            return false;
        }

        // Update current state to the next state
        current_state = redo_result.board_state.clone();

        // Update the state history for backwards compatibility
        _state_history.add(current_state.clone());

        // Reset timers (simplified)
        if (timer_red != null) {
            timer_red.stop();
        }
        if (timer_black != null) {
            timer_black.stop();
        }

        // Play redo sound
        sound_manager.play_sound(SoundEffect.REDO);

        return true;
    }

    /**
     * Pause the game
     */
    public void pause() {
        if (!is_game_over() && !_is_paused) {
            _is_paused = true;

            // Stop all timers
            if (timer_red != null) {
                timer_red.pause();
            }
            if (timer_black != null) {
                timer_black.pause();
            }
        }
    }

    /**
     * Resume the game
     */
    public void resume() {
        if (!is_game_over() && _is_paused) {
            _is_paused = false;

            // Resume active player's timer
            var active_timer = get_active_timer();
            if (active_timer != null) {
                active_timer.resume();
            }
        }
    }

    /**
     * Check if game is paused
     */
    public bool is_paused() {
        return _is_paused;
    }

    /**
     * Check if game is over
     */
    public bool is_game_over() {
        return current_state.is_game_over();
    }

    /**
     * Check if undo is available
     */
    public bool can_undo() {
        return move_history_manager.can_undo() && !is_game_over();
    }

    /**
     * Check if redo is available
     */
    public bool can_redo() {
        return move_history_manager.can_redo() && !is_game_over();
    }

    /**
     * Clear move history (typically called when starting a new game)
     */
    public void clear_move_history() {
        move_history_manager.clear();
    }

    /**
     * Get game duration
     */
    public TimeSpan get_game_duration() {
        var end_time = finished_at ?? new DateTime.now_utc();
        return end_time.difference(created_at);
    }

    /**
     * Get move history
     */
    public DraughtsMove[] get_move_history() {
        var moves = new Gee.ArrayList<DraughtsMove>();

        for (int i = 1; i < _state_history.size; i++) {
            var state = _state_history[i];
            if (state.last_move != null) {
                moves.add(state.last_move);
            }
        }

        return moves.to_array();
    }

    /**
     * Get current move number
     */
    public int get_move_number() {
        return current_state.move_count;
    }

    /**
     * Get all legal moves for the current position
     */
    public DraughtsMove[] get_legal_moves() {
        if (rule_engine == null || current_state == null) {
            return new DraughtsMove[0];
        }

        return rule_engine.generate_legal_moves(current_state);
    }

    /**
     * Get all capture moves available for a specific piece
     */
    public DraughtsMove[] get_capture_moves_for_piece(GamePiece piece) {
        if (rule_engine == null || current_state == null) {
            return new DraughtsMove[0];
        }

        // Get all legal moves for the current position
        var all_moves = rule_engine.generate_legal_moves(current_state);
        var capture_moves = new Gee.ArrayList<DraughtsMove>();

        // Filter to only capture moves from the specified piece
        foreach (var move in all_moves) {
            if (move.piece_id == piece.id && move.is_capture()) {
                capture_moves.add(move);
            }
        }

        return capture_moves.to_array();
    }

    /**
     * Check for game end conditions
     */
    private void check_game_end_conditions() {
        // Use rule engine to check game result
        var game_status = rule_engine.check_game_result(current_state);

        if (game_status != GameStatus.IN_PROGRESS) {
            end_game(game_status);
            return;
        }

        // Check for draw conditions
        var move_history = get_move_history();
        var draw_reason = rule_engine.check_draw_conditions(current_state, move_history);

        if (draw_reason != null) {
            end_game(GameStatus.DRAW);
        }
    }

    /**
     * End game with specified result
     */
    private void end_game(GameStatus result) {
        this.result = result;
        this.finished_at = new DateTime.now_utc();
        current_state.set_game_status(result);

        // Stop all timers
        if (timer_red != null) {
            timer_red.stop();
        }
        if (timer_black != null) {
            timer_black.stop();
        }

        // Play game end sound
        sound_manager.play_sound(SoundEffect.GAME_END);
    }

    /**
     * End game due to time expiration
     */
    private void end_game_by_time() {
        var active_timer = get_active_timer();
        if (active_timer != null && active_timer.is_time_expired()) {
            var winner = (current_state.active_player == PieceColor.RED) ? GameStatus.BLACK_WINS : GameStatus.RED_WINS;
            end_game(winner);
        }
    }

    /**
     * Get game statistics
     */
    public GameSessionStats get_statistics() {
        var detailed_stats = calculate_detailed_statistics();
        return new GameSessionStats(
            variant.display_name,
            red_player.get_statistics(),
            black_player.get_statistics(),
            get_move_number(),
            get_game_duration(),
            result,
            created_at,
            finished_at,
            detailed_stats.red_captures,
            detailed_stats.red_promotions,
            detailed_stats.black_captures,
            detailed_stats.black_promotions
        );
    }

    /**
     * Calculate detailed statistics from move history
     */
    private DetailedGameStats calculate_detailed_statistics() {
        var moves = get_move_history();
        int red_captures = 0;
        int red_promotions = 0;
        int black_captures = 0;
        int black_promotions = 0;

        for (int i = 0; i < moves.length; i++) {
            var move = moves[i];

            // Determine which player made this move (Red goes first, so even indices are Red)
            bool is_red_move = (i % 2) == 0;

            // Count captures
            if (move.is_capture()) {
                int captures_in_move = move.captured_pieces.length;
                if (is_red_move) {
                    red_captures += captures_in_move;
                } else {
                    black_captures += captures_in_move;
                }
            }

            // Count promotions
            if (move.promoted) {
                if (is_red_move) {
                    red_promotions++;
                } else {
                    black_promotions++;
                }
            }
        }

        return new DetailedGameStats(red_captures, red_promotions, black_captures, black_promotions);
    }

    /**
     * Export game to PGN format
     */
    public string to_pgn() {
        var pgn = new StringBuilder();

        // PGN headers
        pgn.append(@"[Event \"Draughts Game\"]\n");
        pgn.append(@"[Date \"$(created_at.format("%Y.%m.%d"))\"]\n");
        pgn.append(@"[Red \"$(red_player.name)\"]\n");
        pgn.append(@"[Black \"$(black_player.name)\"]\n");
        pgn.append(@"[Variant \"$(variant.display_name)\"]\n");
        pgn.append(@"[Result \"$(format_pgn_result())\"]\n");
        pgn.append("\n");

        // Moves
        var moves = get_move_history();
        for (int i = 0; i < moves.length; i++) {
            if (i % 2 == 0) {
                pgn.append(@"$((i / 2) + 1). ");
            }
            pgn.append(@"$(moves[i].to_algebraic_notation()) ");
        }

        pgn.append(format_pgn_result());
        return pgn.str;
    }

    /**
     * Format result for PGN
     */
    private string format_pgn_result() {
        switch (result) {
            case GameStatus.RED_WINS:
                return "1-0";
            case GameStatus.BLACK_WINS:
                return "0-1";
            case GameStatus.DRAW:
                return "1/2-1/2";
            default:
                return "*";
        }
    }

    /**
     * Get string representation
     */
    public string to_string() {
        return @"Game $id: $(red_player.name) vs $(black_player.name) ($(variant.display_name))";
    }

    /**
     * Generate unique game ID
     */
    public static string generate_id() {
        var now = new DateTime.now_utc();
        return @"game_$(now.to_unix())_$(Random.int_range(1000, 9999))";
    }

    /**
     * Validate game configuration
     */
    public bool is_valid() {
        // Check players
        if (!red_player.is_valid() || !black_player.is_valid()) {
            return false;
        }

        // Check player colors
        if (red_player.color != PieceColor.RED || black_player.color != PieceColor.BLACK) {
            return false;
        }

        // Check game state
        if (!current_state.is_valid()) {
            return false;
        }

        // Check timers (if present)
        if (timer_red != null && !timer_red.is_valid()) {
            return false;
        }
        if (timer_black != null && !timer_black.is_valid()) {
            return false;
        }

        return true;
    }
}

/**
 * Game session statistics
 */
public class GameSessionStats : Object {
    public string variant_name { get; private set; }
    public PlayerStats red_player { get; private set; }
    public PlayerStats black_player { get; private set; }
    public int move_count { get; private set; }
    public TimeSpan duration { get; private set; }
    public GameStatus result { get; private set; }
    public DateTime created_at { get; private set; }
    public DateTime? finished_at { get; private set; }
    public int red_captures { get; private set; }
    public int red_promotions { get; private set; }
    public int black_captures { get; private set; }
    public int black_promotions { get; private set; }

    public GameSessionStats(string variant_name, PlayerStats red_player, PlayerStats black_player,
                           int move_count, TimeSpan duration, GameStatus result,
                           DateTime created_at, DateTime? finished_at,
                           int red_captures = 0, int red_promotions = 0,
                           int black_captures = 0, int black_promotions = 0) {
        this.variant_name = variant_name;
        this.red_player = red_player;
        this.black_player = black_player;
        this.move_count = move_count;
        this.duration = duration;
        this.result = result;
        this.created_at = created_at;
        this.finished_at = finished_at;
        this.red_captures = red_captures;
        this.red_promotions = red_promotions;
        this.black_captures = black_captures;
        this.black_promotions = black_promotions;
    }
}

/**
 * Helper class for detailed game statistics calculation
 */
private class DetailedGameStats : Object {
    public int red_captures { get; private set; }
    public int red_promotions { get; private set; }
    public int black_captures { get; private set; }
    public int black_promotions { get; private set; }

    public DetailedGameStats(int red_captures, int red_promotions, int black_captures, int black_promotions) {
        this.red_captures = red_captures;
        this.red_promotions = red_promotions;
        this.black_captures = black_captures;
        this.black_promotions = black_promotions;
    }
}