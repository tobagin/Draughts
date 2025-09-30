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

    public class ResourceManager : GLib.Object {
        private static ResourceManager? instance;
        private Draughts.Logger logger;
        private HashTable<string, Bytes> resource_cache;
        private HashTable<string, Gdk.Pixbuf> pixbuf_cache;
        private HashTable<string, Gdk.Texture> texture_cache;
        private string resource_base_path;

        // Game asset directories
        private string pieces_path;
        private string boards_path;
        private string themes_path;
        private string sounds_path;
        private string icons_path;

        public static ResourceManager get_instance () {
            if (instance == null) {
                instance = new ResourceManager ();
            }
            return instance;
        }

        private ResourceManager () {
            logger = Logger.get_default();
            resource_cache = new HashTable<string, Bytes> (str_hash, str_equal);
            pixbuf_cache = new HashTable<string, Gdk.Pixbuf> (str_hash, str_equal);
            texture_cache = new HashTable<string, Gdk.Texture> (str_hash, str_equal);

#if DEVELOPMENT
            resource_base_path = "/io/github/tobagin/Draughts/Devel";
#else
            resource_base_path = "/io/github/tobagin/Draughts";
#endif

            // Initialize asset paths
            pieces_path = @"$resource_base_path/assets/pieces";
            boards_path = @"$resource_base_path/assets/boards";
            themes_path = @"$resource_base_path/assets/themes";
            sounds_path = @"$resource_base_path/assets/sounds";
            icons_path = @"$resource_base_path/assets/icons";

            logger.debug ("ResourceManager initialized with base path: %s", resource_base_path);
        }

        public string get_resource_path (string resource_name) {
            return @"$resource_base_path/$resource_name";
        }

        public string get_ui_resource_path (string ui_file) {
            string base_name = ui_file.has_suffix (".blp") ? ui_file.replace (".blp", ".ui") : ui_file;
            if (!base_name.has_suffix (".ui")) {
                base_name += ".ui";
            }
            return get_resource_path (base_name);
        }

        public Bytes? load_resource (string resource_path, bool use_cache = true) {
            if (use_cache && resource_cache.contains (resource_path)) {
                logger.debug ("Loading resource from cache: %s", resource_path);
                return resource_cache.get (resource_path);
            }

            try {
                var resource = resources_lookup_data (resource_path, ResourceLookupFlags.NONE);

                if (use_cache) {
                    resource_cache.set (resource_path, resource);
                    logger.debug ("Resource loaded and cached: %s", resource_path);
                } else {
                    logger.debug ("Resource loaded (no cache): %s", resource_path);
                }

                return resource;
            } catch (Error e) {
                logger.warning ("Failed to load resource '%s': %s", resource_path, e.message);
                return null;
            }
        }

        public string? load_resource_as_string (string resource_path, bool use_cache = true) {
            var bytes = load_resource (resource_path, use_cache);
            if (bytes == null) {
                return null;
            }

            try {
                return (string) bytes.get_data ();
            } catch (Error e) {
                logger.warning ("Failed to convert resource to string '%s': %s", resource_path, e.message);
                return null;
            }
        }

        public InputStream? load_resource_as_stream (string resource_path) {
            try {
                return resources_open_stream (resource_path, ResourceLookupFlags.NONE);
            } catch (Error e) {
                logger.warning ("Failed to open resource stream '%s': %s", resource_path, e.message);
                return null;
            }
        }

        public bool resource_exists (string resource_path) {
            try {
                resources_lookup_data (resource_path, ResourceLookupFlags.NONE);
                return true;
            } catch (Error e) {
                return false;
            }
        }

        public void preload_ui_resources () {
            string[] ui_files = {
                "window.ui",
                "preferences.ui"
            };

            foreach (string ui_file in ui_files) {
                string resource_path = get_ui_resource_path (ui_file);
                if (resource_exists (resource_path)) {
                    load_resource (resource_path, true);
                    logger.debug ("Preloaded UI resource: %s", resource_path);
                } else {
                    logger.warning ("UI resource not found for preloading: %s", resource_path);
                }
            }
        }

        public Gdk.Texture? load_texture (string image_path) {
            logger.warning ("Texture loading not implemented yet for: %s", image_path);
            return null;
        }

        public Gdk.Pixbuf? load_pixbuf (string image_path, int width = -1, int height = -1) {
            var resource_path = get_resource_path (image_path);
            var stream = load_resource_as_stream (resource_path);

            if (stream == null) {
                logger.warning ("Failed to load image resource: %s", resource_path);
                return null;
            }

            try {
                Gdk.Pixbuf pixbuf;
                if (width > 0 && height > 0) {
                    pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, width, height, true, null);
                } else {
                    pixbuf = new Gdk.Pixbuf.from_stream (stream, null);
                }
                logger.debug ("Pixbuf loaded successfully: %s", resource_path);
                return pixbuf;
            } catch (Error e) {
                logger.warning ("Failed to create pixbuf from resource '%s': %s", resource_path, e.message);
                return null;
            }
        }

        public void clear_cache () {
            resource_cache.remove_all ();
            logger.debug ("Resource cache cleared");
        }

        public void cache_resource (string resource_path, Bytes data) {
            resource_cache.set (resource_path, data);
            logger.debug ("Resource manually cached: %s", resource_path);
        }

        public uint get_cache_size () {
            return resource_cache.size ();
        }

        public string[] get_cached_resources () {
            string[] cached = {};
            var keys = resource_cache.get_keys_as_array ();
            for (int i = 0; i < keys.length; i++) {
                cached += keys[i];
            }
            return cached;
        }

        public void validate_essential_resources () throws Error {
            string[] essential_resources = {
                get_ui_resource_path ("window.ui"),
                get_ui_resource_path ("preferences.ui")
            };

            foreach (string resource_path in essential_resources) {
                if (!resource_exists (resource_path)) {
                    throw new IOError.NOT_FOUND ("Essential resource missing: %s", resource_path);
                }
            }

            logger.info ("All essential resources validated successfully");
        }

        // ===== ENHANCED GAME ASSET MANAGEMENT =====

        /**
         * Load piece pixbuf for specific color and type
         */
        public Gdk.Pixbuf? load_piece_pixbuf(PieceColor color, DraughtsPieceType piece_type, string style = "classic", int size = 64) {
            string cache_key = @"piece_$(color)_$(piece_type)_$(style)_$(size)";

            if (pixbuf_cache.contains(cache_key)) {
                return pixbuf_cache.get(cache_key);
            }

            string color_name = (color == PieceColor.RED) ? "red" : "black";
            string type_name = (piece_type == DraughtsPieceType.KING) ? "king" : "regular";
            string filename = @"$(style)/$(color_name)_$(type_name).svg";
            string resource_path = @"$(pieces_path)/$(filename)";

            var pixbuf = load_pixbuf_from_resource(resource_path, size, size);
            if (pixbuf != null) {
                pixbuf_cache.set(cache_key, pixbuf);
                logger.debug("Piece pixbuf loaded and cached: %s", cache_key);
            } else {
                // Fallback to generate programmatic piece
                pixbuf = generate_fallback_piece(color, piece_type, size);
                if (pixbuf != null) {
                    pixbuf_cache.set(cache_key, pixbuf);
                    logger.debug("Fallback piece generated: %s", cache_key);
                }
            }

            return pixbuf;
        }

        /**
         * Load board background texture
         */
        public Gdk.Texture? load_board_texture(string theme = "classic") {
            string cache_key = @"board_$(theme)";

            if (texture_cache.contains(cache_key)) {
                return texture_cache.get(cache_key);
            }

            string filename = @"$(theme)_board.png";
            string resource_path = @"$(boards_path)/$(filename)";

            var pixbuf = load_pixbuf_from_resource(resource_path);
            if (pixbuf != null) {
                var texture = Gdk.Texture.for_pixbuf(pixbuf);
                texture_cache.set(cache_key, texture);
                logger.debug("Board texture loaded: %s", cache_key);
                return texture;
            }

            logger.warning("Failed to load board texture: %s", resource_path);
            return null;
        }

        /**
         * Load theme configuration
         */
        public ThemeConfig? load_theme_config(string theme_name) {
            string config_path = @"$(themes_path)/$(theme_name)/config.json";
            string config_data = load_resource_as_string(config_path, false);

            if (config_data == null) {
                logger.warning("Theme config not found: %s", config_path);
                return create_default_theme_config(theme_name);
            }

            try {
                return parse_theme_config(config_data, theme_name);
            } catch (Error e) {
                logger.error("Failed to parse theme config: %s", e.message);
                return create_default_theme_config(theme_name);
            }
        }

        /**
         * Get available piece styles
         */
        public string[] get_available_piece_styles() {
            // In a real implementation, this would enumerate resource directories
            return { "classic", "modern", "wooden", "flat", "glass", "marble" };
        }

        /**
         * Get available board themes
         */
        public string[] get_available_board_themes() {
            // In a real implementation, this would enumerate resource directories
            return { "classic", "wood", "marble", "green", "blue", "dark", "high-contrast" };
        }

        /**
         * Load sound effect
         */
        public File? get_sound_file(string sound_name) {
            string[] possible_extensions = { ".ogg", ".wav", ".mp3" };

            foreach (string ext in possible_extensions) {
                string resource_path = @"$(sounds_path)/$(sound_name)$(ext)";
                if (resource_exists(resource_path)) {
                    try {
                        var resource_data = load_resource(resource_path, true);
                        if (resource_data != null) {
                            // Create temporary file for sound playback
                            FileIOStream stream;
                            var temp_file = File.new_tmp("draughts_sound_XXXXXX" + ext, out stream);
                            var output_stream = temp_file.create(FileCreateFlags.REPLACE_DESTINATION);
                            output_stream.write_bytes(resource_data);
                            output_stream.close();

                            logger.debug("Sound file extracted: %s", temp_file.get_path());
                            return temp_file;
                        }
                    } catch (Error e) {
                        logger.warning("Failed to extract sound file %s: %s", sound_name, e.message);
                    }
                }
            }

            logger.warning("Sound file not found: %s", sound_name);
            return null;
        }

        /**
         * Load icon by name with fallback
         */
        public Gdk.Pixbuf? load_icon(string icon_name, int size = 24) {
            string cache_key = @"icon_$(icon_name)_$(size)";

            if (pixbuf_cache.contains(cache_key)) {
                return pixbuf_cache.get(cache_key);
            }

            // Try SVG first
            string svg_path = @"$(icons_path)/$(icon_name).svg";
            var pixbuf = load_pixbuf_from_resource(svg_path, size, size);

            if (pixbuf == null) {
                // Fallback to PNG
                string png_path = @"$(icons_path)/$(icon_name).png";
                pixbuf = load_pixbuf_from_resource(png_path, size, size);
            }

            if (pixbuf == null) {
                // Use system icon as ultimate fallback
                try {
                    var icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
                    var icon_paintable = icon_theme.lookup_icon(
                        icon_name,
                        null,
                        size,
                        1,
                        Gtk.TextDirection.NONE,
                        0 // GTK4 removed NONE flag
                    );

                    if (icon_paintable != null) {
                        var snapshot = new Gtk.Snapshot();
                        icon_paintable.snapshot(snapshot, size, size);
                        var render_node = snapshot.free_to_node();

                        if (render_node != null) {
                            // GTK4 renderer API changed - this needs reimplementation
                            // For now, return null to skip this functionality
                            return null;

                            // GTK4 texture conversion - disabled for now
                            // var bytes = texture.save_to_png_bytes();
                            // var stream = new MemoryInputStream.from_bytes(bytes);
                            // pixbuf = new Gdk.Pixbuf.from_stream(stream);
                        }
                    }
                } catch (Error e) {
                    logger.debug("System icon fallback failed for %s: %s", icon_name, e.message);
                }
            }

            if (pixbuf != null) {
                pixbuf_cache.set(cache_key, pixbuf);
                logger.debug("Icon loaded: %s", cache_key);
            }

            return pixbuf;
        }

        /**
         * Preload game assets for better performance
         */
        public void preload_game_assets(string piece_style = "classic", string board_theme = "classic") {
            logger.info("Preloading game assets...");

            // Preload pieces for both colors and types
            PieceColor[] colors = { PieceColor.RED, PieceColor.BLACK };
            DraughtsPieceType[] types = { DraughtsPieceType.MAN, DraughtsPieceType.KING };

            foreach (var color in colors) {
                foreach (var type in types) {
                    load_piece_pixbuf(color, type, piece_style, 64);
                    load_piece_pixbuf(color, type, piece_style, 48); // Smaller size for UI
                }
            }

            // Preload board texture
            load_board_texture(board_theme);

            // Preload common icons
            string[] common_icons = {
                "play", "pause", "stop", "reset", "undo", "redo",
                "settings", "help", "info", "warning", "error"
            };

            foreach (string icon in common_icons) {
                load_icon(icon, 24);
                load_icon(icon, 16);
            }

            logger.info("Game assets preloaded successfully");
        }

        /**
         * Get memory usage statistics
         */
        public ResourceStats get_resource_stats() {
            var stats = ResourceStats();
            stats.cached_resources = resource_cache.size();
            stats.cached_pixbufs = pixbuf_cache.size();
            stats.cached_textures = texture_cache.size();

            // Estimate memory usage (rough calculation)
            stats.estimated_memory_mb = 0;

            pixbuf_cache.@foreach((key, pixbuf) => {
                stats.estimated_memory_mb += (pixbuf.get_width() * pixbuf.get_height() * 4) / (1024 * 1024);
            });

            return stats;
        }


        // ===== PRIVATE HELPER METHODS =====

        private Gdk.Pixbuf? load_pixbuf_from_resource(string resource_path, int width = -1, int height = -1) {
            var stream = load_resource_as_stream(resource_path);
            if (stream == null) {
                return null;
            }

            try {
                Gdk.Pixbuf pixbuf;
                if (width > 0 && height > 0) {
                    pixbuf = new Gdk.Pixbuf.from_stream_at_scale(stream, width, height, true);
                } else {
                    pixbuf = new Gdk.Pixbuf.from_stream(stream);
                }
                return pixbuf;
            } catch (Error e) {
                logger.debug("Failed to load pixbuf from %s: %s", resource_path, e.message);
                return null;
            }
        }

        private Gdk.Pixbuf generate_fallback_piece(PieceColor color, DraughtsPieceType piece_type, int size) {
            // Generate a simple colored circle as fallback
            var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, size, size);
            var cr = new Cairo.Context(surface);

            // Clear background
            cr.set_operator(Cairo.Operator.CLEAR);
            cr.paint();
            cr.set_operator(Cairo.Operator.OVER);

            // Draw piece
            double radius = size * 0.4;
            double center = size * 0.5;

            // Piece color
            if (color == PieceColor.RED) {
                cr.set_source_rgb(0.8, 0.2, 0.2);
            } else {
                cr.set_source_rgb(0.2, 0.2, 0.2);
            }

            cr.arc(center, center, radius, 0, 2 * Math.PI);
            cr.fill();

            // Border
            cr.set_source_rgb(0, 0, 0);
            cr.set_line_width(2);
            cr.arc(center, center, radius, 0, 2 * Math.PI);
            cr.stroke();

            // King crown
            if (piece_type == DraughtsPieceType.KING) {
                cr.set_source_rgb(1, 0.8, 0);
                cr.arc(center, center, radius * 0.6, 0, 2 * Math.PI);
                cr.fill();

                cr.set_source_rgb(0, 0, 0);
                cr.set_line_width(1);
                cr.arc(center, center, radius * 0.6, 0, 2 * Math.PI);
                cr.stroke();
            }

            try {
                return Gdk.pixbuf_get_from_surface(surface, 0, 0, size, size);
            } catch (Error e) {
                logger.error("Failed to generate fallback piece: %s", e.message);
                return null;
            }
        }

        private ThemeConfig create_default_theme_config(string theme_name) {
            var config = ThemeConfig();
            config.name = theme_name;
            config.display_name = theme_name.up(1) + theme_name.substring(1);

            // Default colors based on theme name
            switch (theme_name) {
                case "dark":
                    config.dark_square_color = "#3C3C3C";
                    config.light_square_color = "#6C6C6C";
                    break;
                case "green":
                    config.dark_square_color = "#4A7C59";
                    config.light_square_color = "#9FBC0F";
                    break;
                case "blue":
                    config.dark_square_color = "#4169E1";
                    config.light_square_color = "#87CEEB";
                    break;
                default:
                    config.dark_square_color = "#8B4513";
                    config.light_square_color = "#F5DEB3";
                    break;
            }

            return config;
        }

        private ThemeConfig parse_theme_config(string json_data, string theme_name) throws Error {
            var parser = new Json.Parser();
            parser.load_from_data(json_data);

            var root = parser.get_root().get_object();
            var config = ThemeConfig();

            config.name = theme_name;
            config.display_name = root.get_string_member("display_name");
            config.dark_square_color = root.get_string_member("dark_square_color");
            config.light_square_color = root.get_string_member("light_square_color");

            if (root.has_member("description")) {
                config.description = root.get_string_member("description");
            }

            return config;
        }

        /**
         * Get the default singleton instance
         */
        public static ResourceManager get_default() {
            return get_instance();
        }
    }

    /**
     * Theme configuration structure
     */
    public struct ThemeConfig {
        public string name;
        public string display_name;
        public string description;
        public string dark_square_color;
        public string light_square_color;
    }

    /**
     * Resource usage statistics
     */
    public struct ResourceStats {
        public uint cached_resources;
        public uint cached_pixbufs;
        public uint cached_textures;
        public double estimated_memory_mb;
    }
}