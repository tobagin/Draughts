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
        private string resource_base_path;

        public static ResourceManager get_instance () {
            if (instance == null) {
                instance = new ResourceManager ();
            }
            return instance;
        }

        private ResourceManager () {
            logger = Logger.get_default();
            resource_cache = new HashTable<string, Bytes> (str_hash, str_equal);

#if DEVELOPMENT
            resource_base_path = "/io/github/tobagin/Draughts/Devel";
#else
            resource_base_path = "/io/github/tobagin/Draughts";
#endif

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
            var resource_path = get_resource_path (image_path);
            var stream = load_resource_as_stream (resource_path);

            if (stream == null) {
                logger.warning ("Failed to load image resource: %s", resource_path);
                return null;
            }

            try {
                var texture = Gdk.Texture.new_from_stream (stream, null);
                logger.debug ("Texture loaded successfully: %s", resource_path);
                return texture;
            } catch (Error e) {
                logger.warning ("Failed to create texture from resource '%s': %s", resource_path, e.message);
                return null;
            }
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
            resource_cache.get_keys_as_array ().foreach ((key) => {
                cached += key;
            });
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
    }
}