/**
 * GameControls.vala
 *
 * Game control panel widget providing play/pause, reset, undo,
 * variant selection, and other game management controls.
 */

using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/widgets/game-controls.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/widgets/game-controls.ui")]
#endif
public class Draughts.GameControls : Gtk.Box {


    // Game state
    private DraughtsBoardAdapter? adapter;
    private GameStatus current_status = GameStatus.NOT_STARTED;
    private bool is_paused = false;

    // Signals
    public signal void new_game_requested(DraughtsVariant variant);
    public signal void game_reset_requested();
    public signal void undo_requested();
    public signal void variant_changed(DraughtsVariant variant);
    public signal void difficulty_changed(AIDifficulty difficulty);

    public GameControls() {
        // No UI setup needed since all controls were removed
    }

    /**
     * Connect to a game adapter
     */
    public void connect_adapter(DraughtsBoardAdapter adapter) {
        this.adapter = adapter;

        // Connect to adapter signals
        adapter.game_state_changed.connect(on_game_state_changed);
        adapter.game_finished.connect(on_game_finished);
        adapter.move_made.connect(on_move_made);
    }



    /**
     * Handle game state changes
     */
    private void on_game_state_changed(DraughtsGameState new_state) {
        current_status = new_state.game_status;
        // No UI updates needed since controls were removed
    }

    /**
     * Handle game completion
     */
    private void on_game_finished(GameStatus result) {
        current_status = result;
        is_paused = false;
        // No UI updates needed since controls were removed
    }

    /**
     * Handle move made
     */
    private void on_move_made(DraughtsMove move) {
        // No UI updates needed since controls were removed
    }



    /**
     * Get currently selected variant (default since no dropdown)
     */
    public DraughtsVariant get_selected_variant() {
        return DraughtsVariant.AMERICAN;
    }

    /**
     * Get currently selected difficulty (default since no dropdown)
     */
    public AIDifficulty get_selected_difficulty() {
        return AIDifficulty.MEDIUM;
    }

    /**
     * Set variant selection programmatically (no-op since no dropdown)
     */
    public void set_selected_variant(DraughtsVariant variant) {
        // No-op: variant is now controlled via menu
    }

    /**
     * Set difficulty selection programmatically (no-op since no dropdown)
     */
    public void set_selected_difficulty(AIDifficulty difficulty) {
        // No-op: difficulty is now controlled via menu
    }

    /**
     * Enable/disable all controls
     */
    public void set_controls_enabled(bool enabled) {
        this.sensitive = enabled;
    }

    /**
     * Show/hide advanced controls
     */
    public void set_advanced_mode(bool advanced) {
        // No advanced controls currently in the simplified interface
        // Advanced settings are now in the menu
    }
}