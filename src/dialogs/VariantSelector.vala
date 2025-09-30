/**
 * VariantSelector.vala
 *
 * Dialog for selecting draughts game variants with detailed descriptions,
 * board size information, and preview features.
 */

using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/variant-selector.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/variant-selector.ui")]
#endif
public class Draughts.VariantSelector : Adw.Window {
    [GtkChild]
    private unowned Adw.HeaderBar header_bar;

    [GtkChild]
    private unowned Gtk.ListBox variant_list;

    [GtkChild]
    private unowned Gtk.ScrolledWindow description_scroll;

    [GtkChild]
    private unowned Gtk.Label variant_name_label;

    [GtkChild]
    private unowned Gtk.Label board_size_label;

    [GtkChild]
    private unowned Gtk.Label piece_count_label;

    [GtkChild]
    private unowned Gtk.Label description_label;

    [GtkChild]
    private unowned Gtk.Label rules_summary_label;

    [GtkChild]
    private unowned Gtk.Button select_button;

    [GtkChild]
    private unowned Gtk.Button cancel_button;

    // Currently selected variant
    private DraughtsVariant selected_variant = DraughtsVariant.AMERICAN;
    private GameVariant[] available_variants;

    // Signals
    public signal void variant_selected(DraughtsVariant variant);

    public VariantSelector() {
        setup_variants();
        setup_ui();
        select_default_variant();
    }

    /**
     * Show the dialog and return selected variant
     */
    public static void show_dialog(Gtk.Window parent, DraughtsVariant current_variant, owned VariantSelectedCallback callback) {
        var dialog = new VariantSelector();
        dialog.transient_for = parent;
        dialog.modal = true;
        dialog.selected_variant = current_variant;

        dialog.variant_selected.connect((variant) => {
            callback(variant);
            dialog.close();
        });

        dialog.present();
    }

    /**
     * Setup available variants
     */
    private void setup_variants() {
        available_variants = GameVariant.get_all_variants();
    }

    /**
     * Setup UI components
     */
    private void setup_ui() {
        // Setup variant list
        setup_variant_list();

        // Setup button handlers
        select_button.clicked.connect(() => {
            variant_selected(selected_variant);
        });

        cancel_button.clicked.connect(() => {
            close();
        });

        // Handle window close
        close_request.connect(() => {
            return false; // Allow closing
        });
    }

    /**
     * Setup the variant list
     */
    private void setup_variant_list() {
        variant_list.selection_mode = Gtk.SelectionMode.SINGLE;

        foreach (var variant_info in available_variants) {
            var row = create_variant_row(variant_info);
            variant_list.append(row);
        }

        // Handle selection changes
        variant_list.row_selected.connect(on_variant_row_selected);
    }

    /**
     * Create a row for a variant
     */
    private Gtk.ListBoxRow create_variant_row(GameVariant variant_info) {
        var row = new Gtk.ListBoxRow();
        row.set_data("variant", variant_info.variant);

        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        box.margin_start = 12;
        box.margin_end = 12;
        box.margin_top = 8;
        box.margin_bottom = 8;

        // Variant icon/flag (if available)
        var icon = new Gtk.Image();
        icon.icon_name = get_variant_icon(variant_info.variant);
        icon.icon_size = Gtk.IconSize.LARGE;
        box.append(icon);

        // Variant info
        var info_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
        info_box.hexpand = true;
        info_box.halign = Gtk.Align.START;

        var name_label = new Gtk.Label(variant_info.display_name);
        name_label.halign = Gtk.Align.START;
        name_label.add_css_class("heading");
        info_box.append(name_label);

        var size_info = @"$(variant_info.board_size)×$(variant_info.board_size) board, $(variant_info.initial_piece_count) pieces per player";
        var size_label = new Gtk.Label(size_info);
        size_label.halign = Gtk.Align.START;
        size_label.add_css_class("caption");
        size_label.add_css_class("dim-label");
        info_box.append(size_label);

        box.append(info_box);

        // Popularity/difficulty indicator
        var indicator_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
        indicator_box.valign = Gtk.Align.CENTER;

        var popularity = get_variant_popularity(variant_info.variant);
        var popularity_label = new Gtk.Label(popularity);
        popularity_label.add_css_class("caption");
        popularity_label.add_css_class("accent");
        indicator_box.append(popularity_label);

        box.append(indicator_box);

        row.child = box;
        return row;
    }

