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

namespace Draughts {

#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/preferences.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/Draughts/preferences.ui")]
#endif
    public class Preferences : Adw.PreferencesDialog {
        public signal void board_theme_changed(string theme);
        public signal void piece_style_changed(string style);
    [GtkChild]
    private unowned Adw.ComboRow board_theme_row;
    [GtkChild]
    private unowned Adw.ComboRow piece_style_row;
    [GtkChild]
    private unowned Adw.ComboRow theme_row;
    [GtkChild]
    private unowned Adw.SwitchRow welcome_row;
    [GtkChild]
    private unowned Adw.SwitchRow whats_new_row;
    // Audio section removed from preferences - controlled per-game now
    // [GtkChild]
    // private unowned Adw.SwitchRow sound_effects_row;
    [GtkChild]
    private unowned Adw.SwitchRow game_history_row;
    // Interaction style row removed from UI - kept for potential future use
    // [GtkChild]
    // private unowned Adw.ComboRow interaction_style_row;

    private SettingsManager settings_manager;
    private Draughts.Logger logger;
    private bool is_initial_setup = true;

    public Preferences () {
        Object ();
    }

    construct {
        logger = Logger.get_default();
        settings_manager = SettingsManager.get_instance ();
        setup_board_theme_selection ();
        setup_piece_style_selection ();
        setup_theme_selection ();
        setup_welcome_switch ();
        setup_whats_new_switch ();
        // setup_sound_effects_switch (); // Removed from preferences - controlled per-game
        setup_game_history_switch ();
        // setup_interaction_style_selection (); // Removed from UI - defaults to Click to Move
        bind_settings ();
        is_initial_setup = false;
        logger.debug ("Preferences dialog constructed");
    }

    private void setup_board_theme_selection () {
        string current_theme = settings_manager.get_board_theme();
        int selected_index = get_board_theme_index(current_theme);
        board_theme_row.selected = selected_index;

        board_theme_row.notify["selected"].connect (() => {
            if (!is_initial_setup) {
                string theme_string = get_board_theme_string((int) board_theme_row.selected);
                settings_manager.set_board_theme(theme_string);
                logger.debug ("Board theme preference changed to: %s", theme_string);
                board_theme_changed(theme_string);
            }
        });
    }

    private void setup_piece_style_selection () {
        string current_style = settings_manager.get_piece_style();
        int selected_index = get_piece_style_index(current_style);
        piece_style_row.selected = selected_index;

        piece_style_row.notify["selected"].connect (() => {
            if (!is_initial_setup) {
                string style_string = get_piece_style_string((int) piece_style_row.selected);
                settings_manager.set_piece_style(style_string);
                logger.debug ("Piece style preference changed to: %s", style_string);
                piece_style_changed(style_string);
            }
        });
    }

    private void setup_theme_selection () {
        theme_row.selected = settings_manager.get_color_scheme ();

        theme_row.notify["selected"].connect (() => {
            var selected = (ColorScheme) theme_row.selected;
            settings_manager.set_color_scheme (selected);
            logger.debug ("Theme preference changed to: %s", selected.to_string ());
        });
    }

    private void setup_welcome_switch () {
        welcome_row.active = settings_manager.get_show_welcome ();

        welcome_row.notify["active"].connect (() => {
            settings_manager.set_show_welcome (welcome_row.active);
            logger.debug ("Welcome Screen preference changed to: %s", welcome_row.active.to_string ());
        });
    }

    private void setup_whats_new_switch () {
        whats_new_row.active = settings_manager.get_show_whats_new ();

        whats_new_row.notify["active"].connect (() => {
            settings_manager.set_show_whats_new (whats_new_row.active);
            logger.debug ("What's New preference changed to: %s", whats_new_row.active.to_string ());
        });
    }

    // Sound effects setup removed - now controlled per-game in New Game dialog
    // Code maintained for potential future global sound settings
    /*
    private void setup_sound_effects_switch () {
        sound_effects_row.active = settings_manager.get_sound_effects ();

        sound_effects_row.notify["active"].connect (() => {
            settings_manager.set_sound_effects (sound_effects_row.active);
            logger.debug ("Sound Effects preference changed to: %s", sound_effects_row.active.to_string ());
        });
    }
    */

    private void setup_game_history_switch () {
        game_history_row.active = settings_manager.get_enable_game_history ();

        game_history_row.notify["active"].connect (() => {
            settings_manager.set_enable_game_history (game_history_row.active);
            logger.debug ("Game History preference changed to: %s", game_history_row.active.to_string ());
        });
    }

    // Interaction style selection removed from UI
    // Code maintained for future use when drag-and-drop performance is improved
    // Setting defaults to "Click to Move" (false)
    /*
    private void setup_interaction_style_selection () {
        // Map boolean setting to combo row index: 0 = Click to Move (false), 1 = Drag and Drop (true)
        bool is_drag_and_drop = settings_manager.get_enable_drag_and_drop ();
        interaction_style_row.selected = is_drag_and_drop ? 1 : 0;

        interaction_style_row.notify["selected"].connect (() => {
            bool enable_drag = (interaction_style_row.selected == 1);
            settings_manager.set_enable_drag_and_drop (enable_drag);
            logger.debug ("Interaction style changed to: %s", enable_drag ? "Drag and Drop" : "Click to Move");
        });
    }
    */

    private void bind_settings () {
        // Manual binding handled by notify signals above
        // Direct binding not possible due to type incompatibility (enum string vs uint for theme)
    }

    public void show_preferences (Gtk.Window parent) {
        present (parent);
    }

    // Mapping methods for board theme
    private int get_board_theme_index(string theme) {
        switch (theme) {
            case "classic": return 0;
            case "wood": return 1;
            case "green": return 2;
            case "blue": return 3;
            case "contrast": return 4;
            default: return 0; // Default to classic
        }
    }

    private string get_board_theme_string(int index) {
        switch (index) {
            case 0: return "classic";
            case 1: return "wood";
            case 2: return "green";
            case 3: return "blue";
            case 4: return "contrast";
            default: return "classic";
        }
    }

    // Mapping methods for piece style
    private int get_piece_style_index(string style) {
        switch (style) {
            case "plastic": return 0;
            case "wood": return 1;
            case "metal": return 2;
            case "bottle-cap": return 3;
            default: return 0; // Default to plastic
        }
    }

    private string get_piece_style_string(int index) {
        switch (index) {
            case 0: return "plastic";
            case 1: return "wood";
            case 2: return "metal";
            case 3: return "bottle-cap";
            default: return "plastic";
        }
    }

    }
}