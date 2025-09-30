/**
 * HelpDialog.vala
 *
 * Comprehensive in-app help system with multiple sections:
 * - Getting Started guide
 * - Game variants information
 * - Keyboard shortcuts
 * - About information
 */

using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/help.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/help.ui")]
#endif
public class Draughts.HelpDialog : Adw.Window {
    [GtkChild]
    private unowned Adw.ViewStack view_stack;

    private Logger logger = Logger.get_default();

    public HelpDialog() {
        setup_ui();
    }

    /**
     * Show the help dialog
     */
    public static void show_dialog(Gtk.Window parent, string? page = null) {
        var dialog = new HelpDialog();
        dialog.transient_for = parent;
        dialog.modal = true;

        if (page != null) {
            dialog.view_stack.visible_child_name = page;
        }

        dialog.present();
    }

    /**
     * Setup UI components
     */
    private void setup_ui() {
        // Handle window close request
        close_request.connect(() => {
            return false; // Allow close
        });

        logger.debug("Help dialog initialized");
    }

    /**
     * Show specific help page
     */
    public void show_page(string page_name) {
        view_stack.visible_child_name = page_name;
    }
}