    /**
     * Handle variant row selection
     */
    private void on_variant_row_selected(Gtk.ListBoxRow? row) {
        if (row == null) return;

        var variant = (DraughtsVariant)row.get_data<DraughtsVariant>("variant");
        selected_variant = variant;

        update_variant_description(variant);
        select_button.sensitive = true;
    }

    /**
     * Update the variant description panel
     */
    private void update_variant_description(DraughtsVariant variant) {
        var variant_info = get_variant_info(variant);

        variant_name_label.label = variant_info.display_name;
        board_size_label.label = @"$(variant_info.board_size) × $(variant_info.board_size)";
        piece_count_label.label = @"$(variant_info.initial_piece_count) per player";

        description_label.label = get_variant_description(variant);
        rules_summary_label.label = get_variant_rules_summary(variant);
    }

    /**
     * Select default variant
     */
    private void select_default_variant() {
        // Find and select the row for the current variant
        for (int i = 0; i < available_variants.length; i++) {
            if (available_variants[i].variant == selected_variant) {
                var row = variant_list.get_row_at_index(i);
                if (row != null) {
                    variant_list.select_row(row);
                    break;
                }
            }
        }
    }

    /**
     * Get variant info by variant enum
     */
    private GameVariant get_variant_info(DraughtsVariant variant) {
        foreach (var info in available_variants) {
            if (info.variant == variant) {
                return info;
            }
        }
        return available_variants[0]; // Fallback
    }

    /**
     * Get icon for variant
     */
    private string get_variant_icon(DraughtsVariant variant) {
        switch (variant) {
            case DraughtsVariant.AMERICAN:
                return "flag-usa-symbolic";
            case DraughtsVariant.INTERNATIONAL:
                return "globe-symbolic";
            case DraughtsVariant.RUSSIAN:
                return "flag-russia-symbolic";
            case DraughtsVariant.BRAZILIAN:
                return "flag-brazil-symbolic";
            case DraughtsVariant.ITALIAN:
                return "flag-italy-symbolic";
            case DraughtsVariant.SPANISH:
                return "flag-spain-symbolic";
            case DraughtsVariant.GERMAN:
                return "flag-germany-symbolic";
            case DraughtsVariant.SWEDISH:
                return "flag-sweden-symbolic";
            case DraughtsVariant.TURKISH:
                return "flag-turkey-symbolic";
            default:
                return "games-symbolic";
        }
    }

    /**
     * Get popularity indicator for variant
     */
    private string get_variant_popularity(DraughtsVariant variant) {
        switch (variant) {
            case DraughtsVariant.AMERICAN:
            case DraughtsVariant.INTERNATIONAL:
                return "Popular";
            case DraughtsVariant.RUSSIAN:
            case DraughtsVariant.ITALIAN:
                return "Common";
            case DraughtsVariant.BRAZILIAN:
            case DraughtsVariant.SPANISH:
            case DraughtsVariant.GERMAN:
                return "Regional";
            default:
                return "Traditional";
        }
    }

