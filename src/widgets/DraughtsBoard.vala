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
        private Gtk.Button[,] squares;
        private PieceType[,] board_state;
        private Logger logger;
        private Gtk.Grid board_grid;
        private Gtk.AspectFrame aspect_frame;
        private SettingsManager settings_manager;

        // Piece images as Paintables
        private Gdk.Paintable? red_checker_image;
        private Gdk.Paintable? black_checker_image;
        private Gdk.Paintable? red_king_image;
        private Gdk.Paintable? black_king_image;

        // Game state
        private Player current_player;
        private GameState game_state;
        private Position? selected_position;
        private Move[] valid_moves;

        public DraughtsBoard() {
            Object();
            logger = Logger.get_default();
            settings_manager = SettingsManager.get_instance();

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

            setup_aspect_frame();
            create_board();
            initialize_game();
            string board_theme = settings_manager.get_board_theme();
            if (board_theme == "") {
                board_theme = Constants.DEFAULT_BOARD_THEME;
                settings_manager.set_board_theme(board_theme);
            }
            apply_board_theme(board_theme);

            // Set up resize handler for automatic scaling
            setup_resize_handlers();

            // Ensure pieces are displayed after everything is set up
            Idle.add(() => {
                update_board_display();
                // Force initial scaling after a brief delay
                Timeout.add(100, () => {
                    rescale_all_pieces();
                    return false;
                });
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
                string red_checker_path, black_checker_path, red_king_path, black_king_path;

                if (piece_style == "plastic") {
                    // Use default plastic images (no suffix)
                    red_checker_path = "/io/github/tobagin/Draughts/Devel/red-checker.png";
                    black_checker_path = "/io/github/tobagin/Draughts/Devel/black-checker.png";
                    red_king_path = "/io/github/tobagin/Draughts/Devel/red-king.png";
                    black_king_path = "/io/github/tobagin/Draughts/Devel/black-king.png";
                } else {
                    // Use themed images with suffix
                    red_checker_path = @"/io/github/tobagin/Draughts/Devel/red-checker-$(piece_style).png";
                    black_checker_path = @"/io/github/tobagin/Draughts/Devel/black-checker-$(piece_style).png";
                    red_king_path = @"/io/github/tobagin/Draughts/Devel/red-king-$(piece_style).png";
                    black_king_path = @"/io/github/tobagin/Draughts/Devel/black-king-$(piece_style).png";
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

                logger.info("Successfully loaded %s piece images from resources", piece_style);
            } catch (Error e) {
                logger.warning("Failed to load piece images: %s", e.message);
                // Fall back to default plastic images
                try {
                    red_checker_image = Gdk.Texture.from_resource("/io/github/tobagin/Draughts/Devel/red-checker.png");
                    black_checker_image = Gdk.Texture.from_resource("/io/github/tobagin/Draughts/Devel/black-checker.png");
                    red_king_image = Gdk.Texture.from_resource("/io/github/tobagin/Draughts/Devel/red-king.png");
                    black_king_image = Gdk.Texture.from_resource("/io/github/tobagin/Draughts/Devel/black-king.png");
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

            // Clear existing images to force reload
            red_checker_image = null;
            black_checker_image = null;
            red_king_image = null;
            black_king_image = null;

            // Load new themed images
            load_piece_images();

            // Use Idle.add to ensure the refresh happens after any pending operations
            Idle.add(() => {
                // Force a complete refresh of the board display
                // This will re-render all pieces with the new images
                update_board_display();

                // Force a re-scale to ensure proper sizing
                rescale_all_pieces();

                logger.info("Piece images reloaded and board updated with new theme");
                return false;
            });
        }

        private void set_piece_image_size(Gtk.Image image, Gtk.Button button) {
            // Schedule the sizing to happen after the widget is fully realized
            Idle.add(() => {
                calculate_and_set_piece_size(image);
                return false;
            });
        }

        private void setup_resize_handlers() {
            // Connect to size allocation changes for responsive scaling
            board_grid.notify["width"].connect(() => {
                Idle.add(() => {
                    rescale_all_pieces();
                    return false;
                });
            });

            board_grid.notify["height"].connect(() => {
                Idle.add(() => {
                    rescale_all_pieces();
                    return false;
                });
            });

            aspect_frame.notify["width"].connect(() => {
                Idle.add(() => {
                    rescale_all_pieces();
                    return false;
                });
            });

            aspect_frame.notify["height"].connect(() => {
                Idle.add(() => {
                    rescale_all_pieces();
                    return false;
                });
            });
        }

        public void rescale_all_pieces() {
            // Rescale all existing piece images
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    var button = squares[row, col];
                    var child = button.get_child();
                    if (child != null && child is Gtk.Image) {
                        calculate_and_set_piece_size((Gtk.Image)child);
                    }
                }
            }
        }

        private void calculate_and_set_piece_size(Gtk.Image image) {
            // Get actual board dimensions
            int board_width = board_grid.get_allocated_width();
            int board_height = board_grid.get_allocated_height();

            // If dimensions aren't available yet, try to get them from the aspect frame
            if (board_width <= 0 || board_height <= 0) {
                board_width = aspect_frame.get_allocated_width();
                board_height = aspect_frame.get_allocated_height();
            }

            // Use the smaller dimension to ensure pieces fit properly
            int board_dimension = (board_width > 0 && board_height > 0) ?
                int.min(board_width, board_height) : 400; // reasonable fallback

            // Calculate square size and make pieces 90% of that (still 12.5% larger than before)
            int square_size = board_dimension / board_size;
            int piece_size = (int)(square_size * 0.9); // Was 0.8, now 0.9 (12.5% increase)

            // Ensure reasonable bounds but allow more scaling
            if (piece_size < 40) {
                piece_size = 40;  // Reasonable minimum
            } else if (piece_size > 250) {
                piece_size = 250; // Allow even larger pieces (increased from 200)
            }

            image.set_pixel_size(piece_size);
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

            // Create the grid that will hold the board
            board_grid = new Gtk.Grid();
            board_grid.add_css_class("draughts-board");
            board_grid.set_hexpand(true);
            board_grid.set_vexpand(true);

            aspect_frame.set_child(board_grid);
            append(aspect_frame);
        }

        private void create_board() {
            // Initialize arrays
            squares = new Gtk.Button[board_size, board_size];
            board_state = new PieceType[board_size, board_size];

            // Clear any existing children from board_grid
            while (board_grid.get_first_child() != null) {
                board_grid.remove(board_grid.get_first_child());
            }
            board_grid.set_column_homogeneous(true);
            board_grid.set_row_homogeneous(true);
            board_grid.set_hexpand(true);
            board_grid.set_vexpand(true);

            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    var button = new Gtk.Button();
                    button.set_hexpand(true);
                    button.set_vexpand(true);
                    button.set_halign(Gtk.Align.FILL);
                    button.set_valign(Gtk.Align.FILL);

                    // Chess board pattern: dark squares on (row + col) % 2 == 1
                    if ((row + col) % 2 == 1) {
                        button.add_css_class("draughts-dark-square");
                    } else {
                        button.add_css_class("draughts-light-square");
                    }

                    squares[row, col] = button;
                    board_grid.attach(button, col, row, 1, 1);

                    // Connect click handler
                    int captured_row = row;
                    int captured_col = col;
                    button.clicked.connect(() => {
                        on_square_clicked(captured_row, captured_col);
                    });
                }
            }
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
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    var button = squares[row, col];
                    var piece = board_state[row, col];

                    // Remove existing piece and highlight classes
                    button.remove_css_class("draughts-red-piece");
                    button.remove_css_class("draughts-black-piece");
                    button.remove_css_class("draughts-red-king");
                    button.remove_css_class("draughts-black-king");
                    button.remove_css_class("draughts-selected");
                    button.remove_css_class("draughts-valid-move");
                    button.remove_css_class("draughts-capture-move");

                    // Add piece images
                    switch (piece) {
                        case PieceType.RED_REGULAR:
                            if (red_checker_image != null) {
                                var image = new Gtk.Image.from_paintable(red_checker_image);
                                set_piece_image_size(image, button);
                                button.set_child(image);
                            }
                            break;
                        case PieceType.RED_KING:
                            if (red_king_image != null) {
                                var image = new Gtk.Image.from_paintable(red_king_image);
                                set_piece_image_size(image, button);
                                button.set_child(image);
                            }
                            break;
                        case PieceType.BLACK_REGULAR:
                            if (black_checker_image != null) {
                                var image = new Gtk.Image.from_paintable(black_checker_image);
                                set_piece_image_size(image, button);
                                button.set_child(image);
                            }
                            break;
                        case PieceType.BLACK_KING:
                            if (black_king_image != null) {
                                var image = new Gtk.Image.from_paintable(black_king_image);
                                set_piece_image_size(image, button);
                                button.set_child(image);
                            }
                            break;
                        case PieceType.NONE:
                            button.set_child(null);
                            break;
                    }

                    // Add selection highlighting
                    if (selected_position != null && selected_position.row == row && selected_position.col == col) {
                        button.add_css_class("draughts-selected");
                    }

                    // Add move highlighting
                    foreach (Move move in valid_moves) {
                        if (move.to.row == row && move.to.col == col) {
                            if (move.captures.length > 0) {
                                button.add_css_class("draughts-capture-move");
                            } else {
                                button.add_css_class("draughts-valid-move");
                            }
                            break;
                        }
                    }
                }
            }
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
            if (row >= 0 && row < board_size && col >= 0 && col < board_size) {
                var button = squares[row, col];

                // Clear existing highlight classes
                button.remove_css_class("draughts-selected");
                button.remove_css_class("draughts-valid-move");
                button.remove_css_class("draughts-capture-move");
                button.remove_css_class("draughts-playable");

                // Add appropriate highlight class
                switch (highlight_type) {
                    case "selected":
                        button.add_css_class("draughts-selected");
                        break;
                    case "possible":
                        button.add_css_class("draughts-valid-move");
                        break;
                    case "capture":
                        button.add_css_class("draughts-capture-move");
                        break;
                    case "playable":
                        button.add_css_class("draughts-playable");
                        break;
                }
            }
        }

        public void clear_highlights() {
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    var button = squares[row, col];
                    button.remove_css_class("draughts-selected");
                    button.remove_css_class("draughts-valid-move");
                    button.remove_css_class("draughts-capture-move");
                    button.remove_css_class("draughts-playable");
                }
            }
        }

        // Enable external move handling by exposing square click events
        public signal void square_clicked(int row, int col);

        // Override the internal click handler to emit the signal
        private void on_square_clicked_external(int row, int col) {
            // In external mode, only emit signal - let the adapter handle all logic
            square_clicked(row, col);
        }

        public void set_external_mode(bool external) {
            // Reconnect click handlers based on mode
            for (int row = 0; row < board_size; row++) {
                for (int col = 0; col < board_size; col++) {
                    var button = squares[row, col];

                    // Disconnect existing handlers (can't disconnect specific lambda)
                    // button.clicked.disconnect(on_square_clicked);

                    if (external) {
                        // Connect external handler
                        int captured_row = row;
                        int captured_col = col;
                        button.clicked.connect(() => {
                            square_clicked(captured_row, captured_col);
                        });
                    } else {
                        // Connect internal handler
                        int captured_row = row;
                        int captured_col = col;
                        button.clicked.connect(() => {
                            on_square_clicked(captured_row, captured_col);
                        });
                    }
                }
            }
        }

        private void apply_board_theme(string theme) {
            // Remove existing theme classes
            board_grid.remove_css_class("draughts-board-classic");
            board_grid.remove_css_class("draughts-board-wood");
            board_grid.remove_css_class("draughts-board-green");
            board_grid.remove_css_class("draughts-board-blue");
            board_grid.remove_css_class("draughts-board-contrast");

            // Apply new theme class
            switch (theme) {
                case "classic":
                    board_grid.add_css_class("draughts-board-classic");
                    break;
                case "wood":
                    board_grid.add_css_class("draughts-board-wood");
                    break;
                case "green":
                    board_grid.add_css_class("draughts-board-green");
                    break;
                case "blue":
                    board_grid.add_css_class("draughts-board-blue");
                    break;
                case "contrast":
                    board_grid.add_css_class("draughts-board-contrast");
                    break;
                default:
                    board_grid.add_css_class("draughts-board-classic");
                    break;
            }

            logger.debug("Applied board theme: %s", theme);
        }

    }
}