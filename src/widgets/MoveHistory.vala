/**
 * MoveHistory.vala
 *
 * Widget displaying the complete move history of the current game.
 * Supports move navigation, game replay, and algebraic notation display.
 */

using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/widgets/move-history.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/widgets/move-history.ui")]
#endif
public class Draughts.MoveHistory : Gtk.Box {
    [GtkChild]
    private unowned Gtk.ScrolledWindow history_scroll;

    [GtkChild]
    private unowned Gtk.ListView move_list;

    [GtkChild]
    private unowned Gtk.Label moves_count_label;

    [GtkChild]
    private unowned Gtk.Button export_pgn_button;

    [GtkChild]
    private unowned Gtk.Button clear_history_button;

    [GtkChild]
    private unowned Gtk.Box navigation_controls;

    [GtkChild]
    private unowned Gtk.Button first_move_button;

    [GtkChild]
    private unowned Gtk.Button prev_move_button;

    [GtkChild]
    private unowned Gtk.Button next_move_button;

    [GtkChild]
    private unowned Gtk.Button last_move_button;

    // Data model
    private Gtk.StringList move_model;
    private Gee.ArrayList<DraughtsMove> moves;
    private int current_move_index = -1;
    private bool replay_mode = false;

    // Connected game
    private DraughtsBoardAdapter? adapter;

    // Signals
    public signal void move_selected(int move_index);
    public signal void replay_position_changed(int move_index);
    public signal void export_requested(string pgn_content);

    public MoveHistory() {
        moves = new Gee.ArrayList<DraughtsMove>();
        move_model = new Gtk.StringList(null);

        setup_move_list();
        setup_controls();
        update_navigation_state();
    }

    /**
     * Connect to game adapter
     */
    public void connect_adapter(DraughtsBoardAdapter adapter) {
        if (this.adapter != null) {
            // Disconnect from previous adapter
            this.adapter.move_made.disconnect(on_move_made);
            this.adapter.game_finished.disconnect(on_game_finished);
        }

        this.adapter = adapter;

        // Connect to new adapter
        adapter.move_made.connect(on_move_made);
        adapter.game_finished.connect(on_game_finished);

        clear_history();
    }

    /**
     * Setup the move list view
     */
    private void setup_move_list() {
        move_list.model = new Gtk.SingleSelection(move_model);

        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect(on_list_item_setup);
        factory.bind.connect(on_list_item_bind);
        move_list.factory = factory;

        // Handle selection changes
        var selection = move_list.model as Gtk.SingleSelection;
        selection.selection_changed.connect(on_selection_changed);
    }

    /**
     * Setup control buttons
     */
    private void setup_controls() {
        export_pgn_button.clicked.connect(on_export_pgn);
        clear_history_button.clicked.connect(on_clear_history);

        // Navigation buttons
        first_move_button.clicked.connect(() => navigate_to_move(0));
        prev_move_button.clicked.connect(() => navigate_relative(-1));
        next_move_button.clicked.connect(() => navigate_relative(1));
        last_move_button.clicked.connect(() => navigate_to_move(moves.size - 1));

        // Keyboard shortcuts
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        this.add_controller(key_controller);
    }

    /**
     * Handle list item setup
     */
    private void on_list_item_setup(Object obj) {
        var item = obj as Gtk.ListItem;
        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        box.add_css_class("move-entry");

        // Move number label
        var number_label = new Gtk.Label("");
        number_label.add_css_class("move-number");
        number_label.set_size_request(40, -1);
        box.append(number_label);

        // Move notation label
        var notation_label = new Gtk.Label("");
        notation_label.add_css_class("move-notation");
        notation_label.hexpand = true;
        notation_label.halign = Gtk.Align.START;
        box.append(notation_label);

        // Time taken label
        var time_label = new Gtk.Label("");
        time_label.add_css_class("move-time");
        time_label.add_css_class("dim-label");
        box.append(time_label);

        item.child = box;
    }

