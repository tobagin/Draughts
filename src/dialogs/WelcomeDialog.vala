/**
 * WelcomeDialog.vala
 *
 * First-run welcome dialog that introduces users to the game
 * and provides quick start information.
 */

using Draughts;

#if DEVELOPMENT
[GtkTemplate (ui = "/io/github/tobagin/Draughts/Devel/dialogs/welcome.ui")]
#else
[GtkTemplate (ui = "/io/github/tobagin/Draughts/dialogs/welcome.ui")]
#endif
public class Draughts.WelcomeDialog : Adw.Window {
    [GtkChild]
    private unowned Gtk.Button start_button;

    [GtkChild]
    private unowned Gtk.CheckButton show_on_startup;

    private Logger logger = Logger.get_default();
    private SettingsManager settings;

    public signal void ready_to_play();

    public WelcomeDialog() {
        settings = SettingsManager.get_instance();
        setup_ui();
    }

    /**
     * Show the welcome dialog if it's first run or if user enabled it
     */
    public static void show_if_needed(Gtk.Window parent) {
        var settings = SettingsManager.get_instance();

        // Check if we should show welcome dialog
        if (settings.is_first_run() || settings.get_show_welcome()) {
            var dialog = new WelcomeDialog();
            dialog.transient_for = parent;
            dialog.modal = true;
            dialog.present();
        }
    }

    /**
     * Force show the welcome dialog (for menu item)
     */
    public static void show_dialog(Gtk.Window parent) {
        var dialog = new WelcomeDialog();
        dialog.transient_for = parent;
        dialog.modal = true;
        dialog.present();
    }

    /**
     * Setup UI components
     */
    private void setup_ui() {
        // Load current setting
        show_on_startup.active = settings.get_show_welcome();

        // Start button
        start_button.clicked.connect(() => {
            // Save preference
            settings.set_show_welcome(show_on_startup.active);

            // Mark first run as complete if needed
            if (settings.is_first_run()) {
                settings.set_first_run_complete();
            }

            ready_to_play();
            close();
        });

        // Handle window close
        close_request.connect(() => {
            // Save preference even if user closes without clicking start
            settings.set_show_welcome(show_on_startup.active);

            if (settings.is_first_run()) {
                settings.set_first_run_complete();
            }

            return false;
        });

        logger.debug("Welcome dialog initialized");
    }
}
