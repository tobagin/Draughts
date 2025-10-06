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
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/game-end.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/game-end.ui")]
#endif
public class Draughts.GameEndDialog : Adw.AlertDialog {
    // Result section
    [GtkChild]
    private unowned Gtk.Image result_icon;
    [GtkChild]
    private unowned Gtk.Label result_title;
    [GtkChild]
    private unowned Gtk.Label result_subtitle;

    // General statistics
    [GtkChild]
    private unowned Gtk.Label total_moves_value;
    [GtkChild]
    private unowned Gtk.Label game_duration_value;

    // Red player statistics
    [GtkChild]
    private unowned Gtk.Label red_captures_value;
    [GtkChild]
    private unowned Gtk.Label red_promotions_value;
    [GtkChild]
    private unowned Gtk.Label red_moves_value;
    [GtkChild]
    private unowned Gtk.Label red_pieces_remaining_value;

    // Black player statistics
    [GtkChild]
    private unowned Gtk.Label black_captures_value;
    [GtkChild]
    private unowned Gtk.Label black_promotions_value;
    [GtkChild]
    private unowned Gtk.Label black_moves_value;
    [GtkChild]
    private unowned Gtk.Label black_pieces_remaining_value;

    private Logger logger;

    public GameEndDialog() {
        Object();
    }

    construct {
        logger = Logger.get_default();
        logger.debug("GameEndDialog constructed");
    }

    /**
     * Show the game end dialog with full game session statistics
     */
    public void show_game_end_with_session(Gtk.Window parent, DraughtsGameState final_state, GameSessionStats session_stats, PieceColor? local_player_color = null, bool is_multiplayer = false) {
        populate_results(final_state, local_player_color);
        populate_statistics_from_session(session_stats, final_state);

        // Update button labels for multiplayer
        if (is_multiplayer) {
            set_response_label("new_game", _("Play Again"));
            set_response_label("close", _("Exit to Menu"));
        }

        present(parent);
    }

    /**
     * Show the game end dialog with game statistics - fallback method
     */
    public void show_game_end(Gtk.Window parent, DraughtsGameState final_state, GameStatistics stats, PieceColor? local_player_color = null, bool is_multiplayer = false) {
        populate_results(final_state, local_player_color);
        populate_statistics(stats, final_state);

        // Update button labels for multiplayer
        if (is_multiplayer) {
            set_response_label("new_game", _("Play Again"));
            set_response_label("close", _("Exit to Menu"));
        }

        present(parent);
    }

    /**
     * Populate the result section based on game outcome
     */
    private void populate_results(DraughtsGameState final_state, PieceColor? local_player_color) {
        // Determine if this is a multiplayer game by checking if local_player_color is provided
        bool is_multiplayer = (local_player_color != null);

        switch (final_state.game_status) {
            case GameStatus.RED_WINS:
                if (is_multiplayer) {
                    bool local_won = (local_player_color == PieceColor.RED);
                    if (local_won) {
                        result_icon.set_from_icon_name("emblem-favorite-symbolic");
                        result_icon.add_css_class("success");
                        result_title.set_text(_("You Win!"));
                        result_subtitle.set_text(_("Congratulations on your victory!"));
                    } else {
                        result_icon.set_from_icon_name("emblem-important-symbolic");
                        result_icon.add_css_class("error");
                        result_title.set_text(_("Opponent Wins!"));
                        result_subtitle.set_text(_("Better luck next time!"));
                    }
                } else {
                    result_icon.set_from_icon_name("emblem-favorite-symbolic");
                    result_icon.add_css_class("success");
                    result_title.set_text(_("Red Player Wins!"));
                    result_subtitle.set_text(_("Congratulations on your victory!"));
                }
                break;

            case GameStatus.BLACK_WINS:
                if (is_multiplayer) {
                    bool local_won = (local_player_color == PieceColor.BLACK);
                    if (local_won) {
                        result_icon.set_from_icon_name("emblem-favorite-symbolic");
                        result_icon.add_css_class("success");
                        result_title.set_text(_("You Win!"));
                        result_subtitle.set_text(_("Congratulations on your victory!"));
                    } else {
                        result_icon.set_from_icon_name("emblem-important-symbolic");
                        result_icon.add_css_class("error");
                        result_title.set_text(_("Opponent Wins!"));
                        result_subtitle.set_text(_("Better luck next time!"));
                    }
                } else {
                    result_icon.set_from_icon_name("emblem-favorite-symbolic");
                    result_icon.add_css_class("success");
                    result_title.set_text(_("Black Player Wins!"));
                    result_subtitle.set_text(_("Congratulations on your victory!"));
                }
                break;

            case GameStatus.DRAW:
                result_icon.set_from_icon_name("emblem-synchronizing-symbolic");
                result_icon.add_css_class("warning");
                result_title.set_text(_("Game Drawn!"));
                result_subtitle.set_text(_("Well played by both sides!"));
                break;


            default:
                result_icon.set_from_icon_name("dialog-information-symbolic");
                result_title.set_text(_("Game Ended"));
                result_subtitle.set_text(_("Thanks for playing!"));
                break;
        }
    }