    /**
     * Get detailed description for variant
     */
    private string get_variant_description(DraughtsVariant variant) {
        switch (variant) {
            case DraughtsVariant.AMERICAN:
                return "The most popular variant in North America, also known as Checkers or Anglo-American Draughts. Features an 8×8 board with simple rules and mandatory captures.";

            case DraughtsVariant.INTERNATIONAL:
                return "Also known as International Draughts or Polish Draughts, played on a 10×10 board. This is the official variant for world championships and features complex flying king rules.";

            case DraughtsVariant.RUSSIAN:
                return "Similar to International Draughts but with different capture rules. Men can capture backwards and kings have enhanced movement capabilities.";

            case DraughtsVariant.BRAZILIAN:
                return "A variant of International Draughts popular in Brazil. Features the same 8×8 board as American Checkers but with international-style rules.";

            case DraughtsVariant.ITALIAN:
                return "Traditional Italian variant played since the Renaissance. Men cannot capture kings, and kings move only one square at a time.";

            case DraughtsVariant.SPANISH:
                return "Similar to International Draughts with some unique rules. Men can capture backwards and promote to kings on the last row.";

            case DraughtsVariant.CZECH:
                return "Central European variant with its own distinct rules for captures and king movement.";

            case DraughtsVariant.THAI:
                return "Traditional Southeast Asian variant with unique board setup and movement rules.";

            case DraughtsVariant.GERMAN:
                return "German variant featuring traditional European draughts rules with regional modifications.";

            case DraughtsVariant.SWEDISH:
                return "Scandinavian variant with traditional Nordic draughts conventions.";

            case DraughtsVariant.POOL:
                return "American Pool Checkers, a variant of American Checkers with modified rules for competitive play.";

            case DraughtsVariant.TURKISH:
                return "Traditional Turkish variant with unique movement patterns and capture rules.";

            case DraughtsVariant.ARMENIAN:
                return "Armenian traditional draughts with regional rule variations.";

            case DraughtsVariant.GOTHIC:
                return "Historical variant based on medieval draughts rules.";

            case DraughtsVariant.FRISIAN:
                return "Dutch regional variant from Frisia, played on a 10×10 board with unique rules.";

            case DraughtsVariant.CANADIAN:
                return "Large board variant played on a 12×12 board, offering extended gameplay and strategic depth.";

            default:
                return "Traditional draughts variant with regional rule modifications.";
        }
    }

    /**
     * Get rules summary for variant
     */
    private string get_variant_rules_summary(DraughtsVariant variant) {
        var info = get_variant_info(variant);
        var summary = new StringBuilder();

        summary.append_printf("• Board: %d×%d squares\n", info.board_size, info.board_size);
        summary.append_printf("• Pieces: %d per player\n", info.initial_piece_count);

        switch (variant) {
            case DraughtsVariant.AMERICAN:
                summary.append("• Men move and capture diagonally forward\n");
                summary.append("• Kings move and capture in all diagonal directions\n");
                summary.append("• Mandatory captures, longest sequence required\n");
                break;

            case DraughtsVariant.INTERNATIONAL:
                summary.append("• Men move forward, capture in all directions\n");
                summary.append("• Flying kings with long-range movement\n");
                summary.append("• Majority capture rule applies\n");
                break;

            case DraughtsVariant.RUSSIAN:
                summary.append("• Men can capture backwards\n");
                summary.append("• Kings move multiple squares\n");
                summary.append("• Capture priority rules apply\n");
                break;

            case DraughtsVariant.ITALIAN:
                summary.append("• Men cannot capture kings\n");
                summary.append("• Kings move one square at a time\n");
                summary.append("• Traditional Italian capture rules\n");
                break;

            default:
                summary.append("• Regional rule variations\n");
                summary.append("• Traditional draughts gameplay\n");
                break;
        }

        return summary.str;
    }

    /**
     * Set the currently selected variant
     */
    public void set_selected_variant(DraughtsVariant variant) {
        selected_variant = variant;
        select_default_variant();
    }

    /**
     * Get the currently selected variant
     */
    public DraughtsVariant get_selected_variant() {
        return selected_variant;
    }
}

/**
 * Callback delegate for variant selection
 */
public delegate void VariantSelectedCallback(DraughtsVariant variant);