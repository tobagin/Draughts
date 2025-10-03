/**
 * GameReplayDialog.vala
 *
 * Dialog for replaying games with full playback controls and move navigation.
 */

using Gtk;
using Adw;
using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/game-replay.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/game-replay.ui")]
#endif
public class Draughts.GameReplayDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    [GtkChild]
    private unowned MenuButton options_button;
    [GtkChild]
    private unowned Box board_container;
    [GtkChild]
    private unowned AspectFrame board_frame;
    [GtkChild]
    private unowned Frame board_frame_inner;
    [GtkChild]
    private unowned Box board_placeholder;
    [GtkChild]
    private unowned Box controls_box;
    [GtkChild]
    private unowned Button first_button;
    [GtkChild]
    private unowned Button prev_button;
    [GtkChild]
    private unowned Button play_pause_button;
    [GtkChild]
    private unowned Button next_button;
    [GtkChild]
    private unowned Button last_button;
    [GtkChild]
    private unowned Scale speed_scale;
    [GtkChild]
    private unowned Scale move_scale;
    [GtkChild]
    private unowned Box side_panel;
    [GtkChild]
    private unowned ListBox move_history_list;
    [GtkChild]
    private unowned Button side_panel_button;

    private GameHistoryRecord? game_record = null;
    private DraughtsBoard replay_board;
    private Logger logger;
    private uint playback_timer_id = 0;
    private bool is_playing = false;
    private int current_move_index = 0;
    private DraughtsGameState[] game_states;
    private Adw.Dialog? side_panel_sheet = null;

    // Properties for data binding
    public string game_title { get; private set; default = ""; }
    public string game_subtitle { get; private set; default = ""; }
    public string current_move_text { get; private set; default = ""; }
    public string total_moves_text { get; private set; default = ""; }
    public string players_text { get; private set; default = ""; }
    public string result_text { get; private set; default = ""; }
    public string variant_text { get; private set; default = ""; }
    public string duration_text { get; private set; default = ""; }
    public string move_notation { get; private set; default = ""; }
    public string move_description { get; private set; default = ""; }
    public string red_stats_text { get; private set; default = ""; }
    public string black_stats_text { get; private set; default = ""; }

    public GameReplayDialog(GameHistoryRecord record) {
        logger.debug("GameReplayDialog: Constructor called");

        if (record == null) {
            logger.debug("GameReplayDialog: record is NULL!");
        } else {
            logger.debug("GameReplayDialog: record is not null");
            this.game_record = record;
            logger.debug("GameReplayDialog: game_record assigned in constructor");
        }

        logger.debug("GameReplayDialog: Constructor completed successfully");
    }

    construct {
        logger = Logger.get_default();
        logger.debug("GameReplayDialog: construct() started");

        if (game_record == null) {
            logger.debug("GameReplayDialog: game_record is null in construct! Will defer initialization.");
            // Set default values for display
            game_title = _("Game Replay");
            game_subtitle = _("No game data available");
            notify_all_properties();

            // Use a timeout to initialize after construction is complete
            Timeout.add(1, () => {
                logger.debug("GameReplayDialog: Timeout callback - checking game_record again");
                if (game_record != null) {
                    logger.debug("GameReplayDialog: Found game_record in timeout, initializing");
                    initialize_replay_content();
                } else {
                    logger.debug("GameReplayDialog: game_record still null in timeout");
                }
                return false; // Don't repeat
            });
            return;
        }

        logger.debug("GameReplayDialog: About to setup_game_states()");
        setup_game_states();
        logger.debug("GameReplayDialog: setup_game_states() completed");

        logger.debug("GameReplayDialog: About to setup_board()");
        setup_board();
        logger.debug("GameReplayDialog: setup_board() completed");

        logger.debug("GameReplayDialog: About to setup_controls()");
        setup_controls();
        logger.debug("GameReplayDialog: setup_controls() completed");

        logger.debug("GameReplayDialog: About to setup_actions()");
        setup_actions();
        logger.debug("GameReplayDialog: setup_actions() completed");

        logger.debug("GameReplayDialog: About to populate_game_info()");
        populate_game_info();
        logger.debug("GameReplayDialog: populate_game_info() completed");

        logger.debug("GameReplayDialog: About to populate_move_history()");
        populate_move_history();
        logger.debug("GameReplayDialog: populate_move_history() completed");

        logger.debug("GameReplayDialog: About to go_to_position(0)");
        go_to_position(0);
        logger.debug("GameReplayDialog: go_to_position(0) completed");

        logger.debug("GameReplayDialog: construct() completed successfully");
    }

    /**
     * Initialize replay content after construction is complete
     */
    private void initialize_replay_content() {
        logger.debug("GameReplayDialog: initialize_replay_content() started");

        if (game_record == null) {
            logger.debug("GameReplayDialog: game_record is null, cannot initialize");
            return;
        }

        logger.debug("GameReplayDialog: About to setup_game_states()");
        setup_game_states();
        logger.debug("GameReplayDialog: setup_game_states() completed");

        logger.debug("GameReplayDialog: About to setup_board()");
        setup_board();
        logger.debug("GameReplayDialog: setup_board() completed");

        logger.debug("GameReplayDialog: About to setup_controls()");
        setup_controls();
        logger.debug("GameReplayDialog: setup_controls() completed");

        logger.debug("GameReplayDialog: About to setup_actions()");
        setup_actions();
        logger.debug("GameReplayDialog: setup_actions() completed");

        logger.debug("GameReplayDialog: About to populate_game_info()");
        populate_game_info();
        logger.debug("GameReplayDialog: populate_game_info() completed");

        logger.debug("GameReplayDialog: About to populate_move_history()");
        populate_move_history();
        logger.debug("GameReplayDialog: populate_move_history() completed");

        logger.debug("GameReplayDialog: About to go_to_position(0)");
        go_to_position(0);
        logger.debug("GameReplayDialog: go_to_position(0) completed");

        logger.debug("GameReplayDialog: initialize_replay_content() completed successfully");
    }

    /**
     * Setup game states for replay
     */
    private void setup_game_states() {
        game_states = new DraughtsGameState[game_record.moves.length + 1];

        // Create initial state using the correct variant from the game record
        var variant_enum = get_variant_from_name(game_record.variant_name);
        var variant = new GameVariant(variant_enum);
        var initial_pieces = variant.create_initial_setup();
        game_states[0] = new DraughtsGameState(initial_pieces, PieceColor.RED, variant.board_size);

        // Apply each move to create subsequent states
        for (int i = 0; i < game_record.moves.length; i++) {
            var move = game_record.moves[i];
            game_states[i + 1] = game_states[i].apply_move(move);
        }
    }

    /**
     * Setup the replay board
     */
    private void setup_board() {
        replay_board = new DraughtsBoard();
        replay_board.hexpand = true;
        replay_board.vexpand = true;

        // Set the board size based on the actual game state
        if (game_states != null && game_states.length > 0) {
            int required_board_size = detect_board_size_from_game_state(game_states[0]);
            logger.debug(@"GameReplayDialog: Setting board size to $(required_board_size)x$(required_board_size)");
            replay_board.set_board_size(required_board_size);
        }

        // Replace placeholder with board
        board_frame_inner.set_child(replay_board);
    }

    /**
     * Detect the required board size from the variant name
     */
    private int detect_board_size_from_game_state(DraughtsGameState state) {
        return get_board_size_for_variant(game_record.variant_name);
    }

    private int get_board_size_for_variant(string variant_name) {
        switch (variant_name.down()) {
            case "international draughts":
            case "frisian draughts":
                return 10;
            case "canadian draughts":
                return 12;
            default:
                return 8; // All other variants including Brazilian Draughts
        }
    }

    /**
     * Setup playback controls
     */
    private void setup_controls() {
        // Button connections
        first_button.clicked.connect(() => go_to_position(0));
        prev_button.clicked.connect(go_to_previous_move);
        play_pause_button.clicked.connect(toggle_playback);
        next_button.clicked.connect(go_to_next_move);
        last_button.clicked.connect(() => go_to_position(game_record.moves.length));

        // Scale connections
        move_scale.adjustment.lower = 0;
        move_scale.adjustment.upper = game_record.moves.length;
        move_scale.adjustment.value = 0;
        move_scale.value_changed.connect(on_move_scale_changed);

        speed_scale.value_changed.connect(on_speed_changed);

        // Move history list
        move_history_list.row_selected.connect(on_move_history_selected);

        // Side panel button for mobile (shows bottom sheet)
        side_panel_button.clicked.connect(show_side_panel_sheet);
    }

    /**
     * Setup dialog actions
     */
    private void setup_actions() {
        var action_group = new SimpleActionGroup();

        // Export action
        var export_action = new SimpleAction("export", null);
        export_action.activate.connect(on_export_game);
        action_group.add_action(export_action);

        // Copy action
        var copy_action = new SimpleAction("copy", null);
        copy_action.activate.connect(on_copy_notation);
        action_group.add_action(copy_action);

        // Reset action
        var reset_action = new SimpleAction("reset", null);
        reset_action.activate.connect(() => go_to_position(0));
        action_group.add_action(reset_action);

        // Speed action (for menu-based speed control on mobile)
        var speed_action = new SimpleAction("speed", VariantType.STRING);
        speed_action.activate.connect((parameter) => {
            if (parameter != null) {
                string speed_str = parameter.get_string();
                double speed = double.parse(speed_str);
                speed_scale.set_value(speed);
                logger.info(@"Playback speed changed to $(speed)×");
            }
        });
        action_group.add_action(speed_action);

        insert_action_group("replay", action_group);
    }

    /**
     * Populate game information
     */
    private void populate_game_info() {
        game_title = game_record.get_display_title();
        game_subtitle = @"$(game_record.variant_name) • $(game_record.get_date_played())";
        players_text = @"$(game_record.red_player_name) vs $(game_record.black_player_name)";
        result_text = game_record.get_result_text();
        variant_text = game_record.variant_name;
        duration_text = format_duration(game_record.duration);
        total_moves_text = @"/ $(game_record.total_moves)";

        // Statistics
        int red_moves = (game_record.total_moves + 1) / 2;
        int black_moves = game_record.total_moves / 2;
        red_stats_text = @"$(red_moves) moves • $(game_record.red_captures) captures • $(game_record.red_promotions) promotions";
        black_stats_text = @"$(black_moves) moves • $(game_record.black_captures) captures • $(game_record.black_promotions) promotions";

        // Notify all properties
        notify_all_properties();
    }

    /**
     * Populate move history list
     */
    private void populate_move_history() {
        for (int i = 0; i < game_record.moves.length; i++) {
            var move = game_record.moves[i];
            var row = create_move_row(i + 1, move);
            move_history_list.append(row);
        }
    }

    /**
     * Create a move history row
     */
    private Widget create_move_row(int move_number, DraughtsMove move) {
        var row = new Adw.ActionRow();
        row.title = @"$(move_number). $(move.to_algebraic_notation())";

        string subtitle = "";
        if (move.is_capture()) {
            subtitle += @"Captures $(move.captured_pieces.length) piece(s)";
        }
        if (move.promoted) {
            if (subtitle != "") subtitle += " • ";
            subtitle += "Promotion";
        }
        if (subtitle == "") {
            subtitle = "Simple move";
        }

        row.subtitle = subtitle;
        row.set_data("move-index", move_number - 1);

        return row;
    }

    /**
     * Go to a specific position
     */
    private void go_to_position(int position) {
        position = int.max(0, int.min(position, game_record.moves.length));
        current_move_index = position;

        // Update board state
        if (replay_board != null && game_states != null && position < game_states.length) {
            logger.debug(@"GameReplayDialog: Updating board to position $(position)");
            replay_board.update_from_draughts_game_state(game_states[position]);
        }

        // Update UI
        current_move_text = position.to_string();
        move_scale.set_value(position);

        // Update move information
        if (position > 0) {
            var move = game_record.moves[position - 1];
            move_notation = @"$(position). $(move.to_algebraic_notation())";

            string description = "";
            if (move.is_capture()) {
                description += @"Captures $(move.captured_pieces.length) piece(s)";
            }
            if (move.promoted) {
                if (description != "") description += " • ";
                description += "Piece promoted to king";
            }
            if (description == "") {
                description = "Simple move";
            }
            move_description = description;
        } else {
            move_notation = "Starting position";
            move_description = "Game beginning";
        }

        // Update button states
        first_button.sensitive = position > 0;
        prev_button.sensitive = position > 0;
        next_button.sensitive = position < game_record.moves.length;
        last_button.sensitive = position < game_record.moves.length;

        // Select move in history list
        if (position > 0) {
            var child = move_history_list.get_row_at_index(position - 1);
            if (child != null) {
                move_history_list.select_row(child);
            }
        } else {
            move_history_list.unselect_all();
        }

        notify_all_properties();
    }

    /**
     * Go to next move
     */
    private void go_to_next_move() {
        if (current_move_index < game_record.moves.length) {
            go_to_position(current_move_index + 1);
        } else {
            stop_playback();
        }
    }

    /**
     * Go to previous move
     */
    private void go_to_previous_move() {
        if (current_move_index > 0) {
            go_to_position(current_move_index - 1);
        }
    }

    /**
     * Toggle playback
     */
    private void toggle_playback() {
        if (is_playing) {
            stop_playback();
        } else {
            start_playback();
        }
    }

    /**
     * Start automatic playback
     */
    private void start_playback() {
        if (current_move_index >= game_record.moves.length) {
            go_to_position(0);
        }

        is_playing = true;
        play_pause_button.icon_name = "media-playback-pause-symbolic";
        play_pause_button.tooltip_text = _("Pause");

        double speed = speed_scale.get_value();
        uint interval = (uint)(1000.0 / speed); // Base interval is 1 second

        playback_timer_id = Timeout.add(interval, () => {
            go_to_next_move();
            return is_playing && current_move_index < game_record.moves.length;
        });
    }

    /**
     * Stop automatic playback
     */
    private void stop_playback() {
        is_playing = false;
        play_pause_button.icon_name = "media-playback-start-symbolic";
        play_pause_button.tooltip_text = _("Play");

        if (playback_timer_id > 0) {
            Source.remove(playback_timer_id);
            playback_timer_id = 0;
        }
    }

    /**
     * Handle move scale change
     */
    private void on_move_scale_changed() {
        int position = (int)move_scale.get_value();
        if (position != current_move_index) {
            go_to_position(position);
        }
    }

    /**
     * Handle speed change
     */
    private void on_speed_changed() {
        if (is_playing) {
            // Restart playback with new speed
            stop_playback();
            start_playback();
        }
    }

    /**
     * Handle move history selection
     */
    private void on_move_history_selected(ListBoxRow? row) {
        if (row != null) {
            int move_index = row.get_data<int>("move-index");
            go_to_position(move_index + 1);
        }
    }

    /**
     * Export game to PGN
     */
    private void on_export_game() {
        var file_dialog = new FileDialog();
        file_dialog.title = _("Export Game Replay");
        file_dialog.set_initial_name(@"$(game_record.id)_replay.pgn");

        file_dialog.save.begin(this.get_root() as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_dialog.save.end(res);
                if (file != null) {
                    file.replace_contents(game_record.pgn_notation.data, null, false, FileCreateFlags.NONE, null);
                    logger.info("Game replay exported successfully");
                }
            } catch (Error e) {
                logger.error(@"Failed to export game replay: $(e.message)");
            }
        });
    }

    /**
     * Copy game notation to clipboard
     */
    private void on_copy_notation() {
        var clipboard = get_clipboard();
        clipboard.set_text(game_record.pgn_notation);
        logger.info("Game notation copied to clipboard");
    }

    /**
     * Format duration as human-readable string
     */
    private string format_duration(TimeSpan duration) {
        int total_seconds = (int)(duration / TimeSpan.SECOND);
        int minutes = total_seconds / 60;
        int seconds = total_seconds % 60;
        return "%d:%02d".printf(minutes, seconds);
    }

    /**
     * Notify all bound properties
     */
    private void notify_all_properties() {
        notify_property("game-title");
        notify_property("game-subtitle");
        notify_property("current-move-text");
        notify_property("total-moves-text");
        notify_property("players-text");
        notify_property("result-text");
        notify_property("variant-text");
        notify_property("duration-text");
        notify_property("move-notation");
        notify_property("move-description");
        notify_property("red-stats-text");
        notify_property("black-stats-text");
    }

    /**
     * Convert variant name string to DraughtsVariant enum
     */
    private DraughtsVariant get_variant_from_name(string variant_name) {
        switch (variant_name.down()) {
            case "american checkers":
                return DraughtsVariant.AMERICAN;
            case "international draughts":
                return DraughtsVariant.INTERNATIONAL;
            case "russian draughts":
                return DraughtsVariant.RUSSIAN;
            case "brazilian draughts":
                return DraughtsVariant.BRAZILIAN;
            case "italian draughts":
                return DraughtsVariant.ITALIAN;
            case "spanish draughts":
                return DraughtsVariant.SPANISH;
            case "czech draughts":
                return DraughtsVariant.CZECH;
            case "thai draughts":
                return DraughtsVariant.THAI;
            case "german draughts":
                return DraughtsVariant.GERMAN;
            case "swedish draughts":
                return DraughtsVariant.SWEDISH;
            case "pool checkers":
                return DraughtsVariant.POOL;
            case "turkish draughts":
                return DraughtsVariant.TURKISH;
            case "armenian draughts":
                return DraughtsVariant.ARMENIAN;
            case "gothic draughts":
                return DraughtsVariant.GOTHIC;
            case "frisian draughts":
                return DraughtsVariant.FRISIAN;
            case "canadian draughts":
                return DraughtsVariant.CANADIAN;
            default:
                logger.debug(@"GameReplayDialog: Unknown variant name '$(variant_name)', defaulting to Brazilian Draughts");
                return DraughtsVariant.BRAZILIAN;
        }
    }

    /**
     * Show side panel as bottom sheet on mobile
     */
    private void show_side_panel_sheet() {
        if (side_panel_sheet != null) {
            side_panel_sheet.present(this);
            return;
        }

        // Create a dialog to show side panel content as a drawer/bottom sheet
        side_panel_sheet = new Adw.Dialog();
        side_panel_sheet.title = _("Game Information");
        side_panel_sheet.content_width = 400;
        side_panel_sheet.content_height = 600;

        var toolbar_view = new Adw.ToolbarView();

        var header = new Adw.HeaderBar();
        header.show_end_title_buttons = false;
        header.show_start_title_buttons = false;

        var close_button = new Button.with_label(_("Done"));
        close_button.add_css_class("suggested-action");
        close_button.clicked.connect(() => {
            side_panel_sheet.close();
        });
        header.pack_end(close_button);

        var window_title = new Adw.WindowTitle(_("Game Information"), "");
        header.set_title_widget(window_title);

        toolbar_view.add_top_bar(header);

        // Create scrollable content with side panel info
        var scrolled = new ScrolledWindow();
        scrolled.vexpand = true;
        scrolled.hscrollbar_policy = PolicyType.NEVER;

        var content_box = new Box(Orientation.VERTICAL, 12);
        content_box.margin_start = 12;
        content_box.margin_end = 12;
        content_box.margin_top = 12;
        content_box.margin_bottom = 12;

        // Add game info
        var info_group = new Adw.PreferencesGroup();
        info_group.title = _("Game Information");

        var players_row = new Adw.ActionRow();
        players_row.title = players_text;
        players_row.subtitle = result_text;
        var players_icon = new Image.from_icon_name("system-users-symbolic");
        players_row.add_prefix(players_icon);
        info_group.add(players_row);

        var variant_row = new Adw.ActionRow();
        variant_row.title = _("Variant");
        variant_row.subtitle = variant_text;
        var variant_icon = new Image.from_icon_name("applications-games-symbolic");
        variant_row.add_prefix(variant_icon);
        info_group.add(variant_row);

        var duration_row = new Adw.ActionRow();
        duration_row.title = _("Game Duration");
        duration_row.subtitle = duration_text;
        var duration_icon = new Image.from_icon_name("alarm-symbolic");
        duration_row.add_prefix(duration_icon);
        info_group.add(duration_row);

        content_box.append(info_group);

        // Add current move info
        var move_group = new Adw.PreferencesGroup();
        move_group.title = _("Current Move");

        var move_info_row = new Adw.ActionRow();
        move_info_row.title = move_notation;
        move_info_row.subtitle = move_description;
        var move_icon = new Image.from_icon_name("view-list-symbolic");
        move_info_row.add_prefix(move_icon);
        move_group.add(move_info_row);

        content_box.append(move_group);

        // Add statistics
        var stats_group = new Adw.PreferencesGroup();
        stats_group.title = _("Game Statistics");

        var red_stats_row = new Adw.ActionRow();
        red_stats_row.title = _("Red Player");
        red_stats_row.subtitle = red_stats_text;
        var red_icon = new Image.from_icon_name("media-record-symbolic");
        red_icon.add_css_class("red-piece");
        red_stats_row.add_prefix(red_icon);
        stats_group.add(red_stats_row);

        var black_stats_row = new Adw.ActionRow();
        black_stats_row.title = _("Black Player");
        black_stats_row.subtitle = black_stats_text;
        var black_icon = new Image.from_icon_name("media-record-symbolic");
        black_icon.add_css_class("black-piece");
        black_stats_row.add_prefix(black_icon);
        stats_group.add(black_stats_row);

        content_box.append(stats_group);

        scrolled.set_child(content_box);
        toolbar_view.set_content(scrolled);
        side_panel_sheet.set_child(toolbar_view);

        side_panel_sheet.present(this);
    }

    /**
     * Clean up when dialog is destroyed
     */
    public override void dispose() {
        stop_playback();
        base.dispose();
    }
}