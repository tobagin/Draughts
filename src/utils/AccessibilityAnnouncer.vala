/**
 * AccessibilityAnnouncer.vala
 *
 * Screen reader announcement system for draughts game accessibility.
 * Provides contextual audio feedback for game events and board state.
 */

using Draughts;

public class Draughts.AccessibilityAnnouncer : Object {
    private DraughtsBoardAdapter? adapter;
    private bool screen_reader_enabled = false;
    private bool move_announcements_enabled = true;
    private bool game_status_announcements_enabled = true;
    private AnnouncementLevel announcement_level = AnnouncementLevel.MOVE_AND_CAPTURE;

    // Announcement queue for managing multiple simultaneous announcements
    private Gee.Queue<string> announcement_queue;
    private bool is_announcing = false;
    private uint announcement_timer = 0;

    public AccessibilityAnnouncer() {
        announcement_queue = new Gee.ArrayQueue<string>();

        // Connect to system accessibility settings
        connect_to_system_settings();
    }

    /**
     * Connect to game adapter for event notifications
     */
    public void connect_adapter(DraughtsBoardAdapter adapter) {
        if (this.adapter != null) {
            // Disconnect from previous adapter
            this.adapter.game_state_changed.disconnect(on_game_state_changed);
            this.adapter.move_made.disconnect(on_move_made);
            this.adapter.game_finished.disconnect(on_game_finished);
        }

        this.adapter = adapter;

        // Connect to new adapter
        adapter.game_state_changed.connect(on_game_state_changed);
        adapter.move_made.connect(on_move_made);
        adapter.game_finished.connect(on_game_finished);
    }

    /**
     * Connect to system accessibility settings
     */
    private void connect_to_system_settings() {
        // Check if screen reader is active
        var settings = new Settings("org.gnome.desktop.a11y.applications");
        screen_reader_enabled = settings.get_boolean("screen-reader-enabled");

        // Monitor changes to accessibility settings
        settings.changed.connect((key) => {
            if (key == "screen-reader-enabled") {
                screen_reader_enabled = settings.get_boolean(key);
            }
        });
    }

    /**
     * Handle game state changes
     */
    private void on_game_state_changed(DraughtsGameState new_state) {
        if (!should_announce()) return;

        if (game_status_announcements_enabled) {
            announce_game_status(new_state);
        }

        // Announce turn changes
        if (move_announcements_enabled) {
            announce_turn_change(new_state.active_player);
        }
    }

    /**
     * Handle move events
     */
    private void on_move_made(DraughtsMove move) {
        if (!should_announce() || !move_announcements_enabled) return;

        string announcement = create_move_announcement(move);
        queue_announcement(announcement);
    }

    /**
     * Handle game finished events
     */
    private void on_game_finished(GameStatus result) {
        if (!should_announce()) return;

        string announcement = create_game_result_announcement(result);
        queue_announcement(announcement, true); // High priority
    }

    /**
     * Create detailed move announcement
     */
    private string create_move_announcement(DraughtsMove move) {
        var announcement = new StringBuilder();

        // Get piece information
        var current_state = adapter?.get_current_state();
        if (current_state == null) return "Move made";

        // Find the piece that moved
        GamePiece? moving_piece = null;
        foreach (var piece in current_state.pieces) {
            if (piece.position.equals(move.to_position)) {
                moving_piece = piece;
                break;
            }
        }

        if (moving_piece == null) return "Move made";

        // Basic move description
        string piece_desc = get_piece_description(moving_piece);
        string from_square = get_square_name(move.from_position);
        string to_square = get_square_name(move.to_position);

        switch (announcement_level) {
            case AnnouncementLevel.MOVE_ONLY:
                announcement.append_printf("%s to %s", from_square, to_square);
                break;

            case AnnouncementLevel.MOVE_AND_CAPTURE:
                announcement.append_printf("%s moves from %s to %s", piece_desc, from_square, to_square);

                if (move.move_type == MoveType.CAPTURE || move.move_type == MoveType.MULTIPLE_CAPTURE) {
                    int captures = move.captured_pieces.length;
                    if (captures == 1) {
                        announcement.append(", capturing one piece");
                    } else {
                        announcement.append_printf(", capturing %d pieces", captures);
                    }
                }
                break;

            case AnnouncementLevel.FULL_DESCRIPTION:
                announcement.append_printf("%s at %s moves to %s", piece_desc, from_square, to_square);

                // Add capture details
                if (move.move_type == MoveType.CAPTURE || move.move_type == MoveType.MULTIPLE_CAPTURE) {
                    var captured_descriptions = new StringBuilder();
                    for (int i = 0; i < move.captured_pieces.length; i++) {
                        int captured_id = move.captured_pieces[i];
                        captured_descriptions.append_printf("piece %d", captured_id);
                        if (i < move.captured_pieces.length - 1) {
                            captured_descriptions.append(", ");
                        }
                    }
                    announcement.append_printf(", capturing pieces at %s", captured_descriptions.str);
                }

                // Add promotion information
                if (move.is_promotion) {
                    announcement.append(", promoted to king");
                }
                break;
        }

        return announcement.str;
    }

