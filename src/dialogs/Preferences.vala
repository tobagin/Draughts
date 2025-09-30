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
        public signal void variant_changed_start_new_game();
        public signal void board_theme_changed(string theme);
        public signal void piece_style_changed(string style);
    [GtkChild]
    private unowned Adw.ComboRow game_variant_row;
    [GtkChild]
    private unowned Adw.ComboRow board_theme_row;
    [GtkChild]
    private unowned Adw.ComboRow piece_style_row;
    [GtkChild]
    private unowned Adw.ComboRow ai_difficulty_row;
    [GtkChild]
    private unowned Adw.ComboRow theme_row;
    [GtkChild]
    private unowned Adw.SwitchRow welcome_row;
    [GtkChild]
    private unowned Adw.SwitchRow whats_new_row;
    [GtkChild]
    private unowned Adw.SwitchRow sound_effects_row;

    private SettingsManager settings_manager;
    private Draughts.Logger logger;
    private bool is_initial_setup = true;

    public Preferences () {
        Object ();
    }

    construct {
        logger = Logger.get_default();
        settings_manager = SettingsManager.get_instance ();
        setup_game_variant_selection ();
        setup_board_theme_selection ();
        setup_piece_style_selection ();
        setup_ai_difficulty_selection ();
        setup_theme_selection ();
        setup_welcome_switch ();
        setup_whats_new_switch ();
        setup_sound_effects_switch ();
        bind_settings ();
        is_initial_setup = false;
        logger.debug ("Preferences dialog constructed");
    }

    private void setup_game_variant_selection () {
        // Map string setting to combo row index
        string current_variant = settings_manager.get_game_rules();
        int selected_index = get_variant_index(current_variant);
        game_variant_row.selected = selected_index;

        game_variant_row.notify["selected"].connect (() => {
            string variant_string = get_variant_string((int) game_variant_row.selected);

            if (!is_initial_setup) {
                show_variant_rules_dialog(variant_string);
            } else {
                apply_variant_change(variant_string);
            }
        });
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

    private void setup_ai_difficulty_selection () {
        AIDifficulty current_difficulty = settings_manager.get_ai_difficulty();
        int selected_index = get_ai_difficulty_index(current_difficulty);
        ai_difficulty_row.selected = selected_index;

        ai_difficulty_row.notify["selected"].connect (() => {
            AIDifficulty difficulty = get_ai_difficulty_from_index((int) ai_difficulty_row.selected);
            settings_manager.set_ai_difficulty(difficulty);
            logger.debug ("AI difficulty preference changed to: %s", difficulty.to_string());
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

    private void setup_sound_effects_switch () {
        sound_effects_row.active = settings_manager.get_sound_effects ();

        sound_effects_row.notify["active"].connect (() => {
            settings_manager.set_sound_effects (sound_effects_row.active);
            logger.debug ("Sound Effects preference changed to: %s", sound_effects_row.active.to_string ());
        });
    }

    private void bind_settings () {
        // Manual binding handled by notify signals above
        // Direct binding not possible due to type incompatibility (enum string vs uint for theme)
    }

    public void show_preferences (Gtk.Window parent) {
        present (parent);
    }

    // Mapping methods for game variant
    private int get_variant_index(string variant) {
        switch (variant) {
            case "checkers": return 0; // American Checkers
            case "international": return 1; // International Draughts
            case "russian": return 2;
            case "brazilian": return 3;
            case "italian": return 4;
            case "spanish": return 5;
            case "czech": return 6;
            case "thai": return 7;
            case "german": return 8;
            case "swedish": return 9;
            case "pool": return 10;
            case "graeco-turkish": return 11;
            case "armenian": return 12;
            case "gothic": return 13;
            case "frisian": return 14;
            case "canadian": return 15;
            default: return 1; // Default to International
        }
    }

    private string get_variant_string(int index) {
        switch (index) {
            case 0: return "checkers";
            case 1: return "international";
            case 2: return "russian";
            case 3: return "brazilian";
            case 4: return "italian";
            case 5: return "spanish";
            case 6: return "czech";
            case 7: return "thai";
            case 8: return "german";
            case 9: return "swedish";
            case 10: return "pool";
            case 11: return "graeco-turkish";
            case 12: return "armenian";
            case 13: return "gothic";
            case 14: return "frisian";
            case 15: return "canadian";
            default: return "international";
        }
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

    // Mapping methods for AI difficulty
    private int get_ai_difficulty_index(AIDifficulty difficulty) {
        switch (difficulty) {
            case AIDifficulty.BEGINNER: return 0;
            case AIDifficulty.EASY: return 1;
            case AIDifficulty.MEDIUM: return 2;
            case AIDifficulty.HARD: return 3;
            case AIDifficulty.EXPERT: return 4;
            case AIDifficulty.MASTER: return 5;
            case AIDifficulty.GRANDMASTER: return 6;
            default: return 2; // Default to medium
        }
    }

    private AIDifficulty get_ai_difficulty_from_index(int index) {
        switch (index) {
            case 0: return AIDifficulty.BEGINNER;
            case 1: return AIDifficulty.EASY;
            case 2: return AIDifficulty.MEDIUM;
            case 3: return AIDifficulty.HARD;
            case 4: return AIDifficulty.EXPERT;
            case 5: return AIDifficulty.MASTER;
            case 6: return AIDifficulty.GRANDMASTER;
            default: return AIDifficulty.MEDIUM;
        }
    }

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
            default: return DraughtsVariant.INTERNATIONAL;
        }
    }

    private void show_variant_rules_dialog(string variant_string) {
        var rules_dialog = new VariantRulesDialog();

        string current_variant = settings_manager.get_game_rules();

        var parent_window = this.get_root() as Gtk.Window;
        rules_dialog.show_rules_for_variant(variant_string, parent_window);

        rules_dialog.response.connect((response) => {
            if (response == "continue") {
                apply_variant_change(variant_string);
                logger.info("User accepted variant change to: %s", variant_string);
            } else {
                // User cancelled, revert to previous selection
                int previous_index = get_variant_index(current_variant);
                is_initial_setup = true; // Prevent infinite recursion
                game_variant_row.selected = previous_index;
                is_initial_setup = false;
                logger.info("User cancelled variant change, reverted to: %s", current_variant);
            }
        });
    }

    private void apply_variant_change(string variant_string) {
        settings_manager.set_game_rules(variant_string);
        var variant = string_to_variant(variant_string);
        settings_manager.set_default_variant(variant);

        // Update board size to match the variant
        int board_size = variant.get_variant_board_size();
        settings_manager.set_board_size(board_size);

        logger.debug("Game variant preference changed to: %s (board size: %d)", variant_string, board_size);

        // Emit signal to start new game with new variant
        variant_changed_start_new_game();
    }
    }
}