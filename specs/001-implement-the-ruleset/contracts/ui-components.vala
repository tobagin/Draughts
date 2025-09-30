/**
 * UI Components Contract - Interface definitions for game UI elements
 *
 * This contract defines interfaces for the user interface components,
 * ensuring proper separation between game logic and presentation.
 */

namespace Draughts.UI.Contracts {

    /**
     * Interface for the main game board widget
     */
    public interface IGameBoard : Object {
        /**
         * Update the board display with new game state
         * @param state Current game state to display
         * @param highlighted_moves Legal moves to highlight, null for none
         */
        public abstract void update_board_state(GameState state, Move[]? highlighted_moves);

        /**
         * Set the board size and recalculate layout
         * @param size Board size (8, 10, or 12)
         */
        public abstract void set_board_size(int size);

        /**
         * Enable or disable user interaction
         * @param interactive true to allow moves, false to disable
         */
        public abstract void set_interactive(bool interactive);

        /**
         * Highlight legal moves for a selected piece
         * @param piece_position Position of selected piece
         * @param legal_moves Array of legal moves from this position
         */
        public abstract void highlight_legal_moves(Position piece_position, Move[] legal_moves);

        /**
         * Clear all highlighting and selection
         */
        public abstract void clear_highlights();

        /**
         * Animate a move from one position to another
         * @param move Move to animate
         * @param duration_ms Animation duration in milliseconds
         */
        public abstract void animate_move(Move move, uint duration_ms);

        /**
         * Signal emitted when user clicks on a board square
         * @param position Position that was clicked
         * @param piece Piece at that position, null if empty
         */
        public signal void square_clicked(Position position, GamePiece? piece);

        /**
         * Signal emitted when user attempts to make a move
         * @param move Proposed move from user interaction
         */
        public signal void move_attempted(Move move);

        /**
         * Signal emitted when piece selection changes
         * @param selected_position New selected position, null if deselected
         */
        public signal void piece_selected(Position? selected_position);
    }

    /**
     * Interface for game control panel
     */
    public interface IGameControls : Object {
        /**
         * Update the display of current player turn
         * @param active_player Current player (RED or BLACK)
         * @param player_name Display name of current player
         */
        public abstract void update_current_player(PieceColor active_player, string player_name);

        /**
         * Update timer displays
         * @param red_time Time remaining for red player in milliseconds
         * @param black_time Time remaining for black player in milliseconds
         */
        public abstract void update_timers(uint64 red_time, uint64 black_time);

        /**
         * Update move counter display
         * @param move_count Current number of moves in the game
         */
        public abstract void update_move_count(int move_count);

        /**
         * Enable or disable game control buttons
         * @param undo_available Whether undo button should be enabled
         * @param pause_available Whether pause button should be enabled
         */
        public abstract void update_button_states(bool undo_available, bool pause_available);

        /**
         * Show game result notification
         * @param result Final game result
         * @param message Human-readable result message
         */
        public abstract void show_game_result(GameResult result, string message);

        /**
         * Signal emitted when user requests undo
         */
        public signal void undo_requested();

        /**
         * Signal emitted when user toggles pause
         */
        public signal void pause_toggled();

        /**
         * Signal emitted when user requests new game
         */
        public signal void new_game_requested();

        /**
         * Signal emitted when user opens preferences
         */
        public signal void preferences_requested();
    }

    /**
     * Interface for variant selection dialog
     */
    public interface IVariantSelector : Object {
        /**
         * Show variant selection dialog
         * @param available_variants Array of supported variants
         * @param current_variant Currently selected variant, null for none
         */
        public abstract void show_selection(GameVariant[] available_variants, GameVariant? current_variant);

        /**
         * Hide the selection dialog
         */
        public abstract void hide_selection();

        /**
         * Get the currently selected variant
         * @return Selected variant or null if none
         */
        public abstract GameVariant? get_selected_variant();

        /**
         * Signal emitted when user selects a variant
         * @param variant Selected game variant
         */
        public signal void variant_selected(GameVariant variant);

