/**
 * NetworkSession.vala
 *
 * Manages multiplayer session state including room information,
 * player roles, and game synchronization.
 */

using Draughts;

namespace Draughts {

    /**
     * Session state for multiplayer game
     */
    public enum SessionState {
        IDLE,
        CREATING_ROOM,
        WAITING_FOR_OPPONENT,
        JOINING_ROOM,
        IN_GAME,
        GAME_ENDED;

        public string to_string() {
            switch (this) {
                case IDLE: return "Idle";
                case CREATING_ROOM: return "Creating Room";
                case WAITING_FOR_OPPONENT: return "Waiting for Opponent";
                case JOINING_ROOM: return "Joining Room";
                case IN_GAME: return "In Game";
                case GAME_ENDED: return "Game Ended";
                default: return "Unknown";
            }
        }
    }

    /**
     * Player role in multiplayer session
     */
    public enum PlayerRole {
        HOST,
        GUEST;

        public string to_string() {
            switch (this) {
                case HOST: return "Host";
                case GUEST: return "Guest";
                default: return "Unknown";
            }
        }
    }

    /**
     * Network session manager
     */
    public class NetworkSession : GLib.Object {
        private NetworkClient client;
        private Logger logger;
        private SessionState _state;
        private PlayerRole _role;

        // Session data
        public string? room_code { get; private set; }
        public PieceColor? local_player_color { get; private set; }
        public string? opponent_name { get; private set; }
        public DraughtsVariant? game_variant { get; private set; }
        public string player_name { get; set; default = "Guest"; }

        // Timer configuration
        public bool use_timer { get; set; default = false; }
        public int minutes_per_side { get; set; default = 5; }
        public int increment_seconds { get; set; default = 0; }
        public string clock_type { get; set; default = "Fischer"; }

        public SessionState state {
            get { return _state; }
            private set {
                if (_state != value) {
                    _state = value;
                    state_changed(_state);
                }
            }
        }

        public PlayerRole role {
            get { return _role; }
            private set { _role = value; }
        }

        // Signals
        public signal void state_changed(SessionState new_state);
        public signal void room_created(string room_code, PieceColor your_color);
        public signal void opponent_joined(string opponent_name);
        public signal void game_started(DraughtsVariant variant, PieceColor your_color, string opponent_name);
        public signal void move_received(DraughtsMove move);
        public signal void game_ended(GameStatus result, string reason);
        public signal void opponent_disconnected();
        public signal void opponent_reconnected();
        public signal void session_error(string error_message);

        public NetworkSession(NetworkClient client) {
            this.client = client;
            this.logger = Logger.get_default();
            this._state = SessionState.IDLE;

            // Generate a default player name
            this.player_name = generate_guest_name();

            // Connect to network client signals
            setup_client_signals();

            logger.info("NetworkSession: Initialized with player name: %s", player_name);
        }

        /**
         * Set up network client signal handlers
         */
        private void setup_client_signals() {
            client.message_received.connect(on_network_message_received);
            client.disconnected.connect(on_network_disconnected);
            client.error_occurred.connect(on_network_error);
        }

        /**
         * Create a new multiplayer room
         */
        public async bool create_room(DraughtsVariant variant) {
            if (state != SessionState.IDLE) {
                logger.warning("NetworkSession: Cannot create room, not in IDLE state");
                return false;
            }

            logger.info("NetworkSession: Creating room for variant: %s", variant.to_string());
            state = SessionState.CREATING_ROOM;
            role = PlayerRole.HOST;
            game_variant = variant;

            // Create and send room creation message
            var message = new CreateRoomMessage(variant, player_name);
            message.use_timer = use_timer;
            message.minutes_per_side = minutes_per_side;
            message.increment_seconds = increment_seconds;
            message.clock_type = clock_type;

            if (client.send_message(message)) {
                logger.debug("NetworkSession: Room creation request sent");
                return true;
            } else {
                logger.error("NetworkSession: Failed to send room creation request");
                state = SessionState.IDLE;
                session_error("Failed to send room creation request");
                return false;
            }
        }