    /**
     * Populate statistics section using GameSessionStats
     */
    private void populate_statistics_from_session(GameSessionStats session_stats, DraughtsGameState final_state) {
        // General statistics
        total_moves_value.set_text(session_stats.move_count.to_string());

        // Format game duration from TimeSpan (in microseconds)
        int total_seconds = (int)(session_stats.duration / TimeSpan.SECOND);
        int minutes = total_seconds / 60;
        int seconds = total_seconds % 60;
        game_duration_value.set_text("%d:%02d".printf(minutes, seconds));

        // Calculate individual player moves (Red typically goes first)
        int red_moves = (session_stats.move_count + 1) / 2;
        int black_moves = session_stats.move_count / 2;

        // Red player statistics
        red_captures_value.set_text(session_stats.red_captures.to_string());
        red_promotions_value.set_text(session_stats.red_promotions.to_string());
        red_moves_value.set_text(red_moves.to_string());
        red_pieces_remaining_value.set_text(count_pieces_for_player(final_state, Player.RED).to_string());

        // Black player statistics
        black_captures_value.set_text(session_stats.black_captures.to_string());
        black_promotions_value.set_text(session_stats.black_promotions.to_string());
        black_moves_value.set_text(black_moves.to_string());
        black_pieces_remaining_value.set_text(count_pieces_for_player(final_state, Player.BLACK).to_string());
    }

    /**
     * Populate statistics section - fallback method
     */
    private void populate_statistics(GameStatistics stats, DraughtsGameState final_state) {
        // General statistics
        total_moves_value.set_text(stats.total_moves.to_string());

        // Format game duration
        int minutes = (int)(stats.game_duration_seconds / 60);
        int seconds = (int)(stats.game_duration_seconds % 60);
        game_duration_value.set_text("%d:%02d".printf(minutes, seconds));

        // Red player statistics
        red_captures_value.set_text(stats.red_captures.to_string());
        red_promotions_value.set_text(stats.red_promotions.to_string());
        red_moves_value.set_text(stats.red_moves.to_string());
        red_pieces_remaining_value.set_text(count_pieces_for_player(final_state, Player.RED).to_string());

        // Black player statistics
        black_captures_value.set_text(stats.black_captures.to_string());
        black_promotions_value.set_text(stats.black_promotions.to_string());
        black_moves_value.set_text(stats.black_moves.to_string());
        black_pieces_remaining_value.set_text(count_pieces_for_player(final_state, Player.BLACK).to_string());
    }

    /**
     * Count remaining pieces for a player
     */
    private int count_pieces_for_player(DraughtsGameState state, Player player) {
        int count = 0;
        foreach (var piece in state.pieces) {
            // Convert Player enum to PieceColor enum
            PieceColor piece_color = (player == Player.RED) ? PieceColor.RED : PieceColor.BLACK;
            if (piece.color == piece_color) {
                count++;
            }
        }
        return count;
    }
}

/**
 * Game statistics data structure
 */
public class Draughts.GameStatistics : Object {
    public int total_moves { get; set; default = 0; }
    public double game_duration_seconds { get; set; default = 0.0; }

    public int red_captures { get; set; default = 0; }
    public int red_promotions { get; set; default = 0; }
    public int red_moves { get; set; default = 0; }

    public int black_captures { get; set; default = 0; }
    public int black_promotions { get; set; default = 0; }
    public int black_moves { get; set; default = 0; }

    public GameStatistics() {
        Object();
    }

    /**
     * Calculate statistics from move count and game duration
     */
    public void calculate_basic_stats(int total_move_count, double duration_seconds) {
        total_moves = total_move_count;
        game_duration_seconds = duration_seconds;

        // Simple approximation: divide moves evenly between players
        red_moves = (total_move_count + 1) / 2;  // Red typically goes first
        black_moves = total_move_count / 2;

        // For now, set default values - these could be calculated from game state analysis
        red_captures = 0;
        red_promotions = 0;
        black_captures = 0;
        black_promotions = 0;
    }
}