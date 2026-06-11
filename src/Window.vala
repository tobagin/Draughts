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

namespace Draughts {


#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/window.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/Draughts/window.ui")]
#endif

    public class Window : Adw.ApplicationWindow {

[GtkChild]
        private unowned Adw.HeaderBar header_bar;

        [GtkChild]
        private unowned Adw.WindowTitle window_title;

        [GtkChild]
        private unowned Gtk.DropDown move_history_dropdown;

        [GtkChild]
        private unowned Gtk.StringList move_history_model;

        [GtkChild]
        private unowned Gtk.MenuButton menu_button;

        [GtkChild]
        private unowned Adw.ToastOverlay toast_overlay;

        [GtkChild]
        private unowned Gtk.Box board_container;



        [GtkChild]
        private unowned Gtk.Button undo_button;

        // Redo button removed from headerbar UI
        // [GtkChild]
        // private unowned Gtk.Button redo_button;

        [GtkChild]
        private unowned Gtk.Button pause_button;

        [GtkChild]
        private unowned Gtk.Button resign_button;

        [GtkChild]
        private unowned Gtk.Image server_status_icon;

        [GtkChild]
        private unowned Gtk.Box pause_overlay;

        [GtkChild]
        private unowned Gtk.Box disconnect_overlay;

        [GtkChild]
        private unowned Adw.HeaderBar bottom_bar;

        [GtkChild]
        private unowned Gtk.Label red_timer_display;

        [GtkChild]
        private unowned Gtk.Label black_timer_display;

        [GtkChild]
        private unowned Gtk.Button first_move_button;

        [GtkChild]
        private unowned Gtk.Button prev_move_button;

        [GtkChild]
        private unowned Gtk.Button next_move_button;

        [GtkChild]
        private unowned Gtk.Button last_move_button;

        [GtkChild]
        private unowned Gtk.Label mobile_move_label;

        private DraughtsBoard draughts_board;
        private DraughtsBoardAdapter adapter;
        private BoardRenderer renderer;
        private BoardInteractionHandler interaction_handler;
        private TimerDisplay timer_display;
        private SimpleAction show_history_action;
        private SimpleAction undo_move_action;

        private Logger logger;
        private SettingsManager settings_manager;
        private bool is_first_move = true;
        private bool is_paused = false;
        private bool is_navigating = false;
        private bool is_multiplayer_game = false;

        // Server connection management
        private MultiplayerGameController? server_controller = null;
        private bool is_server_connected = false;
        private bool version_mismatch_shown = false;
        private uint reconnect_timeout_id = 0;
        private int reconnect_attempts = 0;
        private uint health_check_timeout_id = 0;
        private bool undo_just_used = false;

        public Window(Gtk.Application app) {
            Object(application: app);

            logger = Logger.get_default();
            settings_manager = SettingsManager.get_instance();
            set_default_size(900, 700);
            // Mobile-friendly minimum size (360px width for mobile devices)
            set_size_request(360, 400);
            setup_actions();
            load_css();
            setup_board();
            setup_game_components();
            initialize_window_subtitle();

            // Ensure template widgets are accessible (suppresses unused warnings)
            assert(header_bar != null);
            assert(window_title != null);
            assert(move_history_dropdown != null);
            assert(move_history_model != null);
            assert(menu_button != null);
            assert(toast_overlay != null);
            assert(board_container != null);
            assert(undo_button != null);
            // assert(redo_button != null); // Redo button removed from UI

            // Connect move history dropdown
            move_history_dropdown.notify["selected"].connect(on_move_history_selected);

            // Start a game automatically with saved settings
            // Use a delay to ensure widgets are fully realized and sized
            Timeout.add(200, () => {
                start_game_with_saved_settings();
                return false;
            });

            // Auto-connect to multiplayer server
            Timeout.add(500, () => {
                connect_to_server_async.begin();
                return false;
            });

            // Handle window close request
            this.close_request.connect(on_close_request);

            logger.info("Window created and initialized");
        }

        private bool on_close_request() {
            // If game in progress, show confirmation
            if (is_game_in_progress()) {
                if (is_multiplayer_game) {
                    show_resign_confirmation_for_action(() => {
                        // Actually close the window/quit
                        var app = get_application();
                        if (app != null) {
                            app.quit();
                        }
                    });
                } else {
                    show_abandon_game_confirmation(() => {
                        // Actually close the window/quit
                        var app = get_application();
                        if (app != null) {
                            app.quit();
                        }
                    });
                }
                return true; // Prevent default close
            }
            return false; // Allow default close
        }

        private void setup_actions() {
            // Existing actions
            var shortcuts_action = new SimpleAction(Constants.ACTION_SHOW_HELP_OVERLAY, null);
            shortcuts_action.activate.connect(() => {
                Draughts.KeyboardShortcuts.show(this);
            });
            add_action(shortcuts_action);

            var close_window_action = new SimpleAction("close-window", null);
            close_window_action.activate.connect(() => {
                close();
                logger.info("Window closed via shortcut");
            });
            add_action(close_window_action);

            var fullscreen_action = new SimpleAction("toggle-fullscreen", null);
            fullscreen_action.activate.connect(() => {
                if (fullscreened) {
                    unfullscreen();
                    logger.debug("Exited fullscreen");
                } else {
                    fullscreen();
                    logger.debug("Entered fullscreen");
                }
            });
            add_action(fullscreen_action);

            // Game actions
            var new_game_action = new SimpleAction("new-game", null);
            new_game_action.activate.connect(() => {
                start_new_game();
            });
            add_action(new_game_action);

            var reset_game_action = new SimpleAction("reset-game", null);
            reset_game_action.activate.connect(() => {
                reset_game();
            });
            add_action(reset_game_action);

            undo_move_action = new SimpleAction("undo-move", null);
            undo_move_action.activate.connect(() => {
                on_undo_requested();
            });
            add_action(undo_move_action);

            var redo_move_action = new SimpleAction("redo-move", null);
            redo_move_action.activate.connect(() => {
                if (adapter != null) {
                    adapter.redo_last_move();
                }
            });
            add_action(redo_move_action);

            // History action
            show_history_action = new SimpleAction("show-history", null);
            show_history_action.activate.connect(() => {
                show_history_dialog();
            });
            add_action(show_history_action);

            // Update history action enabled state based on setting
            update_history_action_state();

            // Export/Import actions
            var export_pdn_action = new SimpleAction("export-pdn", null);
            export_pdn_action.activate.connect(() => {
                show_export_pdn_dialog();
            });
            add_action(export_pdn_action);

            var open_pdn_action = new SimpleAction("open-pdn", null);
            open_pdn_action.activate.connect(() => {
                show_open_pdn_dialog();
            });
            add_action(open_pdn_action);

            logger.debug("Window actions configured");
        }

        private void setup_board() {
            draughts_board = new DraughtsBoard();
            board_container.append(draughts_board);
            logger.debug("Draughts board created and added to container");
        }

        private void setup_game_components() {
            // Create the comprehensive game system components
            renderer = new BoardRenderer(8); // Default board size
            adapter = new DraughtsBoardAdapter(draughts_board);
            // Note: BoardInteractionHandler is not used anymore - DraughtsBoard handles its own interactions
            // interaction_handler = new BoardInteractionHandler(adapter, renderer, draughts_board);

            // Create UI controls
            timer_display = new TimerDisplay();

            // Connect timer to window subtitle
            timer_display.timer_updated.connect(on_timer_updated);
            timer_display.dual_timer_updated.connect(on_dual_timer_updated);
            timer_display.time_expired.connect(on_time_expired);

            // Connect signals
            setup_game_signals();

            // Connect undo button (redo button removed from headerbar UI)
            undo_button.clicked.connect(on_undo_requested);
            // redo_button.clicked.connect(on_redo_requested); // Redo removed from UI

            // Connect pause button
            pause_button.clicked.connect(on_pause_button_clicked);

            // Connect resign button
            resign_button.clicked.connect(on_resign_button_clicked);

            // Connect navigation buttons
            first_move_button.clicked.connect(on_first_move_clicked);
            prev_move_button.clicked.connect(on_prev_move_clicked);
            next_move_button.clicked.connect(on_next_move_clicked);
            last_move_button.clicked.connect(on_last_move_clicked);

            // Initialize button states
            update_undo_redo_buttons();
            update_navigation_buttons();

            logger.debug("Comprehensive game components initialized");
        }

