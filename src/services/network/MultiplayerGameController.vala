/**
 * MultiplayerGameController.vala
 *
 * Game controller for multiplayer games.
 * Extends local game logic with network synchronization.
 * Implements the IGameController interface for compatibility.
 */

using Draughts;

namespace Draughts {

    /**
     * Controller for multiplayer draughts games
     */
    public class MultiplayerGameController : GLib.Object, IGameController {
        private Game? current_game;
        private NetworkSession session;
        private NetworkClient client;
        private Logger logger;
        private bool is_paused = false;
        private PieceColor local_player_color;

        /**
         * Get the local player's color (for board orientation)
         */
        public PieceColor get_local_player_color() {
            return local_player_color;
        }

        // Move queue for network moves
        private Gee.Queue<DraughtsMove> pending_network_moves;

        // Server URL configuration
        private const string DEFAULT_SERVER_URL = "wss://draughts.tobagin.eu";

        public MultiplayerGameController(string? server_url = null) {
            this.logger = Logger.get_default();
            this.pending_network_moves = new Gee.LinkedList<DraughtsMove>();

            // Initialize network client
            string url = server_url ?? DEFAULT_SERVER_URL;
            this.client = new NetworkClient(url);
            this.session = new NetworkSession(client);

            // Connect to session signals
            setup_session_signals();

            logger.info("MultiplayerGameController: Initialized with server: %s", url);
        }

        /**
         * Set up network session signal handlers
         */
        private void setup_session_signals() {
            session.room_created.connect(on_room_created);
            session.opponent_joined.connect(on_opponent_joined);
            session.game_started.connect(on_game_started);
            session.move_received.connect(on_move_received);
            session.game_ended.connect(on_game_ended);
            session.opponent_disconnected.connect(on_opponent_disconnected);
            session.opponent_reconnected.connect(on_opponent_reconnected);
            session.session_error.connect(on_session_error);
            session.version_mismatch.connect((required, client_ver) => {
                version_mismatch(required, client_ver);
            });
        }

        /**
         * Connect to the multiplayer server
         */
        public async bool connect_to_server() {
            logger.info("MultiplayerGameController: Connecting to server...");
            return yield client.connect_async();
        }

        /**
         * Create a new multiplayer room
         */
        public async bool create_room(DraughtsVariant variant, bool use_timer = false,
                                      int minutes_per_side = 5, int increment_seconds = 0,
                                      string clock_type = "Fischer") {
            logger.info("MultiplayerGameController: Creating room for variant: %s", variant.to_string());

            // Configure session timer settings
            session.use_timer = use_timer;
            session.minutes_per_side = minutes_per_side;
            session.increment_seconds = increment_seconds;
            session.clock_type = clock_type;

            return yield session.create_room(variant);
        }

        /**
         * Join an existing multiplayer room
         */
        public async bool join_room(string room_code) {
            logger.info("MultiplayerGameController: Joining room: %s", room_code);
            return yield session.join_room(room_code);
        }

        /**
         * Start quick match search
         */
        public async bool quick_match(DraughtsVariant variant) {
            logger.info("MultiplayerGameController: Starting quick match for variant: %s", variant.to_string());
            return yield session.quick_match(variant);
        }

        /**
         * Cancel quick match search
         */
        public bool cancel_quick_match() {
            logger.info("MultiplayerGameController: Canceling quick match");
            return session.cancel_quick_match();
        }

        /**
         * Start a new game (IGameController implementation)
         * For multiplayer, this is called after room setup
         */
        public Game start_new_game(GameVariant variant, GamePlayer red_player,
                                   GamePlayer black_player, Timer? timer_config) {
            logger.info("MultiplayerGameController: Starting multiplayer game");

            current_game = new Game(Game.generate_id(), variant, red_player, black_player);

            if (timer_config != null) {
                current_game.set_timers(timer_config, timer_config.clone());
            }

            is_paused = false;
            pending_network_moves.clear();

            logger.info("MultiplayerGameController: Game started - Local player: %s",
                       local_player_color.to_string());

            return current_game;
        }

        /**
         * Make a move in the current game (IGameController implementation)
         */
        public bool make_move(DraughtsMove move) {
            if (current_game == null || is_paused) {
                logger.warning("MultiplayerGameController: Cannot make move - game not active");
                return false;
            }

            // Check if it's the local player's turn
            var current_player_color = current_game.current_state.active_player;
            if (current_player_color != local_player_color) {
                logger.warning("MultiplayerGameController: Not your turn! Current: %s, Local: %s",
                             current_player_color.to_string(), local_player_color.to_string());
                return false;
            }

            // Apply move locally (optimistic update)
            bool success = current_game.make_move(move);

            if (success) {
                // Send move to server
                session.make_move(move);

                // Emit signal for UI update
                game_state_changed(current_game.current_state, move);

                logger.debug("MultiplayerGameController: Local move made and sent to server");

                // Check if the game ended as a result of this move
                if (current_game.is_game_over()) {
                    var result = current_game.current_state.game_status;
                    logger.info("MultiplayerGameController: Game ended locally with result: %s", result.to_string());

                    // Notify server so it can broadcast game_ended to both players
                    session.notify_game_ended(result, "game_over");
                }
            } else {
                logger.warning("MultiplayerGameController: Move validation failed");
            }

            return success;
        }

