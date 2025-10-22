/**
 * AIGameController.vala
 *
 * Handles AI move execution and timing.
 * Responsible for:
 * - Detecting when it's AI's turn
 * - Calculating AI moves asynchronously
 * - Managing AI move timing
 * - Triggering AI move animations
 */

using Draughts;

public class Draughts.AIGameController : Object {

    private IGameController game_controller;
    private AnimationController animation_controller;
    private Logger logger;
    private OpeningBook? opening_book;

    // AI state
    private bool ai_move_in_progress = false;
    private IAIPlayer? current_ai_player = null;

    // Signals
    public signal void ai_move_ready(DraughtsMove move);
    public signal void ai_thinking_started();
    public signal void ai_thinking_finished();

    public AIGameController(
        IGameController game_controller,
        AnimationController animation_controller
    ) {
        this.game_controller = game_controller;
        this.animation_controller = animation_controller;
        this.logger = Logger.get_default();

        // Initialize opening book
        try {
            this.opening_book = new OpeningBook();
        } catch (Error e) {
            logger.warning("Failed to initialize opening book: %s", e.message);
            this.opening_book = null;
        }
    }

    /**
     * Check if it's AI's turn and start move calculation if needed
     */
    public async void check_and_process_ai_turn(Game game, DraughtsGameState state) {
        if (ai_move_in_progress || animation_controller.is_animation_in_progress()) {
            return;
        }

        // Check if current player is AI
        var current_player = (state.active_player == PieceColor.RED)
            ? game.red_player
            : game.black_player;

        if (current_player.player_type != PlayerType.AI) {
            return; // Not AI's turn
        }

        // Process AI move
        yield process_ai_move(game, state, current_player);
    }

    /**
     * Process an AI move asynchronously
     */
    private async void process_ai_move(
        Game game,
        DraughtsGameState state,
        GamePlayer ai_player
    ) {
        ai_move_in_progress = true;
        ai_thinking_started();

        logger.info("AI is thinking (Difficulty: %s)...", ai_player.ai_difficulty.to_string());

        // Small delay to make AI feel more natural
        yield delay_ms(300);

        DraughtsMove? best_move = null;

        // Try opening book first
        if (opening_book != null && opening_book.is_enabled() && state.move_count < 15) {
            best_move = opening_book.lookup_position(state);
            if (best_move != null) {
                logger.info("AI using opening book move");
            }
        }

        // If no opening book move, calculate using AI
        if (best_move == null) {
            // Create AI player if needed
            if (current_ai_player == null ||
                current_ai_player.get_difficulty_level() != (int)ai_player.ai_difficulty) {
                var ai_manager = new AIDifficultyManager();
                current_ai_player = ai_manager.create_ai_player(ai_player.ai_difficulty);
            }

            // Get time limit for this difficulty
            var ai_manager = new AIDifficultyManager();
            uint time_limit = ai_manager.get_recommended_time_limit(ai_player.ai_difficulty);

            // Calculate best move
            var rule_engine = game_controller.get_rule_engine();
            best_move = current_ai_player.calculate_best_move(state, rule_engine, time_limit);
        }

        ai_thinking_finished();
        ai_move_in_progress = false;

        if (best_move != null) {
            logger.info("AI selected move: %s", best_move.to_algebraic_notation());

            // Add to opening book if early in game
            if (opening_book != null && state.move_count < 15) {
                opening_book.add_opening(state, best_move);
            }

            ai_move_ready(best_move);
        } else {
            logger.error("AI failed to find a valid move!");
        }
    }

    /**
     * Check if AI is currently thinking
     */
    public bool is_ai_thinking() {
        return ai_move_in_progress;
    }

    /**
     * Enable or disable the opening book
     */
    public void set_opening_book_enabled(bool enabled) {
        if (opening_book != null) {
            opening_book.set_enabled(enabled);
            logger.info("Opening book %s", enabled ? "enabled" : "disabled");
        }
    }

    /**
     * Get opening book statistics
     */
    public string? get_opening_book_stats() {
        if (opening_book != null) {
            return opening_book.get_statistics();
        }
        return null;
    }

    /**
     * Update opening book with game result
     */
    public void update_opening_book_result(
        DraughtsGameState state,
        DraughtsMove move,
        GameStatus result
    ) {
        if (opening_book != null) {
            opening_book.update_move_result(state, move, result);
        }
    }

    /**
     * Helper function for async delay
     */
    private async void delay_ms(uint milliseconds) {
        Timeout.add(milliseconds, () => {
            delay_ms.callback();
            return Source.REMOVE;
        });
        yield;
    }

    /**
     * Cancel current AI calculation
     */
    public void cancel_ai_calculation() {
        if (current_ai_player != null && current_ai_player.is_thinking()) {
            current_ai_player.cancel_calculation();
        }
        ai_move_in_progress = false;
    }
}
