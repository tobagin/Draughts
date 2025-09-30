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
public class Draughts.NewGameDialog : Adw.AlertDialog {
    [GtkChild]
    private unowned Adw.ActionRow human_vs_human_row;
    [GtkChild]
    private unowned Adw.ActionRow human_vs_ai_row;

    public signal void game_mode_selected(bool is_human_vs_ai);

    construct {
        // Connect row activation signals
        human_vs_human_row.activated.connect(() => {
            game_mode_selected(false); // Human vs Human
            close();
        });

        human_vs_ai_row.activated.connect(() => {
            game_mode_selected(true); // Human vs AI
            close();
        });
    }

    public static void show(Gtk.Window parent) {
        var dialog = new NewGameDialog();
        dialog.present(parent);
    }
}