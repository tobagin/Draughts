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

        private DraughtsBoard draughts_board;

        private Logger logger;

        public Window(Gtk.Application app) {
            Object(application: app);

            logger = Logger.get_default();
            set_default_size(700, 700);
            set_size_request(300, 300);
            setup_actions();
            load_css();
            setup_board();
            initialize_window_subtitle();

            // Ensure template widgets are accessible (suppresses unused warnings)
            assert(header_bar != null);
            assert(window_title != null);
            assert(menu_button != null);
            assert(toast_overlay != null);
            assert(board_container != null);

            logger.info("Window created and initialized");
        }

        private void setup_actions() {
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

            logger.debug("Window actions configured");
        }

        private void setup_board() {
            draughts_board = new DraughtsBoard();
            board_container.append(draughts_board);
            logger.debug("Draughts board created and added to container");
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

        public void start_new_game() {
            if (draughts_board != null) {
                draughts_board.start_new_game();
                logger.info("New game started");
            }
        }

        public void reset_game() {
            if (draughts_board != null) {
                draughts_board.reset_game();
                logger.info("Game reset");
            }
        }

        public void show_scores() {
            logger.info("Showing scores dialog");
            // TODO: Implement scores dialog
            var toast = new Adw.Toast("Scores feature coming soon!");
            toast.set_timeout(3);
            toast_overlay.add_toast(toast);
        }


        public void set_game_rules(string rules) {
            logger.info("Setting game rules to: %s", rules);
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
            var toast = new Adw.Toast("Game rules changed to %s (%dx%d board)".printf(display_name, board_size, board_size));
            toast.set_timeout(3);
            toast_overlay.add_toast(toast);
        }

        public void set_board_theme(string theme) {
            logger.info("Setting board theme to: %s", theme);
            if (draughts_board != null) {
                draughts_board.set_board_theme(theme);
            }

            string display_name = get_theme_display_name(theme);
            var toast = new Adw.Toast("Board theme changed to %s".printf(display_name));
            toast.set_timeout(3);
            toast_overlay.add_toast(toast);
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
    }
}

