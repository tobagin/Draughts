/*
 * Copyright (C) 2025 Thiago Fernandes
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

using Gtk;
using Adw;
using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/multiplayer.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/multiplayer.ui")]
#endif
public class Draughts.MultiplayerDialog : Adw.Dialog {
    [GtkChild]
    private unowned Adw.ViewStack view_stack;

    // Main view
    [GtkChild]
    private unowned Button host_button;
    [GtkChild]
    private unowned Button join_button;
    [GtkChild]
    private unowned Button quick_match_button;
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;

    // Host settings view
    [GtkChild]
    private unowned Adw.HeaderBar host_header_bar;
    [GtkChild]
    private unowned Adw.ComboRow variant_row;
    [GtkChild]
    private unowned Adw.SwitchRow use_timer_row;
    [GtkChild]
    private unowned Adw.SpinRow minutes_row;
    [GtkChild]
    private unowned Adw.SpinRow increment_row;
    [GtkChild]
    private unowned Adw.ComboRow clock_type_row;
    [GtkChild]
    private unowned Button create_room_button;
    [GtkChild]
    private unowned Button cancel_host_button;

    // Join room view
    [GtkChild]
    private unowned Adw.HeaderBar join_header_bar;
    [GtkChild]
    private unowned Entry room_code_entry;
    [GtkChild]
    private unowned Button join_room_button;
    [GtkChild]
    private unowned Button cancel_join_button;

    // Quick match view
    [GtkChild]
    private unowned Adw.HeaderBar quick_match_header_bar;
    [GtkChild]
    private unowned Adw.ComboRow quick_match_variant_row;
    [GtkChild]
    private unowned Button start_quick_match_button;
    [GtkChild]
    private unowned Button cancel_quick_match_button;

    // Waiting view
    [GtkChild]
    private unowned Adw.HeaderBar waiting_header_bar;
    [GtkChild]
    private unowned Label waiting_label;
    [GtkChild]
    private unowned Box room_code_box;
    [GtkChild]
    private unowned Label room_code_label;
    [GtkChild]
    private unowned Button copy_code_button;
    [GtkChild]
    private unowned Box quick_match_variant_box;
    [GtkChild]
    private unowned Label quick_match_variant_label;
    [GtkChild]
    private unowned Button cancel_waiting_button;

    private MultiplayerGameController? controller;
    private Logger logger;
    private SettingsManager settings_manager;
    private bool is_connected = false;
    private bool is_quick_matching = false;

    public signal void game_ready(MultiplayerGameController controller);

    construct {
        logger = Logger.get_default();
        settings_manager = SettingsManager.get_instance();

        // Connect button signals
        host_button.clicked.connect(on_host_clicked);
        join_button.clicked.connect(on_join_clicked);
        quick_match_button.clicked.connect(on_quick_match_clicked);

        join_room_button.clicked.connect(on_join_room_clicked);
        cancel_join_button.clicked.connect(on_cancel_join_clicked);

        create_room_button.clicked.connect(on_create_room_clicked);
        cancel_host_button.clicked.connect(on_cancel_host_clicked);

        start_quick_match_button.clicked.connect(on_start_quick_match_clicked);
        cancel_quick_match_button.clicked.connect(on_cancel_quick_match_clicked);

        copy_code_button.clicked.connect(on_copy_code_clicked);
        cancel_waiting_button.clicked.connect(on_cancel_waiting_clicked);

        // Connect timer toggle
        use_timer_row.notify["active"].connect(() => {
            bool enabled = use_timer_row.active;
            minutes_row.sensitive = enabled;
            increment_row.sensitive = enabled;
            clock_type_row.sensitive = enabled;
        });

        // Initialize settings from preferences
        load_settings_from_preferences();

        // Connect to map signal to initialize controller after dialog is ready
        this.map.connect(() => {
            if (controller == null) {
                initialize_controller();
            }
        });

        logger.info("MultiplayerDialog: Initialized");
    }

    /**
     * Initialize the multiplayer controller
     */
    private void initialize_controller() {
        // Get server URL from settings or use default
        string server_url = settings_manager.get_string("multiplayer-server-url");
        if (server_url == "") {
            server_url = "ws://145.241.228.207:8123"; // Default server
        }

        controller = new MultiplayerGameController(server_url);

        // Connect to controller signals
        controller.room_created.connect(on_room_created);
        controller.opponent_joined.connect(on_opponent_joined);
        controller.multiplayer_game_started.connect(on_game_started);
        controller.multiplayer_error.connect(on_multiplayer_error);

        // Connect to network client signals for connection status
        var client = controller.get_client();
        client.connected.connect(() => {
            is_connected = true;
            update_connection_status(true, "Connected");
            enable_multiplayer_buttons(true);
        });
        client.disconnected.connect((reason) => {
            is_connected = false;
            update_connection_status(false, @"Disconnected: $reason");
            enable_multiplayer_buttons(false);
        });
        client.state_changed.connect((state) => {
            update_connection_state(state);
        });
        client.session_restored.connect((room_code, variant, opponent_name, player_color) => {
            on_session_restored(room_code, variant, opponent_name, player_color);
        });

        // Disable buttons until connected
        enable_multiplayer_buttons(false);
        update_connection_status(false, "Connecting...");

        // Connect to server (with error handling)
        controller.connect_to_server.begin((obj, res) => {
            try {
                bool success = controller.connect_to_server.end(res);
                if (!success) {
                    is_connected = false;
                    enable_multiplayer_buttons(false);
                    update_connection_status(false, "Connection failed");
                    // Don't show error dialog here - wait for user to try an action
                    logger.warning("MultiplayerDialog: Failed to connect to server on initialization");
                    show_view("main");
                }
            } catch (Error e) {
                logger.error("MultiplayerDialog: Connection error: %s", e.message);
                is_connected = false;
                enable_multiplayer_buttons(false);
                update_connection_status(false, "Connection error");
                show_view("main");
            }
        });
    }

    /**
     * Handle host button clicked
     */
    private void on_host_clicked() {
        if (!is_connected) {
            show_error("Cannot connect to multiplayer server.\n\nPlease make sure:\n• The server is running\n• Server address is correct (currently: ws://145.241.228.207:8123)");
            return;
        }
        logger.info("MultiplayerDialog: Host button clicked");
        show_view("host");
    }

    /**
     * Handle join button clicked
     */
    private void on_join_clicked() {
        if (!is_connected) {
            show_error("Cannot connect to multiplayer server.\n\nPlease make sure:\n• The server is running\n• Server address is correct (currently: ws://145.241.228.207:8123)");
            return;
        }
        logger.info("MultiplayerDialog: Join button clicked");
        show_view("join");
        room_code_entry.grab_focus();
    }

    /**
     * Handle quick match button clicked
     */
    private void on_quick_match_clicked() {
        if (!is_connected) {
            show_error("Cannot connect to multiplayer server.\n\nPlease make sure:\n• The server is running\n• Server address is correct (currently: ws://145.241.228.207:8123)");
            return;
        }

        logger.info("MultiplayerDialog: Quick match clicked");
        show_view("quick_match");
    }

    /**
     * Handle start quick match button clicked
     */
    private void on_start_quick_match_clicked() {
        logger.info("MultiplayerDialog: Starting quick match...");

        // Get variant from selection
        DraughtsVariant variant = get_variant_from_index((int)quick_match_variant_row.selected);

        // Show waiting view
        show_view("waiting");
        waiting_label.label = _("Searching for opponent...");

        // Hide room code, show variant instead
        room_code_box.visible = false;
        quick_match_variant_box.visible = true;
        quick_match_variant_label.label = get_variant_display_name(variant);

        // Mark as quick matching
        is_quick_matching = true;

        // Start quick match
        controller.quick_match.begin(variant, (obj, res) => {
            bool success = controller.quick_match.end(res);
            if (!success) {
                is_quick_matching = false;
                show_error("Failed to start quick match");
                show_view("main");
            }
        });
    }

    /**
     * Handle cancel quick match button clicked
     */
    private void on_cancel_quick_match_clicked() {
        show_view("main");
    }

    /**
     * Handle create room button clicked
     */
    private void on_create_room_clicked() {
        logger.info("MultiplayerDialog: Creating room...");

        // Get variant from selection
        DraughtsVariant variant = get_variant_from_index((int)variant_row.selected);

        // Get timer settings
        bool use_timer = use_timer_row.active;
        int minutes = (int)minutes_row.value;
        int increment = (int)increment_row.value;
        string clock_type = (clock_type_row.selected == 0) ? "Fischer" : "Bronstein";

        // Show waiting view
        show_view("waiting");
        waiting_label.label = _("Creating room...");

        // Show room code, hide variant
        room_code_box.visible = true;
        quick_match_variant_box.visible = false;

        // Create room
        controller.create_room.begin(variant, use_timer, minutes, increment, clock_type, (obj, res) => {
            bool success = controller.create_room.end(res);
            if (!success) {
                show_error("Failed to create room");
                show_view("main");
            }
        });
    }

    /**
     * Handle join room button clicked
     */
    private void on_join_room_clicked() {
        string room_code = room_code_entry.text.strip().up();

        if (room_code.length != 6) {
            show_error("Room code must be 6 characters");
            return;
        }

        logger.info("MultiplayerDialog: Joining room: %s", room_code);

        // Show waiting view
        show_view("waiting");
        waiting_label.label = _("Joining room...");
        room_code_label.label = room_code;

        // Join room
        controller.join_room.begin(room_code, (obj, res) => {
            bool success = controller.join_room.end(res);
            if (!success) {
                show_error("Failed to join room");
                show_view("main");
            }
        });
    }

    /**
     * Handle cancel join button
     */
    private void on_cancel_join_clicked() {
        room_code_entry.text = "";
        show_view("main");
    }

    /**
     * Handle cancel host button
     */
    private void on_cancel_host_clicked() {
        show_view("main");
    }

    /**
     * Handle copy code button
     */
    private void on_copy_code_clicked() {
        var clipboard = Gdk.Display.get_default().get_clipboard();
        clipboard.set_text(room_code_label.label);
        logger.debug("MultiplayerDialog: Room code copied to clipboard");
    }

    /**
     * Handle cancel waiting button
     */
    private void on_cancel_waiting_clicked() {
        // If we're in quick match mode, cancel it
        if (is_quick_matching) {
            controller.cancel_quick_match();
            is_quick_matching = false;
        }

        controller.leave_session();
        show_view("main");
    }

    /**
     * Handle room created event
     */
    private void on_room_created(string room_code, PieceColor your_color) {
        logger.info("MultiplayerDialog: Room created - %s", room_code);
        room_code_label.label = room_code;
        waiting_label.label = _("Waiting for opponent...");
    }

    /**
     * Handle opponent joined event
     */
    private void on_opponent_joined(string opponent_name) {
        logger.info("MultiplayerDialog: Opponent joined - %s", opponent_name);
        waiting_label.label = @"$opponent_name joined! Starting game...";
    }

    /**
     * Handle game started event
     */
    private void on_game_started(DraughtsVariant variant, PieceColor your_color, string opponent_name) {
        logger.info("MultiplayerDialog: Game started!");

        // Clear quick match flag
        is_quick_matching = false;

        // Emit signal with controller
        game_ready(controller);

        // Close dialog
        close();
    }

    /**
     * Handle session restored event - auto-reconnect to ongoing game
     */
    private void on_session_restored(string room_code, string variant_str, string opponent_name, PieceColor player_color) {
        logger.info("MultiplayerDialog: Session restored - Room: %s, Variant: %s, Opponent: %s, Color: %s",
                   room_code, variant_str, opponent_name, player_color.to_string());

        // The server will automatically send a GAME_STARTED message to restore the full game state
        // We just need to wait for that signal which will trigger on_game_started()
        // For now, just log that we're reconnecting
        logger.info("MultiplayerDialog: Waiting for server to send game state...");
    }

    /**
     * Handle multiplayer error
     */
    private void on_multiplayer_error(string error_message) {
        logger.warning("MultiplayerDialog: Multiplayer error - %s", error_message);
        show_error(error_message);
        show_view("main");
    }

    /**
     * Show different views
     */
    private void show_view(string view_name) {
        view_stack.visible_child_name = view_name;
    }

    /**
     * Update connection status
     */
    private void update_connection_status(bool connected, string message) {
        // Update main view
        var main_window_title = header_bar.title_widget as Adw.WindowTitle;
        if (main_window_title != null) {
            main_window_title.subtitle = message;
        }

        // Update host view
        var host_window_title = host_header_bar.title_widget as Adw.WindowTitle;
        if (host_window_title != null) {
            host_window_title.subtitle = message;
        }

        // Update join view
        var join_window_title = join_header_bar.title_widget as Adw.WindowTitle;
        if (join_window_title != null) {
            join_window_title.subtitle = message;
        }

        // Update quick match view
        var quick_match_window_title = quick_match_header_bar.title_widget as Adw.WindowTitle;
        if (quick_match_window_title != null) {
            quick_match_window_title.subtitle = message;
        }

        // Update waiting view
        var waiting_window_title = waiting_header_bar.title_widget as Adw.WindowTitle;
        if (waiting_window_title != null) {
            waiting_window_title.subtitle = message;
        }
    }

    /**
     * Update connection state
     */
    private void update_connection_state(ConnectionState state) {
        switch (state) {
            case ConnectionState.CONNECTED:
                update_connection_status(true, _("Connected"));
                break;
            case ConnectionState.CONNECTING:
                update_connection_status(false, _("Connecting..."));
                break;
            case ConnectionState.RECONNECTING:
                update_connection_status(false, _("Reconnecting..."));
                break;
            case ConnectionState.DISCONNECTED:
                update_connection_status(false, _("Disconnected"));
                break;
            case ConnectionState.ERROR:
                update_connection_status(false, _("Connection error"));
                break;
        }
    }

    /**
     * Enable or disable multiplayer buttons based on connection status
     */
    private void enable_multiplayer_buttons(bool enabled) {
        host_button.sensitive = enabled;
        join_button.sensitive = enabled;
        quick_match_button.sensitive = enabled;
    }

    /**
     * Show error message
     */
    private void show_error(string message) {
        var dialog = new Adw.AlertDialog(_("Error"), message);
        dialog.add_response("ok", _("OK"));
        dialog.set_default_response("ok");
        dialog.present(this);
    }

    /**
     * Show info message
     */
    private void show_info(string message) {
        var dialog = new Adw.AlertDialog(_("Information"), message);
        dialog.add_response("ok", _("OK"));
        dialog.set_default_response("ok");
        dialog.present(this);
    }

    /**
     * Load settings from New Game preferences
     */
    private void load_settings_from_preferences() {
        // Load default variant
        DraughtsVariant variant = settings_manager.get_default_variant();
        variant_row.selected = (uint)variant;
        quick_match_variant_row.selected = (uint)variant;

        // Load timer settings
        bool timer_enabled = settings_manager.get_boolean("new-game-time-limit-enabled");
        use_timer_row.active = timer_enabled;

        int minutes = settings_manager.get_int("new-game-minutes-per-side");
        minutes_row.value = minutes;

        int increment = settings_manager.get_int("new-game-increment-seconds");
        increment_row.value = increment;

        // Load clock type (0 = Fischer, 1 = Bronstein)
        int clock_type = settings_manager.get_int("new-game-clock-type");
        clock_type_row.selected = clock_type;
    }

    /**
     * Get variant from combo row index
     */
    private DraughtsVariant get_variant_from_index(int index) {
        switch (index) {
            case 0: return DraughtsVariant.AMERICAN;
            case 1: return DraughtsVariant.INTERNATIONAL;
            case 2: return DraughtsVariant.RUSSIAN;
            case 3: return DraughtsVariant.BRAZILIAN;
            case 4: return DraughtsVariant.ITALIAN;
            case 5: return DraughtsVariant.SPANISH;
            case 6: return DraughtsVariant.CZECH;
            case 7: return DraughtsVariant.THAI;
            case 8: return DraughtsVariant.GERMAN;
            case 9: return DraughtsVariant.SWEDISH;
            case 10: return DraughtsVariant.POOL;
            case 11: return DraughtsVariant.TURKISH;
            case 12: return DraughtsVariant.ARMENIAN;
            case 13: return DraughtsVariant.GOTHIC;
            case 14: return DraughtsVariant.FRISIAN;
            case 15: return DraughtsVariant.CANADIAN;
            default: return DraughtsVariant.INTERNATIONAL;
        }
    }

    private string get_variant_display_name(DraughtsVariant variant) {
        switch (variant) {
            case DraughtsVariant.AMERICAN: return _("American Checkers");
            case DraughtsVariant.INTERNATIONAL: return _("International Draughts");
            case DraughtsVariant.RUSSIAN: return _("Russian Draughts");
            case DraughtsVariant.BRAZILIAN: return _("Brazilian Draughts");
            case DraughtsVariant.ITALIAN: return _("Italian Draughts");
            case DraughtsVariant.SPANISH: return _("Spanish Draughts");
            case DraughtsVariant.CZECH: return _("Czech Draughts");
            case DraughtsVariant.THAI: return _("Thai Draughts");
            case DraughtsVariant.GERMAN: return _("German Draughts");
            case DraughtsVariant.SWEDISH: return _("Swedish Draughts");
            case DraughtsVariant.POOL: return _("Pool Checkers");
            case DraughtsVariant.TURKISH: return _("Turkish Draughts");
            case DraughtsVariant.ARMENIAN: return _("Armenian Draughts");
            case DraughtsVariant.GOTHIC: return _("Gothic Draughts");
            case DraughtsVariant.FRISIAN: return _("Frisian Draughts");
            case DraughtsVariant.CANADIAN: return _("Canadian Checkers");
            default: return _("International Draughts");
        }
    }

    /**
     * Static method to show the dialog
     */
    public static MultiplayerDialog show(Gtk.Window parent) {
        var dialog = new MultiplayerDialog();
        dialog.present(parent);
        return dialog;
    }
}
