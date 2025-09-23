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

    public class Logger : GLib.Object {
        private static Once<Logger> _once = Once<Logger>();

        private string log_domain;

        private Logger() {
            log_domain = Config.ID;
        }

        public static Logger get_default() {
            return _once.once(() => {
                return new Logger();
            });
        }

        public void debug(string format, ...) {
            var args = va_list();
            var message = format.vprintf(args);
            GLib.log_structured(log_domain, GLib.LogLevelFlags.LEVEL_DEBUG,
                "MESSAGE", message,
                "MESSAGE_ID", "debug");
        }

        public void info(string format, ...) {
            var args = va_list();
            var message = format.vprintf(args);
            GLib.log_structured(log_domain, GLib.LogLevelFlags.LEVEL_INFO,
                "MESSAGE", message,
                "MESSAGE_ID", "info");
        }

        public void warning(string format, ...) {
            var args = va_list();
            var message = format.vprintf(args);
            GLib.log_structured(log_domain, GLib.LogLevelFlags.LEVEL_WARNING,
                "MESSAGE", message,
                "MESSAGE_ID", "warning");
        }

        public void error(string format, ...) {
            var args = va_list();
            var message = format.vprintf(args);
            GLib.log_structured(log_domain, GLib.LogLevelFlags.LEVEL_ERROR,
                "MESSAGE", message,
                "MESSAGE_ID", "error");
        }

        public void critical(string format, ...) {
            var args = va_list();
            var message = format.vprintf(args);
            GLib.log_structured(log_domain, GLib.LogLevelFlags.LEVEL_CRITICAL,
                "MESSAGE", message,
                "MESSAGE_ID", "critical");
        }
    }
}