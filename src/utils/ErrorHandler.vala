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

namespace Draughts {

    public enum ErrorSeverity {
        INFO,
        WARNING,
        ERROR,
        CRITICAL
    }

    public class ErrorHandler : GLib.Object {
        private static ErrorHandler? instance;
        private Draughts.Logger logger;
        private weak Gtk.Window? main_window;
        private weak Adw.ToastOverlay? toast_overlay;

        public static ErrorHandler get_instance () {
            if (instance == null) {
                instance = new ErrorHandler ();
            }
            return instance;
        }

        private ErrorHandler () {
            logger = Logger.get_default();
        }

        public void set_main_window (Gtk.Window window) {
            main_window = window;
            logger.debug ("Main window set for error handling");
        }

        public void set_toast_overlay (Adw.ToastOverlay overlay) {
            toast_overlay = overlay;
            logger.debug ("Toast overlay set for error notifications");
        }

        public void handle_error (GLib.Error error, string context = "", ErrorSeverity severity = ErrorSeverity.ERROR) {
            string full_message = context.length > 0 ? @"$context: $(error.message)" : error.message;

            switch (severity) {
                case ErrorSeverity.INFO:
                    logger.info (full_message);
                    show_toast (full_message, Adw.ToastPriority.NORMAL);
                    break;
                case ErrorSeverity.WARNING:
                    logger.warning (full_message);
                    show_toast (full_message, Adw.ToastPriority.HIGH);
                    break;
                case ErrorSeverity.ERROR:
                    logger.error (full_message);
                    show_error_dialog (full_message);
                    break;
                case ErrorSeverity.CRITICAL:
                    logger.critical (full_message);
                    show_critical_error_dialog (full_message);
                    break;
            }
        }

        public void handle_message (string message, string context = "", ErrorSeverity severity = ErrorSeverity.INFO) {
            string full_message = context.length > 0 ? @"$context: $message" : message;

            switch (severity) {
                case ErrorSeverity.INFO:
                    logger.info (full_message);
                    show_toast (full_message, Adw.ToastPriority.NORMAL);
                    break;
                case ErrorSeverity.WARNING:
                    logger.warning (full_message);
                    show_toast (full_message, Adw.ToastPriority.HIGH);
                    break;
                case ErrorSeverity.ERROR:
                    logger.error (full_message);
                    show_error_dialog (full_message);
                    break;
                case ErrorSeverity.CRITICAL:
                    logger.critical (full_message);
                    show_critical_error_dialog (full_message);
                    break;
            }
        }

        private void show_toast (string message, Adw.ToastPriority priority = Adw.ToastPriority.NORMAL) {
            if (toast_overlay != null) {
                var toast = new Adw.Toast (message) {
                    priority = priority,
                    timeout = 3
                };
                toast_overlay.add_toast (toast);
                logger.debug ("Toast notification shown: %s", message);
            } else {
                logger.warning ("No toast overlay available for notification: %s", message);
            }
        }

        private void show_error_dialog (string message) {
            if (main_window != null && !main_window.in_destruction ()) {
                var dialog = new Adw.AlertDialog (_("Error"), message);
                dialog.add_response ("ok", _("OK"));
                dialog.set_response_appearance ("ok", Adw.ResponseAppearance.DEFAULT);
                dialog.present (main_window);
                logger.debug ("Error dialog shown: %s", message);
            } else {
                // Fallback to toast if no main window
                show_toast (message, Adw.ToastPriority.HIGH);
            }
        }

        private void show_critical_error_dialog (string message) {
            if (main_window != null && !main_window.in_destruction ()) {
                var dialog = new Adw.AlertDialog (_("Critical Error"), message);
                dialog.add_response ("ok", _("OK"));
                dialog.add_response ("quit", _("Quit Application"));
                dialog.set_response_appearance ("ok", Adw.ResponseAppearance.DEFAULT);
                dialog.set_response_appearance ("quit", Adw.ResponseAppearance.DESTRUCTIVE);
                dialog.set_default_response ("ok");
                dialog.set_close_response ("ok");

                dialog.response.connect ((response) => {
                    if (response == "quit") {
                        var app = GLib.Application.get_default ();
                        if (app != null) {
                            app.quit ();
                        }
                    }
                    // Suppress unused variable warning by referencing self
                    assert(this != null);
                });

                dialog.present (main_window);
                logger.debug ("Critical error dialog shown: %s", message);
            } else {
                // Fallback behavior for critical errors without main window
                logger.critical ("Critical error occurred but no main window available: %s", message);
                var app = GLib.Application.get_default ();
                if (app != null) {
                    app.quit ();
                }
            }
        }

        public void show_confirmation_dialog (string title, string message, owned ConfirmationCallback callback) {
            if (main_window != null && !main_window.in_destruction ()) {
                var dialog = new Adw.AlertDialog (title, message);
                dialog.add_response ("cancel", _("Cancel"));
                dialog.add_response ("confirm", _("Confirm"));
                dialog.set_response_appearance ("cancel", Adw.ResponseAppearance.DEFAULT);
                dialog.set_response_appearance ("confirm", Adw.ResponseAppearance.SUGGESTED);
                dialog.set_default_response ("confirm");
                dialog.set_close_response ("cancel");

                dialog.response.connect ((response) => {
                    callback (response == "confirm");
                });

                dialog.present (main_window);
                logger.debug ("Confirmation dialog shown: %s", title);
            } else {
                logger.warning ("No main window available for confirmation dialog");
                callback (false);
            }
        }

        public void show_info_toast (string message) {
            handle_message (message, "", ErrorSeverity.INFO);
        }

        public void show_warning_toast (string message) {
            handle_message (message, "", ErrorSeverity.WARNING);
        }

        public void show_success_toast (string message) {
            show_toast (message, Adw.ToastPriority.NORMAL);
            logger.info ("Success: %s", message);
        }

        // Callback delegate for confirmation dialogs
        public delegate void ConfirmationCallback (bool confirmed);
    }
}