    /**
     * Create game result announcement
     */
    private string create_game_result_announcement(GameStatus result) {
        switch (result) {
            case GameStatus.RED_WINS:
                return "Game over. Red player wins!";
            case GameStatus.BLACK_WINS:
                return "Game over. Black player wins!";
            case GameStatus.DRAW:
                return "Game over. The game is a draw.";
            default:
                return "Game finished.";
        }
    }

    /**
     * Announce game status
     */
    private void announce_game_status(DraughtsGameState state) {
        if (state.is_game_over()) {
            string announcement = create_game_result_announcement(state.game_status);
            queue_announcement(announcement, true);
        }
    }

    /**
     * Announce turn change
     */
    private void announce_turn_change(PieceColor active_player) {
        string player_name = (active_player == PieceColor.RED) ? "Red" : "Black";
        string announcement = @"$(player_name)'s turn";
        queue_announcement(announcement);
    }

    /**
     * Announce board position for navigation
     */
    public void announce_board_position(int row, int col) {
        if (!should_announce()) return;

        string square_name = get_square_name_for_position(row, col);

        var current_state = adapter?.get_current_state();
        if (current_state == null) {
            queue_announcement(@"Cursor at $(square_name)");
            return;
        }

        var pos = new BoardPosition(row, col, current_state.board_size);
        GamePiece? piece = null;

        foreach (var p in current_state.pieces) {
            if (p.position.equals(pos)) {
                piece = p;
                break;
            }
        }

        string announcement;
        if (piece != null) {
            string piece_desc = get_piece_description(piece);
            announcement = @"$(square_name), $(piece_desc)";
        } else {
            bool is_dark = (row + col) % 2 == 1;
            string square_color = is_dark ? "dark" : "light";
            announcement = @"$(square_name), empty $(square_color) square";
        }

        queue_announcement(announcement);
    }

    /**
     * Announce available moves for current position
     */
    public void announce_available_moves(int row, int col) {
        if (!should_announce() || adapter == null) return;

        var legal_moves = adapter.get_legal_moves_for_position(row, col);
        string square_name = get_square_name_for_position(row, col);

        if (legal_moves.size == 0) {
            queue_announcement(@"No legal moves from $(square_name)");
            return;
        }

        var move_list = new StringBuilder();
        move_list.append_printf("From %s, %d legal moves: ", square_name, legal_moves.size);

        int max_moves_to_announce = int.min(5, legal_moves.size);
        for (int i = 0; i < max_moves_to_announce; i++) {
            var move = legal_moves.get(i);
            string to_square = get_square_name(move.to_position);
            move_list.append(to_square);

            if (move.move_type == MoveType.CAPTURE || move.move_type == MoveType.MULTIPLE_CAPTURE) {
                move_list.append(" capture");
            }

            if (i < max_moves_to_announce - 1) {
                move_list.append(", ");
            }
        }

        if (legal_moves.size > 5) {
            move_list.append(@" and $(legal_moves.size - 5) more");
        }

        queue_announcement(move_list.str);
    }

