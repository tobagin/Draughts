/**
 * GamePreferences.vala
 *
 * Comprehensive game preferences dialog for configuring draughts game settings,
 * AI opponents, timers, board themes, and accessibility options.
 */

using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/game-preferences.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/game-preferences.ui")]
#endif
public class Draughts.GamePreferences : Adw.PreferencesDialog {
    // Game Settings
    [GtkChild]
    private unowned Adw.ComboRow default_variant_row;

    [GtkChild]
    private unowned Adw.SwitchRow show_legal_moves_row;

    [GtkChild]
    private unowned Adw.SwitchRow animate_moves_row;

    [GtkChild]
    private unowned Adw.SwitchRow sound_effects_row;

    [GtkChild]
    private unowned Adw.ComboRow interaction_mode_row;

    // AI Settings
    [GtkChild]
    private unowned Adw.ComboRow ai_difficulty_row;

    [GtkChild]
    private unowned Adw.SpinRow ai_thinking_time_row;

    [GtkChild]
    private unowned Adw.SwitchRow show_ai_thinking_row;

    [GtkChild]
    private unowned Adw.SwitchRow ai_progress_indicator_row;

    // Timer Settings
    [GtkChild]
    private unowned Adw.ComboRow default_timer_mode_row;

    [GtkChild]
    private unowned Adw.SpinRow countdown_minutes_row;

    [GtkChild]
    private unowned Adw.SpinRow fischer_increment_row;

    [GtkChild]
    private unowned Adw.SpinRow delay_seconds_row;

    [GtkChild]
    private unowned Adw.SwitchRow timer_warnings_row;

    [GtkChild]
    private unowned Adw.SwitchRow timer_sounds_row;

    // Display Settings
    [GtkChild]
    private unowned Adw.ComboRow board_theme_row;

    [GtkChild]
    private unowned Adw.ComboRow piece_style_row;

    [GtkChild]
    private unowned Adw.SwitchRow show_coordinates_row;

    [GtkChild]
    private unowned Adw.SwitchRow highlight_last_move_row;

    [GtkChild]
    private unowned Adw.SwitchRow show_move_history_row;

    // Accessibility Settings
    [GtkChild]
    private unowned Adw.SwitchRow high_contrast_row;

    [GtkChild]
    private unowned Adw.SwitchRow large_pieces_row;

    [GtkChild]
    private unowned Adw.SwitchRow screen_reader_row;

    [GtkChild]
    private unowned Adw.SwitchRow keyboard_navigation_row;

    [GtkChild]
    private unowned Adw.ComboRow move_announcement_row;

    // Settings storage
    private SettingsManager? settings_manager;

    public GamePreferences() {
        setup_preference_models();
        load_current_settings();
        connect_signals();
    }

    /**
     * Setup dropdown models and options
     */
    private void setup_preference_models() {
        setup_variant_model();
        setup_ai_difficulty_model();
        setup_timer_mode_model();
        setup_interaction_mode_model();
        setup_theme_models();
        setup_accessibility_models();
    }

    /**
     * Setup variant selection model
     */
    private void setup_variant_model() {
        var variant_model = new Gtk.StringList(null);
        var variants = GameVariant.get_all_variants();

        foreach (var variant in variants) {
            variant_model.append(variant.display_name);
        }

        default_variant_row.model = variant_model;
    }

    /**
     * Setup AI difficulty model
     */
    private void setup_ai_difficulty_model() {
        var difficulty_model = new Gtk.StringList(null);

        string[] difficulties = {
            "Beginner",
            "Easy",
            "Medium",
            "Hard",
            "Expert",
            "Master",
            "Grandmaster"
        };

        foreach (string difficulty in difficulties) {
            difficulty_model.append(difficulty);
        }

        ai_difficulty_row.model = difficulty_model;
    }

    /**
     * Setup timer mode model
     */
    private void setup_timer_mode_model() {
        var timer_model = new Gtk.StringList(null);

        string[] modes = {
            "Untimed",
            "Countdown Timer",
            "Fischer Increment",
            "Delay Timer"
        };

        foreach (string mode in modes) {
            timer_model.append(mode);
        }

        default_timer_mode_row.model = timer_model;
    }

    /**
     * Setup interaction mode model
     */
    private void setup_interaction_mode_model() {
        var interaction_model = new Gtk.StringList(null);

        interaction_model.append("Click to Select");
        interaction_model.append("Drag and Drop");

        interaction_mode_row.model = interaction_model;
    }