    /**
     * Handle list item binding
     */
    private void on_list_item_bind(Object obj) {
        var item = obj as Gtk.ListItem;
        var position = item.position;
        if (position >= moves.size) return;

        var move = moves.get((int)position);
        var box = item.child as Gtk.Box;

        var number_label = box.get_first_child() as Gtk.Label;
        var notation_label = number_label.get_next_sibling() as Gtk.Label;
        var time_label = notation_label.get_next_sibling() as Gtk.Label;

        // Set move number (1-based, with player indication)
        int move_number = ((int)position / 2) + 1;
        string player_indicator = (position % 2 == 0) ? "." : "...";
        number_label.label = @"$move_number$player_indicator";

        // Set move notation
        notation_label.label = move.to_algebraic_notation();

        // Set time taken (if available)
        if (move.time_taken > 0) {
            time_label.label = format_move_time(move.time_taken);
        } else {
            time_label.label = "";
        }

        // Highlight current move in replay mode
        if (replay_mode && position == current_move_index) {
            box.add_css_class("current-move");
        } else {
            box.remove_css_class("current-move");
        }
    }

    /**
     * Handle move selection
     */
    private void on_selection_changed(uint position, uint n_items) {
        var selection = move_list.model as Gtk.SingleSelection;
        uint selected_position = selection.selected;

        if (selected_position < moves.size) {
            move_selected((int)selected_position);

            if (replay_mode) {
                current_move_index = (int)selected_position;
                replay_position_changed(current_move_index);
                update_navigation_state();
            }
        }
    }

