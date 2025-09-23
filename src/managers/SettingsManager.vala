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
        public int get_board_size () {
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
    }
}