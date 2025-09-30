/**
 * BoardInteractionHandler.vala
 *
 * Handles mouse and touch interactions for the draughts board.
 * Manages piece selection, drag and drop, move validation, and click handling.
 */

using Draughts;

public class Draughts.BoardInteractionHandler : Object {
    private DraughtsBoardAdapter adapter;
    private BoardRenderer renderer;
    private Gtk.Widget widget;
    private SettingsManager settings_manager;

    // Interaction state
    private bool is_dragging = false;
    private int selected_row = -1;
    private int selected_col = -1;
    private int drag_start_row = -1;
    private int drag_start_col = -1;
    private double drag_offset_x = 0;
    private double drag_offset_y = 0;

    // Interaction mode
    private InteractionMode current_mode = InteractionMode.CLICK_TO_SELECT;

    // Signals
    public signal void piece_selected(int row, int col);
    public signal void piece_deselected();
    public signal void move_attempted(int from_row, int from_col, int to_row, int to_col);
    public signal void invalid_move_attempted();

    public BoardInteractionHandler(DraughtsBoardAdapter adapter, BoardRenderer renderer, Gtk.Widget widget) {
        this.adapter = adapter;
        this.renderer = renderer;
        this.widget = widget;
        this.settings_manager = SettingsManager.get_instance();

        // Set initial interaction mode from settings
        update_interaction_mode_from_settings();

        // Listen for setting changes
        settings_manager.bind("drag-and-drop", this, "drag-and-drop-enabled", GLib.SettingsBindFlags.DEFAULT);
        notify["drag-and-drop-enabled"].connect(() => {
            update_interaction_mode_from_settings();
        });

        setup_event_handlers();
    }

    // Property to bind with settings
    public bool drag_and_drop_enabled { get; set; }

    /**
     * Update interaction mode based on current setting
     */
    private void update_interaction_mode_from_settings() {
        bool enabled = settings_manager.get_drag_and_drop();
        current_mode = enabled ? InteractionMode.DRAG_AND_DROP : InteractionMode.CLICK_TO_SELECT;
        clear_selection();
    }

    /**
     * Setup mouse and touch event handlers
     */
    private void setup_event_handlers() {
        // Create gesture controllers
        var click_gesture = new Gtk.GestureClick();
        var drag_gesture = new Gtk.GestureDrag();

        // Configure click gesture
        click_gesture.button = Gdk.BUTTON_PRIMARY;
        click_gesture.pressed.connect(on_button_press);
        click_gesture.released.connect(on_button_release);

        // Configure drag gesture
        drag_gesture.drag_begin.connect(on_drag_begin);
        drag_gesture.drag_update.connect(on_drag_update);
        drag_gesture.drag_end.connect(on_drag_end);

        // Add gestures to widget
        widget.add_controller(click_gesture);
        widget.add_controller(drag_gesture);

        // Setup motion controller for hover effects
        var motion_controller = new Gtk.EventControllerMotion();
        motion_controller.motion.connect(on_motion);
        motion_controller.leave.connect(on_leave);
        widget.add_controller(motion_controller);

        // Setup key controller for keyboard shortcuts
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        widget.add_controller(key_controller);
    }

    /**
     * Handle button press events
     */
    private void on_button_press(int n_press, double x, double y) {
        if (!adapter.is_human_turn()) {
            return;
        }

        int row, col;
        if (!renderer.screen_to_board_coords(x, y, out row, out col)) {
            return;
        }

        // Check if there's a piece at this position
        var legal_moves = adapter.get_legal_moves_for_position(row, col);
        bool has_piece = legal_moves.size > 0;

        switch (current_mode) {
            case InteractionMode.CLICK_TO_SELECT:
                handle_click_to_select(row, col, has_piece);
                break;
            case InteractionMode.DRAG_AND_DROP:
                handle_drag_start(row, col, has_piece, x, y);
                break;
        }
    }

    /**
     * Handle button release events
     */
    private void on_button_release(int n_press, double x, double y) {
        if (current_mode == InteractionMode.CLICK_TO_SELECT && selected_row != -1) {
            int row, col;
            if (renderer.screen_to_board_coords(x, y, out row, out col)) {
                if (row != selected_row || col != selected_col) {
                    // Attempt to move to this square
                    attempt_move(selected_row, selected_col, row, col);
                }
            }
        }
    }

    /**
     * Handle drag begin events
     */
    private void on_drag_begin(double start_x, double start_y) {
        if (!adapter.is_human_turn() || current_mode != InteractionMode.DRAG_AND_DROP) {
            return;
        }

        int row, col;
        if (!renderer.screen_to_board_coords(start_x, start_y, out row, out col)) {
            return;
        }

        var legal_moves = adapter.get_legal_moves_for_position(row, col);
        if (legal_moves.size > 0) {
            is_dragging = true;
            drag_start_row = row;
            drag_start_col = col;

            // Calculate offset from piece center
            double piece_center_x, piece_center_y;
            renderer.board_to_screen_coords(row, col, out piece_center_x, out piece_center_y);
            drag_offset_x = start_x - piece_center_x;
            drag_offset_y = start_y - piece_center_y;

            // Select the piece and show possible moves
            select_piece(row, col);
        }
    }

    /**
     * Handle drag update events
     */
    private void on_drag_update(double offset_x, double offset_y) {
        if (!is_dragging) {
            return;
        }

        // Update cursor or visual feedback during drag
        widget.queue_draw();
    }

