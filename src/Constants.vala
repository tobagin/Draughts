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

    [Compact]
    public class Constants {

        // Window Defaults
        public const int DEFAULT_WINDOW_WIDTH = 800;
        public const int DEFAULT_WINDOW_HEIGHT = 600;
        public const bool DEFAULT_WINDOW_MAXIMIZED = false;

        // Settings Keys
        public const string SETTINGS_COLOR_SCHEME = "color-scheme";
        public const string SETTINGS_WINDOW_WIDTH = "window-width";
        public const string SETTINGS_WINDOW_HEIGHT = "window-height";
        public const string SETTINGS_WINDOW_MAXIMIZED = "window-maximized";
        public const string SETTINGS_FIRST_RUN = "first-run";
        public const string SETTINGS_LAST_VERSION_RAN = "last-version-ran";
        public const string SETTINGS_SHOW_WHATS_NEW = "show-whats-new";

        // UI Constants
        public const string MAIN_WINDOW_ICON = "preferences-system-symbolic";
        public const string MENU_BUTTON_ICON = "open-menu-symbolic";
        public const string DEFAULT_THEME_SCHEME = "default";

        // Game Settings
        public const string SETTINGS_BOARD_SIZE = "board-size";
        public const string SETTINGS_GAME_RULES = "game-rules";
        public const string SETTINGS_BOARD_THEME = "board-theme";

        // Game Defaults
        public const int DEFAULT_BOARD_SIZE = 8;
        public const string DEFAULT_GAME_RULES = "checkers";
        public const string DEFAULT_BOARD_THEME = "classic";

        // Action Names
        public const string ACTION_QUIT = "quit";
        public const string ACTION_ABOUT = "about";
        public const string ACTION_PREFERENCES = "preferences";
        public const string ACTION_SHOW_HELP_OVERLAY = "show-help-overlay";

        // File Paths
        public const string METAINFO_SUBPATH = "share/metainfo";
        public const string SCHEMAS_SUBPATH = "share/glib-2.0/schemas";

        // Timeout Values (in milliseconds)
        public const int WHATS_NEW_DELAY = 500;
        public const int DIALOG_ANIMATION_DELAY = 300;
    }
}