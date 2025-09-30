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

    public enum ColorScheme {
        DEFAULT = 0,
        LIGHT = 1,
        DARK = 2
    }

    public class SettingsManager : GLib.Object {
        private static SettingsManager? instance;
        private GLib.Settings settings;
        private Draughts.Logger logger;

        public signal void theme_changed (ColorScheme scheme);
        public signal void ai_difficulty_changed (AIDifficulty difficulty);

        public static SettingsManager get_instance () {
            if (instance == null) {
                instance = new SettingsManager ();
            }
            return instance;
        }

        private SettingsManager () {
            logger = Logger.get_default();
            settings = new GLib.Settings (Config.ID);

            // Connect to settings changes
            settings.changed[Constants.SETTINGS_COLOR_SCHEME].connect (() => {
                var scheme = (ColorScheme) settings.get_enum (Constants.SETTINGS_COLOR_SCHEME);
                apply_theme (scheme);
                theme_changed (scheme);
                logger.debug ("Theme changed to: %s", scheme.to_string ());
            });

            // Apply initial theme
            var initial_scheme = (ColorScheme) settings.get_enum (Constants.SETTINGS_COLOR_SCHEME);
            apply_theme (initial_scheme);
            logger.debug ("SettingsManager initialized with theme: %s", initial_scheme.to_string ());
        }

        public ColorScheme get_color_scheme () {
            return (ColorScheme) settings.get_enum (Constants.SETTINGS_COLOR_SCHEME);
        }

        public void set_color_scheme (ColorScheme scheme) {
            settings.set_enum (Constants.SETTINGS_COLOR_SCHEME, scheme);
        }

        public void bind_color_scheme (GLib.Object object, string property) {
            settings.bind (Constants.SETTINGS_COLOR_SCHEME, object, property, SettingsBindFlags.DEFAULT);
        }

        // What's New feature settings
        public bool get_show_whats_new () {
            return settings.get_boolean (Constants.SETTINGS_SHOW_WHATS_NEW);
        }

        public void set_show_whats_new (bool show) {
            settings.set_boolean (Constants.SETTINGS_SHOW_WHATS_NEW, show);
        }

        public void bind_show_whats_new (GLib.Object object, string property) {
            settings.bind (Constants.SETTINGS_SHOW_WHATS_NEW, object, property, SettingsBindFlags.DEFAULT);
        }

        // Welcome dialog settings
        public bool get_show_welcome () {
            return settings.get_boolean ("show-welcome");
        }

        public void set_show_welcome (bool show) {
            settings.set_boolean ("show-welcome", show);
        }

        // First run detection
        public bool is_first_run () {
            return settings.get_boolean (Constants.SETTINGS_FIRST_RUN);
        }

        public void set_first_run_complete () {
            settings.set_boolean (Constants.SETTINGS_FIRST_RUN, false);
        }

        private void apply_theme (ColorScheme scheme) {
            var style_manager = Adw.StyleManager.get_default ();

            switch (scheme) {
                case ColorScheme.DEFAULT:
                    style_manager.color_scheme = Adw.ColorScheme.DEFAULT;
                    break;
                case ColorScheme.LIGHT:
                    style_manager.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
                    break;
                case ColorScheme.DARK:
                    style_manager.color_scheme = Adw.ColorScheme.FORCE_DARK;
                    break;
            }
        }

        // Window state management
        public void save_window_state (int width, int height, bool maximized) {
            settings.set_int (Constants.SETTINGS_WINDOW_WIDTH, width);
            settings.set_int (Constants.SETTINGS_WINDOW_HEIGHT, height);
            settings.set_boolean (Constants.SETTINGS_WINDOW_MAXIMIZED, maximized);
        }

        public void get_window_state (out int width, out int height, out bool maximized) {
            width = settings.get_int (Constants.SETTINGS_WINDOW_WIDTH);
            height = settings.get_int (Constants.SETTINGS_WINDOW_HEIGHT);
            maximized = settings.get_boolean (Constants.SETTINGS_WINDOW_MAXIMIZED);
        }

        // Generic settings helpers
        public bool get_boolean (string key) {
            return settings.get_boolean (key);
        }

        public void set_boolean (string key, bool value) {
            settings.set_boolean (key, value);
        }

        public int get_int (string key) {
            return settings.get_int (key);
        }

        public void set_int (string key, int value) {
            settings.set_int (key, value);
        }

        public string get_string (string key) {
            return settings.get_string (key);
        }

        public void set_string (string key, string value) {
            settings.set_string (key, value);
        }

        public void bind (string key, GLib.Object object, string property, SettingsBindFlags flags = SettingsBindFlags.DEFAULT) {
            settings.bind (key, object, property, flags);
        }

        // Game settings management
        public int get_settings_board_size () {
            return settings.get_int (Constants.SETTINGS_BOARD_SIZE);
        }

        public void set_board_size (int size) {
            settings.set_int (Constants.SETTINGS_BOARD_SIZE, size);
        }

        public string get_game_rules () {
            return settings.get_string (Constants.SETTINGS_GAME_RULES);
        }

        public void set_game_rules (string rules) {
            settings.set_string (Constants.SETTINGS_GAME_RULES, rules);
        }

        public string get_board_theme () {
            return settings.get_string (Constants.SETTINGS_BOARD_THEME);
        }

        public void set_board_theme (string theme) {
            settings.set_string (Constants.SETTINGS_BOARD_THEME, theme);
        }

        // Comprehensive Draughts Game Settings
        public DraughtsVariant get_default_variant() {
            return (DraughtsVariant) settings.get_enum("default-variant");
        }

        public void set_default_variant(DraughtsVariant variant) {
            logger.debug("=== SETTINGS: SAVING VARIANT ===");
            logger.debug("Saving variant: %s", variant.to_string());
            settings.set_enum("default-variant", variant);
            logger.debug("=================================");
        }

        public bool get_show_legal_moves() {
            return settings.get_boolean("show-legal-moves");
        }

        public void set_show_legal_moves(bool show) {
            settings.set_boolean("show-legal-moves", show);
        }

        public bool get_animate_moves() {
            return settings.get_boolean("animate-moves");
        }

        public void set_animate_moves(bool animate) {
            settings.set_boolean("animate-moves", animate);
        }

        public bool get_sound_effects() {
            return settings.get_boolean("sound-effects");
        }

        public void set_sound_effects(bool enabled) {
            settings.set_boolean("sound-effects", enabled);
        }

        public bool get_drag_and_drop() {
            return settings.get_boolean("drag-and-drop");
        }

        public void set_drag_and_drop(bool enabled) {
            settings.set_boolean("drag-and-drop", enabled);
        }

        public InteractionMode get_interaction_mode() {
            return (InteractionMode) settings.get_enum("interaction-mode");
        }

        public void set_interaction_mode(InteractionMode mode) {
            settings.set_enum("interaction-mode", mode);
        }

        // AI Settings
        public AIDifficulty get_ai_difficulty() {
            return (AIDifficulty) settings.get_enum("ai-difficulty");
        }

        public void set_ai_difficulty(AIDifficulty difficulty) {
            settings.set_enum("ai-difficulty", difficulty);
            ai_difficulty_changed(difficulty);
        }

        public int get_ai_thinking_time() {
            return settings.get_int("ai-thinking-time");
        }

        public void set_ai_thinking_time(int seconds) {
            settings.set_int("ai-thinking-time", seconds);
        }

        public bool get_show_ai_thinking() {
            return settings.get_boolean("show-ai-thinking");
        }

        public void set_show_ai_thinking(bool show) {
            settings.set_boolean("show-ai-thinking", show);
        }

        public bool get_ai_progress_indicator() {
            return settings.get_boolean("ai-progress-indicator");
        }

        public void set_ai_progress_indicator(bool show) {
            settings.set_boolean("ai-progress-indicator", show);
        }

        // Timer Settings
        public TimerMode get_default_timer_mode() {
            return (TimerMode) settings.get_enum("default-timer-mode");
        }

        public void set_default_timer_mode(TimerMode mode) {
            settings.set_enum("default-timer-mode", mode);
        }

        public int get_countdown_minutes() {
            return settings.get_int("countdown-minutes");
        }

        public void set_countdown_minutes(int minutes) {
            settings.set_int("countdown-minutes", minutes);
        }

        public int get_fischer_increment() {
            return settings.get_int("fischer-increment");
        }

        public void set_fischer_increment(int seconds) {
            settings.set_int("fischer-increment", seconds);
        }

        public int get_delay_seconds() {
            return settings.get_int("delay-seconds");
        }

        public void set_delay_seconds(int seconds) {
            settings.set_int("delay-seconds", seconds);
        }

        public bool get_timer_warnings() {
            return settings.get_boolean("timer-warnings");
        }

        public void set_timer_warnings(bool enabled) {
            settings.set_boolean("timer-warnings", enabled);
        }

        public bool get_timer_sounds() {
            return settings.get_boolean("timer-sounds");
        }

        public void set_timer_sounds(bool enabled) {
            settings.set_boolean("timer-sounds", enabled);
        }

        // Display Settings
        public string get_piece_style() {
            return settings.get_string("piece-style");
        }

        public void set_piece_style(string style) {
            settings.set_string("piece-style", style);
        }

        public bool get_show_coordinates() {
            return settings.get_boolean("show-coordinates");
        }

        public void set_show_coordinates(bool show) {
            settings.set_boolean("show-coordinates", show);
        }

        public bool get_highlight_last_move() {
            return settings.get_boolean("highlight-last-move");
        }

        public void set_highlight_last_move(bool highlight) {
            settings.set_boolean("highlight-last-move", highlight);
        }

        public bool get_show_move_history() {
            return settings.get_boolean("show-move-history");
        }

        public void set_show_move_history(bool show) {
            settings.set_boolean("show-move-history", show);
        }

        // Accessibility Settings
        public bool get_high_contrast() {
            return settings.get_boolean("high-contrast");
        }

        public void set_high_contrast(bool enabled) {
            settings.set_boolean("high-contrast", enabled);
        }

        public bool get_large_pieces() {
            return settings.get_boolean("large-pieces");
        }

        public void set_large_pieces(bool enabled) {
            settings.set_boolean("large-pieces", enabled);
        }

        public bool get_screen_reader_support() {
            return settings.get_boolean("screen-reader-support");
        }

        public void set_screen_reader_support(bool enabled) {
            settings.set_boolean("screen-reader-support", enabled);
        }

        public bool get_keyboard_navigation() {
            return settings.get_boolean("keyboard-navigation");
        }

        public void set_keyboard_navigation(bool enabled) {
            settings.set_boolean("keyboard-navigation", enabled);
        }

        public AnnouncementLevel get_move_announcement_mode() {
            return (AnnouncementLevel) settings.get_enum("move-announcement-mode");
        }

        public void set_move_announcement_mode(AnnouncementLevel level) {
            settings.set_enum("move-announcement-mode", level);
        }

        // Session Settings
        public bool get_autosave_enabled() {
            return settings.get_boolean("autosave-enabled");
        }

        public void set_autosave_enabled(bool enabled) {
            settings.set_boolean("autosave-enabled", enabled);
        }

        public int get_autosave_interval() {
            return settings.get_int("autosave-interval");
        }

        public void set_autosave_interval(int seconds) {
            settings.set_int("autosave-interval", seconds);
        }

        public bool get_restore_session() {
            return settings.get_boolean("restore-session");
        }

        public void set_restore_session(bool restore) {
            settings.set_boolean("restore-session", restore);
        }

        // Statistics and History
        public int get_games_played() {
            return settings.get_int("games-played");
        }

        public void set_games_played(int count) {
            settings.set_int("games-played", count);
        }

        public void increment_games_played() {
            set_games_played(get_games_played() + 1);
        }

        public int get_games_won() {
            return settings.get_int("games-won");
        }

        public void set_games_won(int count) {
            settings.set_int("games-won", count);
        }

        public void increment_games_won() {
            set_games_won(get_games_won() + 1);
        }

        // Settings Management
        public void reset_to_defaults() {
            var keys = settings.list_keys();
            foreach (var key in keys) {
                settings.reset(key);
            }
            logger.info("Settings reset to defaults");
        }

        public void export_to_file(File file) {
            try {
                var export_data = create_export_data();

                var output_stream = file.create(FileCreateFlags.REPLACE_DESTINATION);
                var data_stream = new DataOutputStream(output_stream);
                data_stream.put_string(export_data);
                data_stream.close();

                logger.info("Settings exported to: %s", file.get_path());
            } catch (Error e) {
                logger.error("Failed to export settings: %s", e.message);
            }
        }

        public void import_from_file(File file) {
            try {
                var input_stream = file.read();
                var data_stream = new DataInputStream(input_stream);

                var import_data = new StringBuilder();
                string line;
                while ((line = data_stream.read_line()) != null) {
                    import_data.append_printf("%s\n", line);
                }

                data_stream.close();

                apply_import_data(import_data.str);
                logger.info("Settings imported from: %s", file.get_path());
            } catch (Error e) {
                logger.error("Failed to import settings: %s", e.message);
            }
        }

        private string create_export_data() {
            var json_builder = new Json.Builder();
            json_builder.begin_object();

            json_builder.set_member_name("export_version");
            json_builder.add_string_value("1.0");

            json_builder.set_member_name("export_date");
            json_builder.add_string_value(new DateTime.now_local().format_iso8601());

            json_builder.set_member_name("settings");
            json_builder.begin_object();

            // Export all settings
            var keys = settings.list_keys();
            foreach (var key in keys) {
                var variant_value = settings.get_value(key);
                json_builder.set_member_name(key);

                // Handle different variant types
                if (variant_value.is_of_type(VariantType.BOOLEAN)) {
                    json_builder.add_boolean_value(variant_value.get_boolean());
                } else if (variant_value.is_of_type(VariantType.INT32)) {
                    json_builder.add_int_value(variant_value.get_int32());
                } else if (variant_value.is_of_type(VariantType.STRING)) {
                    json_builder.add_string_value(variant_value.get_string());
                } else {
                    json_builder.add_string_value(variant_value.print(false));
                }
            }

            json_builder.end_object();
            json_builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(json_builder.get_root());
            generator.pretty = true;

            return generator.to_data(null);
        }

        private void apply_import_data(string json_data) {
            try {
                var parser = new Json.Parser();
                parser.load_from_data(json_data);

                var root_object = parser.get_root().get_object();
                if (!root_object.has_member("settings")) {
                    logger.warning("Invalid import data: missing settings section");
                    return;
                }

                var settings_obj = root_object.get_object_member("settings");

                settings_obj.foreach_member((object, key, value_node) => {
                    try {
                        if (value_node.get_value_type() == typeof(bool)) {
                            settings.set_boolean(key, value_node.get_boolean());
                        } else if (value_node.get_value_type() == typeof(int64)) {
                            settings.set_int(key, (int)value_node.get_int());
                        } else if (value_node.get_value_type() == typeof(string)) {
                            settings.set_string(key, value_node.get_string());
                        }
                    } catch (Error e) {
                        logger.warning("Failed to import setting %s: %s", key, e.message);
                    }
                });

            } catch (Error e) {
                logger.error("Failed to parse import data: %s", e.message);
            }
        }

        // Utility method to get the default singleton instance
        public static SettingsManager get_default() {
            return get_instance();
        }
    }
}