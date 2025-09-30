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
        private unowned Gtk.MenuButton menu_button;

        [GtkChild]
        private unowned Adw.ToastOverlay toast_overlay;

        [GtkChild]
        private unowned Gtk.Box board_container;



        [GtkChild]
        private unowned Gtk.Button undo_button;

        [GtkChild]
        private unowned Gtk.Button redo_button;

        private DraughtsBoard draughts_board;
        private DraughtsBoardAdapter adapter;
        private BoardRenderer renderer;
        private BoardInteractionHandler interaction_handler;
        private TimerDisplay timer_display;
        private SimpleAction show_history_action;

        private Logger logger;
        private SettingsManager settings_manager;

        public Window(Gtk.Application app) {
            Object(application: app);

            logger = Logger.get_default();
            settings_manager = SettingsManager.get_instance();
            set_default_size(900, 700);
            set_size_request(600, 400);
            setup_actions();
            load_css();
            setup_board();
            setup_game_components();
            initialize_window_subtitle();

            // Ensure template widgets are accessible (suppresses unused warnings)
            assert(header_bar != null);
            assert(window_title != null);
            assert(menu_button != null);
            assert(toast_overlay != null);
            assert(board_container != null);
            assert(undo_button != null);
            assert(redo_button != null);

            // Start a new game automatically after initialization
            // Use a delay to ensure widgets are fully realized and sized
            Timeout.add(200, () => {
                start_new_game();

                // Note: rescale_all_pieces was removed during button-to-canvas refactor
                // Pieces now scale automatically via DrawingArea

                return false;
            });

            logger.info("Window created and initialized");
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

            var undo_move_action = new SimpleAction("undo-move", null);
            undo_move_action.activate.connect(() => {
                if (adapter != null) {
                    adapter.undo_last_move();
                }
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
            var export_pgn_action = new SimpleAction("export-pgn", null);
            export_pgn_action.activate.connect(() => {
                show_export_pgn_dialog();
            });
            add_action(export_pgn_action);

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
            interaction_handler = new BoardInteractionHandler(adapter, renderer, draughts_board);

            // Create UI controls
            timer_display = new TimerDisplay();

            // Connect timer to window subtitle
            timer_display.timer_updated.connect(on_timer_updated);

            // Connect signals
            setup_game_signals();

            // Connect undo/redo buttons
            undo_button.clicked.connect(on_undo_requested);
            redo_button.clicked.connect(on_redo_requested);

            // Initialize button states
            update_undo_redo_buttons();

            logger.debug("Comprehensive game components initialized");
        }

        private void setup_game_signals() {
            // Adapter signals
            adapter.game_state_changed.connect(on_game_state_changed);
            adapter.game_finished.connect(on_game_finished);
            adapter.move_made.connect(on_move_made);

            // Interaction handler signals
            interaction_handler.piece_selected.connect(on_piece_selected);
            interaction_handler.piece_deselected.connect(on_piece_deselected);
            interaction_handler.move_attempted.connect(on_move_attempted);
            interaction_handler.invalid_move_attempted.connect(on_invalid_move_attempted);

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

                // Update undo/redo button states (should be disabled for new game)
                update_undo_redo_buttons();

                // Note: Toast notifications for new game start have been disabled to avoid
                // showing toasts during replay setup and other automated game starts
                // User feedback is provided through UI state changes instead

                logger.info("New game started with variant: %s", variant.to_string());
            }
        }

        private void on_new_game_requested_with_mode(DraughtsVariant variant, bool is_human_vs_ai) {
            if (adapter != null) {
                adapter.start_new_game_with_mode(variant, is_human_vs_ai);
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

                var toast = new Adw.Toast("Game reset");
                toast.set_timeout(2);
                toast_overlay.add_toast(toast);

                logger.info("Game reset");
            }
        }

        private void on_undo_requested() {
            if (adapter != null && adapter.undo_last_move()) {
                // Move undone - no toast needed, visual board update is sufficient

                logger.info("Move undone");
                update_undo_redo_buttons();
            }
        }

        private void on_redo_requested() {
            if (adapter != null && adapter.redo_last_move()) {
                // Move redone - no toast needed, visual board update is sufficient

                logger.info("Move redone");
                update_undo_redo_buttons();
            }
        }

        private void update_undo_redo_buttons() {
            if (adapter != null) {
                undo_button.set_sensitive(adapter.can_undo());
                redo_button.set_sensitive(adapter.can_redo());
            } else {
                undo_button.set_sensitive(false);
                redo_button.set_sensitive(false);
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
            // Update timer display based on active player
            if (timer_display != null) {
                // Convert PieceColor to Player for timer display
                var player = (new_state.active_player == PieceColor.RED) ? Player.RED : Player.BLACK;
                timer_display.set_active_player(player);
            }

            logger.debug("Game state changed, active player: %s", new_state.active_player.to_string());
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

                // Connect to dialog responses
                dialog.response.connect((response) => {
                    if (response == "new_game") {
                        start_new_game();
                    }
                    // "close" response just closes the dialog
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
                    dialog.show_game_end_with_session(this, final_state, session_stats);
                } else {
                    // Fallback to basic statistics
                    var fallback_stats = new GameStatistics();
                    fallback_stats.calculate_basic_stats(0, 0.0);
                    dialog.show_game_end(this, final_state, fallback_stats);
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
            // Update undo/redo button states
            update_undo_redo_buttons();

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
            if (window_title != null) {
                if (timer_text == "") {
                    // No timer - show game variant as subtitle
                    initialize_window_subtitle();
                } else {
                    // Show timer in subtitle
                    window_title.set_subtitle(timer_text);
                }
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
            show_new_game_dialog();
        }

        private void show_new_game_dialog() {
            var dialog = new NewGameDialog();
            dialog.game_mode_selected.connect((is_human_vs_ai) => {
                // Get the currently selected variant from settings
                var settings_manager = SettingsManager.get_instance();
                var variant = settings_manager.get_default_variant();
                logger.info("Starting new game with variant: %s, Human vs AI: %s", variant.to_string(), is_human_vs_ai.to_string());
                on_new_game_requested_with_mode(variant, is_human_vs_ai);
            });
            dialog.present(this);
        }

        public void reset_game() {
            on_game_reset_requested();
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
         * Show export PGN dialog
         */
        private void show_export_pgn_dialog() {
            if (adapter == null) {
                return;
            }

            // Create file chooser dialog
            var dialog = new Gtk.FileDialog();
            dialog.title = "Export Game to PDN";
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
         * PDN uses numeric square notation, e.g., "32-28" or "32x23"
         */
        private string generate_pdn_content() {
            var pdn = new StringBuilder();

            // PDN headers (standard PDN format)
            pdn.append_printf("[Event \"Draughts Game\"]\n");
            pdn.append_printf("[Date \"%s\"]\n", new DateTime.now_local().format("%Y.%m.%d"));
            pdn.append_printf("[White \"Player 1\"]\n");  // PDN uses White/Black, not Red/Black
            pdn.append_printf("[Black \"Player 2\"]\n");

            if (adapter != null) {
                var current_state = adapter.get_current_state();
                if (current_state != null) {
                    // Add variant information
                    var variant = adapter.get_current_variant();
                    if (variant != null) {
                        pdn.append_printf("[GameType \"%s\"]\n", get_pdn_game_type(variant));
                    }

                    // Add result
                    if (current_state.is_game_over()) {
                        switch (current_state.game_status) {
                            case GameStatus.RED_WINS:
                                pdn.append_printf("[Result \"2-0\"]\n");  // PDN uses 2-0 for White win
                                break;
                            case GameStatus.BLACK_WINS:
                                pdn.append_printf("[Result \"0-2\"]\n");  // PDN uses 0-2 for Black win
                                break;
                            case GameStatus.DRAW:
                                pdn.append_printf("[Result \"1-1\"]\n");  // PDN uses 1-1 for draws
                                break;
                            default:
                                pdn.append_printf("[Result \"*\"]\n");
                                break;
                        }
                    } else {
                        pdn.append_printf("[Result \"*\"]\n");
                    }
                }
            }

            pdn.append_printf("\n");

            // Add move history in PDN numeric notation
            if (adapter != null) {
                var current_game = adapter.get_current_game();
                if (current_game != null) {
                    var moves = current_game.get_move_history();
                    if (moves.length > 0) {
                        int move_number = 1;
                        var line = new StringBuilder();
                        int board_size = current_game.current_state.board_size;

                        for (int i = 0; i < moves.length; i++) {
                            var move = moves[i];

                            // Add move number for white's move
                            if (i % 2 == 0) {
                                if (line.len > 0) {
                                    pdn.append_printf("%s\n", line.str);
                                    line = new StringBuilder();
                                }
                                line.append_printf("%d. ", move_number);
                            }

                            // Format move in PDN numeric notation
                            string move_str = format_move_for_pdn(move, board_size);
                            line.append(move_str);
                            line.append(" ");

                            // Increment move number after black's move
                            if (i % 2 == 1) {
                                move_number++;
                            }
                        }

                        // Add final line if not empty
                        if (line.len > 0) {
                            pdn.append_printf("%s", line.str);
                        }

                        // Add result indicator at end
                        var final_state = adapter.get_current_state();
                        if (final_state != null && final_state.is_game_over()) {
                            switch (final_state.game_status) {
                                case GameStatus.RED_WINS:
                                    pdn.append_printf(" 2-0\n");
                                    break;
                                case GameStatus.BLACK_WINS:
                                    pdn.append_printf(" 0-2\n");
                                    break;
                                case GameStatus.DRAW:
                                    pdn.append_printf(" 1-1\n");
                                    break;
                                default:
                                    pdn.append_printf(" *\n");
                                    break;
                            }
                        } else {
                            pdn.append_printf(" *\n");
                        }
                    } else {
                        pdn.append_printf("* No moves made yet *\n");
                    }
                } else {
                    pdn.append_printf("* Game data not available *\n");
                }
            } else {
                pdn.append_printf("* Game data not available *\n");
            }

            return pdn.str;
        }

        /**
         * Format a move for PDN notation using numeric squares
         * PDN uses square numbers where playable squares are numbered
         * from 1 to N (typically 1-50 for International, 1-32 for American)
         */
        private string format_move_for_pdn(DraughtsMove move, int board_size) {
            int from_square = position_to_pdn_square(move.from_position, board_size);
            int to_square = position_to_pdn_square(move.to_position, board_size);

            // Use 'x' for captures, '-' for regular moves
            string separator = move.is_capture() ? "x" : "-";

            return @"$(from_square)$(separator)$(to_square)";
        }

        /**
         * Convert board position to PDN square number
         * PDN numbers only the playable (dark) squares from 1 to N
         * Numbering starts from the bottom-left from White's perspective
         */
        private int position_to_pdn_square(BoardPosition pos, int board_size) {
            // For standard draughts, only dark squares are numbered
            // The numbering depends on the board size and starts from row 0

            int row = pos.row;
            int col = pos.col;

            // Calculate which playable square this is
            // Each row has board_size/2 playable squares
            int squares_per_row = board_size / 2;

            // Determine the square number
            // Rows are numbered from bottom (0) to top (board_size-1)
            // Within each row, playable squares are numbered left to right
            int square_in_row = col / 2;

            // Calculate the square number (1-indexed)
            int square = (row * squares_per_row) + square_in_row + 1;

            return square;
        }

        /**
         * Get PDN game type string for a variant
         */
        private string get_pdn_game_type(GameVariant variant) {
            switch (variant.variant) {
                case DraughtsVariant.INTERNATIONAL:
                    return "20";  // International Draughts
                case DraughtsVariant.AMERICAN:
                    return "21";  // American Checkers
                case DraughtsVariant.RUSSIAN:
                    return "25";  // Russian Draughts
                case DraughtsVariant.BRAZILIAN:
                    return "26";  // Brazilian Draughts
                case DraughtsVariant.ITALIAN:
                    return "27";  // Italian Draughts
                case DraughtsVariant.POOL:
                    return "24";  // Pool Checkers
                default:
                    return "00";  // Unknown/Other
            }
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
                on_new_game_requested_with_mode(variant, is_human_vs_ai);
                logger.info("Game restarted with new AI difficulty: %s", new_difficulty.to_string());
            }
        }

        /**
         * Open a PDN file
         */
        public void open_pdn_file(File file) {
            logger.info("Attempting to open PDN file: %s", file.get_path());

            try {
                // Read the file contents
                uint8[] contents;
                string etag_out;
                file.load_contents(null, out contents, out etag_out);
                string pdn_content = (string) contents;

                logger.debug("PDN file loaded, content length: %d", pdn_content.length);

                // Show a dialog informing the user that PDN import is coming
                var dialog = new Adw.MessageDialog(
                    this,
                    _("PDN Import"),
                    _("PDN file import functionality will be available in a future version.\n\nFile: %s").printf(file.get_basename())
                );
                dialog.add_response("ok", _("OK"));
                dialog.set_default_response("ok");
                dialog.set_close_response("ok");
                dialog.present();

                // TODO: Parse PDN and load game into replay dialog

            } catch (Error e) {
                logger.error("Failed to open PDN file: %s", e.message);
                var toast = new Adw.Toast(_("Failed to open file: %s").printf(e.message));
                toast_overlay.add_toast(toast);
            }
        }
    }
}

