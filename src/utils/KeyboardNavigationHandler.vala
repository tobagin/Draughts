/**
 * KeyboardNavigationHandler.vala
 *
 * Comprehensive keyboard navigation system for draughts game accessibility.
 * Provides full keyboard control of the game board and interface elements.
 */

using Draughts;

public class Draughts.KeyboardNavigationHandler : Object {
    private DraughtsBoardAdapter adapter;
    private BoardRenderer renderer;
    private Gtk.Widget board_widget;

    // Navigation state
    private int cursor_row = 0;
    private int cursor_col = 0;
    private int selected_row = -1;
    private int selected_col = -1;
    private bool navigation_enabled = false;

    // Visual indicators
    private bool show_cursor = true;
    private bool cursor_visible = true;
    private uint cursor_blink_timer = 0;

    // Signals
    public signal void cursor_moved(int row, int col);
    public signal void piece_selected_by_keyboard(int row, int col);
    public signal void move_attempted_by_keyboard(int from_row, int from_col, int to_row, int to_col);

    public KeyboardNavigationHandler(DraughtsBoardAdapter adapter, BoardRenderer renderer, Gtk.Widget board_widget) {
        this.adapter = adapter;
        this.renderer = renderer;
        this.board_widget = board_widget;

        setup_keyboard_events();
        start_cursor_blink_timer();
    }

    /**
     * Setup keyboard event handling
     */
    private void setup_keyboard_events() {
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        key_controller.key_released.connect(on_key_released);
        board_widget.add_controller(key_controller);

        // Ensure widget can receive focus
        board_widget.focusable = true;
        board_widget.can_focus = true;
    }

    /**
     * Handle key press events
     */
    private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        if (!navigation_enabled) return false;

        bool ctrl_pressed = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
        bool shift_pressed = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
        bool alt_pressed = (state & Gdk.ModifierType.ALT_MASK) != 0;

        switch (keyval) {
            // Cursor movement
            case Gdk.Key.Up:
            case Gdk.Key.k:
                move_cursor(0, -1);
                return true;

            case Gdk.Key.Down:
            case Gdk.Key.j:
                move_cursor(0, 1);
                return true;

            case Gdk.Key.Left:
            case Gdk.Key.h:
                move_cursor(-1, 0);
                return true;

            case Gdk.Key.Right:
            case Gdk.Key.l:
                move_cursor(1, 0);
                return true;

            // Diagonal movement
            case Gdk.Key.q:
                move_cursor(-1, -1);
                return true;

            case Gdk.Key.e:
                move_cursor(1, -1);
                return true;

            case Gdk.Key.z:
                if (!ctrl_pressed) {
                    move_cursor(-1, 1);
                    return true;
                }
                break;

            case Gdk.Key.c:
                if (!ctrl_pressed) {
                    move_cursor(1, 1);
                    return true;
                }
                break;

            // Selection and moves
            case Gdk.Key.space:
            case Gdk.Key.Return:
                handle_selection_or_move();
                return true;

            case Gdk.Key.Escape:
                clear_selection();
                return true;

            // Quick navigation
            case Gdk.Key.Home:
                if (ctrl_pressed) {
                    move_cursor_to_corner(0, 0);
                } else {
                    move_cursor_to_start_of_row();
                }
                return true;

            case Gdk.Key.End:
                if (ctrl_pressed) {
                    move_cursor_to_corner(get_navigation_board_size() - 1, get_navigation_board_size() - 1);
                } else {
                    move_cursor_to_end_of_row();
                }
                return true;

            case Gdk.Key.Page_Up:
                move_cursor(0, -4);
                return true;

            case Gdk.Key.Page_Down:
                move_cursor(0, 4);
                return true;

            // Piece information
            case Gdk.Key.i:
                announce_square_info();
                return true;

            case Gdk.Key.p:
                announce_piece_info();
                return true;

            case Gdk.Key.m:
                announce_available_moves();
                return true;

            // Game control shortcuts
            case Gdk.Key.n:
                if (ctrl_pressed) {
                    // New game
                    board_widget.activate_action("win.new-game", null);
                    return true;
                }
                break;

            case Gdk.Key.r:
                if (ctrl_pressed) {
                    // Reset game
                    board_widget.activate_action("win.reset-game", null);
                    return true;
                }
                break;

            case Gdk.Key.u:
                if (ctrl_pressed) {
                    // Undo move
                    board_widget.activate_action("win.undo-move", null);
                    return true;
                }
                break;

            // Help
            case Gdk.Key.F1:
            case Gdk.Key.question:
                announce_keyboard_help();
                return true;
        }

