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

    /**
     * Sound effect types for game events
     */
    public enum SoundEffect {
        MOVE,           // Regular move
        CAPTURE,        // Capturing a piece
        KING,           // Piece promoted to king
        GAME_START,     // Game begins
        GAME_END,       // Game over
        TIMER_WARNING,  // Timer running low
        ILLEGAL_MOVE,   // Invalid move attempted
        UNDO,           // Move undone
        REDO;           // Move redone

        public string to_filename() {
            switch (this) {
                case MOVE:
                    return "move.ogg";
                case CAPTURE:
                    return "capture.ogg";
                case KING:
                    return "king.ogg";
                case GAME_START:
                    return "game-start.ogg";
                case GAME_END:
                    return "game-end.ogg";
                case TIMER_WARNING:
                    return "timer-warning.ogg";
                case ILLEGAL_MOVE:
                    return "illegal-move.ogg";
                case UNDO:
                    return "undo.ogg";
                case REDO:
                    return "redo.ogg";
                default:
                    return "move.ogg";
            }
        }
    }

    /**
     * SoundManager handles all audio playback for the game
     * Uses GStreamer for cross-platform audio support
     */
    public class SoundManager : Object {
        private static SoundManager? instance;
        private SettingsManager settings;
        private Logger logger;
        private Gst.Element? playbin;
        private HashTable<SoundEffect, string> sound_cache;
        private bool gstreamer_initialized = false;

        public static SoundManager get_instance() {
            if (instance == null) {
                instance = new SoundManager();
            }
            return instance;
        }

        private SoundManager() {
            settings = SettingsManager.get_instance();
            logger = Logger.get_default();
            sound_cache = new HashTable<SoundEffect, string>(direct_hash, direct_equal);

            // Initialize GStreamer
            try {
                string[] args = {};
                unowned string[] args_ref = args;
                Gst.init(ref args_ref);
                gstreamer_initialized = true;
                logger.debug("GStreamer initialized successfully");
            } catch (Error e) {
                logger.error("Failed to initialize GStreamer: %s", e.message);
                gstreamer_initialized = false;
            }

            // Create playbin element for audio playback
            if (gstreamer_initialized) {
                try {
                    playbin = Gst.ElementFactory.make("playbin", "player");
                    if (playbin == null) {
                        logger.warning("Failed to create playbin element");
                        gstreamer_initialized = false;
                    }
                } catch (Error e) {
                    logger.error("Error creating playbin: %s", e.message);
                    gstreamer_initialized = false;
                }
            }

            // Preload sound URIs
            preload_sounds();
        }

        /**
         * Preload all sound effect URIs from resources
         */
        private void preload_sounds() {
            if (!gstreamer_initialized) {
                return;
            }

            foreach (var effect in new SoundEffect[] {
                SoundEffect.MOVE,
                SoundEffect.CAPTURE,
                SoundEffect.KING,
                SoundEffect.GAME_START,
                SoundEffect.GAME_END,
                SoundEffect.TIMER_WARNING,
                SoundEffect.ILLEGAL_MOVE,
                SoundEffect.UNDO,
                SoundEffect.REDO
            }) {
                try {
                    // Convert Config.ID to path format (io.github.tobagin.Draughts -> io/github/tobagin/Draughts)
                    var id_path = Config.ID.replace(".", "/");
                    var resource_path = @"/$(id_path)/sounds/$(effect.to_filename())";
                    var uri = @"resource://$(resource_path)";
                    sound_cache.insert(effect, uri);
                    logger.debug("Cached sound: %s -> %s", effect.to_string(), uri);
                } catch (Error e) {
                    logger.warning("Failed to cache sound %s: %s", effect.to_string(), e.message);
                }
            }
        }

        /**
         * Play a sound effect
         */
        public void play_sound(SoundEffect effect) {
            // Check if sound effects are enabled
            if (!settings.get_sound_effects()) {
                logger.debug("Sound effects disabled, skipping: %s", effect.to_string());
                return;
            }

            if (!gstreamer_initialized || playbin == null) {
                logger.debug("GStreamer not initialized, cannot play sound");
                return;
            }

            // Get the sound URI from cache
            var uri = sound_cache.lookup(effect);
            if (uri == null) {
                logger.warning("Sound effect not cached: %s", effect.to_string());
                return;
            }

            try {
                // Stop current playback
                playbin.set_state(Gst.State.NULL);

                // Set the URI
                playbin.set("uri", uri);

                // Start playback
                var ret = playbin.set_state(Gst.State.PLAYING);
                if (ret == Gst.StateChangeReturn.FAILURE) {
                    logger.warning("Failed to play sound: %s", effect.to_string());
                } else {
                    logger.debug("Playing sound: %s", effect.to_string());
                }

                // Set up end-of-stream handling
                var bus = playbin.get_bus();
                bus.add_watch(Priority.DEFAULT, (bus, message) => {
                    if (message.type == Gst.MessageType.EOS ||
                        message.type == Gst.MessageType.ERROR) {
                        playbin.set_state(Gst.State.NULL);
                    }
                    return true;
                });

            } catch (Error e) {
                logger.error("Error playing sound %s: %s", effect.to_string(), e.message);
            }
        }

        /**
         * Play sound for a move based on its characteristics
         */
        public void play_move_sound(DraughtsMove move, bool is_capture, bool is_promotion) {
            if (is_promotion) {
                play_sound(SoundEffect.KING);
            } else if (is_capture) {
                play_sound(SoundEffect.CAPTURE);
            } else {
                play_sound(SoundEffect.MOVE);
            }
        }

        /**
         * Stop all audio playback
         */
        public void stop_all() {
            if (playbin != null) {
                playbin.set_state(Gst.State.NULL);
            }
        }

        /**
         * Set volume level (0.0 to 1.0)
         */
        public void set_volume(double volume) {
            if (playbin != null) {
                playbin.set("volume", volume.clamp(0.0, 1.0));
            }
        }

        /**
         * Get current volume level
         */
        public double get_volume() {
            if (playbin != null) {
                double volume;
                playbin.get("volume", out volume);
                return volume;
            }
            return 1.0;
        }

        /**
         * Test if audio system is working
         */
        public bool test_audio() {
            if (!gstreamer_initialized || playbin == null) {
                return false;
            }

            // Try to play a simple test sound
            play_sound(SoundEffect.MOVE);
            return true;
        }

        public static SoundManager get_default() {
            return get_instance();
        }
    }
}
