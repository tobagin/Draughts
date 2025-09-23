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

    public class Application : Adw.Application {
        private Logger logger;
        private SettingsManager settings;
        private Draughts.Window? main_window;

        public Application() {
            Object(
                application_id: Config.ID,
                flags: ApplicationFlags.DEFAULT_FLAGS
            );

            logger = Logger.get_default();
        }

        public override void activate() {
            base.activate();

            var window = active_window;
            if (window == null) {
                main_window = new Draughts.Window(this);
                window = main_window;
            } else {
                main_window = window as Draughts.Window;
            }

            window.present();
            logger.info("Application activated");

            // Check if we should show What's New dialog after a delay to ensure GTK is ready
            Idle.add(() => {
                check_and_show_whats_new();
                return false;
            });
        }

        public override void startup() {
            base.startup();

            settings = SettingsManager.get_instance();
            setup_actions();
            logger.info("Application started");
        }

        private void setup_actions() {
            var quit_action = new SimpleAction(Constants.ACTION_QUIT, null);
            quit_action.activate.connect(quit);
            add_action(quit_action);
            const string[] quit_accels = {"<primary>q", null};
            set_accels_for_action("app.quit", quit_accels);

            var about_action = new SimpleAction(Constants.ACTION_ABOUT, null);
            about_action.activate.connect(() => {
                DraughtsAboutDialog.show(active_window);
            });
            add_action(about_action);
            const string[] about_accels = {"<primary>F1", null};
            set_accels_for_action("app.about", about_accels);

            var preferences_action = new SimpleAction(Constants.ACTION_PREFERENCES, null);
            preferences_action.activate.connect(show_preferences);
            add_action(preferences_action);
            const string[] preferences_accels = {"<primary>comma", null};
            set_accels_for_action("app.preferences", preferences_accels);

            var new_game_action = new SimpleAction("new-game", null);
            new_game_action.activate.connect(start_new_game);
            add_action(new_game_action);
            const string[] new_game_accels = {"<primary>n", null};
            set_accels_for_action("app.new-game", new_game_accels);

            var reset_game_action = new SimpleAction("reset-game", null);
            reset_game_action.activate.connect(reset_game);
            add_action(reset_game_action);
            const string[] reset_game_accels = {"<primary>r", null};
            set_accels_for_action("app.reset-game", reset_game_accels);

            var scores_action = new SimpleAction("scores", null);
            scores_action.activate.connect(show_scores);
            add_action(scores_action);
            const string[] scores_accels = {"<primary>s", null};
            set_accels_for_action("app.scores", scores_accels);

            const string[] help_accels = {"<primary>question", null};
            set_accels_for_action("win.show-help-overlay", help_accels);

            const string[] close_window_accels = {"<primary>w", null};
            set_accels_for_action("win.close-window", close_window_accels);

            const string[] fullscreen_accels = {"F11", null};
            set_accels_for_action("win.toggle-fullscreen", fullscreen_accels);

            // Initialize saved settings values
            string saved_game_rules = settings.get_game_rules();
            if (saved_game_rules == "") {
                saved_game_rules = Constants.DEFAULT_GAME_RULES;
                settings.set_game_rules(saved_game_rules);
            }

            string saved_board_theme = settings.get_board_theme();
            if (saved_board_theme == "") {
                saved_board_theme = Constants.DEFAULT_BOARD_THEME;
                settings.set_board_theme(saved_board_theme);
            }

            // Game rules radio action
            var game_rules_action = new SimpleAction.stateful("game-rules-radio", VariantType.STRING, new Variant.string(saved_game_rules));
            game_rules_action.activate.connect(on_game_rules_changed);
            add_action(game_rules_action);

            // Board theme radio action
            var board_theme_action = new SimpleAction.stateful("board-theme-radio", VariantType.STRING, new Variant.string(saved_board_theme));
            board_theme_action.activate.connect(on_board_theme_changed);
            add_action(board_theme_action);


            logger.debug("Application actions configured");
        }


        private void show_preferences() {
            logger.debug("Preferences action triggered");
            var preferences_dialog = new Draughts.Preferences();
            preferences_dialog.show_preferences(active_window);
        }

        private void start_new_game() {
            logger.info("New game action triggered");
            if (main_window != null) {
                main_window.start_new_game();
            }
        }

        private void reset_game() {
            logger.info("Reset game action triggered");
            if (main_window != null) {
                main_window.reset_game();
            }
        }

        private void show_scores() {
            logger.info("Scores action triggered");
            if (main_window != null) {
                main_window.show_scores();
            }
        }

        private void on_game_rules_changed(SimpleAction action, Variant? parameter) {
            if (parameter == null) return;

            string rules = parameter.get_string();
            logger.info("Game rules changed to: %s", rules);

            // Update action state
            action.set_state(parameter);

            if (main_window != null) {
                main_window.set_game_rules(rules);
            }

            // Save to settings
            if (settings != null) {
                settings.set_game_rules(rules);
            }
        }

        private void on_board_theme_changed(SimpleAction action, Variant? parameter) {
            if (parameter == null) return;

            string theme = parameter.get_string();
            logger.info("Board theme changed to: %s", theme);

            // Update action state
            action.set_state(parameter);

            if (main_window != null) {
                main_window.set_board_theme(theme);
            }

            // Save to settings
            if (settings != null) {
                settings.set_board_theme(theme);
            }
        }


        private void check_and_show_whats_new() {
            // Check if this is a new version and show release notes automatically
            if (should_show_release_notes()) {
                // Small delay to ensure main window is fully presented
                Timeout.add(Constants.WHATS_NEW_DELAY, () => {
                    if (main_window != null && !main_window.in_destruction()) {
                        logger.info("Showing automatic release notes for new version");
                        DraughtsAboutDialog.show_with_release_notes(main_window);
                    }
                    return false;
                });
            }
        }

        private bool should_show_release_notes() {
            if (settings == null) {
                settings = SettingsManager.get_instance();
                if (settings == null) {
                    return false;
                }
            }

            string last_version = settings.get_string(Constants.SETTINGS_LAST_VERSION_RAN);
            string current_version = Config.VERSION;

            // Handle first run - initialize version tracking but don't show dialog
            if (settings.is_first_run()) {
                logger.info("First run detected, initializing version tracking");
                settings.set_first_run_complete();
                settings.set_string(Constants.SETTINGS_LAST_VERSION_RAN, current_version);
                return false;
            }

            // Initialize version tracking for edge cases
            if (last_version == "") {
                settings.set_string(Constants.SETTINGS_LAST_VERSION_RAN, current_version);
                return false;
            }

            // Compare versions to determine if this is an upgrade, downgrade, or same version
            int version_comparison = compare_versions(current_version, last_version);

            if (version_comparison > 0) {
                // Current version is newer - this is an upgrade
                settings.set_string(Constants.SETTINGS_LAST_VERSION_RAN, current_version);
                logger.info("Version upgrade detected: %s → %s", last_version, current_version);

                // Only show dialog if user wants it
                if (settings.get_show_whats_new()) {
                    logger.info("Showing What's New dialog for version %s", current_version);
                    return true;
                }
            } else if (version_comparison < 0) {
                // Current version is older - this is a regression/downgrade
                logger.warning("Version regression detected: %s → %s (not updating tracking)", last_version, current_version);
                return false;
            } else {
                // Same version - no action needed
                logger.debug("Same version running: %s", current_version);
                return false;
            }

            if (!settings.get_show_whats_new()) {
                logger.debug("What's New feature is disabled in preferences");
            }

            return false;
        }

        private int compare_versions(string version1, string version2) {
            // Split versions into parts (e.g., "1.2.3" -> ["1", "2", "3"])
            string[] parts1 = version1.split(".");
            string[] parts2 = version2.split(".");

            // Get the maximum length to handle different version formats
            int max_length = int.max(parts1.length, parts2.length);

            for (int i = 0; i < max_length; i++) {
                // Get version part or default to 0 if not present
                int num1 = (i < parts1.length) ? int.parse(parts1[i]) : 0;
                int num2 = (i < parts2.length) ? int.parse(parts2[i]) : 0;

                if (num1 > num2) {
                    return 1;  // version1 is newer
                } else if (num1 < num2) {
                    return -1; // version1 is older
                }
                // Continue if equal
            }

            return 0; // Versions are equal
        }
    }
}