        return false;
    }

    /**
     * Handle key release events
     */
    private void on_key_released(uint keyval, uint keycode, Gdk.ModifierType state) {
        // Currently no specific key release handling needed
    }

    /**
     * Move cursor by delta
     */
    private void move_cursor(int delta_col, int delta_row) {
        int new_row = cursor_row + delta_row;
        int new_col = cursor_col + delta_col;

        int board_size = get_navigation_board_size();

        // Wrap around or clamp to bounds
        new_row = int.max(0, int.min(board_size - 1, new_row));
        new_col = int.max(0, int.min(board_size - 1, new_col));

        if (new_row != cursor_row || new_col != cursor_col) {
            cursor_row = new_row;
            cursor_col = new_col;

            cursor_moved(cursor_row, cursor_col);
            announce_cursor_position();

            // Reset cursor blink
            cursor_visible = true;
            queue_board_redraw();
        }
    }

    /**
     * Move cursor to specific position
     */
    private void move_cursor_to_position(int row, int col) {
        int board_size = get_navigation_board_size();
        row = int.max(0, int.min(board_size - 1, row));
        col = int.max(0, int.min(board_size - 1, col));

        if (row != cursor_row || col != cursor_col) {
            cursor_row = row;
            cursor_col = col;
            cursor_moved(cursor_row, cursor_col);
            announce_cursor_position();
            queue_board_redraw();
        }
    }

    /**
     * Move cursor to corner
     */
    private void move_cursor_to_corner(int row, int col) {
        move_cursor_to_position(row, col);
    }

    /**
     * Move cursor to start of current row
     */
    private void move_cursor_to_start_of_row() {
        move_cursor_to_position(cursor_row, 0);
    }

    /**
     * Move cursor to end of current row
     */
    private void move_cursor_to_end_of_row() {
        int board_size = get_navigation_board_size();
        move_cursor_to_position(cursor_row, board_size - 1);
    }

    /**
     * Handle selection or move action
     */
    private void handle_selection_or_move() {
        if (selected_row == -1) {
            // No piece selected, try to select piece at cursor
            var legal_moves = adapter.get_legal_moves_for_position(cursor_row, cursor_col);
            if (legal_moves.size > 0) {
                selected_row = cursor_row;
                selected_col = cursor_col;
                piece_selected_by_keyboard(cursor_row, cursor_col);
                announce_piece_selected();
                queue_board_redraw();
            } else {
                announce_no_piece_at_cursor();
            }
        } else {
            // Piece already selected, try to move
            if (cursor_row == selected_row && cursor_col == selected_col) {
                // Clicked same square, deselect
                clear_selection();
            } else {
                // Try to move to cursor position
                move_attempted_by_keyboard(selected_row, selected_col, cursor_row, cursor_col);
                bool success = adapter.handle_board_move(selected_row, selected_col, cursor_row, cursor_col);
                if (success) {
                    announce_move_made(selected_row, selected_col, cursor_row, cursor_col);
                    clear_selection();
                } else {
                    announce_invalid_move();
                }
            }
        }
    }

    /**
     * Clear current selection
     */
    private void clear_selection() {
        if (selected_row != -1) {
            selected_row = -1;
            selected_col = -1;
            announce_selection_cleared();
            queue_board_redraw();
        }
    }

    /**
     * Start cursor blink timer
     */
    private void start_cursor_blink_timer() {
        if (cursor_blink_timer != 0) {
            Source.remove(cursor_blink_timer);
        }

        cursor_blink_timer = Timeout.add(500, () => {
            if (show_cursor && navigation_enabled) {
                cursor_visible = !cursor_visible;
                queue_board_redraw();
            }
            return true;
        });
    }

    /**
     * Queue board redraw
     */
    private void queue_board_redraw() {
        board_widget.queue_draw();
    }

    /**
     * Get board size from current variant
     */
    private int get_navigation_board_size() {
        var variant = adapter.get_current_variant();
        return variant != null ? variant.board_size : 8;
    }

    /**
     * Render keyboard navigation overlays
     */
    public void render_navigation_overlay(Cairo.Context cr) {
        if (!navigation_enabled || !show_cursor) return;

        double square_size = renderer.get_square_size();

        // Draw cursor
        if (cursor_visible) {
            render_cursor(cr, cursor_row, cursor_col, square_size);
        }

        // Draw selection highlight
        if (selected_row != -1) {
            render_selection_highlight(cr, selected_row, selected_col, square_size);
        }
    }

    /**
     * Render cursor indicator
     */
    private void render_cursor(Cairo.Context cr, int row, int col, double square_size) {
        double x = col * square_size;
        double y = row * square_size;

        // Cursor border
        cr.set_source_rgba(1.0, 1.0, 0.0, 0.8); // Yellow
        cr.set_line_width(3.0);
        cr.rectangle(x + 2, y + 2, square_size - 4, square_size - 4);
        cr.stroke();

        // Cursor corners
        double corner_size = 8.0;
        cr.set_line_width(2.0);

        // Top-left corner
        cr.move_to(x + 2, y + 2 + corner_size);
        cr.line_to(x + 2, y + 2);
        cr.line_to(x + 2 + corner_size, y + 2);
        cr.stroke();

        // Top-right corner
        cr.move_to(x + square_size - 2 - corner_size, y + 2);
        cr.line_to(x + square_size - 2, y + 2);
        cr.line_to(x + square_size - 2, y + 2 + corner_size);
        cr.stroke();

        // Bottom-left corner
        cr.move_to(x + 2, y + square_size - 2 - corner_size);
        cr.line_to(x + 2, y + square_size - 2);
        cr.line_to(x + 2 + corner_size, y + square_size - 2);
        cr.stroke();

        // Bottom-right corner
        cr.move_to(x + square_size - 2 - corner_size, y + square_size - 2);
        cr.line_to(x + square_size - 2, y + square_size - 2);
        cr.line_to(x + square_size - 2, y + square_size - 2 - corner_size);
        cr.stroke();
    }

    /**
     * Render selection highlight
     */
    private void render_selection_highlight(Cairo.Context cr, int row, int col, double square_size) {
        double x = col * square_size;
        double y = row * square_size;

        cr.set_source_rgba(0.0, 1.0, 0.0, 0.3); // Green with transparency
        cr.rectangle(x, y, square_size, square_size);
        cr.fill();

        cr.set_source_rgba(0.0, 1.0, 0.0, 0.8); // Green border
        cr.set_line_width(2.0);
        cr.rectangle(x + 1, y + 1, square_size - 2, square_size - 2);
        cr.stroke();
    }

    /**
     * Enable/disable keyboard navigation
     */
    public void set_navigation_enabled(bool enabled) {
        navigation_enabled = enabled;

        if (enabled) {
            board_widget.grab_focus();
        } else {
            clear_selection();
        }

        queue_board_redraw();
    }

    /**
     * Check if navigation is enabled
     */
    public bool is_navigation_enabled() {
        return navigation_enabled;
    }

    /**
     * Set cursor visibility
     */
    public void set_cursor_visible(bool visible) {
        show_cursor = visible;
        queue_board_redraw();
    }

    /**
     * Get current cursor position
     */
    public void get_cursor_position(out int row, out int col) {
        row = cursor_row;
        col = cursor_col;
    }

    /**
     * Set cursor position
     */
    public void set_cursor_position(int row, int col) {
        move_cursor_to_position(row, col);
    }

    /**
     * Audio/screen reader announcements
     */
    private void announce_cursor_position() {
        string square_name = get_square_name(cursor_row, cursor_col);
        string announcement = @"Cursor at $square_name";

        var piece = get_piece_at_position(cursor_row, cursor_col);
        if (piece != null) {
            announcement += @", $(get_piece_description(piece))";
        } else {
            announcement += ", empty square";
        }

        announce_to_screen_reader(announcement);
    }

    private void announce_piece_selected() {
        string square_name = get_square_name(selected_row, selected_col);
        var piece = get_piece_at_position(selected_row, selected_col);
        string piece_desc = piece != null ? get_piece_description(piece) : "piece";

        announce_to_screen_reader(@"Selected $(piece_desc) at $(square_name)");
    }

    private void announce_selection_cleared() {
        announce_to_screen_reader("Selection cleared");
    }

    private void announce_no_piece_at_cursor() {
        string square_name = get_square_name(cursor_row, cursor_col);
        announce_to_screen_reader(@"No piece at $(square_name)");
    }

    private void announce_move_made(int from_row, int from_col, int to_row, int to_col) {
        string from_square = get_square_name(from_row, from_col);
        string to_square = get_square_name(to_row, to_col);
        announce_to_screen_reader(@"Moved from $(from_square) to $(to_square)");
    }

    private void announce_invalid_move() {
        announce_to_screen_reader("Invalid move");
    }

    private void announce_square_info() {
        string square_name = get_square_name(cursor_row, cursor_col);
        var piece = get_piece_at_position(cursor_row, cursor_col);

        if (piece != null) {
            string piece_desc = get_piece_description(piece);
            announce_to_screen_reader(@"$(square_name): $(piece_desc)");
        } else {
            bool is_dark = (cursor_row + cursor_col) % 2 == 1;
            string square_color = is_dark ? "dark" : "light";
            announce_to_screen_reader(@"$(square_name): empty $(square_color) square");
        }
    }

    private void announce_piece_info() {
        var piece = get_piece_at_position(cursor_row, cursor_col);
        if (piece != null) {
            string detailed_desc = get_detailed_piece_description(piece);
            announce_to_screen_reader(detailed_desc);
        } else {
            announce_to_screen_reader("No piece at cursor position");
        }
    }

    private void announce_available_moves() {
        var legal_moves = adapter.get_legal_moves_for_position(cursor_row, cursor_col);

        if (legal_moves.size == 0) {
            announce_to_screen_reader("No legal moves available");
        } else {
            var move_descriptions = new StringBuilder();
            move_descriptions.append_printf("%d legal moves: ", legal_moves.size);

            for (int i = 0; i < legal_moves.size && i < 5; i++) { // Limit to first 5 moves
                var move = legal_moves.get(i);
                string to_square = get_square_name(move.to_position.row, move.to_position.col);
                move_descriptions.append_printf("%s", to_square);
                if (i < legal_moves.size - 1 && i < 4) {
                    move_descriptions.append(", ");
                }
            }

            if (legal_moves.size > 5) {
                move_descriptions.append(" and more");
            }

            announce_to_screen_reader(move_descriptions.str);
        }
    }

    private void announce_keyboard_help() {
        announce_to_screen_reader("Keyboard navigation help: Arrow keys to move cursor, Space to select or move, Escape to clear selection, I for square info, M for available moves");
    }

    /**
     * Helper methods
     */
    private string get_square_name(int row, int col) {
        char col_letter = (char)('a' + col);
        int row_number = get_navigation_board_size() - row;
        return @"$(col_letter)$(row_number)";
    }

    private GamePiece? get_piece_at_position(int row, int col) {
        var current_state = adapter.get_current_state();
        if (current_state == null) return null;

        var pos = new BoardPosition(row, col, get_navigation_board_size());
        foreach (var piece in current_state.pieces) {
            if (piece.position.equals(pos)) {
                return piece;
            }
        }
        return null;
    }

    private string get_piece_description(GamePiece piece) {
        string color = (piece.color == PieceColor.RED) ? "red" : "black";
        string type = (piece.piece_type == DraughtsPieceType.KING) ? "king" : "man";
        return @"$(color) $(type)";
    }

    private string get_detailed_piece_description(GamePiece piece) {
        string basic_desc = get_piece_description(piece);
        string square_name = get_square_name(piece.position.row, piece.position.col);
        return @"$(basic_desc) at $(square_name), piece ID $(piece.id)";
    }

    private void announce_to_screen_reader(string message) {
        // This would integrate with AT-SPI or similar accessibility framework
        // For now, we'll use a simple debug output
        debug("Screen reader announcement: %s", message);

        // In a real implementation, this would send the announcement to the accessibility system
        // using AT-SPI or similar platform-specific accessibility APIs
    }

    /**
     * Cleanup
     */
    public override void dispose() {
        if (cursor_blink_timer != 0) {
            Source.remove(cursor_blink_timer);
            cursor_blink_timer = 0;
        }
        base.dispose();
    }
}