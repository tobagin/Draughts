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
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/new-game.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/new-game.ui")]
#endif
public class Draughts.NewGameDialog : Adw.Dialog {
    [GtkChild]
    private unowned Button cancel_button;
    [GtkChild]
    private unowned Button start_button;
    [GtkChild]
    private unowned Adw.ComboRow variant_row;
    [GtkChild]
    private unowned Adw.ComboRow opposing_player_row;
    [GtkChild]
    private unowned Adw.ComboRow play_as_row;
    [GtkChild]
    private unowned Adw.ComboRow difficulty_row;
    [GtkChild]
    private unowned Switch time_limit_switch;
    [GtkChild]
    private unowned Adw.SpinRow minutes_per_side_row;
    [GtkChild]
    private unowned Adw.SpinRow increment_row;
    [GtkChild]
    private unowned Adw.ComboRow clock_type_row;
    [GtkChild]
    private unowned Switch sound_effects_switch;

    public signal void game_started(
        DraughtsVariant variant,
        bool is_human_vs_ai,
        PieceColor human_color,
        int ai_difficulty,
        bool use_time_limit,
        int minutes_per_side,
        int increment_seconds,
        string clock_type
    );

    construct {
        // Connect cancel button
        cancel_button.clicked.connect(() => {
            close();
        });

        // Connect start button
        start_button.clicked.connect(() => {
            on_start_clicked();
        });

        // Connect opposing player selection to enable/disable AI options
        opposing_player_row.notify["selected"].connect(() => {
            bool is_ai = opposing_player_row.selected == 1; // 0 = Human, 1 = AI
            play_as_row.sensitive = is_ai;
            difficulty_row.sensitive = is_ai;
        });

        // Connect time limit switch to enable/disable time limit options
        time_limit_switch.notify["active"].connect(() => {
            bool enabled = time_limit_switch.active;
            minutes_per_side_row.sensitive = enabled;
            increment_row.sensitive = enabled;
            clock_type_row.sensitive = enabled;
        });

        // Load saved settings or set defaults
        load_saved_settings();
    }

    private void load_saved_settings() {
        var settings = SettingsManager.get_instance();

        // Load variant (default: International = 1)
        DraughtsVariant saved_variant = settings.get_default_variant();
        variant_row.selected = get_variant_index(saved_variant);

        // Load opponent type (default: Human = 0)
        opposing_player_row.selected = settings.get_int("new-game-opponent-type");

        // Load human color (default: Red = 0)
        play_as_row.selected = settings.get_int("new-game-human-color");

        // Load AI difficulty (default: Intermediate = 1)
        difficulty_row.selected = settings.get_int("new-game-ai-difficulty");

        // Load time limit enabled (default: false)
        time_limit_switch.active = settings.get_boolean("new-game-time-limit-enabled");

        // Load time limit values
        minutes_per_side_row.value = settings.get_int("new-game-minutes-per-side");
        increment_row.value = settings.get_int("new-game-increment-seconds");

        // Load clock type (default: Fischer = 0)
        clock_type_row.selected = settings.get_int("new-game-clock-type");

        // Load sound effects (default: true)
        sound_effects_switch.active = settings.get_boolean("sound-effects");

        // Trigger the sensitivity update for AI options
        bool is_ai = opposing_player_row.selected == 1;
        play_as_row.sensitive = is_ai;
        difficulty_row.sensitive = is_ai;

        // Trigger the sensitivity update for time limit options
        bool time_enabled = time_limit_switch.active;
        minutes_per_side_row.sensitive = time_enabled;
        increment_row.sensitive = time_enabled;
        clock_type_row.sensitive = time_enabled;
    }

    private void save_settings() {
        var settings = SettingsManager.get_instance();

        // Save all current settings
        DraughtsVariant variant = get_variant_from_index((int)variant_row.selected);
        settings.set_default_variant(variant);
        settings.set_int("new-game-opponent-type", (int)opposing_player_row.selected);
        settings.set_int("new-game-human-color", (int)play_as_row.selected);
        settings.set_int("new-game-ai-difficulty", (int)difficulty_row.selected);
        settings.set_boolean("new-game-time-limit-enabled", time_limit_switch.active);
        settings.set_int("new-game-minutes-per-side", (int)minutes_per_side_row.value);
        settings.set_int("new-game-increment-seconds", (int)increment_row.value);
        settings.set_int("new-game-clock-type", (int)clock_type_row.selected);
        settings.set_boolean("sound-effects", sound_effects_switch.active);
    }

    private void on_start_clicked() {
        // Save current settings for next time
        save_settings();

        // Get selected variant
        DraughtsVariant variant = get_variant_from_index((int)variant_row.selected);

        bool is_human_vs_ai = opposing_player_row.selected == 1;

        // Determine human color
        PieceColor human_color = PieceColor.RED;
        if (is_human_vs_ai) {
            human_color = play_as_row.selected == 0 ? PieceColor.RED : PieceColor.BLACK;
        }

        // Get AI difficulty (0-4 mapping to Beginner through Grandmaster)
        int ai_difficulty = (int)difficulty_row.selected;

        // Get time limit settings
        bool use_time_limit = time_limit_switch.active;
        int minutes_per_side = (int)minutes_per_side_row.value;
        int increment_seconds = (int)increment_row.value;
        string clock_type = clock_type_row.selected == 0 ? "Fischer" : "Bronstein";

        // Emit signal with all configuration
        game_started(
            variant,
            is_human_vs_ai,
            human_color,
            ai_difficulty,
            use_time_limit,
            minutes_per_side,
            increment_seconds,
            clock_type
        );

        close();
    }

    public static void show(Gtk.Window parent) {
        var dialog = new NewGameDialog();
        dialog.present(parent);
    }

    // Helper methods for variant conversion
    private int get_variant_index(DraughtsVariant variant) {
        switch (variant) {
            case DraughtsVariant.AMERICAN: return 0;
            case DraughtsVariant.INTERNATIONAL: return 1;
            case DraughtsVariant.RUSSIAN: return 2;
            case DraughtsVariant.BRAZILIAN: return 3;
            case DraughtsVariant.ITALIAN: return 4;
            case DraughtsVariant.SPANISH: return 5;
            case DraughtsVariant.CZECH: return 6;
            case DraughtsVariant.THAI: return 7;
            case DraughtsVariant.GERMAN: return 8;
            case DraughtsVariant.SWEDISH: return 9;
            case DraughtsVariant.POOL: return 10;
            case DraughtsVariant.TURKISH: return 11;
            case DraughtsVariant.ARMENIAN: return 12;
            case DraughtsVariant.GOTHIC: return 13;
            case DraughtsVariant.FRISIAN: return 14;
            case DraughtsVariant.CANADIAN: return 15;
            default: return 1; // Default to International
        }
    }

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
}