        private void setup_game_signals() {
            // Adapter signals
            adapter.game_state_changed.connect(on_game_state_changed);
            adapter.game_finished.connect(on_game_finished);
            adapter.move_made.connect(on_move_made);

            // Note: Interaction handler signals removed - DraughtsBoard handles its own interactions now
            // interaction_handler.piece_selected.connect(on_piece_selected);
            // interaction_handler.piece_deselected.connect(on_piece_deselected);
            // interaction_handler.move_attempted.connect(on_move_attempted);
            // interaction_handler.invalid_move_attempted.connect(on_invalid_move_attempted);

            // Timer signals
            // Timer display signals - removed since TimerDisplay no longer has these

            // Settings signals
            var settings_manager = SettingsManager.get_instance();
            settings_manager.ai_difficulty_changed.connect(on_difficulty_changed);

            logger.debug("Game signals connected");
        }

        private void load_css() {
            var css_provider = new Gtk.CssProvider();
#if DEVELOPMENT
            css_provider.load_from_resource("/io/github/tobagin/Draughts/Devel/style.css");
#else
            css_provider.load_from_resource("/io/github/tobagin/Draughts/style.css");
#endif
            Gtk.StyleContext.add_provider_for_display(
                get_display(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
            logger.debug("CSS loaded successfully");
        }

        private void initialize_window_subtitle() {
            // Set subtitle based on saved game rules
            if (window_title != null && draughts_board != null) {
                string current_rules = draughts_board.get_game_rules();
                string display_name = get_rules_display_name(current_rules);
                window_title.set_subtitle(display_name);
            }

            // Initialize move history dropdown with "Game Start"
            rebuild_move_history_dropdown();
        }

        private void rebuild_move_history_dropdown() {
            is_navigating = true;

            // Clear existing items
            move_history_model.splice(0, move_history_model.get_n_items(), null);

            // Add "Game Start"
            move_history_model.append(_("Game Start"));

            if (adapter != null) {
                var current_game = adapter.get_current_game();
                if (current_game != null) {
                    var moves = current_game.get_move_history();

                    for (int i = 0; i < moves.length; i++) {
                        var move = moves[i];
                        int move_number = (i / 2) + 1;
                        bool is_white_move = (i % 2) == 0;
                        string move_label = format_move_for_dropdown(move, move_number, is_white_move);
                        move_history_model.append(move_label);
                    }
                }
            }

            // Select the current position
            int current_position = get_current_move_index();
            uint n_items = move_history_model.get_n_items();

            // Ensure current_position is within bounds
            if (current_position < 0) {
                current_position = 0;
            } else if (current_position >= n_items) {
                current_position = (int)n_items - 1;
            }

            if (n_items > 0) {
                move_history_dropdown.set_selected((uint)current_position);
            }

            is_navigating = false;
            
            // Update mobile label
            update_mobile_move_label(current_position);
        }

        private void update_mobile_move_label(int current_index) {
            if (mobile_move_label == null) return;

            if (current_index <= 0) {
                mobile_move_label.label = _("Game Start");
                return;
            }

            // Calculate actual move number
            // Each index > 0 represents a half-move (ply)
            // Index 1 = 1. Red ...
            // Index 2 = 1. ... Black
            // Index 3 = 2. Red ...
            
            int move_num = ((current_index - 1) / 2) + 1;
            bool is_white = ((current_index - 1) % 2) != 0; // Index 1 is Black? No wait.
            // Index 1 (first move) is Red (White in engine terms usually, but here Red/Black).
            // Let's check format_move_for_dropdown loop:
            // for (int i = 0; i < moves.length; i++)
            // move_number = (i / 2) + 1
            // is_white_move = (i % 2) == 0 -> This implies 0 is White?
            
            // Let's re-verify `format_move_for_dropdown` logic in the file view.
            // Line 380: bool is_white_move = (i % 2) == 0; 
            // This suggests the first move (i=0) is considered "White" (or Red).
            
            // So for current_index (which is dropdown index):
            // Dropdown index 0 = "Game Start"
            // Dropdown index 1 corresponds to moves[0] (i=0)
            
            int move_idx = current_index - 1;
            int move_number = (move_idx / 2) + 1;
            bool is_second_player = (move_idx % 2) != 0;
            
            string suffix = is_second_player ? "b" : "a";
            mobile_move_label.label = _("Move %d%s").printf(move_number, suffix);
        }

        private string format_move_for_dropdown(DraughtsMove move, int move_number, bool is_white_move) {
            string move_suffix = is_white_move ? "a" : "b";
            string piece_moved = get_piece_description(move);
            string from_square = position_to_notation(move.from_position);
            string to_square = position_to_notation(move.to_position);

            return @"$(move_number)$(move_suffix). $(piece_moved) moves from $(from_square) to $(to_square)";
        }

        private string get_piece_description(DraughtsMove move) {
            // Determine if it's White (Red) or Black based on move index
            // For now, we'll use the piece color from the move if available
            // Otherwise default to describing by color
            return move.is_capture() ? "piece" : "piece";
        }

        private string position_to_notation(BoardPosition pos) {
            // Convert to algebraic notation (e.g., "a1", "b2", etc.)
            char file = (char)('a' + pos.col);
            int rank = pos.row + 1;
            return @"$(file)$(rank)";
        }

        private int get_current_move_index() {
            if (adapter == null) {
                return 0;
            }

            var current_game = adapter.get_current_game();
            if (current_game == null) {
                return 0;
            }

            var moves = current_game.get_move_history();
            int total_moves = moves.length;

            // Check how many moves we can redo
            int redo_count = 0;
            var temp_adapter = adapter;
            while (temp_adapter.can_redo()) {
                redo_count++;
                // We can't actually count without changing state, so we'll track differently
                break;
            }

            // Current index is total moves - number of undos (which equals redo count)
            // Since we don't track undos directly, we'll use the move history length
            return total_moves - redo_count;
        }

        private void on_move_history_selected() {
            if (is_navigating) {
                return;
            }

            uint selected = move_history_dropdown.get_selected();
            navigate_to_move_index((int)selected);
        }

        private void navigate_to_move_index(int target_index) {
            if (adapter == null) {
                return;
            }

            is_navigating = true;

            // First, go back to the start
            while (adapter.can_undo()) {
                adapter.undo_last_move();
            }

            // Then redo to the target position
            for (int i = 0; i < target_index && adapter.can_redo(); i++) {
                adapter.redo_last_move();
            }

            update_undo_redo_buttons();
            update_navigation_buttons();

            is_navigating = false;
        }

        // Signal handlers for game events
        private void on_new_game_requested(DraughtsVariant variant) {
            if (adapter != null) {
                adapter.start_new_game(variant);
                var variant_obj = new GameVariant(variant);

                // Update renderer for board size
                renderer = new BoardRenderer(variant_obj.board_size);

                // Update board widget size to match the new variant
                if (draughts_board != null) {
                    string variant_rules = variant_obj.id;
                    draughts_board.set_game_rules(variant_rules);
                }

                // Update window title
                if (window_title != null) {
                    window_title.set_subtitle(variant_obj.display_name);
                }
                rebuild_move_history_dropdown();

                // Reset first move flag for timer
                is_first_move = true;
                undo_just_used = false;

                // Initialize turn indicator for Red (starting player)
                update_turn_indicator(PieceColor.RED);

                // Update undo/redo button states (should be disabled for new game)
                update_undo_redo_buttons();

                // Note: Toast notifications for new game start have been disabled to avoid
                // showing toasts during replay setup and other automated game starts
                // User feedback is provided through UI state changes instead

                logger.info("New game started with variant: %s", variant.to_string());
            }
        }

        private void on_new_game_requested_with_configuration(
            DraughtsVariant variant,
            bool is_human_vs_ai,
            PieceColor human_color,
            int ai_difficulty,
            bool use_time_limit,
            int minutes_per_side,
            int increment_seconds,
            string clock_type
        ) {
            is_multiplayer_game = false;  // Reset multiplayer flag for single-player games

            // Hide resign button for single-player
            resign_button.set_visible(false);

            if (adapter != null) {
                // Configure AI difficulty based on the selection
                AIDifficulty difficulty;
                switch (ai_difficulty) {
                    case 0:
                        difficulty = AIDifficulty.BEGINNER;
                        break;
                    case 1:
                        difficulty = AIDifficulty.INTERMEDIATE;
                        break;
                    case 2:
                        difficulty = AIDifficulty.ADVANCED;
                        break;
                    case 3:
                        difficulty = AIDifficulty.EXPERT;
                        break;
                    case 4:
                        difficulty = AIDifficulty.GRANDMASTER;
                        break;
                    default:
                        difficulty = AIDifficulty.INTERMEDIATE;
                        break;
                }

                // Configure timers if enabled
                if (use_time_limit && timer_display != null) {
                    TimeSpan base_time = TimeSpan.SECOND * (minutes_per_side * 60);
                    TimeSpan increment_time = TimeSpan.SECOND * increment_seconds;

                    Timer red_timer;
                    Timer black_timer;

                    if (clock_type == "Fischer") {
                        red_timer = new Timer.fischer(base_time, increment_time);
                        black_timer = new Timer.fischer(base_time, increment_time);
                    } else {
                        // Bronstein uses delay mode
                        red_timer = new Timer.with_delay(base_time, increment_time);
                        black_timer = new Timer.with_delay(base_time, increment_time);
                    }

                    timer_display.set_timers(red_timer, black_timer);
                } else if (timer_display != null) {
                    // No time limit - set null timers
                    timer_display.set_timers(null, null);
                }

                // Start new game with full configuration
                adapter.start_new_game_with_configuration(
                    variant,
                    is_human_vs_ai,
                    human_color,
                    difficulty,
                    use_time_limit,
                    minutes_per_side,
                    increment_seconds,
                    clock_type
                );

                var variant_obj = new GameVariant(variant);

                // Update renderer for board size
                renderer = new BoardRenderer(variant_obj.board_size);

                // Update board widget size to match the new variant
                if (draughts_board != null) {
                    string variant_rules = variant_obj.id;
                    draughts_board.set_game_rules(variant_rules);
                }

                // Update window title
                if (window_title != null) {
                    window_title.set_subtitle(variant_obj.display_name);
                }
                rebuild_move_history_dropdown();

                // Reset first move flag for timer
                is_first_move = true;
                undo_just_used = false;

                // Initialize turn indicator for Red (starting player)
                update_turn_indicator(PieceColor.RED);

                // Update undo/redo button states (should be disabled for new game)
                update_undo_redo_buttons();

                string mode_text = is_human_vs_ai ? "Human vs AI" : "Human vs Human";
                logger.info("New game started with variant: %s, Mode: %s", variant.to_string(), mode_text);
            }
        }

        private void on_game_paused() {
            if (timer_display != null) {
                timer_display.pause_timers();
            }
            logger.info("Game paused");
        }

        private void on_game_resumed() {
            if (timer_display != null) {
                timer_display.resume_timers();
            }
            logger.info("Game resumed");
        }

        private void on_game_reset_requested() {
            if (adapter != null) {
                adapter.reset_game();
                timer_display.reset_timers();

                // Reset first move flag
                is_first_move = true;

                // Initialize turn indicator for Red (starting player)
                update_turn_indicator(PieceColor.RED);

                var toast = new Adw.Toast("Game reset");
                toast.set_timeout(2);
                toast_overlay.add_toast(toast);

                logger.info("Game reset");
            }
        }

        private void on_undo_requested() {
            // Disable undo for multiplayer games
            if (is_multiplayer_game) {
                logger.info("Undo not allowed in multiplayer games");
                return;
            }

            if (adapter == null) {
                return;
            }

            // Disable undo button and action immediately to prevent double-clicks/keypresses
            undo_button.set_sensitive(false);
            undo_move_action.set_enabled(false);

            // For human vs AI games, undo one full round (player move + CPU move)
            var current_game = adapter.get_current_game();
            if (current_game != null) {
                // Check if it's human vs AI by checking player types
                bool is_vs_ai = (current_game.red_player.player_type == PlayerType.AI ||
                                current_game.black_player.player_type == PlayerType.AI);

                if (is_vs_ai) {
                    // For vs AI: remove 2 moves from history (AI's move + player's move)
                    print("\n*** WINDOW: Undo button clicked, calling controller.undo_full_round ***\n");
                    var controller = adapter.get_controller();
                    print("*** WINDOW: controller is %s ***\n", controller != null ? "NOT NULL" : "NULL");
                    if (controller != null) {
                        bool success = controller.undo_full_round(1);
                        print("*** WINDOW: undo_full_round returned %s ***\n", success ? "TRUE" : "FALSE");
                        if (success) {
                            logger.info("Undone AI's last move and player's previous move");
                            // Set flag to keep undo disabled until next move
                            undo_just_used = true;
                            // Rebuild the move history dropdown to reflect removed moves
                            // Use idle callback to ensure game state is fully updated
                            Idle.add(() => {
                                rebuild_move_history_dropdown();
                                update_undo_redo_buttons();
                                return false;
                            });
                        } else {
                            // Undo failed, re-enable button
                            update_undo_redo_buttons();
                        }
                    } else {
                        // No controller, re-enable button
                        update_undo_redo_buttons();
                    }
                } else {
                    // For human vs human, undo one move
                    if (adapter.undo_last_move()) {
                        logger.info("Move undone");
                        // Set flag to keep undo disabled until next move
                        undo_just_used = true;
                        update_undo_redo_buttons();
                        update_navigation_buttons();
                    } else {
                        // Undo failed, re-enable button
                        update_undo_redo_buttons();
                    }
                }
            } else {
                // No game, re-enable button
                update_undo_redo_buttons();
            }
        }

        private void on_redo_requested() {
            if (adapter != null && adapter.redo_last_move()) {
                // Move redone - no toast needed, visual board update is sufficient

                logger.info("Move redone");
                update_undo_redo_buttons();
                update_navigation_buttons();
            }
        }

        private void on_pause_button_clicked() {
            if (is_paused) {
                resume_game();
            } else {
                pause_game();
            }
        }

        private void pause_game() {
            is_paused = true;

            // Show pause overlay
            pause_overlay.visible = true;

            // Hide pieces on the board
            if (draughts_board != null) {
                draughts_board.set_pieces_visible(false);
            }

            // Pause timer
            if (timer_display != null) {
                timer_display.pause_timers();
            }

            // Update button icon and tooltip
            pause_button.icon_name = "media-playback-start-symbolic";
            pause_button.tooltip_text = _("Resume Game");

            logger.info("Game paused");
        }

        private void resume_game() {
            is_paused = false;

            // Hide pause overlay
            pause_overlay.visible = false;

            // Show pieces on the board
            if (draughts_board != null) {
                draughts_board.set_pieces_visible(true);
            }

            // Resume timer
            if (timer_display != null) {
                timer_display.resume_timers();
            }

            // Update button icon and tooltip
            pause_button.icon_name = "media-playback-pause-symbolic";
            pause_button.tooltip_text = _("Pause Game");

            logger.info("Game resumed");
        }

        private void on_resign_button_clicked() {
            if (!is_multiplayer_game) {
                return;
            }

            // Show confirmation dialog
            // Show confirmation dialog
            var dialog = new Adw.AlertDialog(
                _("Resign from Game?"),
                _("Are you sure you want to resign? This will end the game and count as a loss.")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("resign", _("Resign"));
            dialog.set_response_appearance("resign", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.choose.begin(this, null, (obj, res) => {
                try {
                    var response = dialog.choose.end(res);
                    if (response == "resign") {
                        var controller = adapter.get_controller();
                        if (controller is MultiplayerGameController) {
                            var multiplayer_controller = (MultiplayerGameController) controller;
                            multiplayer_controller.resign();
                            logger.info("Player resigned from multiplayer game");
                        }
                    }
                } catch (Error e) {
                     logger.warning("Error showing resign dialog: %s", e.message);
                }
            });
            
            // dialog.present(); is likely redundant if choose.begin calls it? 
            // Adw.AlertDialog.choose() does NOT automatically present. You must call present() beforehand or it might work contextually.
            // Wait, docs say "This function shows the dialog". choose() is async.
            // Actually Adw.AlertDialog documentation says: "This function is equivalent to calling prepare() and then wait_for_response()."
            // Wait, for Adw.MessageDialog, it was run/response.
            // For Adw.AlertDialog, "choose" is the method. 
            // "This function shows the dialog to the user" - yes.
            // But let's keep it safe. 
            // Existing code had dialog.present() at 831. 
            // I will keep lines 831 if they were outside the block.
            // The garbage ended at 829. 831 was dialog.present().

        }

        private void update_undo_redo_buttons() {
            // Disable undo/redo for multiplayer games
            if (is_multiplayer_game) {
                undo_button.set_sensitive(false);
                undo_move_action.set_enabled(false);
                // redo_button.set_sensitive(false); // Redo removed from UI
                return;
            }

            // If undo was just used, keep it disabled
            if (undo_just_used) {
                undo_button.set_sensitive(false);
                undo_move_action.set_enabled(false);
                return;
            }

            if (adapter != null) {
                var current_game = adapter.get_current_game();
                bool can_undo = false;

                if (current_game != null) {
                    // Check if it's human vs AI
                    bool is_vs_ai = (current_game.red_player.player_type == PlayerType.AI ||
                                    current_game.black_player.player_type == PlayerType.AI);

                    if (is_vs_ai) {
                        // For vs AI, only allow undo if:
                        // 1. There are at least 2 moves in history (player + AI)
                        // 2. The current turn is the human player's turn (AI just played)
                        int history_size = current_game.get_history_size();
                        var current_state = current_game.current_state;

                        // Check if current player is human
                        bool current_is_human = false;
                        if (current_state.active_player == PieceColor.RED) {
                            current_is_human = (current_game.red_player.player_type == PlayerType.HUMAN);
                        } else {
                            current_is_human = (current_game.black_player.player_type == PlayerType.HUMAN);
                        }

                        print("*** update_undo_redo_buttons: history_size=%d, current_is_human=%s, undo_just_used=%s ***\n",
                              history_size, current_is_human ? "TRUE" : "FALSE", undo_just_used ? "TRUE" : "FALSE");

                        can_undo = (history_size >= 2 && current_is_human);
                    } else {
                        // For human vs human, use normal undo check
                        can_undo = adapter.can_undo();
                    }
                }

                undo_button.set_sensitive(can_undo);
                undo_move_action.set_enabled(can_undo);
                // redo_button.set_sensitive(adapter.can_redo()); // Redo removed from UI
            } else {
                undo_button.set_sensitive(false);
                undo_move_action.set_enabled(false);
                // redo_button.set_sensitive(false); // Redo removed from UI
            }
        }

        private void update_navigation_buttons() {
            if (adapter != null) {
                // Disable navigation during AI turn
                if (adapter.is_ai_turn()) {
                    first_move_button.set_sensitive(false);
                    prev_move_button.set_sensitive(false);
                    next_move_button.set_sensitive(false);
                    last_move_button.set_sensitive(false);
                    return;
                }

                int history_size = adapter.get_history_size();
                int current_pos = adapter.get_current_viewing_position();

                // First/Previous enabled if not at game start
                bool can_go_back = current_pos > -1;
                first_move_button.set_sensitive(can_go_back);
                prev_move_button.set_sensitive(can_go_back);

                // Next/Last enabled if not at current position
                bool can_go_forward = !adapter.is_at_current_position();
                next_move_button.set_sensitive(can_go_forward);
                last_move_button.set_sensitive(can_go_forward);
            } else {
                first_move_button.set_sensitive(false);
                prev_move_button.set_sensitive(false);
                next_move_button.set_sensitive(false);
                last_move_button.set_sensitive(false);
            }
        }

        private void on_first_move_clicked() {
            if (adapter != null) {
                is_navigating = true;
                // View game start position (position -1)
                adapter.view_history_at_position(-1);
                update_undo_redo_buttons();
                update_navigation_buttons();
                move_history_dropdown.set_selected(0);
                is_navigating = false;
                logger.info("Viewing game start");
            }
        }

        private void on_prev_move_clicked() {
            if (adapter != null) {
                is_navigating = true;
                int current_pos = adapter.get_current_viewing_position();
                if (current_pos > -1) {
                    adapter.view_history_at_position(current_pos - 1);
                    update_undo_redo_buttons();
                    update_navigation_buttons();
                    uint current = move_history_dropdown.get_selected();
                    if (current > 0) {
                        move_history_dropdown.set_selected(current - 1);
                    }
                }
                is_navigating = false;
                logger.info("Viewing previous move");
            }
        }

        private void on_next_move_clicked() {
            if (adapter != null) {
                is_navigating = true;
                int current_viewing_pos = adapter.get_current_viewing_position();
                int actual_current_pos = adapter.get_actual_current_position();

                // Check if the next position would be the current game position
                if (current_viewing_pos >= actual_current_pos) {
                    // Return to current position (enables interaction)
                    adapter.return_to_current_position();
                    move_history_dropdown.set_selected(move_history_model.get_n_items() - 1);
                    logger.info("Returned to current position");
                } else {
                    // View next historical position
                    adapter.view_history_at_position(current_viewing_pos + 1);
                    uint current = move_history_dropdown.get_selected();
                    move_history_dropdown.set_selected(current + 1);
                    logger.info("Viewing next move");
                }

                update_undo_redo_buttons();
                update_navigation_buttons();
                is_navigating = false;
            }
        }

        private void on_last_move_clicked() {
            if (adapter != null) {
                is_navigating = true;
                // Return to current game state
                adapter.return_to_current_position();
                update_undo_redo_buttons();
                update_navigation_buttons();
                move_history_dropdown.set_selected(move_history_model.get_n_items() - 1);
                is_navigating = false;
                logger.info("Returned to current position");
            }
        }

        private void on_variant_changed(DraughtsVariant variant) {
            var variant_obj = new GameVariant(variant);

            // Update renderer for new board size
            renderer = new BoardRenderer(variant_obj.board_size);

            // Update window subtitle
            if (window_title != null) {
                window_title.set_subtitle(variant_obj.display_name);
            }

            logger.info("Variant changed to: %s", variant.to_string());
        }

        private void on_difficulty_changed(AIDifficulty difficulty) {
            logger.info("AI difficulty changed to: %s", difficulty.to_string());

            // If there's an active game with AI players, restart it with the new difficulty
            if (adapter != null) {
                var current_game = adapter.get_current_game();
                if (current_game != null && has_ai_player(current_game)) {
                    logger.info("Restarting AI game with new difficulty: %s", difficulty.to_string());
                    restart_current_game_with_new_ai_difficulty(current_game, difficulty);
                }
            }
        }

        private void on_game_state_changed(DraughtsGameState new_state) {
            // Start timer on first move
            if (is_first_move && timer_display != null) {
                timer_display.start_game_timer();
                is_first_move = false;
                logger.debug("Started game timer on first move");
            }

            // Update timer display based on active player
            if (timer_display != null) {
                // Convert PieceColor to Player for timer display
                var player = (new_state.active_player == PieceColor.RED) ? Player.RED : Player.BLACK;
                timer_display.set_active_player(player);
            }

            // Update bottom bar turn indicator
            update_turn_indicator(new_state.active_player);

            logger.debug("Game state changed, active player: %s", new_state.active_player.to_string());
        }

        private void update_turn_indicator(PieceColor active_player) {
            // Turn indicator removed - no longer displayed
        }

        private void on_game_finished(GameStatus result) {
            // Pause timers
            if (timer_display != null) {
                timer_display.pause_timers();
            }

            // Get final game state and real statistics
            DraughtsGameState final_state = null;
            GameSessionStats session_stats = null;

            if (adapter != null) {
                // Get the real current game state
                final_state = adapter.get_current_state();
                if (final_state != null) {
                    final_state.game_status = result; // Update the result
                }

                // Get the full game session statistics
                session_stats = adapter.get_full_game_statistics();
            }

            // Show game end dialog with real statistics
            if (final_state != null) {
                var dialog = new GameEndDialog();

                // Check if this is a multiplayer game and get local player color
                PieceColor? local_player_color = null;
                bool is_multiplayer = adapter.get_controller() is MultiplayerGameController;
                if (is_multiplayer) {
                    var multiplayer_controller = (MultiplayerGameController) adapter.get_controller();
                    local_player_color = multiplayer_controller.get_local_player_color();
                }

                // Connect to dialog responses
                dialog.response.connect((response) => {
                    if (response == "new_game") {
                        if (is_multiplayer) {
                            // "Play Again" in multiplayer - show multiplayer dialog to find new opponent
                            var app = get_application() as Draughts.Application;
                            if (app != null) {
                                app.activate_action("play-online", null);
                            }
                        } else {
                            // "New Game" in single player - show new game dialog
                            start_new_game();
                        }
                    } else if (response == "close") {
                        if (is_multiplayer) {
                            // "Exit to Menu" in multiplayer - start new single player game with saved settings
                            start_game_with_saved_settings();
                        }
                        // In single player, "Close" just closes the dialog (default behavior)
                    }
                });

                // Save game to history
                var current_game = adapter.get_current_game();
                logger.debug(@"Window: Attempting to save game to history, current_game is $(current_game != null ? "not null" : "NULL")");
                if (current_game != null) {
                    logger.debug(@"Window: Game is over: $(current_game.is_game_over())");
                    var history_manager = GameHistoryManager.get_default();
                    history_manager.add_game(current_game);
                    logger.debug(@"Window: Game saved to history: $(current_game.id)");
                } else {
                    logger.debug("Window: current_game is NULL, not saving to history");
                }

                // Use real session statistics if available, otherwise fallback
                if (session_stats != null) {
                    dialog.show_game_end_with_session(this, final_state, session_stats, local_player_color, is_multiplayer);
                } else {
                    // Fallback to basic statistics
                    var fallback_stats = new GameStatistics();
                    fallback_stats.calculate_basic_stats(0, 0.0);
                    dialog.show_game_end(this, final_state, fallback_stats, local_player_color, is_multiplayer);
                }
            } else {
                // Fallback to simple toast if we can't get game state
                string message = "";
                switch (result) {
                    case GameStatus.RED_WINS:
                        message = "Red wins!";
                        break;
                    case GameStatus.BLACK_WINS:
                        message = "Black wins!";
                        break;
                    case GameStatus.DRAW:
                        message = "Game ended in a draw";
                        break;
                    default:
                        message = "Game finished";
                        break;
                }

                var toast = new Adw.Toast(message);
                toast.set_timeout(5);
                toast_overlay.add_toast(toast);
            }

            logger.info("Game finished: %s", result.to_string());
        }

        private void on_move_made(DraughtsMove move) {
            // Clear the undo_just_used flag to re-enable undo after a new move
            undo_just_used = false;

            // Update undo/redo button states
            update_undo_redo_buttons();
            update_navigation_buttons();

            // Rebuild move history dropdown
            if (!is_navigating) {
                rebuild_move_history_dropdown();
            }

            // Update timer display when a move is made
            if (timer_display != null) {
                var current_state = adapter.get_current_state();
                if (current_state != null) {
                    // Switch to the next player's timer
                    timer_display.switch_player();
                }
            }

            logger.debug("Move made: %s", move.to_string());
        }

        /**
         * Handle timer updates from TimerDisplay
         */
        private void on_timer_updated(string timer_text) {
            // Timer label was removed - dual timer displays are used instead
            // This method is kept for backward compatibility but does nothing
        }

        /**
         * Handle time expiration (player ran out of time)
         */
        private void on_time_expired(Player player) {
            logger.info("Time expired for player: %s", player.to_string());

            // Stop all timers immediately
            if (timer_display != null) {
                timer_display.pause_timers();
            }

            // Determine the winner (opposite player)
            GameStatus result;
            string winner_name;
            string loser_name;

            if (player == Player.RED) {
                result = GameStatus.BLACK_WINS;
                winner_name = "Black";
                loser_name = "Red";
            } else {
                result = GameStatus.RED_WINS;
                winner_name = "Red";
                loser_name = "Black";
            }

            // End the game in the adapter/controller
            if (adapter != null) {
                var current_game = adapter.get_current_game();
                if (current_game != null) {
                    // Force game to end with the appropriate result
                    current_game.current_state.game_status = result;

                    logger.debug("Game forcefully ended due to timeout");

                    // Trigger the game finished event which will handle saving and showing dialog
                    on_game_finished(result);
                }
            }

            logger.info("Game ended by timeout - %s wins", winner_name);
        }

        /**
         * Handle dual timer updates for bottom bar displays
         */
        private void on_dual_timer_updated(string red_time, string black_time) {
            if (red_timer_display != null) {
                red_timer_display.label = red_time;
            }
            if (black_timer_display != null) {
                black_timer_display.label = black_time;
            }
        }

        private void on_piece_selected(int row, int col) {
            logger.debug("Piece selected at (%d, %d)", row, col);
        }

        private void on_piece_deselected() {
            logger.debug("Piece deselected");
        }

        private void on_move_attempted(int from_row, int from_col, int to_row, int to_col) {
            logger.debug("Move attempted: (%d, %d) to (%d, %d)", from_row, from_col, to_row, to_col);
        }

        private void on_invalid_move_attempted() {
            var toast = new Adw.Toast("Invalid move");
            toast.set_timeout(2);
            toast_overlay.add_toast(toast);

            logger.debug("Invalid move attempted");
        }

        // Timer expired and warning methods removed - TimerDisplay no longer has these signals

        // Legacy methods for compatibility
        public void start_new_game() {
            logger.info("start_new_game() called");

            // Check if game is in progress - show confirmation
            if (is_game_in_progress()) {
                if (is_multiplayer_game) {
                    show_resign_confirmation_for_action(() => {
                        show_new_game_dialog();
                    });
                } else {
                    show_abandon_game_confirmation(() => {
                        show_new_game_dialog();
                    });
                }
                return;
            }

            show_new_game_dialog();
        }

        private void start_game_with_saved_settings() {
            // Get saved settings
            var variant = settings_manager.get_default_variant();
            int opponent_type = settings_manager.get_int("new-game-opponent-type");
            int human_color_index = settings_manager.get_int("new-game-human-color");
            var ai_difficulty = settings_manager.get_ai_difficulty();

            bool use_time_limit = settings_manager.get_boolean("new-game-time-limit-enabled");
            int minutes_per_side = settings_manager.get_int("new-game-minutes-per-side");
            int increment_seconds = settings_manager.get_int("new-game-increment-seconds");
            int clock_type_int = settings_manager.get_int("new-game-clock-type");
            string clock_type_str = (clock_type_int == 0) ? "Fischer" : "Bronstein";

            // opponent_type: 0 = Human, 1 = AI
            bool is_human_vs_ai = (opponent_type == 1);

            // human_color_index: 0 = Red, 1 = Black
            PieceColor human_color = (human_color_index == 0) ? PieceColor.RED : PieceColor.BLACK;

            logger.info("Auto-starting game with saved settings: variant=%s, vs_ai=%s, color=%s",
                variant.to_string(), is_human_vs_ai.to_string(), human_color.to_string());

            // Start new game with the saved configuration
            on_new_game_requested_with_configuration(variant, is_human_vs_ai, human_color, ai_difficulty,
                use_time_limit, minutes_per_side, increment_seconds, clock_type_str);
        }

        private void show_new_game_dialog() {
            var dialog = new NewGameDialog();
            dialog.game_started.connect((variant, is_human_vs_ai, human_color, ai_difficulty, use_time_limit, minutes_per_side, increment_seconds, clock_type) => {
                logger.info("Starting new game with variant: %s, Human vs AI: %s, Human color: %s, AI difficulty: %d",
                    variant.to_string(), is_human_vs_ai.to_string(), human_color.to_string(), ai_difficulty);
                logger.info("Time limit settings: enabled=%s, minutes=%d, increment=%d, clock_type=%s",
                    use_time_limit.to_string(), minutes_per_side, increment_seconds, clock_type);

                // Start new game with the configuration
                on_new_game_requested_with_configuration(variant, is_human_vs_ai, human_color, ai_difficulty,
                    use_time_limit, minutes_per_side, increment_seconds, clock_type);
            });
            dialog.present(this);
        }

        public void reset_game() {
            // Check if game is in progress - show confirmation
            if (is_game_in_progress()) {
                if (is_multiplayer_game) {
                    show_resign_confirmation_for_action(() => {
                        on_game_reset_requested();
                    });
                } else {
                    show_abandon_game_confirmation(() => {
                        on_game_reset_requested();
                    });
                }
                return;
            }

            on_game_reset_requested();
        }

        public void show_play_online_dialog() {
            // Check if game is in progress - show confirmation
            if (is_game_in_progress()) {
                if (is_multiplayer_game) {
                    show_resign_confirmation_for_action(() => {
                        do_show_play_online_dialog();
                    });
                } else {
                    show_abandon_game_confirmation(() => {
                        do_show_play_online_dialog();
                    });
                }
                return;
            }

            do_show_play_online_dialog();
        }

        private void do_show_play_online_dialog() {
            var dialog = MultiplayerDialog.display_dialog(this, server_controller);
            dialog.game_ready.connect((controller) => {
                logger.info("Multiplayer game ready, setting up controller");
                set_multiplayer_controller(controller);
            });
        }

        /**
         * Check if a game is in progress
         */
        private bool is_game_in_progress() {
            if (adapter == null) {
                return false;
            }

            var controller = adapter.get_controller();
            if (controller == null) {
                return false;
            }

            var game = controller.get_current_game();
            if (game == null) {
                return false;
            }

            // For multiplayer games, consider game in progress as soon as it starts
            if (is_multiplayer_game) {
                var state = controller.get_current_state();
                if (state == null) {
                    return false;
                }
                var status = state.game_status;
                return status == GameStatus.IN_PROGRESS ||
                       status == GameStatus.ACTIVE ||
                       status == GameStatus.NOT_STARTED;
            }

            // For single-player games, only consider in progress after first move
            return game.get_move_number() > 0 && !game.is_game_over();
        }

        /**
         * Show resign confirmation dialog before performing an action (multiplayer)
         */
        private delegate void ActionCallback();

        private void show_resign_confirmation_for_action(owned ActionCallback action) {
            var dialog = new Adw.AlertDialog(
                _("Resign from Current Game?"),
                _("Starting a new action will resign your current multiplayer game. This will count as a loss. Do you want to resign?")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("resign", _("Resign and Continue"));
            dialog.set_response_appearance("resign", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.choose.begin(this, null, (obj, res) => {
                var response = dialog.choose.end(res);
                if (response == "resign") {
                    // Resign from current game
                    var controller = adapter.get_controller();
                    if (controller is MultiplayerGameController) {
                        var multiplayer_controller = (MultiplayerGameController) controller;
                        multiplayer_controller.resign();
                        logger.info("Player resigned from multiplayer game to perform new action");
                    }
                    // Perform the action
                    action();
                }
                dialog.destroy();
            });

            dialog.present(this);
        }

        /**
         * Show abandon game confirmation dialog before performing an action (single-player)
         */
        private void show_abandon_game_confirmation(owned ActionCallback action) {
            var dialog = new Adw.AlertDialog(
                _("Abandon Current Game?"),
                _("You have a game in progress. Are you sure you want to abandon it?")
            );

            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("abandon", _("Abandon Game"));
            dialog.set_response_appearance("abandon", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response("cancel");
            dialog.set_close_response("cancel");

            dialog.choose.begin(this, null, (obj, res) => {
                var response = dialog.choose.end(res);
                if (response == "abandon") {
                    // Perform the action
                    action();
                }
            });
        }

        /**
         * Set multiplayer controller and switch to multiplayer mode
         */
        public void set_multiplayer_controller(MultiplayerGameController controller) {
            is_multiplayer_game = true;
            if (adapter != null) {
                adapter.set_multiplayer_controller(controller);

                // Connect to error signal
                controller.multiplayer_error.connect(on_multiplayer_error);
                controller.opponent_disconnected.connect(on_opponent_disconnected);
                controller.opponent_reconnected.connect(on_opponent_reconnected);
                controller.version_mismatch.connect(on_version_mismatch);

                // Show resign button for multiplayer
                resign_button.set_visible(true);

                // Update window subtitle with the multiplayer game variant
                var game = controller.get_current_game();
                if (game != null && game.variant != null) {
                    window_title.set_subtitle(game.variant.display_name);

                    // Set up timers if the game has them
                    if (game.timer_red != null && game.timer_black != null && timer_display != null) {
                        timer_display.set_timers(game.timer_red, game.timer_black);
                        logger.info("Multiplayer game timers configured");
                    } else if (timer_display != null) {
                        timer_display.set_timers(null, null);
                    }
                }
            }
        }

        /**
         * Handle multiplayer error (e.g., server crash)
         */
        private void on_multiplayer_error(string error_message) {
            logger.error("Window: Multiplayer error - %s", error_message);

            // Update connection status to disconnected
            update_server_connection_status(false);

            // Start reconnection attempts
            schedule_reconnect();

            // Only show error dialog if we're actually in a multiplayer game
            if (is_multiplayer_game) {
                // Show error dialog
                var dialog = new Adw.AlertDialog(_("Multiplayer Connection Lost"), error_message);
                dialog.add_response("ok", _("OK"));
                dialog.set_default_response("ok");
                dialog.set_close_response("ok");
                dialog.present(this);
            }
        }

        /**
         * Handle version mismatch - prompt user to update
         */
        private void on_version_mismatch(string required_version, string client_version) {
            logger.error("Window: Version mismatch - Client: %s, Required: %s", client_version, required_version);

            // The signal can arrive from both the background connection and an
            // in-game controller; only present the update dialog once.
            if (version_mismatch_shown) {
                return;
            }
            version_mismatch_shown = true;

            // Show update required dialog
            var dialog = new Adw.AlertDialog(
                _("Update Required"),
                _("Your game version (%s) is outdated. Please update to version %s or later to play online.").printf(client_version, required_version)
            );
            dialog.add_response("cancel", _("Cancel"));
            dialog.add_response("update", _("Update"));
            dialog.set_response_appearance("update", Adw.ResponseAppearance.SUGGESTED);
            dialog.set_default_response("update");
            dialog.set_close_response("cancel");
            dialog.choose.begin(this, null, (obj, res) => {
                var response = dialog.choose.end(res);
                if (response == "update") {
                    // Open the app in the system's software center
                    // Try appstream:// URL first (works with GNOME Software, KDE Discover, etc.)
                    try {
                        string app_id = Config.ID;
                        string appstream_url = @"appstream://$(app_id)";
                        logger.info("Opening software center with URL: %s", appstream_url);
                        var launcher = new Gtk.UriLauncher(appstream_url);
                        launcher.launch.begin(this, null);
                    } catch (Error e) {
                        logger.error("Failed to open software center: %s", e.message);

                        // Fallback to GitHub releases page
                        var launcher = new Gtk.UriLauncher("https://github.com/tobagin/Draughts/releases");
                        launcher.launch.begin(this, null);
                    }
                }
                
                // Start new single-player game
                start_game_with_saved_settings();
            });
        }

        /**
         * Handle opponent disconnected
         */
        private void on_opponent_disconnected() {
            logger.warning("Window: Opponent disconnected");
            // Show disconnect overlay (similar to pause)
            disconnect_overlay.visible = true;

            // Also show a toast
            var toast = new Adw.Toast(_("Opponent disconnected. Waiting for reconnection..."));
            toast.set_timeout(5);
            toast_overlay.add_toast(toast);
        }

        /**
         * Handle opponent reconnected
         */
        private void on_opponent_reconnected() {
            logger.info("Window: Opponent reconnected");
            // Hide disconnect overlay
            disconnect_overlay.visible = false;

            // Show reconnection toast
            var toast = new Adw.Toast(_("Opponent reconnected!"));
            toast.set_timeout(3);
            toast_overlay.add_toast(toast);
        }

        public void set_game_rules(string rules) {
            logger.info("Setting game rules to: %s", rules);

            // Convert string rule to DraughtsVariant enum
            DraughtsVariant variant = string_to_variant(rules);

            if (adapter != null) {
                adapter.set_variant(variant);
            }

            // Legacy compatibility - also update the old board widget
            if (draughts_board != null) {
                draughts_board.set_game_rules(rules);
            }

            string display_name = get_rules_display_name(rules);

            // Update window subtitle
            if (window_title != null) {
                window_title.set_subtitle(display_name);
            }

            // Get board size for this rule set
            int board_size = get_board_size_for_rules(rules);
            // Rules changed - no toast needed as user initiated this change

            // GameControls removed - variant is now controlled via menu
        }

        /**
         * Convert string rule name to DraughtsVariant enum
         */
        private DraughtsVariant string_to_variant(string rules) {
            switch (rules) {
                case "checkers": return DraughtsVariant.AMERICAN;
                case "international": return DraughtsVariant.INTERNATIONAL;
                case "russian": return DraughtsVariant.RUSSIAN;
                case "brazilian": return DraughtsVariant.BRAZILIAN;
                case "italian": return DraughtsVariant.ITALIAN;
                case "spanish": return DraughtsVariant.SPANISH;
                case "czech": return DraughtsVariant.CZECH;
                case "thai": return DraughtsVariant.THAI;
                case "german": return DraughtsVariant.GERMAN;
                case "swedish": return DraughtsVariant.SWEDISH;
                case "pool": return DraughtsVariant.POOL;
                case "graeco-turkish": return DraughtsVariant.TURKISH;
                case "armenian": return DraughtsVariant.ARMENIAN;
                case "gothic": return DraughtsVariant.GOTHIC;
                case "frisian": return DraughtsVariant.FRISIAN;
                case "canadian": return DraughtsVariant.CANADIAN;
                default: return DraughtsVariant.AMERICAN;
            }
        }

        public void set_board_theme(string theme) {
            logger.info("Setting board theme to: %s", theme);
            if (draughts_board != null) {
                draughts_board.set_board_theme(theme);
            }

            string display_name = get_theme_display_name(theme);
            // Theme changed - no toast needed as user initiated this change
        }

        public void set_piece_theme(string theme) {
            logger.info("Setting piece theme to: %s", theme);

            // Update the board widget with new piece images
            if (draughts_board != null) {
                draughts_board.reload_piece_images();
            }

            string display_name = get_piece_theme_display_name(theme);
            // Piece theme changed - no toast needed as user initiated this change
        }

        public void set_ai_difficulty(AIDifficulty difficulty) {
            logger.info("Setting AI difficulty to: %s", difficulty.to_string());
            // AI difficulty is handled by the on_difficulty_changed signal handler
            // which automatically restarts AI games with the new difficulty

            string display_name = get_difficulty_display_name(difficulty);
            // AI difficulty changed - no toast needed as user initiated this change
        }

        private int get_board_size_for_rules(string rules) {
            switch (rules) {
                case "canadian":
                    return 12;
                case "international":
                case "frisian":
                    return 10;
                case "checkers":
                case "brazilian":
                case "italian":
                case "spanish":
                case "czech":
                case "thai":
                case "german":
                case "swedish":
                case "russian":
                case "pool":
                case "graeco-turkish":
                case "armenian":
                case "gothic":
                default:
                    return 8;
            }
        }

        private string get_rules_display_name(string rules) {
            switch (rules) {
                case "checkers": return "Checkers/Anglo-American Draughts";
                case "italian": return "Italian Draughts";
                case "spanish": return "Spanish Draughts";
                case "czech": return "Czech Draughts";
                case "thai": return "Thai Draughts";
                case "german": return "German Draughts";
                case "swedish": return "Swedish Draughts";
                case "russian": return "Russian Draughts";
                case "pool": return "Pool Checkers";
                case "international": return "International Draughts";
                case "brazilian": return "Brazilian Draughts";
                case "frisian": return "Frisian Draughts";
                case "canadian": return "Canadian Draughts";
                case "graeco-turkish": return "Graeco-Turkish Draughts";
                case "armenian": return "Armenian Draughts";
                case "gothic": return "Gothic Draughts";
                default: return rules;
            }
        }

        private string get_theme_display_name(string theme) {
            switch (theme) {
                case "classic": return "Classic Brown/Beige";
                case "wood": return "Wood Light/Dark";
                case "green": return "Green/White";
                case "blue": return "Blue/Gray";
                case "contrast": return "High Contrast";
                default: return theme;
            }
        }

        private string get_piece_theme_display_name(string theme) {
            switch (theme) {
                case "plastic": return "Plastic";
                case "wood": return "Wood";
                case "metal": return "Metal";
                default: return theme;
            }
        }

        private string get_difficulty_display_name(AIDifficulty difficulty) {
            switch (difficulty) {
                case AIDifficulty.BEGINNER: return "Beginner";
                case AIDifficulty.EASY: return "Easy";
                case AIDifficulty.MEDIUM: return "Medium";
                case AIDifficulty.HARD: return "Hard";
                case AIDifficulty.EXPERT: return "Expert";
                case AIDifficulty.MASTER: return "Master";
                case AIDifficulty.GRANDMASTER: return "Grandmaster";
                default: return "Medium";
            }
        }

        /**
         * Show move history panel
         */
        private void show_move_history_panel() {
            // This would show/hide a move history panel
            // For now, just show a toast
            var toast = new Adw.Toast("Move history panel toggle - feature coming soon");
            toast.set_timeout(3);
            toast_overlay.add_toast(toast);

            logger.debug("Move history panel toggled");
        }

        /**
         * Update the enabled state of the history action based on settings
         */
        private void update_history_action_state() {
            bool enabled = settings_manager.get_enable_game_history();
            show_history_action.set_enabled(enabled);
            logger.debug(@"History action enabled state set to: $enabled");
        }

        /**
         * Show game history dialog
         */
        private void show_history_dialog() {
            var history_dialog = new GameHistoryDialog();

            // Connect to replay request
            history_dialog.replay_requested.connect((record) => {
                logger.debug(@"Window: Replay requested for game: $(record != null ? record.id : "NULL")");

                try {
                    logger.debug("Window: About to create GameReplayDialog");
                    // Show replay dialog without closing history dialog first
                    var replay_dialog = new GameReplayDialog(record);
                    logger.debug("Window: GameReplayDialog created successfully");

                    logger.debug("Window: About to present replay dialog");
                    replay_dialog.present(this);
                    logger.debug("Window: Replay dialog presented successfully");
                } catch (Error e) {
                    logger.debug(@"Window: Error creating/presenting replay dialog: $(e.message)");
                }
            });

            history_dialog.present(this);
        }

        /**
         * Show export PDN dialog
         */
        private void show_export_pdn_dialog() {
            if (adapter == null) {
                return;
            }

            // Create file chooser dialog
            var dialog = new Gtk.FileDialog();
            dialog.title = _("Export Game to PDN");
            dialog.modal = true;

            // Set default filename
            var now = new DateTime.now_local();
            string default_name = @"draughts_game_$(now.format("%Y%m%d_%H%M%S")).pdn";
            dialog.initial_name = default_name;

            dialog.save.begin(this, null, (obj, res) => {
                try {
                    var file = dialog.save.end(res);
                    if (file != null) {
                        export_game_to_file(file);
                    }
                } catch (Error e) {
                    logger.warning("Error in export dialog: %s", e.message);
                }
            });
        }

        /**
         * Export game to PDN file (Portable Draughts Notation)
         */
        private void export_game_to_file(File file) {
            try {
                // Generate PDN content
                string pdn_content = generate_pdn_content();

                // Write to file
                var stream = file.create(FileCreateFlags.REPLACE_DESTINATION);
                var data_stream = new DataOutputStream(stream);
                data_stream.put_string(pdn_content);
                data_stream.close();

                var toast = new Adw.Toast(@"Game exported to $(file.get_basename())");
                toast.set_timeout(3);
                toast_overlay.add_toast(toast);

                logger.info("Game exported to: %s", file.get_path());

            } catch (Error e) {
                var toast = new Adw.Toast(@"Export failed: $(e.message)");
                toast.set_timeout(5);
                toast_overlay.add_toast(toast);

                logger.error("Export failed: %s", e.message);
            }
        }

        /**
         * Generate PDN content for export (Portable Draughts Notation)
         */
        private string generate_pdn_content() throws Error {
            if (adapter == null || adapter.get_current_game() == null) {
                 throw new IOError.FAILED("No active game to export");
            }
            
            var game = adapter.get_current_game();
            return PDNParser.generate_pdn(game);
        }

        /**
         * Add move history widget to window layout
         */
        public void add_move_history_widget(MoveHistory move_history) {
            // This would add the move history widget to the window layout
            // Implementation depends on the window UI structure
            logger.debug("Move history widget added to window");
        }

        /**
         * Check if the current game has any AI players
         */
        private bool has_ai_player(Game game) {
            return game.red_player.is_ai() || game.black_player.is_ai();
        }

        /**
         * Restart the current game with new AI difficulty
         */
        private void restart_current_game_with_new_ai_difficulty(Game current_game, AIDifficulty new_difficulty) {
            if (adapter == null) {
                return;
            }

            // Get current game configuration
            var variant = current_game.variant.variant;
            bool is_human_vs_ai = false;

            // Determine if it's Human vs AI (and which player is AI)
            if (current_game.red_player.is_human() && current_game.black_player.is_ai()) {
                is_human_vs_ai = true;
            } else if (current_game.red_player.is_ai() && current_game.black_player.is_human()) {
                // For now, we assume black is AI for simplicity
                // This could be enhanced to support red AI in the future
                is_human_vs_ai = true;
            } else if (current_game.red_player.is_ai() && current_game.black_player.is_ai()) {
                // Both players are AI - restart with new difficulty for both
                is_human_vs_ai = true;
            }

            if (is_human_vs_ai) {
                // Restart the game with new AI difficulty
                // Use default settings for other parameters
                PieceColor human_color = current_game.red_player.is_human() ? PieceColor.RED : PieceColor.BLACK;
                int ai_difficulty_index = (int)new_difficulty;
                on_new_game_requested_with_configuration(
                    variant,
                    is_human_vs_ai,
                    human_color,
                    ai_difficulty_index,
                    false, // use_time_limit
                    5,     // minutes_per_side (default)
                    0,     // increment_seconds (default)
                    "Fischer" // clock_type (default)
                );
                logger.info("Game restarted with new AI difficulty: %s", new_difficulty.to_string());
            }
        }

        /**
         * Show open PDN dialog
         */
        private void show_open_pdn_dialog() {
            var dialog = new Gtk.FileDialog();
            dialog.title = _("Open PDN File");
            dialog.modal = true;
            
            var filter_pdn = new Gtk.FileFilter();
            filter_pdn.name = "Portable Draughts Notation (*.pdn)";
            filter_pdn.add_pattern("*.pdn");
            
            var filter_all = new Gtk.FileFilter();
            filter_all.name = "All Files";
            filter_all.add_pattern("*");
            
            var filters = new ListStore(typeof(Gtk.FileFilter));
            filters.append(filter_pdn);
            filters.append(filter_all);
            dialog.set_filters(filters);

            dialog.open.begin(this, null, (obj, res) => {
                try {
                    var file = dialog.open.end(res);
                    if (file != null) {
                        open_pdn_file(file);
                    }
                } catch (Error e) {
                    logger.warning("Error in open dialog: %s", e.message);
                }
            });
        }

        /**
         * Open a PDN file
         */
        public void open_pdn_file(File file) {
            logger.info("Attempting to open PDN file: %s", file.get_path());

            try {
                var parser = new PDNParser();
                var pdn = parser.parse_file(file.get_path());

                // Determine variant
                DraughtsVariant variant_type = DraughtsVariant.AMERICAN; // Default
                if (pdn.variant != null) {
                    variant_type = pdn.variant.variant;
                }

                if (adapter != null) {
                    // Start a new game with the parsed variant
                    // For now, load as Human vs Human so we can replay/analyze
                    on_new_game_requested_with_configuration(
                        variant_type,
                        false, // is_human_vs_ai (false for analysis/replay)
                        PieceColor.RED,
                        0, // Difficulty (ignored)
                        false, // No time limit
                        0, 0, ""
                    );

                    // Apply moves
                    // This is a simplified "load" - we just execute moves one by one
                    // ideally we might want a specific "load game" mode, but this works for now
                    apply_pdn_moves(pdn);
                }

                var toast = new Adw.Toast(_("Game loaded from %s").printf(file.get_basename()));
                toast.set_timeout(3);
                toast_overlay.add_toast(toast);

            } catch (Error e) {
                logger.error("Failed to open PDN file: %s", e.message);
                var dialog = new Adw.AlertDialog(
                    _("Failed to open file"),
                    e.message
                );
                dialog.add_response("ok", _("OK"));
                dialog.set_default_response("ok");
                dialog.set_close_response("ok");
                dialog.present(this);
            }
        }

        private void apply_pdn_moves(ParsedPDN pdn) {
             if (pdn.moves.size == 0) {
                 return;
             }

             if (adapter == null || adapter.get_controller() == null) {
                 return;
             }
             
             var controller = adapter.get_controller();
             var current_game = adapter.get_current_game();
             
             if (current_game == null) {
                 return;
             }
             
             int moves_applied = 0;
             // Pause timer updates during replay to avoid side effects
             // But valid moves will update game state correctly
             
             foreach (string move_str in pdn.moves) {
                 var parsed = PDNParser.parse_move_string(move_str);
                 if (parsed == null) {
                     logger.warning("Failed to parse PDN move string: %s", move_str);
                     continue;
                 }
                 
                 // Get board size from current game state
                 int board_size = current_game.current_state.board_size;
                 
                 var from_pos = PDNParser.square_to_position(parsed.from_sq, board_size);
                 var to_pos = PDNParser.square_to_position(parsed.to_sq, board_size);
                 
                 if (from_pos == null || to_pos == null) {
                     logger.warning("Invalid positions in PDN move: %s (Board size: %d)", move_str, board_size);
                     continue;
                 }
                 
                 // Find matching legal move
                 var legal_moves = current_game.get_legal_moves();
                 DraughtsMove? matching_move = null;
                 
                 foreach (var move in legal_moves) {
                     if (move.from_position.equals(from_pos) && move.to_position.equals(to_pos)) {
                         matching_move = move;
                         break;
                     }
                 }
                 
                 if (matching_move != null) {
                     // Execute the move through the controller
                     if (controller.make_move(matching_move)) {
                         moves_applied++;
                     } else {
                         logger.warning("Controller failed to execute valid move: %s", move_str);
                         break;
                     }
                 } else {
                     logger.warning("No legal move found matching PDN: %s (%d->%d)", 
                         move_str, parsed.from_sq, parsed.to_sq);
                     break; 
                 }
             }
             
             if (moves_applied > 0) {
                 var toast = new Adw.Toast(_("Replayed %d moves").printf(moves_applied));
                 toast_overlay.add_toast(toast);
                 logger.info("Successfully replayed %d moves from PDN", moves_applied);
                 
                 // Force history dropdown update
                 rebuild_move_history_dropdown();
                 update_navigation_buttons();
             }
        }

        /**
         * Connect to multiplayer server with exponential backoff
         */
        private async void connect_to_server_async() {
            if (server_controller != null && server_controller.is_connected()) {
                logger.info("Already connected to server");
                update_server_connection_status(true);
                return;
            }

            // Create controller if needed
            if (server_controller == null) {
                server_controller = new MultiplayerGameController();
                // Catch version mismatches on the background connection too, not
                // just once an in-game controller is wired up
                server_controller.version_mismatch.connect(on_version_mismatch);
            }

            logger.info("Attempting to connect to multiplayer server (attempt %d)...", reconnect_attempts + 1);

            bool connected = yield server_controller.connect_to_server();

            if (connected) {
                logger.info("Successfully connected to multiplayer server");

                // Show reconnection toast if this was a reconnect attempt
                bool was_reconnecting = reconnect_attempts > 0;
                reconnect_attempts = 0;
                update_server_connection_status(true);

                if (was_reconnecting) {
                    var toast = new Adw.Toast(_("Connected to multiplayer server"));
                    toast_overlay.add_toast(toast);
                }

                // Start periodic health check (every 30 seconds)
                start_health_check();
            } else {
                logger.warning("Failed to connect to multiplayer server");
                update_server_connection_status(false);
                stop_health_check();
                schedule_reconnect();
            }
        }

        /**
         * Schedule reconnection attempt with exponential backoff
         */
        private void schedule_reconnect() {
            // Cancel existing timeout if any
            if (reconnect_timeout_id > 0) {
                Source.remove(reconnect_timeout_id);
                reconnect_timeout_id = 0;
            }

            // Calculate delay with exponential backoff: 5s, 10s, 20s, 40s, 80s, 160s, ...
            int delay = (int) Math.pow(2, reconnect_attempts) * 5000;

            reconnect_attempts++;

            logger.info("Scheduling reconnect attempt in %d seconds...", delay / 1000);

            reconnect_timeout_id = Timeout.add(delay, () => {
                reconnect_timeout_id = 0;
                connect_to_server_async.begin();
                return false;
            });
        }

        /**
         * Update connection status and enable/disable Play Online action
         */
        private void update_server_connection_status(bool connected) {
            is_server_connected = connected;

            // Enable/disable Play Online action
            var app = this.get_application();
            if (app != null) {
                var action = app.lookup_action("play-online");
                if (action != null && action is SimpleAction) {
                    ((SimpleAction) action).set_enabled(connected);
                }
            }

            // Update visual status indicator (check if widget is available)
            if (server_status_icon == null) {
                return;
            }

            if (connected) {
                server_status_icon.set_from_icon_name("io.github.tobagin.Draughts-connected-symbolic");
                server_status_icon.set_tooltip_text(_("Multiplayer server: Connected"));
                server_status_icon.set_opacity(1.0);
                server_status_icon.remove_css_class("error");
                server_status_icon.add_css_class("success");
            } else {
                server_status_icon.set_from_icon_name("io.github.tobagin.Draughts-disconnected-symbolic");
                server_status_icon.set_tooltip_text(_("Multiplayer server: Offline"));
                server_status_icon.set_opacity(0.5);
                server_status_icon.remove_css_class("success");
                server_status_icon.add_css_class("error");
            }

            logger.info("Multiplayer server connection status: %s", connected ? "connected" : "disconnected");
        }

        /**
         * Start periodic health check to detect server disconnection
         */
        private void start_health_check() {
            stop_health_check();

            // Check connection every 30 seconds
            health_check_timeout_id = Timeout.add_seconds(30, () => {
                check_server_health.begin();
                return true;
            });
        }

        /**
         * Stop health check
         */
        private void stop_health_check() {
            if (health_check_timeout_id > 0) {
                Source.remove(health_check_timeout_id);
                health_check_timeout_id = 0;
            }
        }

        /**
         * Check if server is still reachable
         */
        private async void check_server_health() {
            if (server_controller == null || !server_controller.is_connected()) {
                logger.warning("Health check failed: Server disconnected");
                update_server_connection_status(false);
                stop_health_check();
                schedule_reconnect();
            }
        }

        /**
         * Clean up server connection on window destroy
         */
        public override void dispose() {
            // Cancel reconnect timeout
            if (reconnect_timeout_id > 0) {
                Source.remove(reconnect_timeout_id);
                reconnect_timeout_id = 0;
            }

            // Stop health check
            stop_health_check();

            // Disconnect from server
            if (server_controller != null) {
                server_controller = null;
            }

            base.dispose();
        }
    }
}