    /**
     * Announce game statistics
     */
    public void announce_game_statistics() {
        if (!should_announce() || adapter == null) return;

        var stats = adapter.get_game_statistics();
        if (stats == null) return;

        var announcement = new StringBuilder();
        announcement.append_printf("Game statistics: Red has %d pieces, Black has %d pieces",
                                 stats.red_piece_count, stats.black_piece_count);

        if (stats.red_king_count > 0 || stats.black_king_count > 0) {
            announcement.append_printf(". Kings: Red %d, Black %d",
                                     stats.red_king_count, stats.black_king_count);
        }

        queue_announcement(announcement.str);
    }

    /**
     * Queue announcement for screen reader
     */
    private void queue_announcement(string message, bool high_priority = false) {
        if (!should_announce()) return;

        if (high_priority) {
            // Clear queue and announce immediately for important messages
            announcement_queue.clear();
            announce_immediately(message);
        } else {
            announcement_queue.offer(message);
            process_announcement_queue();
        }
    }

    /**
     * Process queued announcements
     */
    private void process_announcement_queue() {
        if (is_announcing || announcement_queue.is_empty) return;

        string message = announcement_queue.poll();
        if (message != null) {
            announce_immediately(message);
        }
    }

    /**
     * Make immediate announcement
     */
    private void announce_immediately(string message) {
        is_announcing = true;

        // Send to screen reader via AT-SPI
        send_to_screen_reader(message);

        // Set timer to mark announcement as complete
        if (announcement_timer != 0) {
            Source.remove(announcement_timer);
        }

        announcement_timer = Timeout.add(calculate_announcement_duration(message), () => {
            is_announcing = false;
            announcement_timer = 0;

            // Process next announcement in queue
            Idle.add(() => {
                process_announcement_queue();
                return false;
            });

            return false;
        });
    }

    /**
     * Send message to screen reader
     */
    private void send_to_screen_reader(string message) {
        // This would integrate with AT-SPI or similar accessibility framework
        // For development, we'll use debug output
        debug("Screen reader: %s", message);

        // In production, this would use:
        // - AT-SPI on Linux
        // - MSAA/UI Automation on Windows
        // - NSAccessibility on macOS
        // For now, we simulate the announcement

        try {
            // Example AT-SPI integration (requires atspi library)
            // var accessible = get_accessible_object();
            // accessible.announce(message);
        } catch (Error e) {
            warning("Failed to send screen reader announcement: %s", e.message);
        }
    }

    /**
     * Calculate announcement duration based on message length
     */
    private uint calculate_announcement_duration(string message) {
        // Rough estimate: 150 words per minute reading speed
        // Plus base time for processing
        uint words = message.split(" ").length;
        uint duration_ms = (uint)((words / 150.0) * 60.0 * 1000.0);
        return uint.max(1000, duration_ms + 500); // Minimum 1 second, plus 500ms buffer
    }

    /**
     * Helper methods
     */
    private bool should_announce() {
        return screen_reader_enabled || move_announcements_enabled;
    }

    private string get_piece_description(GamePiece piece) {
        string color = (piece.color == PieceColor.RED) ? "Red" : "Black";
        string type = (piece.piece_type == DraughtsPieceType.KING) ? "king" : "man";
        return @"$(color) $(type)";
    }

    private string get_square_name(BoardPosition position) {
        return get_square_name_for_position(position.row, position.col);
    }

    private string get_square_name_for_position(int row, int col) {
        char col_letter = (char)('a' + col);
        int board_size = adapter?.get_current_state()?.board_size ?? 8;
        int row_number = board_size - row;
        return @"$(col_letter)$(row_number)";
    }

    /**
     * Public configuration methods
     */
    public void set_screen_reader_enabled(bool enabled) {
        screen_reader_enabled = enabled;
    }

    public void set_move_announcements_enabled(bool enabled) {
        move_announcements_enabled = enabled;
    }

    public void set_announcement_level(AnnouncementLevel level) {
        announcement_level = level;
    }

    public void set_game_status_announcements_enabled(bool enabled) {
        game_status_announcements_enabled = enabled;
    }

    /**
     * Cleanup
     */
    public override void dispose() {
        if (announcement_timer != 0) {
            Source.remove(announcement_timer);
            announcement_timer = 0;
        }
        base.dispose();
    }
}

/**
 * Announcement detail level
 */
public enum AnnouncementLevel {
    OFF,
    MOVE_ONLY,
    MOVE_AND_CAPTURE,
    FULL_DESCRIPTION
}