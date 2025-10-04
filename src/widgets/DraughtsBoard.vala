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

    public enum PieceType {
        NONE,
        RED_REGULAR,
        RED_KING,
        BLACK_REGULAR,
        BLACK_KING
    }

    public enum Player {
        RED,
        BLACK
    }

    public enum GameState {
        WAITING,
        PLAYING,
        RED_WINS,
        BLACK_WINS,
        DRAW
    }

    public struct Position {
        public int row;
        public int col;

        public Position(int row, int col) {
            this.row = row;
            this.col = col;
        }

        public bool equals(Position other) {
            return this.row == other.row && this.col == other.col;
        }
    }

    public struct Move {
        public Position from;
        public Position to;
        public Position[] captures;

        public Move(Position from, Position to, Position[]? captures = null) {
            this.from = from;
            this.to = to;
            this.captures = captures ?? new Position[0];
        }
    }

    public class DraughtsBoard : Gtk.Box {
        private int board_size;
        private PieceType[,] board_state;
        private Logger logger;
        private Gtk.DrawingArea drawing_area;
        private Gtk.AspectFrame aspect_frame;
        private SettingsManager settings_manager;

        // Piece images as Paintables
        private Gdk.Paintable? red_checker_image;
        private Gdk.Paintable? black_checker_image;
        private Gdk.Paintable? red_king_image;
        private Gdk.Paintable? black_king_image;

        // Cached Cairo surfaces for fast rendering
        private Cairo.Surface? red_checker_surface;
        private Cairo.Surface? black_checker_surface;
        private Cairo.Surface? red_king_surface;
        private Cairo.Surface? black_king_surface;

        // Game state
        private Player current_player;
        private GameState game_state;
        private Position? selected_position;
        private Move[] valid_moves;

        // Drag and drop state
        private bool is_dragging = false;
        private int drag_start_row = -1;
        private int drag_start_col = -1;
        private double drag_current_x = 0;
        private double drag_current_y = 0;

        // Hover state
        private int hover_row = -1;
        private int hover_col = -1;

        // Visibility state
        private bool pieces_visible = true;

        // Board orientation state
        private bool flip_board = false; // true = black at bottom, false = red at bottom

        // Animation state
        private bool is_animating = false;
        private int anim_from_row = -1;
        private int anim_from_col = -1;
        private int anim_to_row = -1;
        private int anim_to_col = -1;
        private PieceType anim_piece_type = PieceType.NONE;
        private double anim_progress = 0.0; // 0.0 to 1.0
        private int64 anim_start_time = 0;
        private const int ANIMATION_DURATION_MS = 300;
        private uint anim_tick_callback_id = 0;
        private Position[]? anim_captured_pieces = null; // Pieces to fade out after animation
        private double anim_fade_progress = 0.0; // For captured piece fade-out

        // Highlighting state for drawing
        private Gee.HashMap<string, string> highlighted_squares; // "row,col" -> highlight_type
        private Gee.HashMap<string, PieceType> preview_pieces; // "row,col" -> piece_type (for move previews)
        private Gee.HashSet<string> playable_pieces; // "row,col" set for pieces that can move (blue glow)
        private int hover_glow_row = -1; // Row of piece with hover glow effect (gold)
        private int hover_glow_col = -1; // Col of piece with hover glow effect (gold)

        // Gesture controllers
        private Gtk.GestureDrag drag_gesture;

        // Board colors (will be set by theme)
        private Gdk.RGBA light_square_color;
        private Gdk.RGBA dark_square_color;
        private Gdk.RGBA selected_color;
        private Gdk.RGBA valid_move_color;
        private Gdk.RGBA capture_move_color;

        public DraughtsBoard() {
            Object();
            logger = Logger.get_default();
            settings_manager = SettingsManager.get_instance();
            highlighted_squares = new Gee.HashMap<string, string>();
            preview_pieces = new Gee.HashMap<string, PieceType>();
            playable_pieces = new Gee.HashSet<string>();

            // Load piece images first
            load_piece_images();

            // Get board size from game rules, fallback to default
            string game_rules = settings_manager.get_game_rules();
            if (game_rules == "") {
                game_rules = Constants.DEFAULT_GAME_RULES;
                settings_manager.set_game_rules(game_rules);
            }

            board_size = get_board_size_for_rules(game_rules);
            settings_manager.set_board_size(board_size);

            valid_moves = new Move[0];

            // Initialize default colors (will be overridden by theme)
            initialize_default_colors();

            setup_aspect_frame();
            create_drawing_area();
            create_board();  // Initialize board_state array
            setup_event_handlers();
            // Don't initialize game with pieces - board starts empty
            // Pieces will be added when user starts a new game via DraughtsBoardAdapter
            string board_theme = settings_manager.get_board_theme();
            if (board_theme == "") {
                board_theme = Constants.DEFAULT_BOARD_THEME;
                settings_manager.set_board_theme(board_theme);
            }
            apply_board_theme(board_theme);

            // Ensure pieces are displayed after everything is set up
            Idle.add(() => {
                update_board_display();
                return false;
            });

            logger.info("DraughtsBoard widget created with size %dx%d", board_size, board_size);
        }

        private void load_piece_images() {
            // Get the current piece style from settings
            var settings_manager = SettingsManager.get_instance();
            string piece_style = settings_manager.get_piece_style();

            logger.info("Loading piece images with theme: %s", piece_style);

            try {
                logger.info("About to load themed images for: %s", piece_style);
                // Load themed images from resources
                // Build resource path based on application ID (works for both dev and production)
                string resource_base = "/" + Config.ID.replace(".", "/");
                string red_checker_path, black_checker_path, red_king_path, black_king_path;

                if (piece_style == "plastic") {
                    // Use default plastic images (no suffix)
                    red_checker_path = @"$(resource_base)/red-checker.png";
                    black_checker_path = @"$(resource_base)/black-checker.png";
                    red_king_path = @"$(resource_base)/red-king.png";
                    black_king_path = @"$(resource_base)/black-king.png";
                } else {
                    // Use themed images with suffix
                    red_checker_path = @"$(resource_base)/red-checker-$(piece_style).png";
                    black_checker_path = @"$(resource_base)/black-checker-$(piece_style).png";
                    red_king_path = @"$(resource_base)/red-king-$(piece_style).png";
                    black_king_path = @"$(resource_base)/black-king-$(piece_style).png";
                }

                logger.info("Loading textures from paths:");
                logger.info("  Red checker: %s", red_checker_path);
                logger.info("  Black checker: %s", black_checker_path);
                logger.info("  Red king: %s", red_king_path);
                logger.info("  Black king: %s", black_king_path);

                red_checker_image = Gdk.Texture.from_resource(red_checker_path);
                black_checker_image = Gdk.Texture.from_resource(black_checker_path);
                red_king_image = Gdk.Texture.from_resource(red_king_path);
                black_king_image = Gdk.Texture.from_resource(black_king_path);

                // Convert to Cairo surfaces for fast rendering
                red_checker_surface = texture_to_cairo_surface(red_checker_image as Gdk.Texture);
                black_checker_surface = texture_to_cairo_surface(black_checker_image as Gdk.Texture);
                red_king_surface = texture_to_cairo_surface(red_king_image as Gdk.Texture);
                black_king_surface = texture_to_cairo_surface(black_king_image as Gdk.Texture);

                logger.info("Successfully loaded %s piece images from resources", piece_style);
            } catch (Error e) {
                logger.warning("Failed to load piece images: %s", e.message);
                // Fall back to default plastic images
                try {
                    string resource_base = "/" + Config.ID.replace(".", "/");
                    red_checker_image = Gdk.Texture.from_resource(@"$(resource_base)/red-checker.png");
                    black_checker_image = Gdk.Texture.from_resource(@"$(resource_base)/black-checker.png");
                    red_king_image = Gdk.Texture.from_resource(@"$(resource_base)/red-king.png");
                    black_king_image = Gdk.Texture.from_resource(@"$(resource_base)/black-king.png");

                    // Convert to Cairo surfaces for fast rendering
                    red_checker_surface = texture_to_cairo_surface(red_checker_image as Gdk.Texture);
                    black_checker_surface = texture_to_cairo_surface(black_checker_image as Gdk.Texture);
                    red_king_surface = texture_to_cairo_surface(red_king_image as Gdk.Texture);
                    black_king_surface = texture_to_cairo_surface(black_king_image as Gdk.Texture);

                    logger.info("Fell back to plastic piece images");
                } catch (Error fallback_error) {
                    logger.error("Failed to load fallback piece images: %s", fallback_error.message);
                    red_checker_image = null;
                    black_checker_image = null;
                    red_king_image = null;
                    black_king_image = null;
                }
            }
        }

        /**
         * Reload piece images with new theme and update the board display
         */
        public void reload_piece_images() {
            logger.info("reload_piece_images() called - starting piece theme update");

            // Clear existing images and surfaces to force reload
            red_checker_image = null;
            black_checker_image = null;
            red_king_image = null;
            black_king_image = null;
            red_checker_surface = null;
            black_checker_surface = null;
            red_king_surface = null;
            black_king_surface = null;

            // Load new themed images
            load_piece_images();

            // Use Idle.add to ensure the refresh happens after any pending operations
            Idle.add(() => {
                // Force a complete refresh of the board display
                // This will re-render all pieces with the new images
                update_board_display();

                logger.info("Piece images reloaded and board updated with new theme");
                return false;
            });
        }

        /**
         * Convert a Gdk.Texture to a Cairo surface for fast rendering
         */
        private Cairo.Surface? texture_to_cairo_surface(Gdk.Texture texture) {
            int width = texture.get_width();
            int height = texture.get_height();

            var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, width, height);
            var cr = new Cairo.Context(surface);

            // Use snapshot to render texture to Cairo
            var snapshot = new Gtk.Snapshot();
            texture.snapshot(snapshot, width, height);
            var node = snapshot.free_to_node();

            if (node != null) {
                node.draw(cr);
            }

            return surface;
        }

        private void initialize_default_colors() {
            // Classic theme colors
            light_square_color = { 0.94f, 0.85f, 0.69f, 1.0f }; // Beige
            dark_square_color = { 0.55f, 0.35f, 0.17f, 1.0f };  // Brown
            selected_color = { 0.2f, 0.6f, 1.0f, 0.5f };        // Blue highlight
            valid_move_color = { 0.3f, 0.8f, 0.3f, 0.4f };      // Green highlight
            capture_move_color = { 1.0f, 0.3f, 0.3f, 0.5f };    // Red highlight
        }

        private void setup_aspect_frame() {
            // Configure this box
            set_orientation(Gtk.Orientation.VERTICAL);
            set_hexpand(true);
            set_vexpand(true);
            set_halign(Gtk.Align.FILL);
            set_valign(Gtk.Align.FILL);

            // Create AspectFrame to force 1:1 ratio
            aspect_frame = new Gtk.AspectFrame(0.5f, 0.5f, 1.0f, false);
            aspect_frame.set_hexpand(true);
            aspect_frame.set_vexpand(true);

            append(aspect_frame);
        }

        private void create_drawing_area() {
            // Create drawing area
            drawing_area = new Gtk.DrawingArea();
            drawing_area.add_css_class("draughts-board");
            drawing_area.set_hexpand(true);
            drawing_area.set_vexpand(true);
            drawing_area.set_draw_func(on_draw);

            aspect_frame.set_child(drawing_area);
        }

        private void setup_event_handlers() {
            // Click gesture
            var click_gesture = new Gtk.GestureClick();
            click_gesture.pressed.connect(on_button_press);
            drawing_area.add_controller(click_gesture);

            // Drag gesture (for drag and drop) - store reference
            drag_gesture = new Gtk.GestureDrag();
            drag_gesture.drag_begin.connect(on_drag_begin);
            drag_gesture.drag_update.connect(on_drag_update);
            drag_gesture.drag_end.connect(on_drag_end);
            drawing_area.add_controller(drag_gesture);

            // Motion controller (for hover effects)
            var motion_controller = new Gtk.EventControllerMotion();
            motion_controller.motion.connect(on_motion);
            motion_controller.leave.connect(on_leave);
            drawing_area.add_controller(motion_controller);
        }

        /**
         * Main drawing function - renders the board using Cairo
         */
        private void on_draw(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
            // Safety check - ensure board is initialized
            if (board_state == null || width == 0 || height == 0) {
                return;
            }

            // Calculate square size
            double square_size = (double)width / board_size;

            // Draw each square
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    // Transform coordinates for display
                    int display_row = transform_display_row(row);
                    int display_col = transform_display_col(col);

                    double x = display_col * square_size;
                    double y = display_row * square_size;

                    // Determine square color (checkerboard pattern)
                    // Dark squares are playable in draughts (where row + col is odd)
                    bool is_dark = (row + col) % 2 == 1;
                    Gdk.RGBA color = is_dark ? dark_square_color : light_square_color;

                    // Draw square background
                    cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                    cr.rectangle(x, y, square_size, square_size);
                    cr.fill();

                    // Draw highlights from highlighted_squares map (only if pieces are visible)
                    if (pieces_visible) {
                        string key = @"$row,$col";
                        if (highlighted_squares.has_key(key)) {
                            string highlight_type = highlighted_squares[key];
                            Gdk.RGBA highlight_color;

                            switch (highlight_type) {
                                case "selected":
                                    highlight_color = selected_color;
                                    break;
                                case "possible":
                                case "playable":
                                    highlight_color = valid_move_color;
                                    break;
                                case "capture":
                                    highlight_color = capture_move_color;
                                    break;
                                default:
                                    highlight_color = valid_move_color;
                                    break;
                            }

                            cr.set_source_rgba(highlight_color.red, highlight_color.green, highlight_color.blue, highlight_color.alpha);
                            cr.rectangle(x, y, square_size, square_size);
                            cr.fill();
                        }
                    }

                    // Draw piece (only if pieces are visible)
                    if (pieces_visible) {
                        var piece = board_state[row, col];
                        // Skip drawing the piece if:
                        // 1. It's being dragged
                        // 2. It's animating (at the source position)
                        bool skip_piece = (is_dragging && drag_start_row == row && drag_start_col == col) ||
                                        (is_animating && anim_from_row == row && anim_from_col == col);

                        if (piece != PieceType.NONE && !skip_piece) {
                            // Draw blue glow for playable pieces
                            string piece_key = @"$row,$col";
                            if (playable_pieces.contains(piece_key)) {
                                cr.save();
                                cr.set_source_rgba(0.3, 0.6, 1.0, 0.5); // Blue glow for playable pieces
                                cr.set_line_width(5.0);
                                cr.arc(x + square_size / 2, y + square_size / 2, square_size * 0.42, 0, 2 * Math.PI);
                                cr.stroke();
                                cr.restore();
                            }

                            // Draw gold hover glow on top if hovering this piece
                            if (hover_glow_row == row && hover_glow_col == col) {
                                cr.save();
                                cr.set_source_rgba(1.0, 0.843, 0.0, 0.8); // Gold glow for hover
                                cr.set_line_width(6.0);
                                cr.arc(x + square_size / 2, y + square_size / 2, square_size * 0.45, 0, 2 * Math.PI);
                                cr.stroke();
                                cr.restore();
                            }

                            // Draw the piece
                            draw_piece(cr, piece, x + square_size / 2, y + square_size / 2, square_size * 0.4);
                        }
                    }

                    // Draw preview piece (translucent)
                    string preview_key = @"$row,$col";
                    if (pieces_visible && preview_pieces.has_key(preview_key)) {
                        var preview_piece = preview_pieces[preview_key];
                        cr.save();
                        cr.set_source_rgba(1, 1, 1, 0.5); // Semi-transparent overlay
                        draw_piece_translucent(cr, preview_piece, x + square_size / 2, y + square_size / 2, square_size * 0.4, 0.4);
                        cr.restore();
                    }
                }
            }

            // Draw dragged piece (only if pieces are visible)
            if (is_dragging && pieces_visible) {
                var piece = board_state[drag_start_row, drag_start_col];
                draw_piece(cr, piece, drag_current_x, drag_current_y, square_size * 0.4);
            }

            // Draw animating piece (only if pieces are visible)
            if (is_animating && pieces_visible) {
                // Transform animation coordinates for display
                int from_display_row = transform_display_row(anim_from_row);
                int from_display_col = transform_display_col(anim_from_col);
                int to_display_row = transform_display_row(anim_to_row);
                int to_display_col = transform_display_col(anim_to_col);

                // Calculate interpolated position
                double from_x = from_display_col * square_size + square_size / 2;
                double from_y = from_display_row * square_size + square_size / 2;
                double to_x = to_display_col * square_size + square_size / 2;
                double to_y = to_display_row * square_size + square_size / 2;

                double current_x = from_x + (to_x - from_x) * anim_progress;
                double current_y = from_y + (to_y - from_y) * anim_progress;

                draw_piece(cr, anim_piece_type, current_x, current_y, square_size * 0.4);
            }
        }

        /**
         * Draw a single piece at the given position
         */
        private void draw_piece(Cairo.Context cr, PieceType piece, double cx, double cy, double radius) {
            Cairo.Surface? surface = null;

            switch (piece) {
                case PieceType.RED_REGULAR:
                    surface = red_checker_surface;
                    break;
                case PieceType.RED_KING:
                    surface = red_king_surface;
                    break;
                case PieceType.BLACK_REGULAR:
                    surface = black_checker_surface;
                    break;
                case PieceType.BLACK_KING:
                    surface = black_king_surface;
                    break;
            }

            if (surface != null) {
                // Calculate piece size - larger pieces (radius is 40% of square, so multiply by 2.75 for ~110%)
                double piece_size = radius * 2.75;

                cr.save();

                // Translate to center position and offset by half piece size to center the image
                cr.translate(cx - piece_size / 2, cy - piece_size / 2);

                // Calculate scale factor to fit the image into the desired size
                double scale_x = piece_size / ((Cairo.ImageSurface)surface).get_width();
                double scale_y = piece_size / ((Cairo.ImageSurface)surface).get_height();
                cr.scale(scale_x, scale_y);

                // Draw the cached surface directly - much faster than snapshot
                cr.set_source_surface(surface, 0, 0);
                cr.paint();

                cr.restore();
            } else {
                // Fallback to simple circles if images aren't loaded
                bool is_red = (piece == PieceType.RED_REGULAR || piece == PieceType.RED_KING);
                bool is_king = (piece == PieceType.RED_KING || piece == PieceType.BLACK_KING);

                cr.save();
                if (is_red) {
                    cr.set_source_rgb(0.8, 0.2, 0.2); // Red
                } else {
                    cr.set_source_rgb(0.2, 0.2, 0.2); // Black
                }
                cr.arc(cx, cy, radius * 0.8, 0, 2 * Math.PI);
                cr.fill();

                // Draw border
                cr.set_source_rgb(0.1, 0.1, 0.1);
                cr.set_line_width(2.0);
                cr.arc(cx, cy, radius * 0.8, 0, 2 * Math.PI);
                cr.stroke();

                // Draw king crown
                if (is_king) {
                    cr.set_source_rgb(1.0, 0.84, 0.0); // Gold
                    cr.set_font_size(radius);
                    cr.move_to(cx - radius * 0.3, cy + radius * 0.3);
                    cr.show_text("♔");
                }

                cr.restore();
            }
        }

        /**
         * Draw a translucent piece preview at the given position
         */
        private void draw_piece_translucent(Cairo.Context cr, PieceType piece, double cx, double cy, double radius, double alpha) {
            Cairo.Surface? surface = null;

            switch (piece) {
                case PieceType.RED_REGULAR:
                    surface = red_checker_surface;
                    break;
                case PieceType.RED_KING:
                    surface = red_king_surface;
                    break;
                case PieceType.BLACK_REGULAR:
                    surface = black_checker_surface;
                    break;
                case PieceType.BLACK_KING:
                    surface = black_king_surface;
                    break;
            }

            if (surface != null) {
                // Calculate piece size
                double piece_size = radius * 2.75;

                cr.save();

                // Translate to center position
                cr.translate(cx - piece_size / 2, cy - piece_size / 2);

                // Calculate scale factor
                double scale_x = piece_size / ((Cairo.ImageSurface)surface).get_width();
                double scale_y = piece_size / ((Cairo.ImageSurface)surface).get_height();
                cr.scale(scale_x, scale_y);

                // Draw with transparency
                cr.set_source_surface(surface, 0, 0);
                cr.paint_with_alpha(alpha);

                cr.restore();
            } else {
                // Fallback to simple circles with transparency
                bool is_red = (piece == PieceType.RED_REGULAR || piece == PieceType.RED_KING);
                bool is_king = (piece == PieceType.RED_KING || piece == PieceType.BLACK_KING);

                cr.save();
                if (is_red) {
                    cr.set_source_rgba(0.8, 0.2, 0.2, alpha);
                } else {
                    cr.set_source_rgba(0.2, 0.2, 0.2, alpha);
                }
                cr.arc(cx, cy, radius * 0.8, 0, 2 * Math.PI);
                cr.fill();

                // Draw king crown if applicable
                if (is_king) {
                    cr.set_source_rgba(1.0, 0.84, 0.0, alpha);
                    cr.set_font_size(radius);
                    cr.move_to(cx - radius * 0.3, cy + radius * 0.3);
                    cr.show_text("♔");
                }

                cr.restore();
            }
        }

        /**
         * Convert screen coordinates to board coordinates
         */
        private bool screen_to_board(double x, double y, out int row, out int col) {
            int width = drawing_area.get_width();
            double square_size = (double)width / board_size;

            int display_col = (int)(x / square_size);
            int display_row = (int)(y / square_size);

            // Transform back from display coordinates to logical coordinates
            col = flip_board ? (board_size - 1 - display_col) : display_col;
            row = flip_board ? (board_size - 1 - display_row) : display_row;

            return (row >= 0 && row < board_size && col >= 0 && col < board_size);
        }

        /**
         * Handle button press for click-to-select
         */
        private void on_button_press(int n_press, double x, double y) {
            int row, col;
            if (!screen_to_board(x, y, out row, out col)) {
                return;
            }

            on_square_clicked(row, col);
        }

        /**
         * Handle drag begin for drag-and-drop
         */
        private void on_drag_begin(double start_x, double start_y) {
            // Check if drag-and-drop is enabled in preferences
            if (!settings_manager.get_enable_drag_and_drop()) {
                return;
            }

            if (board_state == null) {
                return;
            }

            int row, col;
            if (!screen_to_board(start_x, start_y, out row, out col)) {
                return;
            }

            // Only start drag if there's a piece at this position
            if (board_state[row, col] != PieceType.NONE) {
                is_dragging = true;
                drag_start_row = row;
                drag_start_col = col;
                drag_current_x = start_x;
                drag_current_y = start_y;

                // Select the piece
                selected_position = Position(row, col);
                valid_moves = get_valid_moves_for_piece(selected_position);

                drawing_area.queue_draw();
            }
        }

        /**
         * Handle drag update
         */
        private void on_drag_update(double offset_x, double offset_y) {
            if (!is_dragging || drag_gesture == null) {
                return;
            }

            // Update drag position using stored gesture reference
            double start_x, start_y;
            if (drag_gesture.get_start_point(out start_x, out start_y)) {
                drag_current_x = start_x + offset_x;
                drag_current_y = start_y + offset_y;
                drawing_area.queue_draw();
            }
        }

        /**
         * Handle drag end
         */
        private void on_drag_end(double offset_x, double offset_y) {
            if (!is_dragging || drag_gesture == null) {
                is_dragging = false;
                return;
            }

            double start_x, start_y;
            if (drag_gesture.get_start_point(out start_x, out start_y)) {
                double end_x = start_x + offset_x;
                double end_y = start_y + offset_y;

                int end_row, end_col;
                if (screen_to_board(end_x, end_y, out end_row, out end_col)) {
                    // Try to make the move
                    on_square_clicked(end_row, end_col);
                }
            }

            is_dragging = false;
            drawing_area.queue_draw();
        }

        /**
         * Handle mouse motion for hover effects
         */
        private void on_motion(double x, double y) {
            int row, col;
            if (screen_to_board(x, y, out row, out col)) {
                if (hover_row != row || hover_col != col) {
                    hover_row = row;
                    hover_col = col;

                    // Show gold glow when hovering over a playable piece
                    string piece_key = @"$row,$col";
                    if (playable_pieces.contains(piece_key)) {
                        set_hover_glow(row, col);
                    } else {
                        clear_hover_glow();
                    }
                }
            }
        }

        /**
         * Handle mouse leave
         */
        private void on_leave() {
            hover_row = -1;
            hover_col = -1;
            clear_hover_glow();
        }

        private void create_board() {
            // Initialize board state array
            board_state = new PieceType[board_size, board_size];
            // Drawing is handled by on_draw() - no need to create buttons
        }

        private void initialize_game() {
            // Initialize game state
            current_player = Player.RED;
            game_state = GameState.PLAYING;
            selected_position = null;
            valid_moves = new Move[0];

            // Clear board
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    board_state[row, col] = PieceType.NONE;
                }
            }

            // Calculate piece rows based on board size
            int piece_rows = get_piece_rows_for_board_size(board_size);

            // Place red pieces (top rows)
            for (int row = 0; row < piece_rows; row++) {
                for (int col = 0; col < board_size; col++) {
                    if ((row + col) % 2 == 1) {
                        board_state[row, col] = PieceType.RED_REGULAR;
                    }
                }
            }

            // Place black pieces (bottom rows)
            for (int row = board_size - piece_rows; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    if ((row + col) % 2 == 1) {
                        board_state[row, col] = PieceType.BLACK_REGULAR;
                    }
                }
            }

            update_board_display();
        }

        public void update_board_display() {
            // With DrawingArea, just queue a redraw
            // The on_draw() method will render everything
            drawing_area.queue_draw();
        }

        private void on_square_clicked(int row, int col) {
            if (game_state != GameState.PLAYING) {
                return;
            }

            // Emit signal for the adapter to handle the game logic
            square_clicked(row, col);
        }

        private bool is_player_piece(PieceType piece, Player player) {
            switch (player) {
                case Player.RED:
                    return piece == PieceType.RED_REGULAR || piece == PieceType.RED_KING;
                case Player.BLACK:
                    return piece == PieceType.BLACK_REGULAR || piece == PieceType.BLACK_KING;
                default:
                    return false;
            }
        }

        private bool is_valid_position(Position pos) {
            return pos.row >= 0 && pos.row < board_size && pos.col >= 0 && pos.col < board_size;
        }

        private bool is_king(PieceType piece) {
            return piece == PieceType.RED_KING || piece == PieceType.BLACK_KING;
        }

        private Move[] get_valid_moves_for_piece(Position pos) {
            var piece = board_state[pos.row, pos.col];

            if (piece == PieceType.NONE) {
                return new Move[0];
            }

            // First check for capture moves (mandatory)
            var capture_moves = get_capture_moves_for_piece(pos);
            if (capture_moves.length > 0) {
                return capture_moves;
            }

            // If no captures, get regular moves
            var moves = new Move[0];
            var directions = get_move_directions(piece);

            foreach (var dir in directions) {
                var new_pos = Position(pos.row + dir.row, pos.col + dir.col);

                if (is_valid_position(new_pos) && board_state[new_pos.row, new_pos.col] == PieceType.NONE) {
                    var new_move = Move(pos, new_pos);
                    moves += new_move;
                }
            }

            return moves;
        }

        private Position[] get_move_directions(PieceType piece) {
            var directions = new Position[0];

            switch (piece) {
                case PieceType.RED_REGULAR:
                    // Red moves down (towards black side)
                    directions += Position(1, -1);
                    directions += Position(1, 1);
                    break;
                case PieceType.BLACK_REGULAR:
                    // Black moves up (towards red side)
                    directions += Position(-1, -1);
                    directions += Position(-1, 1);
                    break;
                case PieceType.RED_KING:
                case PieceType.BLACK_KING:
                    // Kings move in all directions
                    directions += Position(-1, -1);
                    directions += Position(-1, 1);
                    directions += Position(1, -1);
                    directions += Position(1, 1);
                    break;
            }

            return directions;
        }

        private Move[] get_capture_moves_for_piece(Position pos) {
            var moves = new Move[0];
            var piece = board_state[pos.row, pos.col];
            var directions = get_move_directions(piece);

            foreach (var dir in directions) {
                var jump_over = Position(pos.row + dir.row, pos.col + dir.col);
                var land_on = Position(pos.row + dir.row * 2, pos.col + dir.col * 2);

                if (is_valid_position(jump_over) && is_valid_position(land_on)) {
                    var jumped_piece = board_state[jump_over.row, jump_over.col];

                    // Check if there's an opponent piece to jump over and landing square is empty
                    if (jumped_piece != PieceType.NONE &&
                        !is_player_piece(jumped_piece, current_player) &&
                        board_state[land_on.row, land_on.col] == PieceType.NONE) {

                        var captures = new Position[1];
                        captures[0] = jump_over;
                        moves += Move(pos, land_on, captures);
                    }
                }
            }

            return moves;
        }

        private void execute_move(Move move) {
            // Move the piece
            var piece = board_state[move.from.row, move.from.col];
            board_state[move.from.row, move.from.col] = PieceType.NONE;
            board_state[move.to.row, move.to.col] = piece;

            // Remove captured pieces
            foreach (var capture_pos in move.captures) {
                board_state[capture_pos.row, capture_pos.col] = PieceType.NONE;
            }

            // Check for king promotion
            if (!is_king(piece)) {
                if ((piece == PieceType.RED_REGULAR && move.to.row == board_size - 1) ||
                    (piece == PieceType.BLACK_REGULAR && move.to.row == 0)) {

                    if (piece == PieceType.RED_REGULAR) {
                        board_state[move.to.row, move.to.col] = PieceType.RED_KING;
                    } else {
                        board_state[move.to.row, move.to.col] = PieceType.BLACK_KING;
                    }
                    logger.info(@"Piece promoted to king at ($(move.to.row), $(move.to.col))");
                }
            }

            // Check for additional captures (multi-jump)
            if (move.captures.length > 0) {
                var additional_captures = get_capture_moves_for_piece(move.to);
                if (additional_captures.length > 0) {
                    // Player must continue capturing
                    selected_position = move.to;
                    valid_moves = additional_captures;
                    update_board_display();
                    return;
                }
            }

            // Switch players
            current_player = (current_player == Player.RED) ? Player.BLACK : Player.RED;
            selected_position = null;
            valid_moves = new Move[0];

            // Check for game end conditions
            check_game_end();

            update_board_display();
            logger.info(@"Move executed: $(current_player == Player.RED ? "BLACK" : "RED")'s turn");
        }

        private void check_game_end() {
            var red_pieces = 0;
            var black_pieces = 0;
            var red_has_moves = false;
            var black_has_moves = false;

            // Count pieces and check for available moves
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    var piece = board_state[row, col];
                    var pos = Position(row, col);

                    if (is_player_piece(piece, Player.RED)) {
                        red_pieces++;
                        if (!red_has_moves && get_valid_moves_for_piece(pos).length > 0) {
                            red_has_moves = true;
                        }
                    } else if (is_player_piece(piece, Player.BLACK)) {
                        black_pieces++;
                        if (!black_has_moves && get_valid_moves_for_piece(pos).length > 0) {
                            black_has_moves = true;
                        }
                    }
                }
            }

            // Determine game state
            if (red_pieces == 0 || !red_has_moves) {
                game_state = GameState.BLACK_WINS;
                logger.info("Game ended: Black wins!");
            } else if (black_pieces == 0 || !black_has_moves) {
                game_state = GameState.RED_WINS;
                logger.info("Game ended: Red wins!");
            }
        }

        public void start_new_game() {
            logger.info("Starting new game");
            initialize_game();
        }

        public void reset_game() {
            logger.info("Resetting game");
            initialize_game();
        }

        public void set_board_size(int size) {
            if (size < 8 || size > 12 || size % 2 != 0) {
                logger.warning("Invalid board size %d. Size must be 8, 10, or 12", size);
                return;
            }

            if (size == board_size) {
                logger.debug("Board size %d already set", size);
                return;
            }

            logger.info("Changing board size from %dx%d to %dx%d", board_size, board_size, size, size);

            board_size = size;
            settings_manager.set_board_size(size);

            reconstruct_board();
            initialize_game();

            logger.info("Board size successfully changed to %dx%d", size, size);
        }

        private void reconstruct_board() {
            logger.debug("Reconstructing board with size %dx%d", board_size, board_size);
            create_board();
        }

        public void set_pieces_visible(bool visible) {
            pieces_visible = visible;
            // Trigger a redraw
            drawing_area.queue_draw();
            logger.debug("Pieces visibility set to: %s", visible.to_string());
        }

        /**
         * Set board perspective based on player color
         * @param player_color Color of the player (RED or BLACK) - their pieces will be at the bottom
         */
        public void set_player_perspective(Player player_color) {
            flip_board = (player_color == Player.BLACK);
            drawing_area.queue_draw();
            logger.debug("Board perspective set to: %s at bottom", player_color.to_string());
        }

        /**
         * Transform row coordinate for display (flip if needed)
         */
        private int transform_display_row(int row) {
            return flip_board ? (board_size - 1 - row) : row;
        }

        /**
         * Transform column coordinate for display (flip if needed)
         */
        private int transform_display_col(int col) {
            return flip_board ? (board_size - 1 - col) : col;
        }

        public void set_game_rules(string rules) {
            logger.info("Setting game rules to: %s", rules);

            // Save rules to settings
            settings_manager.set_game_rules(rules);

            // Set board size based on rules
            int new_board_size = get_board_size_for_rules(rules);
            set_board_size(new_board_size);

            logger.info("Game rules changed to: %s with board size %dx%d", rules, new_board_size, new_board_size);
        }

        public int get_widget_board_size() {
            return board_size;
        }

        public string get_game_rules() {
            return settings_manager.get_game_rules();
        }

        public string get_board_theme() {
            return settings_manager.get_board_theme();
        }

        private int get_board_size_for_rules(string rules) {
            switch (rules) {
                case "canadian":
                    return 12;
                case "international":
                case "frisian":
                    return 10;
                case "checkers":
                case "brazilian":
                case "italian":
                case "spanish":
                case "czech":
                case "thai":
                case "german":
                case "swedish":
                case "russian":
                case "pool":
                case "graeco-turkish":
                case "armenian":
                case "gothic":
                default:
                    return 8;
            }
        }

        private int get_piece_rows_for_board_size(int size) {
            // Standard rule: 3 rows of pieces for 8x8, 4 rows for 10x10, 5 rows for 12x12
            switch (size) {
                case 8:
                    return 3;
                case 10:
                    return 4;
                case 12:
                    return 5;
                default:
                    return 3; // fallback to 8x8 standard
            }
        }

        public void set_board_theme(string theme) {
            logger.info("Setting board theme to: %s", theme);
            apply_board_theme(theme);
        }

        // Methods for external game state synchronization (used by DraughtsBoardAdapter)
        public void clear_board() {
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    board_state[row, col] = PieceType.NONE;
                }
            }
            selected_position = null;
            valid_moves = new Move[0];
        }

        public void set_piece_at(int row, int col, PieceType piece) {
            if (row >= 0 && row < board_size && col >= 0 && col < board_size) {
                board_state[row, col] = piece;
            }
        }

        public PieceType get_piece_at(int row, int col) {
            if (row >= 0 && row < board_size && col >= 0 && col < board_size) {
                return board_state[row, col];
            }
            return PieceType.NONE;
        }

        public void set_current_player(Player player) {
            current_player = player;
        }

        public Player get_current_player() {
            return current_player;
        }

        public void set_game_state(GameState state) {
            game_state = state;
        }

        /**
         * Update board display from DraughtsGameState pieces
         */
        public void update_from_draughts_game_state(DraughtsGameState state) {
            logger.debug(@"DraughtsBoard: Updating board from game state with $(state.pieces.size) pieces, board_size=$(board_size)");

            // Clear the board first
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    board_state[row, col] = PieceType.NONE;
                }
            }

            int red_count = 0, black_count = 0, placed_count = 0;

            // Place pieces from the game state
            foreach (var piece in state.pieces) {
                var pos = piece.position;
                logger.debug(@"DraughtsBoard: Processing piece $(piece.color) $(piece.piece_type) at ($(pos.row),$(pos.col))");

                if (piece.color == PieceColor.RED) red_count++;
                else if (piece.color == PieceColor.BLACK) black_count++;

                if (pos.row >= 0 && pos.row < board_size && pos.col >= 0 && pos.col < board_size) {
                    PieceType piece_type = PieceType.NONE;

                    // Convert from DraughtsPieceType and PieceColor to PieceType
                    if (piece.color == PieceColor.RED) {
                        piece_type = piece.piece_type == DraughtsPieceType.KING ?
                                    PieceType.RED_KING : PieceType.RED_REGULAR;
                    } else if (piece.color == PieceColor.BLACK) {
                        piece_type = piece.piece_type == DraughtsPieceType.KING ?
                                    PieceType.BLACK_KING : PieceType.BLACK_REGULAR;
                    }

                    board_state[pos.row, pos.col] = piece_type;
                    placed_count++;
                } else {
                    logger.debug(@"DraughtsBoard: REJECTED piece at ($(pos.row),$(pos.col)) - out of bounds for board_size=$(board_size)");
                }
            }

            logger.debug(@"DraughtsBoard: Piece summary - Red: $(red_count), Black: $(black_count), Placed: $(placed_count)");

            // Update the visual display
            update_board_display();
        }

        public GameState get_game_state() {
            return game_state;
        }

        public void highlight_square(int row, int col, string highlight_type) {
            // Store the highlight for drawing
            string key = @"$row,$col";
            highlighted_squares[key] = highlight_type;
            drawing_area.queue_draw();
        }

        public void clear_highlights() {
            // Clear all stored highlights
            highlighted_squares.clear();
            preview_pieces.clear();
            playable_pieces.clear();
            hover_glow_row = -1;
            hover_glow_col = -1;
            drawing_area.queue_draw();
        }

        public void set_preview_piece(int row, int col, PieceType piece_type) {
            string key = @"$row,$col";
            preview_pieces[key] = piece_type;
            drawing_area.queue_draw();
        }

        public void clear_preview_pieces() {
            preview_pieces.clear();
            drawing_area.queue_draw();
        }

        public void set_playable_pieces(Gee.HashSet<string> pieces) {
            playable_pieces = pieces;
            drawing_area.queue_draw();
        }

        public void clear_playable_pieces() {
            playable_pieces.clear();
            drawing_area.queue_draw();
        }

        public void set_hover_glow(int row, int col) {
            hover_glow_row = row;
            hover_glow_col = col;
            drawing_area.queue_draw();
        }

        public void clear_hover_glow() {
            hover_glow_row = -1;
            hover_glow_col = -1;
            drawing_area.queue_draw();
        }

        // Enable external move handling by exposing square click events
        public signal void square_clicked(int row, int col);

        // Override the internal click handler to emit the signal
        private void on_square_clicked_external(int row, int col) {
            // In external mode, only emit signal - let the adapter handle all logic
            square_clicked(row, col);
        }

        public void set_external_mode(bool external) {
            // With DrawingArea, event handlers are set up once in setup_event_handlers()
            // No need to reconnect - events are always emitted via square_clicked signal
        }

        private void apply_board_theme(string theme) {
            // Update colors based on theme
            switch (theme) {
                case "classic":
                    light_square_color = { 0.94f, 0.85f, 0.69f, 1.0f }; // Beige
                    dark_square_color = { 0.55f, 0.35f, 0.17f, 1.0f };  // Brown
                    break;
                case "wood":
                    light_square_color = { 0.82f, 0.71f, 0.55f, 1.0f }; // Light wood
                    dark_square_color = { 0.40f, 0.26f, 0.13f, 1.0f };  // Dark wood
                    break;
                case "green":
                    light_square_color = { 0.93f, 0.93f, 0.82f, 1.0f }; // Cream
                    dark_square_color = { 0.46f, 0.59f, 0.34f, 1.0f };  // Forest green
                    break;
                case "blue":
                    light_square_color = { 0.87f, 0.92f, 0.98f, 1.0f }; // Light blue
                    dark_square_color = { 0.42f, 0.55f, 0.66f, 1.0f };  // Steel blue
                    break;
                case "contrast":
                    light_square_color = { 1.0f, 1.0f, 1.0f, 1.0f };    // White
                    dark_square_color = { 0.0f, 0.0f, 0.0f, 1.0f };     // Black
                    break;
                default:
                    light_square_color = { 0.94f, 0.85f, 0.69f, 1.0f }; // Beige
                    dark_square_color = { 0.55f, 0.35f, 0.17f, 1.0f };  // Brown
                    break;
            }

            // Queue redraw to show new colors
            drawing_area.queue_draw();
            logger.debug("Applied board theme: %s", theme);
        }

        /**
         * Easing function for smooth animation (ease-in-out)
         */
        private double ease_in_out(double t) {
            // Cubic ease-in-out
            if (t < 0.5) {
                return 4.0 * t * t * t;
            } else {
                double f = (2.0 * t) - 2.0;
                return 0.5 * f * f * f + 1.0;
            }
        }

        /**
         * Animation tick callback
         */
        private bool on_animation_tick(Gtk.Widget widget, Gdk.FrameClock frame_clock) {
            int64 current_time = frame_clock.get_frame_time() / 1000; // Convert to milliseconds
            int64 elapsed = current_time - anim_start_time;

            if (elapsed >= ANIMATION_DURATION_MS && is_animating) {
                // Animation complete
                anim_progress = 1.0;
                is_animating = false;

                // Clear captured pieces immediately (no fade animation)
                anim_captured_pieces = null;
                anim_fade_progress = 0.0;

                // Stop the tick callback
                anim_tick_callback_id = 0;
                drawing_area.queue_draw();

                animation_completed();
                return Source.REMOVE;
            } else if (is_animating) {
                // Update animation progress
                double linear_progress = (double)elapsed / ANIMATION_DURATION_MS;
                anim_progress = ease_in_out(linear_progress);
            }

            drawing_area.queue_draw();
            return Source.CONTINUE;
        }

        /**
         * Start animating a piece move
         */
        public void animate_move(int from_row, int from_col, int to_row, int to_col, Position[]? captured = null) {
            // Stop any existing animation
            if (anim_tick_callback_id > 0) {
                drawing_area.remove_tick_callback(anim_tick_callback_id);
            }

            // Set up animation state
            is_animating = true;
            anim_from_row = from_row;
            anim_from_col = from_col;
            anim_to_row = to_row;
            anim_to_col = to_col;
            anim_piece_type = board_state[from_row, from_col];

            anim_progress = 0.0;
            anim_start_time = get_monotonic_time() / 1000; // Convert to milliseconds

            // Store captured pieces for fade-out animation
            if (captured != null && captured.length > 0) {
                anim_captured_pieces = captured;
            } else {
                anim_captured_pieces = null;
            }

            // Start animation tick callback
            anim_tick_callback_id = drawing_area.add_tick_callback(on_animation_tick);
        }

        /**
         * Signal emitted when animation completes
         */
        public signal void animation_completed();

        /**
         * Check if animation is currently playing
         */
        public bool get_is_animating() {
            return is_animating || (anim_captured_pieces != null && anim_captured_pieces.length > 0);
        }

    }
}