    /**
     * Setup theme models
     */
    private void setup_theme_models() {
        // Board themes
        var theme_model = new Gtk.StringList(null);
        string[] themes = {
            "Classic Brown",
            "Wood",
            "Green",
            "Blue",
            "High Contrast",
            "Dark Mode"
        };

        foreach (string theme in themes) {
            theme_model.append(theme);
        }

        board_theme_row.model = theme_model;

        // Piece styles
        var piece_model = new Gtk.StringList(null);
        string[] styles = {
            "Classic",
            "Modern",
            "Wooden",
            "Flat Design",
            "High Contrast"
        };

        foreach (string style in styles) {
            piece_model.append(style);
        }

        piece_style_row.model = piece_model;
    }

    /**
     * Setup accessibility models
     */
    private void setup_accessibility_models() {
        var announcement_model = new Gtk.StringList(null);

        string[] modes = {
            "Off",
            "Move Only",
            "Move and Capture",
            "Full Description"
        };

        foreach (string mode in modes) {
            announcement_model.append(mode);
        }

        move_announcement_row.model = announcement_model;
    }

    /**
     * Load current settings into UI
     */
    private void load_current_settings() {
        if (settings_manager == null) {
            settings_manager = SettingsManager.get_default();
        }

        // Load game settings
        default_variant_row.selected = get_variant_index(settings_manager.get_default_variant());
        show_legal_moves_row.active = settings_manager.get_show_legal_moves();
        animate_moves_row.active = settings_manager.get_animate_moves();
        sound_effects_row.active = settings_manager.get_sound_effects();
        interaction_mode_row.selected = settings_manager.get_interaction_mode() == InteractionMode.DRAG_AND_DROP ? 1 : 0;

        // Load AI settings
        ai_difficulty_row.selected = (uint)settings_manager.get_ai_difficulty();
        ai_thinking_time_row.value = settings_manager.get_ai_thinking_time();
        show_ai_thinking_row.active = settings_manager.get_show_ai_thinking();
        ai_progress_indicator_row.active = settings_manager.get_ai_progress_indicator();

        // Load timer settings
        default_timer_mode_row.selected = (uint)settings_manager.get_default_timer_mode();
        countdown_minutes_row.value = settings_manager.get_countdown_minutes();
        fischer_increment_row.value = settings_manager.get_fischer_increment();
        delay_seconds_row.value = settings_manager.get_delay_seconds();
        timer_warnings_row.active = settings_manager.get_timer_warnings();
        timer_sounds_row.active = settings_manager.get_timer_sounds();

        // Load display settings
        board_theme_row.selected = get_theme_index(settings_manager.get_board_theme());
        piece_style_row.selected = get_piece_style_index(settings_manager.get_piece_style());
        show_coordinates_row.active = settings_manager.get_show_coordinates();
        highlight_last_move_row.active = settings_manager.get_highlight_last_move();
        show_move_history_row.active = settings_manager.get_show_move_history();

        // Load accessibility settings
        high_contrast_row.active = settings_manager.get_high_contrast();
        large_pieces_row.active = settings_manager.get_large_pieces();
        screen_reader_row.active = settings_manager.get_screen_reader_support();
        keyboard_navigation_row.active = settings_manager.get_keyboard_navigation();
        move_announcement_row.selected = (uint)settings_manager.get_move_announcement_mode();
    }