        /**
         * Join an existing multiplayer room
         */
        public async bool join_room(string room_code) {
            if (state != SessionState.IDLE) {
                logger.warning("NetworkSession: Cannot join room, not in IDLE state");
                return false;
            }

            logger.info("NetworkSession: Joining room: %s", room_code);
            state = SessionState.JOINING_ROOM;
            role = PlayerRole.GUEST;
            this.room_code = room_code;

            // Create and send join room message
            var message = new JoinRoomMessage(room_code, player_name);

            if (client.send_message(message)) {
                logger.debug("NetworkSession: Room join request sent");
                return true;
            } else {
                logger.error("NetworkSession: Failed to send room join request");
                state = SessionState.IDLE;
                session_error("Failed to send room join request");
                return false;
            }
        }

        /**
         * Start quick match search
         */
        public async bool quick_match(DraughtsVariant variant) {
            if (state != SessionState.IDLE) {
                logger.warning("NetworkSession: Cannot quick match, not in IDLE state");
                return false;
            }

            logger.info("NetworkSession: Starting quick match for variant: %s", variant.to_string());
            state = SessionState.JOINING_ROOM; // Reuse joining state
            game_variant = variant;

            // Create and send quick match message
            var message = new QuickMatchMessage(variant, player_name);

            if (client.send_message(message)) {
                logger.debug("NetworkSession: Quick match request sent");
                return true;
            } else {
                logger.error("NetworkSession: Failed to send quick match request");
                state = SessionState.IDLE;
                session_error("Failed to send quick match request");
                return false;
            }
        }

        /**
         * Cancel quick match search
         */
        public bool cancel_quick_match() {
            logger.info("NetworkSession: Canceling quick match");

            var message = new NetworkMessage(NetworkMessageType.CANCEL_QUICK_MATCH);
            bool success = client.send_message(message);

            if (success && state == SessionState.JOINING_ROOM) {
                state = SessionState.IDLE;
            }

            return success;
        }

        /**
         * Make a move in the multiplayer game
         */
        public bool make_move(DraughtsMove move) {
            if (state != SessionState.IN_GAME) {
                logger.warning("NetworkSession: Cannot make move, not in game");
                return false;
            }

            logger.debug("NetworkSession: Sending move to server");
            var message = new MakeMoveMessage(move);
            return client.send_message(message);
        }

        /**
         * Resign from the current game
         */
        public bool resign() {
            if (state != SessionState.IN_GAME) {
                logger.warning("NetworkSession: Cannot resign, not in game");
                return false;
            }

            logger.info("NetworkSession: Resigning from game");
            var message = new NetworkMessage(NetworkMessageType.RESIGN);
            return client.send_message(message);
        }

        /**
         * Offer a draw to the opponent
         */
        public bool offer_draw() {
            if (state != SessionState.IN_GAME) {
                logger.warning("NetworkSession: Cannot offer draw, not in game");
                return false;
            }

            logger.info("NetworkSession: Offering draw");
            var message = new NetworkMessage(NetworkMessageType.OFFER_DRAW);
            return client.send_message(message);
        }

        /**
         * Leave the current session and reset to idle
         */
        public void leave_session() {
            logger.info("NetworkSession: Leaving session");
            reset_session();
        }