        /**
         * Undo last move (disabled in multiplayer)
         */
        public bool undo_last_move() {
            logger.warning("MultiplayerGameController: Undo not available in multiplayer");
            return false;
        }

        /**
         * Undo full round (disabled in multiplayer)
         */
        public bool undo_full_round(int move_count) {
            logger.warning("MultiplayerGameController: Undo not available in multiplayer");
            return false;
        }

        /**
         * Redo last move (disabled in multiplayer)
         */
        public bool redo_last_move() {
            logger.warning("MultiplayerGameController: Redo not available in multiplayer");
            return false;
        }

        /**
         * Check if undo is available
         */
        public bool can_undo() {
            return false; // Disabled in multiplayer
        }

        /**
         * Check if redo is available
         */
        public bool can_redo() {
            return false; // Disabled in multiplayer
        }

        /**
         * Get the current game state
         */
        public DraughtsGameState get_current_state() {
            if (current_game != null) {
                return current_game.current_state;
            }

            // Return empty state if no game is active
            return new DraughtsGameState(new Gee.ArrayList<GamePiece>(), PieceColor.RED, 8);
        }

        /**
         * Get the current game instance
         */
        public Game get_current_game() {
            if (current_game != null) {
                return current_game;
            }

            // Return a default game if none exists
            return new Game("default", new GameVariant(DraughtsVariant.AMERICAN),
                           GamePlayer.create_default_human(PieceColor.RED),
                           GamePlayer.create_default_human(PieceColor.BLACK));
        }

        /**
         * Set game paused state
         */
        public void set_game_paused(bool paused) {
            is_paused = paused;
            logger.info("MultiplayerGameController: Game %s", paused ? "paused" : "resumed");
        }

        /**
         * Check if a move is legal
         */
        public bool is_move_legal(DraughtsMove move) {
            if (current_game == null) {
                return false;
            }

            var legal_moves = current_game.get_legal_moves();
            foreach (var legal_move in legal_moves) {
                if (moves_equal(move, legal_move)) {
                    return true;
                }
            }
            return false;
        }

        /**
         * View history at position (disabled in multiplayer)
         */
        public DraughtsGameState? view_history_at_position(int position) {
            logger.debug("MultiplayerGameController: History viewing not available in multiplayer");
            return null;
        }

        /**
         * Get history size
         */
        public int get_history_size() {
            if (current_game == null) {
                return 0;
            }
            return current_game.get_history_size();
        }

        /**
         * Get current history position
         */
        public int get_history_position() {
            if (current_game == null) {
                return -1;
            }
            return current_game.get_history_position();
        }

        /**
         * Check if at latest position
         */
        public bool is_at_latest_position() {
            if (current_game == null) {
                return true;
            }
            return current_game.is_at_latest_position();
        }

        /**
         * Resign from the current game
         */
        public bool resign() {
            logger.info("MultiplayerGameController: Resigning from game");
            return session.resign();
        }

        /**
         * Offer a draw
         */
        public bool offer_draw() {
            logger.info("MultiplayerGameController: Offering draw");
            return session.offer_draw();
        }

        /**
         * Leave the current session
         */
        public void leave_session() {
            logger.info("MultiplayerGameController: Leaving multiplayer session");
            session.leave_session();
            current_game = null;
        }

        /**
         * Disconnect from server
         */
        public void disconnect() {
            logger.info("MultiplayerGameController: Disconnecting from server");
            client.disconnect();
        }

        /**
         * Get network session
         */
        public NetworkSession get_session() {
            return session;
        }

        /**
         * Get network client
         */
        public NetworkClient get_client() {
            return client;
        }

        /**
         * Check if connected to server
         */
        public bool is_connected() {
            return client.is_connected();
        }

        /**
         * Get current latency
         */
        public int get_latency() {
            return client.get_latency();
        }

        // Signal handlers for network events

        /**
         * Handle room created event
         */
        private void on_room_created(string room_code, PieceColor your_color) {
            logger.info("MultiplayerGameController: Room created - Code: %s, Color: %s",
                       room_code, your_color.to_string());
            local_player_color = your_color;
            room_created(room_code, your_color);
        }

        /**
         * Handle opponent joined event
         */
        private void on_opponent_joined(string opponent_name) {
            logger.info("MultiplayerGameController: Opponent joined - %s", opponent_name);
            opponent_joined(opponent_name);
        }