    /**
     * Handle drag end events
     */
    private void on_drag_end(double offset_x, double offset_y) {
        if (!is_dragging) {
            return;
        }

        is_dragging = false;

        // Get the current gesture position
        var gesture = widget.get_last_child() as Gtk.GestureDrag; // This is simplified
        double current_x, current_y;
        if (gesture != null && gesture.get_start_point(out current_x, out current_y)) {
            current_x += offset_x;
            current_y += offset_y;

            int target_row, target_col;
            if (renderer.screen_to_board_coords(current_x, current_y, out target_row, out target_col)) {
                // Attempt to move to the target square
                attempt_move(drag_start_row, drag_start_col, target_row, target_col);
            }
        }

        // Clear drag state
        drag_start_row = -1;
        drag_start_col = -1;
        clear_selection();
    }

    /**
     * Handle mouse motion events
     */
    private void on_motion(double x, double y) {
        // Update hover effects or cursor
        int row, col;
        if (renderer.screen_to_board_coords(x, y, out row, out col)) {
            var legal_moves = adapter.get_legal_moves_for_position(row, col);
            if (legal_moves.size > 0 && adapter.is_human_turn()) {
                widget.set_cursor_from_name("pointer");
            } else {
                widget.set_cursor_from_name("default");
            }
        }
    }

    /**
     * Handle mouse leave events
     */
    private void on_leave() {
        widget.set_cursor_from_name("default");
    }

    /**
     * Handle key press events
     */
    private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        switch (keyval) {
            case Gdk.Key.Escape:
                clear_selection();
                return true;

            case Gdk.Key.space:
            case Gdk.Key.Return:
                if (selected_row != -1 && selected_col != -1) {
                    // Show available moves or confirm selection
                    adapter.highlight_possible_moves(selected_row, selected_col);
                    return true;
                }
                break;

            case Gdk.Key.z:
                if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    // Ctrl+Z for undo
                    adapter.undo_last_move();
                    return true;
                }
                break;
        }

        return false;
    }

    /**
     * Handle click-to-select interaction mode
     */
    private void handle_click_to_select(int row, int col, bool has_piece) {
        if (selected_row == row && selected_col == col) {
            // Clicking the same piece again - deselect
            clear_selection();
        } else if (has_piece) {
            // Select this piece
            select_piece(row, col);
        } else if (selected_row != -1) {
            // Try to move to this empty square
            attempt_move(selected_row, selected_col, row, col);
        }
    }

    /**
     * Handle drag start for drag-and-drop mode
     */
    private void handle_drag_start(int row, int col, bool has_piece, double x, double y) {
        if (has_piece) {
            // Start dragging this piece
            select_piece(row, col);
        }
    }

    /**
     * Select a piece and highlight possible moves
     */
    private void select_piece(int row, int col) {
        selected_row = row;
        selected_col = col;

        // Highlight the piece and its possible moves
        adapter.highlight_possible_moves(row, col);

        piece_selected(row, col);
    }

    /**
     * Clear piece selection
     */
    private void clear_selection() {
        selected_row = -1;
        selected_col = -1;

        // Clear highlights
        adapter.clear_highlights();

        piece_deselected();
    }

    /**
     * Attempt to make a move
     */
    private void attempt_move(int from_row, int from_col, int to_row, int to_col) {
        move_attempted(from_row, from_col, to_row, to_col);

        bool success = adapter.handle_board_move(from_row, from_col, to_row, to_col);

        if (success) {
            clear_selection();

            // Process AI turn if needed
            if (!adapter.is_human_turn()) {
                adapter.process_ai_turn.begin();
            }
        } else {
            invalid_move_attempted();

            // Keep the piece selected if move was invalid
            if (current_mode == InteractionMode.CLICK_TO_SELECT) {
                adapter.highlight_possible_moves(from_row, from_col);
            }
        }
    }

    /**
     * Set interaction mode
     */
    public void set_interaction_mode(InteractionMode mode) {
        current_mode = mode;
        clear_selection();
    }

    /**
     * Get current interaction mode
     */
    public InteractionMode get_interaction_mode() {
        return current_mode;
    }

    /**
     * Check if a piece is currently selected
     */
    public bool has_selection() {
        return selected_row != -1 && selected_col != -1;
    }

    /**
     * Get currently selected piece position
     */
    public void get_selection(out int row, out int col) {
        row = selected_row;
        col = selected_col;
    }

    /**
     * Handle board rotation (for different player perspectives)
     */
    public void set_board_orientation(PieceColor player_perspective) {
        // This would rotate the coordinate system if needed
        // For now, we'll keep the standard orientation
    }

    /**
     * Enable/disable interactions
     */
    public void set_interaction_enabled(bool enabled) {
        widget.sensitive = enabled;
    }

    /**
     * Get legal moves for currently selected piece
     */
    public Gee.ArrayList<DraughtsMove> get_selected_piece_moves() {
        if (selected_row != -1 && selected_col != -1) {
            return adapter.get_legal_moves_for_position(selected_row, selected_col);
        }
        return new Gee.ArrayList<DraughtsMove>();
    }

    /**
     * Force selection of a specific piece (for external control)
     */
    public void select_piece_at(int row, int col) {
        var legal_moves = adapter.get_legal_moves_for_position(row, col);
        if (legal_moves.size > 0) {
            select_piece(row, col);
        }
    }

    /**
     * Clear all interaction state
     */
    public void reset() {
        clear_selection();
        is_dragging = false;
        drag_start_row = -1;
        drag_start_col = -1;
    }
}

/**
 * Interaction mode enumeration
 */
public enum InteractionMode {
    CLICK_TO_SELECT,    // Click to select piece, click destination to move
    DRAG_AND_DROP       // Drag piece to destination
}