    /**
     * Handle key press events for navigation
     */
    private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        switch (keyval) {
            case Gdk.Key.Home:
                navigate_to_move(0);
                return true;
            case Gdk.Key.End:
                navigate_to_move(moves.size - 1);
                return true;
            case Gdk.Key.Up:
            case Gdk.Key.Left:
                navigate_relative(-1);
                return true;
            case Gdk.Key.Down:
            case Gdk.Key.Right:
                navigate_relative(1);
                return true;
            case Gdk.Key.space:
                toggle_replay_mode();
                return true;
        }
        return false;
    }

    /**
     * Handle new move from game
     */
    private void on_move_made(DraughtsMove move) {
        add_move(move);
    }

    /**
     * Handle game finished
     */
    private void on_game_finished(GameStatus status) {
        // Add game result to display
        string result_text = "";
        switch (status) {
            case GameStatus.RED_WINS:
                result_text = "1-0";
                break;
            case GameStatus.BLACK_WINS:
                result_text = "0-1";
                break;
            case GameStatus.DRAW:
                result_text = "1/2-1/2";
                break;
        }

        if (result_text != "") {
            move_model.append(@"Result: $result_text");
        }

        update_moves_count();
    }

    /**
     * Handle PGN export request
     */
    private void on_export_pgn() {
        string pgn_content = generate_pgn();
        export_requested(pgn_content);
    }

    /**
     * Handle clear history request
     */
    private void on_clear_history() {
        clear_history();
    }

    /**
     * Add a move to the history
     */
    public void add_move(DraughtsMove move) {
        moves.add(move);

        // Format move for display
        string move_text = move.to_algebraic_notation();
        move_model.append(move_text);

        // Auto-scroll to latest move
        scroll_to_latest_move();

        update_moves_count();
    }

    /**
     * Clear the move history
     */
    public void clear_history() {
        moves.clear();
        move_model.splice(0, move_model.get_n_items(), null);
        current_move_index = -1;
        replay_mode = false;
        update_moves_count();
        update_navigation_state();
    }

    /**
     * Navigate to specific move
     */
    public void navigate_to_move(int move_index) {
        if (move_index < 0 || move_index >= moves.size) {
            return;
        }

        current_move_index = move_index;

        // Select the move in the list
        var selection = move_list.model as Gtk.SingleSelection;
        selection.selected = move_index;

        // Scroll to the move
        move_list.scroll_to(move_index, Gtk.ListScrollFlags.SELECT, null);

        // Enter replay mode if not already
        if (!replay_mode) {
            replay_mode = true;
        }

        replay_position_changed(current_move_index);
        update_navigation_state();
    }

    /**
     * Navigate relative to current position
     */
    public void navigate_relative(int delta) {
        int new_index = current_move_index + delta;
        navigate_to_move(new_index);
    }

    /**
     * Toggle replay mode
     */
    public void toggle_replay_mode() {
        replay_mode = !replay_mode;

        if (replay_mode && current_move_index == -1 && moves.size > 0) {
            navigate_to_move(moves.size - 1);
        }

        update_navigation_state();
    }

    /**
     * Update navigation controls state
     */
    private void update_navigation_state() {
        bool has_moves = moves.size > 0;
        bool can_go_back = replay_mode && current_move_index > 0;
        bool can_go_forward = replay_mode && current_move_index < moves.size - 1;

        first_move_button.sensitive = can_go_back;
        prev_move_button.sensitive = can_go_back;
        next_move_button.sensitive = can_go_forward;
        last_move_button.sensitive = can_go_forward;

        navigation_controls.visible = has_moves;
    }

    /**
     * Update moves count display
     */
    private void update_moves_count() {
        int total_moves = moves.size;
        int full_moves = (total_moves + 1) / 2;

        if (total_moves == 0) {
            moves_count_label.label = "No moves";
        } else {
            moves_count_label.label = @"$total_moves moves ($full_moves turns)";
        }

        export_pgn_button.sensitive = (total_moves > 0);
        clear_history_button.sensitive = (total_moves > 0);
    }

    /**
     * Scroll to the latest move
     */
    private void scroll_to_latest_move() {
        if (moves.size > 0) {
            Timeout.add(50, () => {
                move_list.scroll_to(moves.size - 1, Gtk.ListScrollFlags.NONE, null);
                return false;
            });
        }
    }

    /**
     * Generate PGN content
     */
    private string generate_pgn() {
        var pgn = new StringBuilder();

        // PGN headers
        pgn.append_printf("[Event \"Draughts Game\"]\n");
        pgn.append_printf("[Date \"%s\"]\n", new DateTime.now_local().format("%Y.%m.%d"));
        pgn.append_printf("[Red \"Player 1\"]\n");
        pgn.append_printf("[Black \"Player 2\"]\n");

        if (adapter != null) {
            var variant = adapter.get_current_variant();
            if (variant != null) {
                pgn.append_printf("[Variant \"%s\"]\n", variant.display_name);
            }
        }

        // Game result
        var current_state = adapter?.get_current_state();
        if (current_state != null && current_state.is_game_over()) {
            switch (current_state.game_status) {
                case GameStatus.RED_WINS:
                    pgn.append_printf("[Result \"1-0\"]\n");
                    break;
                case GameStatus.BLACK_WINS:
                    pgn.append_printf("[Result \"0-1\"]\n");
                    break;
                case GameStatus.DRAW:
                    pgn.append_printf("[Result \"1/2-1/2\"]\n");
                    break;
                default:
                    pgn.append_printf("[Result \"*\"]\n");
                    break;
            }
        } else {
            pgn.append_printf("[Result \"*\"]\n");
        }

        pgn.append_printf("\n");

        // Moves
        for (int i = 0; i < moves.size; i++) {
            if (i % 2 == 0) {
                int move_number = (i / 2) + 1;
                pgn.append_printf("%d. ", move_number);
            }

            pgn.append_printf("%s ", moves.get(i).to_algebraic_notation());

            // Line break every 8 moves for readability
            if ((i + 1) % 8 == 0) {
                pgn.append_printf("\n");
            }
        }

        // Add result at end if game is over
        if (current_state != null && current_state.is_game_over()) {
            switch (current_state.game_status) {
                case GameStatus.RED_WINS:
                    pgn.append_printf(" 1-0");
                    break;
                case GameStatus.BLACK_WINS:
                    pgn.append_printf(" 0-1");
                    break;
                case GameStatus.DRAW:
                    pgn.append_printf(" 1/2-1/2");
                    break;
            }
        } else {
            pgn.append_printf(" *");
        }

        return pgn.str;
    }

    /**
     * Format move time for display
     */
    private string format_move_time(TimeSpan time) {
        if (time < TimeSpan.SECOND) {
            int64 ms = time / TimeSpan.MILLISECOND;
            return @"$(ms)ms";
        } else if (time < TimeSpan.MINUTE) {
            double seconds = (double)time / TimeSpan.SECOND;
            return "%.1fs".printf(seconds);
        } else {
            int minutes = (int)(time / TimeSpan.MINUTE);
            int seconds = (int)((time % TimeSpan.MINUTE) / TimeSpan.SECOND);
            string sec_str = "%02d".printf(seconds);
            return @"$minutes:$sec_str";
        }
    }

    /**
     * Get current replay position
     */
    public int get_current_position() {
        return current_move_index;
    }

    /**
     * Check if in replay mode
     */
    public bool is_in_replay_mode() {
        return replay_mode;
    }

    /**
     * Get move at specific index
     */
    public DraughtsMove? get_move_at(int index) {
        if (index >= 0 && index < moves.size) {
            return moves.get(index);
        }
        return null;
    }

    /**
     * Get total number of moves
     */
    public int get_move_count() {
        return moves.size;
    }
}