        /**
         * Handle incoming network messages
         */
        private void on_network_message_received(NetworkMessage message, string raw_json) {
            logger.debug("NetworkSession: Received message type: %s", message.message_type.to_string());

            switch (message.message_type) {
                case NetworkMessageType.ROOM_CREATED:
                    handle_room_created((RoomCreatedMessage) message);
                    break;

                case NetworkMessageType.OPPONENT_JOINED:
                    handle_opponent_joined(message, raw_json);
                    break;

                case NetworkMessageType.GAME_STARTED:
                    handle_game_started((GameStartedMessage) message);
                    break;

                case NetworkMessageType.MOVE_MADE:
                    handle_move_made(message, raw_json);
                    break;

                case NetworkMessageType.GAME_ENDED:
                    handle_game_ended(message, raw_json);
                    break;

                case NetworkMessageType.OPPONENT_DISCONNECTED:
                    handle_opponent_disconnected();
                    break;

                case NetworkMessageType.OPPONENT_RECONNECTED:
                    handle_opponent_reconnected();
                    break;

                case NetworkMessageType.ERROR:
                    handle_error((ErrorMessage) message);
                    break;

                default:
                    logger.debug("NetworkSession: Unhandled message type: %s", message.message_type.to_string());
                    break;
            }
        }

        /**
         * Handle room created response
         */
        private void handle_room_created(RoomCreatedMessage message) {
            logger.info("NetworkSession: Room created with code: %s", message.room_code);
            room_code = message.room_code;
            local_player_color = message.player_color;
            state = SessionState.WAITING_FOR_OPPONENT;
            room_created(room_code, local_player_color);
        }

        /**
         * Handle opponent joined event
         */
        private void handle_opponent_joined(NetworkMessage message, string raw_json) {
            logger.info("NetworkSession: Opponent joined");

            // Parse opponent name from JSON
            try {
                var parser = new Json.Parser();
                parser.load_from_data(raw_json);
                var root = parser.get_root().get_object();

                if (root.has_member("opponent_name")) {
                    opponent_name = root.get_string_member("opponent_name");
                    logger.info("NetworkSession: Opponent name: %s", opponent_name);
                    opponent_joined(opponent_name);
                }
            } catch (Error e) {
                logger.error("NetworkSession: Failed to parse opponent name: %s", e.message);
                opponent_name = "Opponent";
                opponent_joined(opponent_name);
            }
        }

        /**
         * Handle game started event
         */
        private void handle_game_started(GameStartedMessage message) {
            logger.info("NetworkSession: Game started");
            state = SessionState.IN_GAME;
            local_player_color = message.your_color;
            game_variant = message.variant;

            if (opponent_name == null) {
                opponent_name = message.opponent_name;
            }

            logger.info("NetworkSession: Playing as %s against %s", local_player_color.to_string(), opponent_name);
            game_started(game_variant, local_player_color, opponent_name);
        }

        /**
         * Handle move made event
         */
        private void handle_move_made(NetworkMessage message, string raw_json) {
            logger.debug("NetworkSession: Move received from server");

            // Parse move from JSON
            try {
                var parser = new Json.Parser();
                parser.load_from_data(raw_json);
                var root = parser.get_root().get_object();

                if (root.has_member("move")) {
                    var move_obj = root.get_object_member("move");
                    var move = parse_move_from_json(move_obj);
                    if (move != null) {
                        move_received(move);
                    }
                }
            } catch (Error e) {
                logger.error("NetworkSession: Failed to parse move: %s", e.message);
            }
        }

        /**
         * Handle game ended event
         */
        private void handle_game_ended(NetworkMessage message, string raw_json) {
            logger.info("NetworkSession: Game ended");
            state = SessionState.GAME_ENDED;

            // Parse game result from JSON
            try {
                var parser = new Json.Parser();
                parser.load_from_data(raw_json);
                var root = parser.get_root().get_object();

                GameStatus result = GameStatus.DRAW;
                string reason = "Unknown";

                if (root.has_member("result")) {
                    var result_str = root.get_string_member("result");
                    // Parse result string to GameStatus
                    if (result_str == "red_wins") {
                        result = GameStatus.RED_WINS;
                    } else if (result_str == "black_wins") {
                        result = GameStatus.BLACK_WINS;
                    } else {
                        result = GameStatus.DRAW;
                    }
                }

                if (root.has_member("reason")) {
                    reason = root.get_string_member("reason");
                }

                game_ended(result, reason);

            } catch (Error e) {
                logger.error("NetworkSession: Failed to parse game end: %s", e.message);
                game_ended(GameStatus.DRAW, "Unknown");
            }
        }