        /**
         * Signal emitted when user cancels selection
         */
        public signal void selection_cancelled();
    }

    /**
     * Interface for player configuration dialog
     */
    public interface IPlayerSetup : Object {
        /**
         * Show player setup dialog
         * @param red_player Current red player configuration
         * @param black_player Current black player configuration
         */
        public abstract void show_setup(Player red_player, Player black_player);

        /**
         * Hide the setup dialog
         */
        public abstract void hide_setup();

        /**
         * Get configured players
         * @param red_player Output parameter for red player
         * @param black_player Output parameter for black player
         * @return true if configuration is valid, false otherwise
         */
        public abstract bool get_player_configuration(out Player red_player, out Player black_player);

        /**
         * Signal emitted when user confirms player setup
         * @param red_player Configured red player
         * @param black_player Configured black player
         */
        public signal void players_configured(Player red_player, Player black_player);

        /**
         * Signal emitted when user cancels setup
         */
        public signal void setup_cancelled();
    }

    /**
     * Interface for timing configuration
     */
    public interface ITimerSetup : Object {
        /**
         * Show timer configuration dialog
         * @param current_config Current timer configuration, null for untimed
         */
        public abstract void show_configuration(TimerConfig? current_config);

        /**
         * Hide the configuration dialog
         */
        public abstract void hide_configuration();

        /**
         * Get the configured timer settings
         * @return Timer configuration or null for untimed game
         */
        public abstract TimerConfig? get_timer_configuration();

        /**
         * Signal emitted when user confirms timer setup
         * @param config Timer configuration, null for untimed
         */
        public signal void timer_configured(TimerConfig? config);

        /**
         * Signal emitted when user cancels timer setup
         */
        public signal void timer_setup_cancelled();
    }

    /**
     * Interface for accessibility announcements
     */
    public interface IAccessibilityAnnouncer : Object {
        /**
         * Announce current game state to screen readers
         * @param state Game state to describe
         */
        public abstract void announce_game_state(GameState state);

        /**
         * Announce a move that was made
         * @param move Move to describe
         * @param result_state Game state after the move
         */
        public abstract void announce_move(Move move, GameState result_state);

        /**
         * Announce game result
         * @param result Final result
         * @param reason Human-readable reason
         */
        public abstract void announce_game_result(GameResult result, string reason);

        /**
         * Announce available moves for current piece
         * @param piece_position Selected piece position
         * @param legal_moves Available moves from this position
         */
        public abstract void announce_legal_moves(Position piece_position, Move[] legal_moves);

        /**
         * Announce timer warnings
         * @param player Player running low on time
         * @param time_remaining Time left in milliseconds
         */
        public abstract void announce_time_warning(PieceColor player, uint64 time_remaining);
    }

    /**
     * Interface for game preferences management
     */
    public interface IPreferencesManager : Object {
        /**
         * Load preferences from persistent storage
         */
        public abstract void load_preferences();

        /**
         * Save current preferences to persistent storage
         */
        public abstract void save_preferences();

        /**
         * Get game-related preferences
         * @return Current game preferences
         */
        public abstract GamePreferences get_game_preferences();

        /**
         * Set game-related preferences
         * @param prefs New game preferences
         */
        public abstract void set_game_preferences(GamePreferences prefs);

        /**
         * Get AI-related preferences
         * @return Current AI preferences
         */
        public abstract AIPreferences get_ai_preferences();

        /**
         * Set AI-related preferences
         * @param prefs New AI preferences
         */
        public abstract void set_ai_preferences(AIPreferences prefs);

        /**
         * Get accessibility preferences
         * @return Current accessibility preferences
         */
        public abstract AccessibilityPreferences get_accessibility_preferences();

        /**
         * Set accessibility preferences
         * @param prefs New accessibility preferences
         */
        public abstract void set_accessibility_preferences(AccessibilityPreferences prefs);

        /**
         * Signal emitted when preferences change
         * @param category Category that changed (game, ai, accessibility)
         */
        public signal void preferences_changed(string category);
    }
}