/**
 * GameHistoryDialog.vala
 *
 * Dialog for viewing game history with filtering, replay, and management capabilities.
 */

using Gtk;
using Adw;
using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/game-history.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/game-history.ui")]
#endif
public class Draughts.GameHistoryDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;
    [GtkChild]
    private unowned Button filter_button;
    [GtkChild]
    private unowned Button clear_history_button;
    [GtkChild]
    private unowned Adw.ActionRow filter_row;
    [GtkChild]
    private unowned DropDown variant_filter;
    [GtkChild]
    private unowned DropDown result_filter;
    [GtkChild]
    private unowned DropDown player_filter;
    [GtkChild]
    private unowned Adw.ActionRow stats_row;
    [GtkChild]
    private unowned ListBox game_list;
    [GtkChild]
    private unowned Box bottom_toolbar;
    [GtkChild]
    private unowned Button replay_button;
    [GtkChild]
    private unowned Button view_details_button;
    [GtkChild]
    private unowned Button export_button;
    [GtkChild]
    private unowned Button delete_button;

    private GameHistoryManager history_manager;
    private Logger logger;
    private GameHistoryRecord? selected_game = null;
    private Adw.Dialog? filter_sheet = null;

    // Filter models
    private StringList variant_filter_model;
    private StringList result_filter_model;
    private StringList player_filter_model;

    // Properties for data binding
    public string history_subtitle { get; private set; default = ""; }
    public string stats_title { get; private set; default = ""; }
    public string stats_subtitle { get; private set; default = ""; }

    // Signals
    public signal void replay_requested(GameHistoryRecord record);

    public GameHistoryDialog() {
        Object();
    }

    construct {
        logger = Logger.get_default();
        history_manager = GameHistoryManager.get_default();

        setup_filter_models();
        setup_actions();
        setup_list();
        load_game_history();
        update_statistics();

        // Connect filter button for mobile
        filter_button.clicked.connect(show_filter_sheet);

        logger.debug("GameHistoryDialog constructed");
    }

    /**
     * Setup filter dropdown models
     */
    private void setup_filter_models() {
        // Variant filter
        string[] variant_items = {
            _("All Variants"),
            _("American Checkers"),
            _("International Draughts"),
            _("Russian Draughts"),
            _("Brazilian Draughts"),
            _("Italian Draughts"),
            _("Spanish Draughts"),
            _("Czech Draughts"),
            _("Thai Draughts"),
            _("German Draughts"),
            _("Swedish Draughts"),
            _("Pool Checkers"),
            _("Turkish Draughts"),
            _("Armenian Draughts"),
            _("Gothic Draughts"),
            _("Frisian Draughts"),
            _("Canadian Draughts")
        };
        variant_filter_model = new StringList(variant_items);
        variant_filter.model = variant_filter_model;
        variant_filter.selected = 0;

        // Result filter
        string[] result_items = {_("All Results"), _("Red Wins"), _("Black Wins"), _("Draws")};
        result_filter_model = new StringList(result_items);
        result_filter.model = result_filter_model;
        result_filter.selected = 0;

        // Player type filter
        string[] player_items = {_("All Games"), _("Human vs Human"), _("vs Computer")};
        player_filter_model = new StringList(player_items);
        player_filter.model = player_filter_model;
        player_filter.selected = 0;

        // Connect filter change signals
        variant_filter.notify["selected"].connect(apply_filters);
        result_filter.notify["selected"].connect(apply_filters);
        player_filter.notify["selected"].connect(apply_filters);
    }

    /**
     * Setup dialog actions
     */
    private void setup_actions() {
        var action_group = new SimpleActionGroup();

        // Clear history action
        var clear_action = new SimpleAction("clear", null);
        clear_action.activate.connect(on_clear_history);
        action_group.add_action(clear_action);

        // Export all action
        var export_all_action = new SimpleAction("export-all", null);
        export_all_action.activate.connect(on_export_all);
        action_group.add_action(export_all_action);

        insert_action_group("history", action_group);

        // Button signals
        replay_button.clicked.connect(on_replay_clicked);
        view_details_button.clicked.connect(on_view_details_clicked);
        export_button.clicked.connect(on_export_clicked);
        delete_button.clicked.connect(on_delete_clicked);
    }

    /**
     * Setup game list
     */
    private void setup_list() {
        game_list.row_selected.connect(on_game_selected);
        game_list.row_activated.connect(on_game_activated);
    }

    /**
     * Load and display game history
     */
    private void load_game_history() {
        apply_filters();
    }

    /**
     * Apply current filters and update list
     */
    private void apply_filters() {
        logger.debug("GameHistoryDialog: apply_filters() called");

        // Clear existing items
        while (game_list.get_first_child() != null) {
            game_list.remove(game_list.get_first_child());
        }

        // Get total games first for debugging
        var all_games = history_manager.get_all_games();
        logger.debug(@"GameHistoryDialog: Total games in history: $(all_games.length)");

        // Get filter criteria
        string? variant_filter_text = null;
        GameStatus? result_filter_value = null;
        PlayerType? player_type_filter_value = null;

        // Parse variant filter
        switch (variant_filter.selected) {
            case 1: variant_filter_text = "American Checkers"; break;
            case 2: variant_filter_text = "International Draughts"; break;
            case 3: variant_filter_text = "Russian Draughts"; break;
            case 4: variant_filter_text = "Brazilian Draughts"; break;
            case 5: variant_filter_text = "Italian Draughts"; break;
            case 6: variant_filter_text = "Spanish Draughts"; break;
            case 7: variant_filter_text = "Czech Draughts"; break;
            case 8: variant_filter_text = "Thai Draughts"; break;
            case 9: variant_filter_text = "German Draughts"; break;
            case 10: variant_filter_text = "Swedish Draughts"; break;
            case 11: variant_filter_text = "Pool Checkers"; break;
            case 12: variant_filter_text = "Turkish Draughts"; break;
            case 13: variant_filter_text = "Armenian Draughts"; break;
            case 14: variant_filter_text = "Gothic Draughts"; break;
            case 15: variant_filter_text = "Frisian Draughts"; break;
            case 16: variant_filter_text = "Canadian Draughts"; break;
        }

        // Parse result filter
        switch (result_filter.selected) {
            case 1: result_filter_value = GameStatus.RED_WINS; break;
            case 2: result_filter_value = GameStatus.BLACK_WINS; break;
            case 3: result_filter_value = GameStatus.DRAW; break;
        }

        // Parse player type filter
        switch (player_filter.selected) {
            case 1: player_type_filter_value = PlayerType.HUMAN; break;
            case 2: player_type_filter_value = PlayerType.AI; break;
        }

        string variant_debug = variant_filter_text != null ? variant_filter_text : "null";
        string result_debug = result_filter_value != null ? result_filter_value.to_string() : "null";
        string player_debug = player_type_filter_value != null ? player_type_filter_value.to_string() : "null";
        logger.debug(@"GameHistoryDialog: Applied filters - variant: $(variant_debug), result: $(result_debug), player: $(player_debug)");

        // Get filtered games
        var filtered_games = history_manager.get_filtered_games(
            variant_filter_text, result_filter_value, player_type_filter_value);

        logger.debug(@"GameHistoryDialog: Filtered games count: $(filtered_games.length)");

        // Add games to list
        foreach (var game in filtered_games) {
            logger.debug(@"GameHistoryDialog: Adding game to list: $(game.get_display_title())");
            var row = create_game_row(game);
            game_list.append(row);
        }

        // Update subtitle
        history_subtitle = @"$(filtered_games.length) games";
        notify_property("history-subtitle");

        logger.debug(@"Applied filters, showing $(filtered_games.length) games");
    }

    /**
     * Create a list row for a game record
     */
    private Widget create_game_row(GameHistoryRecord record) {
        logger.debug(@"GameHistoryDialog: create_game_row called for game: $(record.get_display_title())");

        var row = new Adw.ActionRow();
        row.title = record.get_display_title();
        row.subtitle = record.get_display_subtitle();

        // Add date and statistics
        var details_box = new Box(Orientation.VERTICAL, 2);
        details_box.halign = Align.END;
        details_box.valign = Align.CENTER;

        var date_label = new Label(record.get_date_played());
        date_label.add_css_class("caption");
        date_label.add_css_class("dim-label");
        details_box.append(date_label);

        var stats_label = new Label(record.get_statistics_summary());
        stats_label.add_css_class("caption");
        stats_label.add_css_class("dim-label");
        details_box.append(stats_label);

        row.add_suffix(details_box);

        // Store record reference
        row.set_data("game-record", record);
        logger.debug(@"GameHistoryDialog: Stored game record data in row for: $(record.get_display_title())");

        return row;
    }

    /**
     * Update statistics display
     */
    private void update_statistics() {
        var stats = history_manager.get_statistics();

        stats_title = @"$(stats.total_games) games played";
        stats_subtitle = @"$(stats.get_win_rate_text()) • Total time: $(stats.get_total_play_time_text())";

        notify_property("stats-title");
        notify_property("stats-subtitle");
    }

    /**
     * Handle game selection
     */
    private void on_game_selected(ListBoxRow? row) {
        logger.debug(@"GameHistoryDialog: on_game_selected called, row is $(row != null ? "not null" : "null")");

        if (row != null) {
            selected_game = row.get_data<GameHistoryRecord>("game-record");
            if (selected_game != null) {
                logger.debug(@"GameHistoryDialog: Retrieved game record from row: $(selected_game.get_display_title())");
            } else {
                logger.debug("GameHistoryDialog: Retrieved game record from row: NULL!");
            }

            replay_button.sensitive = true;
            view_details_button.sensitive = true;
            export_button.sensitive = true;
            delete_button.sensitive = true;
        } else {
            selected_game = null;
            replay_button.sensitive = false;
            view_details_button.sensitive = false;
            export_button.sensitive = false;
            delete_button.sensitive = false;
        }
    }

    /**
     * Handle game activation (double-click)
     */
    private void on_game_activated(ListBoxRow row) {
        var record = row.get_data<GameHistoryRecord>("game-record");
        if (record != null) {
            replay_requested(record);
        }
    }

    /**
     * Handle replay button click
     */
    private void on_replay_clicked() {
        logger.debug("GameHistoryDialog: on_replay_clicked called");

        if (selected_game != null) {
            logger.debug(@"GameHistoryDialog: Emitting replay_requested signal with game: $(selected_game.get_display_title())");
            replay_requested(selected_game);
        } else {
            logger.debug("GameHistoryDialog: selected_game is NULL!");
        }
    }

    /**
     * Handle view details button click
     */
    private void on_view_details_clicked() {
        if (selected_game != null) {
            show_game_details(selected_game);
        }
    }

    /**
     * Handle export button click
     */
    private void on_export_clicked() {
        if (selected_game != null) {
            export_game_pgn(selected_game);
        }
    }

    /**
     * Handle delete button click
     */
    private void on_delete_clicked() {
        if (selected_game != null) {
            show_delete_confirmation(selected_game);
        }
    }

    /**
     * Handle clear history action
     */
    private void on_clear_history() {
        var dialog = new Adw.AlertDialog(_("Clear Game History"),
                                        _("Are you sure you want to delete all game history? This action cannot be undone."));

        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("clear", _("Clear History"));
        dialog.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");

        dialog.response.connect((response) => {
            if (response == "clear") {
                history_manager.clear_history();
                load_game_history();
                update_statistics();
            }
        });

        dialog.present(this);
    }

    /**
     * Handle export all action
     */
    private void on_export_all() {
        var file_dialog = new FileDialog();
        file_dialog.title = _("Export Game History");
        file_dialog.set_initial_name("draughts_history.pgn");

        file_dialog.save.begin(this.get_root() as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_dialog.save.end(res);
                if (file != null) {
                    string pgn_content = history_manager.export_to_pgn();
                    file.replace_contents(pgn_content.data, null, false, FileCreateFlags.NONE, null);

                    show_toast(_("Game history exported successfully"));
                }
            } catch (Error e) {
                logger.error(@"Failed to export game history: $(e.message)");
                show_toast(_("Failed to export game history"));
            }
        });
    }

    /**
     * Show game details in a separate dialog
     */
    private void show_game_details(GameHistoryRecord record) {
        var details_dialog = new Adw.AlertDialog(record.get_display_title(), null);

        var details_text = @"Variant: $(record.variant_name)\n";
        details_text += @"Result: $(record.get_result_text())\n";
        details_text += @"Date: $(record.get_date_played())\n";
        details_text += @"Duration: $(format_duration(record.duration))\n";
        details_text += @"Total Moves: $(record.total_moves)\n\n";
        details_text += @"Red Player: $(record.red_player_name)\n";
        details_text += @"  Type: $(record.red_player_type)\n";
        if (record.red_ai_difficulty != null) {
            details_text += @"  Difficulty: $(record.red_ai_difficulty)\n";
        }
        details_text += @"  Moves: $(((record.total_moves + 1) / 2))\n";
        details_text += @"  Captures: $(record.red_captures)\n";
        details_text += @"  Promotions: $(record.red_promotions)\n\n";
        details_text += @"Black Player: $(record.black_player_name)\n";
        details_text += @"  Type: $(record.black_player_type)\n";
        if (record.black_ai_difficulty != null) {
            details_text += @"  Difficulty: $(record.black_ai_difficulty)\n";
        }
        details_text += @"  Moves: $((record.total_moves / 2))\n";
        details_text += @"  Captures: $(record.black_captures)\n";
        details_text += @"  Promotions: $(record.black_promotions)";

        details_dialog.body = details_text;
        details_dialog.add_response("close", _("Close"));
        details_dialog.present(this);
    }

    /**
     * Export single game to PGN
     */
    private void export_game_pgn(GameHistoryRecord record) {
        var file_dialog = new FileDialog();
        file_dialog.title = _("Export Game");
        file_dialog.set_initial_name(@"$(record.id).pgn");

        file_dialog.save.begin(this.get_root() as Gtk.Window, null, (obj, res) => {
            try {
                var file = file_dialog.save.end(res);
                if (file != null) {
                    file.replace_contents(record.pgn_notation.data, null, false, FileCreateFlags.NONE, null);
                    show_toast(_("Game exported successfully"));
                }
            } catch (Error e) {
                logger.error(@"Failed to export game: $(e.message)");
                show_toast(_("Failed to export game"));
            }
        });
    }

    /**
     * Show delete confirmation dialog
     */
    private void show_delete_confirmation(GameHistoryRecord record) {
        var dialog = new Adw.AlertDialog(_("Delete Game"),
                                        @"Are you sure you want to delete the game \"$(record.get_display_title())\"?");

        dialog.add_response("cancel", _("Cancel"));
        dialog.add_response("delete", _("Delete"));
        dialog.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE);
        dialog.set_default_response("cancel");

        dialog.response.connect((response) => {
            if (response == "delete") {
                history_manager.delete_game(record.id);
                load_game_history();
                update_statistics();
                show_toast(_("Game deleted"));
            }
        });

        dialog.present(this);
    }

    /**
     * Show a toast message
     */
    private void show_toast(string message) {
        // Note: Toast functionality would need to be implemented in the parent window
        logger.info(@"Toast: $message");
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
     * Refresh the dialog content
     */
    public void refresh() {
        load_game_history();
        update_statistics();
    }

    /**
     * Show filter bottom sheet for mobile/tablet
     */
    private void show_filter_sheet() {
        if (filter_sheet != null) {
            filter_sheet.present(this);
            return;
        }

        // Create filter bottom sheet
        filter_sheet = new Adw.Dialog();
        filter_sheet.title = _("Filter Games");
        filter_sheet.content_width = 400;
        filter_sheet.content_height = 500;

        var toolbar_view = new Adw.ToolbarView();

        var header = new Adw.HeaderBar();
        header.show_end_title_buttons = false;
        header.show_start_title_buttons = false;

        var done_button = new Button.with_label(_("Done"));
        done_button.add_css_class("suggested-action");
        done_button.clicked.connect(() => {
            filter_sheet.close();
        });
        header.pack_end(done_button);

        var window_title = new Adw.WindowTitle(_("Filter Games"), "");
        header.set_title_widget(window_title);

        toolbar_view.add_top_bar(header);

        // Create filter content
        var content_box = new Box(Orientation.VERTICAL, 0);
        content_box.margin_start = 12;
        content_box.margin_end = 12;
        content_box.margin_top = 12;
        content_box.margin_bottom = 12;

        // Variant filter
        var variant_group = new Adw.PreferencesGroup();
        variant_group.title = _("Game Variant");

        var variant_row = new Adw.ComboRow();
        variant_row.title = _("Variant");
        variant_row.model = variant_filter_model;
        variant_row.selected = variant_filter.selected;
        variant_row.notify["selected"].connect(() => {
            variant_filter.selected = variant_row.selected;
        });
        variant_group.add(variant_row);
        content_box.append(variant_group);

        // Result filter
        var result_group = new Adw.PreferencesGroup();
        result_group.title = _("Game Result");

        var result_row = new Adw.ComboRow();
        result_row.title = _("Result");
        result_row.model = result_filter_model;
        result_row.selected = result_filter.selected;
        result_row.notify["selected"].connect(() => {
            result_filter.selected = result_row.selected;
        });
        result_group.add(result_row);
        content_box.append(result_group);

        // Player type filter
        var player_group = new Adw.PreferencesGroup();
        player_group.title = _("Player Type");

        var player_row = new Adw.ComboRow();
        player_row.title = _("Players");
        player_row.model = player_filter_model;
        player_row.selected = player_filter.selected;
        player_row.notify["selected"].connect(() => {
            player_filter.selected = player_row.selected;
        });
        player_group.add(player_row);
        content_box.append(player_group);

        toolbar_view.set_content(content_box);
        filter_sheet.set_child(toolbar_view);

        filter_sheet.present(this);
    }
}