        /**
         * Handle game started event
         */
        private void on_game_started(DraughtsVariant variant, PieceColor your_color,
                                     string opponent_name, Gee.ArrayList<DraughtsMove>? moves) {
            logger.info("MultiplayerGameController: Game started - Variant: %s, Your color: %s, Opponent: %s, Moves to restore: %d",
                       variant.to_string(), your_color.to_string(), opponent_name,
                       (moves != null) ? moves.size : 0);

            local_player_color = your_color;

            // Create local and remote players
            GamePlayer local_player;
            GamePlayer remote_player;

            if (your_color == PieceColor.RED) {
                local_player = GamePlayer.create_default_human(PieceColor.RED);
                local_player.name = session.player_name;
                remote_player = new GamePlayer.network_remote("remote", opponent_name, PieceColor.BLACK);
            } else {
                local_player = GamePlayer.create_default_human(PieceColor.BLACK);
                local_player.name = session.player_name;
                remote_player = new GamePlayer.network_remote("remote", opponent_name, PieceColor.RED);
            }

            // Create game variant
            var game_variant = new GameVariant(variant);

            // Create timers if configured
            Timer? timer = null;
            if (session.use_timer) {
                TimeSpan base_time = TimeSpan.SECOND * (session.minutes_per_side * 60);
                TimeSpan increment = TimeSpan.SECOND * session.increment_seconds;

                if (session.clock_type == "Fischer") {
                    timer = new Timer.fischer(base_time, increment);
                } else {
                    timer = new Timer.with_delay(base_time, increment);
                }
            }

            // Start the game
            GamePlayer red_player = (your_color == PieceColor.RED) ? local_player : remote_player;
            GamePlayer black_player = (your_color == PieceColor.BLACK) ? local_player : remote_player;

            start_new_game(game_variant, red_player, black_player, timer);

            // Replay moves to restore game state
            if (moves != null && moves.size > 0) {
                logger.info("MultiplayerGameController: Replaying %d moves to restore game state", moves.size);
                foreach (var move in moves) {
                    bool success = current_game.make_move(move);
                    if (!success) {
                        logger.error("MultiplayerGameController: Failed to replay move during restoration");
                    }
                }
                logger.info("MultiplayerGameController: Game state restored to move %d", moves.size);
            }

            // Emit game started signal
            multiplayer_game_started(variant, your_color, opponent_name);

            // Emit current game state (after replaying moves)
            if (current_game != null) {
                game_state_changed(current_game.current_state, null);
            }
        }

        /**
         * Handle move received from network
         */
        private void on_move_received(DraughtsMove move) {
            logger.debug("MultiplayerGameController: Move received from opponent");

            if (current_game == null) {
                logger.warning("MultiplayerGameController: Received move but no game active");
                return;
            }

            // Verify it's the opponent's turn
            var current_player_color = current_game.current_state.active_player;
            if (current_player_color == local_player_color) {
                logger.warning("MultiplayerGameController: Received move but it's our turn!");
                return;
            }

            // Apply the opponent's move
            bool success = current_game.make_move(move);

            if (success) {
                logger.debug("MultiplayerGameController: Opponent move applied successfully");

                // Emit signal for UI update
                game_state_changed(current_game.current_state, move);

                // Don't check for game end locally - wait for server to send GAME_ENDED message
                // This prevents duplicate game_finished signals
            } else {
                logger.error("MultiplayerGameController: Failed to apply opponent move - game may be desynced!");
            }
        }

        /**
         * Handle game ended event
         */
        private void on_game_ended(GameStatus result, string reason) {
            logger.info("MultiplayerGameController: Game ended - Result: %s, Reason: %s",
                       result.to_string(), reason);

            if (current_game != null) {
                current_game.current_state.game_status = result;
            }

            game_finished(result, reason);
        }

        /**
         * Handle opponent disconnected
         */
        private void on_opponent_disconnected() {
            logger.warning("MultiplayerGameController: Opponent disconnected");
            opponent_disconnected();
        }

        /**
         * Handle opponent reconnected
         */
        private void on_opponent_reconnected() {
            logger.info("MultiplayerGameController: Opponent reconnected");
            opponent_reconnected();
        }

        /**
         * Handle session error
         */
        private void on_session_error(string error_message) {
            logger.warning("MultiplayerGameController: Session error: %s", error_message);
            multiplayer_error(error_message);
        }

        /**
         * Compare two moves for equality
         */
        private bool moves_equal(DraughtsMove a, DraughtsMove b) {
            return a.piece_id == b.piece_id &&
                   a.from_position.equals(b.from_position) &&
                   a.to_position.equals(b.to_position);
        }

        // Additional signals specific to multiplayer
        public signal void room_created(string room_code, PieceColor your_color);
        public signal void opponent_joined(string opponent_name);
        public signal void multiplayer_game_started(DraughtsVariant variant, PieceColor your_color,
                                                   string opponent_name);
        public signal void opponent_disconnected();
        public signal void opponent_reconnected();
        public signal void multiplayer_error(string error_message);
        public signal void version_mismatch(string required_version, string client_version);
    }
}