    /**
     * Connect preference change signals
     */
    private void connect_signals() {
        if (settings_manager == null) return;

        // Game settings
        default_variant_row.notify["selected"].connect(() => {
            var variants = GameVariant.get_all_variants();
            if (default_variant_row.selected < variants.length) {
                settings_manager.set_default_variant(variants[default_variant_row.selected].variant);
            }
        });

        show_legal_moves_row.notify["active"].connect(() => {
            settings_manager.set_show_legal_moves(show_legal_moves_row.active);
        });

        animate_moves_row.notify["active"].connect(() => {
            settings_manager.set_animate_moves(animate_moves_row.active);
        });

        sound_effects_row.notify["active"].connect(() => {
            settings_manager.set_sound_effects(sound_effects_row.active);
        });

        interaction_mode_row.notify["selected"].connect(() => {
            var mode = interaction_mode_row.selected == 1 ? InteractionMode.DRAG_AND_DROP : InteractionMode.CLICK_TO_SELECT;
            settings_manager.set_interaction_mode(mode);
        });

        // AI settings
        ai_difficulty_row.notify["selected"].connect(() => {
            var difficulties = new AIDifficulty[] {
                AIDifficulty.BEGINNER,
                AIDifficulty.EASY,
                AIDifficulty.MEDIUM,
                AIDifficulty.HARD,
                AIDifficulty.EXPERT,
                AIDifficulty.MASTER,
                AIDifficulty.GRANDMASTER
            };
            if (ai_difficulty_row.selected < difficulties.length) {
                settings_manager.set_ai_difficulty(difficulties[ai_difficulty_row.selected]);
            }
        });

        ai_thinking_time_row.notify["value"].connect(() => {
            settings_manager.set_ai_thinking_time((int)ai_thinking_time_row.value);
        });

        show_ai_thinking_row.notify["active"].connect(() => {
            settings_manager.set_show_ai_thinking(show_ai_thinking_row.active);
        });

        // Timer settings
        default_timer_mode_row.notify["selected"].connect(() => {
            var modes = new TimerMode[] {
                TimerMode.UNTIMED,
                TimerMode.COUNTDOWN,
                TimerMode.FISCHER_INCREMENT,
                TimerMode.DELAY
            };
            if (default_timer_mode_row.selected < modes.length) {
                settings_manager.set_default_timer_mode(modes[default_timer_mode_row.selected]);
            }
        });

        countdown_minutes_row.notify["value"].connect(() => {
            settings_manager.set_countdown_minutes((int)countdown_minutes_row.value);
        });

        fischer_increment_row.notify["value"].connect(() => {
            settings_manager.set_fischer_increment((int)fischer_increment_row.value);
        });

        timer_warnings_row.notify["active"].connect(() => {
            settings_manager.set_timer_warnings(timer_warnings_row.active);
        });

        // Display settings
        board_theme_row.notify["selected"].connect(() => {
            string[] themes = { "classic", "wood", "green", "blue", "contrast", "dark" };
            if (board_theme_row.selected < themes.length) {
                settings_manager.set_board_theme(themes[board_theme_row.selected]);
            }
        });

        show_coordinates_row.notify["active"].connect(() => {
            settings_manager.set_show_coordinates(show_coordinates_row.active);
        });

        highlight_last_move_row.notify["active"].connect(() => {
            settings_manager.set_highlight_last_move(highlight_last_move_row.active);
        });

        // Accessibility settings
        high_contrast_row.notify["active"].connect(() => {
            settings_manager.set_high_contrast(high_contrast_row.active);
        });

        large_pieces_row.notify["active"].connect(() => {
            settings_manager.set_large_pieces(large_pieces_row.active);
        });

        screen_reader_row.notify["active"].connect(() => {
            settings_manager.set_screen_reader_support(screen_reader_row.active);
        });

        keyboard_navigation_row.notify["active"].connect(() => {
            settings_manager.set_keyboard_navigation(keyboard_navigation_row.active);
        });
    }

    /**
     * Get index for variant in dropdown
     */
    private uint get_variant_index(DraughtsVariant variant) {
        var variants = GameVariant.get_all_variants();
        for (int i = 0; i < variants.length; i++) {
            if (variants[i].variant == variant) {
                return i;
            }
        }
        return 0;
    }

    /**
     * Get index for theme in dropdown
     */
    private uint get_theme_index(string theme) {
        string[] themes = { "classic", "wood", "green", "blue", "contrast", "dark" };
        for (int i = 0; i < themes.length; i++) {
            if (themes[i] == theme) {
                return i;
            }
        }
        return 0;
    }

    /**
     * Get index for piece style in dropdown
     */
    private uint get_piece_style_index(string style) {
        string[] styles = { "classic", "modern", "wooden", "flat", "contrast" };
        for (int i = 0; i < styles.length; i++) {
            if (styles[i] == style) {
                return i;
            }
        }
        return 0;
    }

    /**
     * Reset all preferences to defaults
     */
    public void reset_to_defaults() {
        if (settings_manager == null) return;

        settings_manager.reset_to_defaults();
        load_current_settings();
    }

    /**
     * Export preferences to file
     */
    public void export_preferences() {
        if (settings_manager == null) return;

        var dialog = new Gtk.FileDialog();
        dialog.title = "Export Preferences";
        dialog.initial_name = "draughts_preferences.json";

        dialog.save.begin(this.get_root() as Gtk.Window, null, (obj, res) => {
            try {
                var file = dialog.save.end(res);
                if (file != null) {
                    settings_manager.export_to_file(file);
                }
            } catch (Error e) {
                warning("Error exporting preferences: %s", e.message);
            }
        });
    }

    /**
     * Import preferences from file
     */
    public void import_preferences() {
        if (settings_manager == null) return;

        var dialog = new Gtk.FileDialog();
        dialog.title = "Import Preferences";

        dialog.open.begin(this.get_root() as Gtk.Window, null, (obj, res) => {
            try {
                var file = dialog.open.end(res);
                if (file != null) {
                    settings_manager.import_from_file(file);
                    load_current_settings();
                }
            } catch (Error e) {
                warning("Error importing preferences: %s", e.message);
            }
        });
    }

    /**
     * Show the preferences dialog
     */
    public static void show_preferences(Gtk.Window parent) {
        var preferences = new GamePreferences();
        preferences.present(parent);
    }
}