        /**
         * Handle opponent disconnected event
         */
        private void handle_opponent_disconnected() {
            logger.warning("NetworkSession: Opponent disconnected");
            opponent_disconnected();
        }

        /**
         * Handle opponent reconnected event
         */
        private void handle_opponent_reconnected() {
            logger.info("NetworkSession: Opponent reconnected");
            opponent_reconnected();
        }

        /**
         * Handle error message
         */
        private void handle_error(ErrorMessage message) {
            logger.error("NetworkSession: Server error: %s - %s", message.error_code, message.error_description);
            session_error(message.error_description);
            reset_session();
        }

        /**
         * Parse DraughtsMove from JSON object
         */
        private DraughtsMove? parse_move_from_json(Json.Object move_obj) {
            try {
                int piece_id = (int) move_obj.get_int_member("piece_id");
                int from_row = (int) move_obj.get_int_member("from_row");
                int from_col = (int) move_obj.get_int_member("from_col");
                int to_row = (int) move_obj.get_int_member("to_row");
                int to_col = (int) move_obj.get_int_member("to_col");
                bool promoted = move_obj.get_boolean_member("promoted");

                // Get board size from current game variant (default to 8 if not set)
                int board_size = (game_variant != null) ? game_variant.get_variant_board_size() : 8;

                var from_pos = new BoardPosition(from_row, from_col, board_size);
                var to_pos = new BoardPosition(to_row, to_col, board_size);

                // Parse captured pieces if present
                DraughtsMove move;
                if (move_obj.has_member("captured_pieces")) {
                    var captured_array = move_obj.get_array_member("captured_pieces");
                    int[] captured_ids = new int[captured_array.get_length()];
                    for (uint i = 0; i < captured_array.get_length(); i++) {
                        captured_ids[i] = (int) captured_array.get_int_element(i);
                    }
                    // Create move with captures
                    move = new DraughtsMove.with_captures(piece_id, from_pos, to_pos, captured_ids);
                } else {
                    // Determine move type based on captured status
                    bool is_capture = move_obj.has_member("is_capture") ? move_obj.get_boolean_member("is_capture") : false;
                    MoveType move_type = is_capture ? MoveType.CAPTURE : MoveType.SIMPLE;

                    // Create move without captures
                    move = new DraughtsMove(piece_id, from_pos, to_pos, move_type);
                }

                move.promoted = promoted;
                return move;

            } catch (Error e) {
                logger.error("NetworkSession: Failed to parse move JSON: %s", e.message);
                return null;
            }
        }

        /**
         * Handle network disconnection
         */
        private void on_network_disconnected(string reason) {
            logger.warning("NetworkSession: Network disconnected: %s", reason);
            session_error("Disconnected from server: " + reason);
        }

        /**
         * Handle network error
         */
        private void on_network_error(string error_message) {
            logger.error("NetworkSession: Network error: %s", error_message);
            session_error("Network error: " + error_message);
        }

        /**
         * Reset session to idle state
         */
        private void reset_session() {
            state = SessionState.IDLE;
            room_code = null;
            local_player_color = null;
            opponent_name = null;
            game_variant = null;
        }

        /**
         * Generate a random guest name
         */
        private string generate_guest_name() {
            int random_num = Random.int_range(1000, 9999);
            return @"Guest_$random_num";
        }

        /**
         * Check if currently in a game
         */
        public bool is_in_game() {
            return state == SessionState.IN_GAME;
        }

        /**
         * Check if hosting a game
         */
        public bool is_host() {
            return role == PlayerRole.HOST;
        }
    }
}
