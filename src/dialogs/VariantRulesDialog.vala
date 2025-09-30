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
    [GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/variant-rules.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/variant-rules.ui")]
#endif
    public class VariantRulesDialog : Adw.AlertDialog {
        [GtkChild]
        private unowned Adw.ActionRow variant_name_row;
        [GtkChild]
        private unowned Adw.ActionRow board_size_row;
        [GtkChild]
        private unowned Adw.ActionRow piece_count_row;
        [GtkChild]
        private unowned Adw.ActionRow men_movement_row;
        [GtkChild]
        private unowned Adw.ActionRow kings_movement_row;
        [GtkChild]
        private unowned Adw.ActionRow kings_fly_row;
        [GtkChild]
        private unowned Adw.ActionRow men_capture_row;
        [GtkChild]
        private unowned Adw.ActionRow kings_capture_row;
        [GtkChild]
        private unowned Adw.ActionRow mandatory_capture_row;
        [GtkChild]
        private unowned Adw.ActionRow capture_priority_row;
        [GtkChild]
        private unowned Adw.ActionRow multiple_capture_row;
        [GtkChild]
        private unowned Adw.ActionRow promotion_condition_row;
        [GtkChild]
        private unowned Adw.ActionRow promotion_timing_row;

        private Logger logger;

        public VariantRulesDialog() {
            Object();
        }

        construct {
            logger = Logger.get_default();
        }

        public void show_rules_for_variant(string variant, Gtk.Window parent) {
            populate_rules_for_variant(variant);
            present(parent);
        }

        private void populate_rules_for_variant(string variant) {
            VariantRulesInfo rules = get_variant_rules_info(variant);

            variant_name_row.subtitle = rules.name;
            board_size_row.subtitle = rules.board_size;
            piece_count_row.subtitle = rules.piece_count;
            men_movement_row.subtitle = rules.men_movement;
            kings_movement_row.subtitle = rules.kings_movement;
            kings_fly_row.subtitle = rules.kings_fly;
            men_capture_row.subtitle = rules.men_capture;
            kings_capture_row.subtitle = rules.kings_capture;
            mandatory_capture_row.subtitle = rules.mandatory_capture;
            capture_priority_row.subtitle = rules.capture_priority;
            multiple_capture_row.subtitle = rules.multiple_capture;
            promotion_condition_row.subtitle = rules.promotion_condition;
            promotion_timing_row.subtitle = rules.promotion_timing;

            logger.debug("Populated variant rules for: %s", variant);
        }

        private VariantRulesInfo get_variant_rules_info(string variant) {
            switch (variant) {
                case "checkers":
                    return VariantRulesInfo() {
                        name = _("American Checkers (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally forward and backward, one square"),
                        kings_fly = _("No - kings move one square at a time"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, must jump over enemy piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "international":
                    return VariantRulesInfo() {
                        name = _("International Draughts (10×10)"),
                        board_size = _("10×10 board with 100 squares"),
                        piece_count = _("20 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "russian":
                    return VariantRulesInfo() {
                        name = _("Russian Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward and backward, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "brazilian":
                    return VariantRulesInfo() {
                        name = _("Brazilian Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward and backward, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "italian":
                    return VariantRulesInfo() {
                        name = _("Italian Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally forward and backward, one square"),
                        kings_fly = _("No - kings move one square at a time"),
                        men_capture = _("Diagonally forward only, cannot capture kings"),
                        kings_capture = _("Diagonally in any direction, must jump over enemy piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Kings have priority over men in captures"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "spanish":
                    return VariantRulesInfo() {
                        name = _("Spanish Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally forward and backward, one square"),
                        kings_fly = _("No - kings move one square at a time"),
                        men_capture = _("Diagonally forward AND backward - unique to Spanish variant"),
                        kings_capture = _("Diagonally in any direction, must jump over enemy piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Player chooses any legal capture"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "czech":
                    return VariantRulesInfo() {
                        name = _("Czech Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "thai":
                    return VariantRulesInfo() {
                        name = _("Thai Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally forward and backward, one square"),
                        kings_fly = _("No - kings move one square at a time"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, must jump over enemy piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "german":
                    return VariantRulesInfo() {
                        name = _("German Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "swedish":
                    return VariantRulesInfo() {
                        name = _("Swedish Draughts (10×10)"),
                        board_size = _("10×10 board with 100 squares"),
                        piece_count = _("20 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "pool":
                    return VariantRulesInfo() {
                        name = _("Pool Checkers (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally forward and backward, one square"),
                        kings_fly = _("No - kings move one square at a time"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, must jump over enemy piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Player chooses any legal capture"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "turkish":
                    return VariantRulesInfo() {
                        name = _("Turkish Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally forward and backward, one square"),
                        kings_fly = _("No - kings move one square at a time"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, must jump over enemy piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "armenian":
                    return VariantRulesInfo() {
                        name = _("Armenian Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "gothic":
                    return VariantRulesInfo() {
                        name = _("Gothic Draughts (8×8)"),
                        board_size = _("8×8 board with 64 squares"),
                        piece_count = _("12 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally forward and backward, one square"),
                        kings_fly = _("No - kings move one square at a time"),
                        men_capture = _("Diagonally forward only, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, must jump over enemy piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Player chooses any legal capture"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "frisian":
                    return VariantRulesInfo() {
                        name = _("Frisian Draughts (10×10)"),
                        board_size = _("10×10 board with 100 squares"),
                        piece_count = _("20 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward and backward, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                case "canadian":
                    return VariantRulesInfo() {
                        name = _("Canadian Draughts (12×12)"),
                        board_size = _("12×12 board with 144 squares"),
                        piece_count = _("30 pieces per player"),
                        men_movement = _("Diagonally forward only, one square"),
                        kings_movement = _("Diagonally in any direction, any distance"),
                        kings_fly = _("Yes - kings can move multiple squares"),
                        men_capture = _("Diagonally forward and backward, must jump over enemy piece"),
                        kings_capture = _("Diagonally in any direction, can land anywhere after jumped piece"),
                        mandatory_capture = _("Yes - must capture if possible"),
                        capture_priority = _("Maximum number of pieces must be captured"),
                        multiple_capture = _("Yes - continue jumping with same piece if possible"),
                        promotion_condition = _("Reach opposite end of board"),
                        promotion_timing = _("Immediately when reaching promotion square")
                    };

                default: // Fallback to International
                    return get_variant_rules_info("international");
            }
        }
    }

    private struct VariantRulesInfo {
        public string name;
        public string board_size;
        public string piece_count;
        public string men_movement;
        public string kings_movement;
        public string kings_fly;
        public string men_capture;
        public string kings_capture;
        public string mandatory_capture;
        public string capture_priority;
        public string multiple_capture;
        public string promotion_condition;
        public string promotion_timing;
    }
}