/**
 * NetworkClient.vala
 *
 * WebSocket client for multiplayer game communication.
 * Handles connection, message sending/receiving, and automatic reconnection.
 */

using Draughts;
using Soup;
using Json;

namespace Draughts {

    /**
     * Connection state for the network client
     */
    public enum ConnectionState {
        DISCONNECTED,
        CONNECTING,
        CONNECTED,
        RECONNECTING,
        ERROR;

        public string to_string() {
            switch (this) {
                case DISCONNECTED: return "Disconnected";
                case CONNECTING: return "Connecting";
                case CONNECTED: return "Connected";
                case RECONNECTING: return "Reconnecting";
                case ERROR: return "Error";
                default: return "Unknown";
            }
        }
    }

    /**
     * WebSocket network client for multiplayer
     */
    public class NetworkClient : GLib.Object {
        private Soup.Session session;
        private Soup.WebsocketConnection? connection;
        private string server_url;
        private ConnectionState _state;
        private Logger logger;
        private uint reconnect_timeout_id = 0;
        private int reconnect_attempts = 0;
        private const int MAX_RECONNECT_ATTEMPTS = 5;
        private const int BASE_RECONNECT_DELAY_MS = 1000;

        // Session persistence
        private string? session_id = null;
        private SettingsManager settings;

        // Ping/pong for connection monitoring
        private uint ping_timeout_id = 0;
        private const int PING_INTERVAL_MS = 30000; // 30 seconds
        private int64 last_pong_time = 0;
        private int latency_ms = 0;

        public ConnectionState state {
            get { return _state; }
            private set {
                if (_state != value) {
                    _state = value;
                    state_changed(_state);
                }
            }
        }

        // Signals
        public signal void connected();
        public signal void disconnected(string reason);
        public signal void state_changed(ConnectionState new_state);
        public signal void message_received(NetworkMessage message, string raw_json);
        public signal void error_occurred(string error_message);
        public signal void latency_updated(int latency_ms);
        public signal void session_restored(string room_code, string variant, string opponent_name, PieceColor player_color);
        public signal void version_mismatch(string required_version, string client_version);

        public NetworkClient(string server_url) {
            this.server_url = server_url;
            this.session = new Soup.Session();
            this._state = ConnectionState.DISCONNECTED;
            this.logger = Logger.get_default();
            this.settings = SettingsManager.get_instance();
            this.last_pong_time = get_monotonic_time() / 1000; // Convert to milliseconds

            // Load stored session ID if exists
            this.session_id = settings.get_string("multiplayer-session-id");
            if (session_id == "" || session_id == null) {
                session_id = null;
                logger.info("NetworkClient: No stored session ID found");
            } else {
                logger.info("NetworkClient: Loaded stored session ID: %s", session_id);
            }

            logger.info("NetworkClient: Initialized with server URL: %s", server_url);
        }

        /**
         * Connect to the WebSocket server
         */
        public async bool connect_async() {
            if (state == ConnectionState.CONNECTED || state == ConnectionState.CONNECTING) {
                logger.warning("NetworkClient: Already connected or connecting");
                return false;
            }

            state = ConnectionState.CONNECTING;
            logger.info("NetworkClient: Attempting to connect to %s", server_url);

            try {
                var message = new Soup.Message("GET", server_url);
                message.get_request_headers().append("Upgrade", "websocket");

                connection = yield session.websocket_connect_async(
                    message,
                    null,          // origin
                    null,          // protocols
                    GLib.Priority.DEFAULT,
                    null           // cancellable
                );

                // Set up WebSocket event handlers
                connection.message.connect(on_message_received);
                connection.closed.connect(on_connection_closed);
                connection.error.connect(on_connection_error);

                state = ConnectionState.CONNECTED;
                reconnect_attempts = 0;
                logger.info("NetworkClient: Successfully connected to server");

                // Send reconnect message if we have a session ID, otherwise send version on first connect
                if (session_id != null && session_id != "") {
                    logger.info("NetworkClient: Sending reconnection request with session ID: %s", session_id);
                    var reconnect_msg = new Json.Builder();
                    reconnect_msg.begin_object();
                    reconnect_msg.set_member_name("type");
                    reconnect_msg.add_string_value("reconnect");
                    reconnect_msg.set_member_name("session_id");
                    reconnect_msg.add_string_value(session_id);
                    reconnect_msg.set_member_name("version");
                    reconnect_msg.add_string_value(Config.VERSION);
                    reconnect_msg.end_object();

                    var gen = new Json.Generator();
                    gen.set_root(reconnect_msg.get_root());
                    string json_msg = gen.to_data(null);
                    logger.debug("NetworkClient: Sending reconnect JSON: %s", json_msg);
                    connection.send_text(json_msg);
                } else {
                    // First connect - send version info
                    logger.info("NetworkClient: Sending initial connect with version: %s", Config.VERSION);
                    var connect_msg = new Json.Builder();
                    connect_msg.begin_object();
                    connect_msg.set_member_name("type");
                    connect_msg.add_string_value("connect");
                    connect_msg.set_member_name("version");
                    connect_msg.add_string_value(Config.VERSION);
                    connect_msg.end_object();

                    var gen = new Json.Generator();
                    gen.set_root(connect_msg.get_root());
                    string json_msg = gen.to_data(null);
                    connection.send_text(json_msg);
                }

                connected();

                // Start ping/pong monitoring
                start_ping_monitor();

                return true;

            } catch (Error e) {
                logger.warning("NetworkClient: Connection failed: %s", e.message);
                state = ConnectionState.ERROR;
                error_occurred(e.message);
                schedule_reconnect();
                return false;
            }
        }

        /**
         * Disconnect from the server
         */
        public void disconnect() {
            logger.info("NetworkClient: Disconnecting from server");
            stop_ping_monitor();
            cancel_reconnect();

            if (connection != null) {
                connection.close(Soup.WebsocketCloseCode.NORMAL, "Client disconnecting");
                connection = null;
            }

            state = ConnectionState.DISCONNECTED;
        }

        /**
         * Send raw JSON string to the server
         */
        public bool send_raw(string json_data) {
            if (connection == null || state != ConnectionState.CONNECTED) {
                logger.warning("NetworkClient: Cannot send raw data, not connected");
                return false;
            }

            try {
                connection.send_text(json_data);
                return true;
            } catch (Error e) {
                logger.error("NetworkClient: Failed to send raw data: %s", e.message);
                error_occurred("Failed to send raw data: " + e.message);
                return false;
            }
        }

        /**
         * Send a message to the server
         */
        public bool send_message(NetworkMessage message) {
            if (state != ConnectionState.CONNECTED || connection == null) {
                logger.warning("NetworkClient: Cannot send message, not connected");
                return false;
            }

            try {
                string json = message.to_json();
                logger.debug("NetworkClient: Sending message: %s", json);
                connection.send_text(json);
                return true;
            } catch (Error e) {
                logger.error("NetworkClient: Failed to send message: %s", e.message);
                error_occurred("Failed to send message: " + e.message);
                return false;
            }
        }

        /**
         * Send a ping message to check connection
         */
        public void send_ping() {
            if (state != ConnectionState.CONNECTED || connection == null) {
                return;
            }

            try {
                var ping_msg = new NetworkMessage(NetworkMessageType.PING);
                send_message(ping_msg);
            } catch (Error e) {
                logger.warning("NetworkClient: Failed to send ping: %s", e.message);
            }
        }

        /**
         * Handle incoming WebSocket messages
         */
        private void on_message_received(int type, Bytes message_bytes) {
            if (type != Soup.WebsocketDataType.TEXT) {
                logger.warning("NetworkClient: Received non-text message, ignoring");
                return;
            }

            var message_str = (string) message_bytes.get_data();
            logger.debug("NetworkClient: Received message: %s", message_str);

            try {
                var parser = new Json.Parser();
                parser.load_from_data(message_str);
                var root = parser.get_root().get_object();

                if (!root.has_member("type")) {
                    logger.warning("NetworkClient: Message has no 'type' field");
                    return;
                }

                var msg_type_str = root.get_string_member("type");

                // Handle session-related messages
                if (msg_type_str == "connected") {
                    if (root.has_member("session_id")) {
                        session_id = root.get_string_member("session_id");
                        settings.set_string("multiplayer-session-id", session_id);
                        logger.info("NetworkClient: Received and stored new session ID: %s", session_id);
                    } else {
                        logger.warning("NetworkClient: Received 'connected' message without session_id");
                    }
                    return;
                } else if (msg_type_str == "reconnected") {
                    logger.info("NetworkClient: Successfully reconnected with existing session!");
                    if (root.has_member("session_id")) {
                        var confirmed_session_id = root.get_string_member("session_id");
                        logger.info("NetworkClient: Session confirmed: %s", confirmed_session_id);
                    }

                    // Check if there's an active room to restore
                    if (root.has_member("room") && !root.get_null_member("room")) {
                        var room_obj = root.get_object_member("room");
                        string room_code = root.get_string_member("room_code");
                        string variant = room_obj.get_string_member("variant");
                        string opponent_name = room_obj.get_string_member("opponent_name");
                        string player_color_str = root.get_string_member("player_color");

                        PieceColor player_color = (player_color_str == "red") ? PieceColor.RED : PieceColor.BLACK;

                        logger.info("NetworkClient: Restoring game session - Room: %s, Variant: %s, Opponent: %s, Color: %s",
                                   room_code, variant, opponent_name, player_color_str);

                        // Emit session restored signal
                        session_restored(room_code, variant, opponent_name, player_color);
                    }
                    return;
                }

                var msg_type = NetworkMessageType.from_string(msg_type_str);

                // Handle pong messages for latency calculation
                if (msg_type == NetworkMessageType.PONG) {
                    handle_pong(root);
                    return;
                }

                // Handle error messages - check for VERSION_MISMATCH
                if (msg_type == NetworkMessageType.ERROR) {
                    string error_code = root.has_member("error_code") ? root.get_string_member("error_code") : "";
                    if (error_code == "VERSION_MISMATCH") {
                        string required = root.has_member("required_version") ? root.get_string_member("required_version") : "unknown";
                        string client = root.has_member("client_version") ? root.get_string_member("client_version") : Config.VERSION;
                        logger.error("NetworkClient: Version mismatch - Client: %s, Required: %s", client, required);
                        version_mismatch(required, client);
                        disconnect();
                        return;
                    }
                }

                // Create appropriate message object based on type
                NetworkMessage? msg = parse_message(msg_type, root);
                if (msg != null) {
                    message_received(msg, message_str);
                }

            } catch (Error e) {
                logger.error("NetworkClient: Failed to parse message: %s", e.message);
                error_occurred("Failed to parse message: " + e.message);
            }
        }

        /**
         * Parse JSON into appropriate NetworkMessage subclass
         */
        private NetworkMessage? parse_message(NetworkMessageType msg_type, Json.Object root) {
            try {
                switch (msg_type) {
                    case NetworkMessageType.ROOM_CREATED:
                        var msg = new RoomCreatedMessage();
                        if (root.has_member("room_code")) {
                            msg.room_code = root.get_string_member("room_code");
                        }
                        if (root.has_member("player_color")) {
                            var color_str = root.get_string_member("player_color");
                            msg.player_color = (color_str == "Red") ? PieceColor.RED : PieceColor.BLACK;
                        }
                        return msg;

                    case NetworkMessageType.GAME_STARTED:
                        var msg = new GameStartedMessage();
                        if (root.has_member("your_color")) {
                            var color_str = root.get_string_member("your_color");
                            msg.your_color = (color_str == "Red") ? PieceColor.RED : PieceColor.BLACK;
                        }
                        if (root.has_member("variant")) {
                            var variant_str = root.get_string_member("variant");
                            msg.variant = parse_variant_from_string(variant_str);
                        }
                        if (root.has_member("opponent_name")) {
                            msg.opponent_name = root.get_string_member("opponent_name");
                        }
                        // Parse timer settings
                        if (root.has_member("use_timer")) {
                            msg.use_timer = root.get_boolean_member("use_timer");
                        }
                        if (root.has_member("minutes_per_side")) {
                            msg.minutes_per_side = (int) root.get_int_member("minutes_per_side");
                        }
                        if (root.has_member("increment_seconds")) {
                            msg.increment_seconds = (int) root.get_int_member("increment_seconds");
                        }
                        if (root.has_member("clock_type")) {
                            msg.clock_type = root.get_string_member("clock_type");
                        }
                        // Parse moves array for game restoration
                        if (root.has_member("moves")) {
                            var moves_array = root.get_array_member("moves");
                            if (moves_array.get_length() > 0) {
                                msg.moves = new Gee.ArrayList<DraughtsMove>();
                                int board_size = msg.variant.get_variant_board_size();
                                for (uint i = 0; i < moves_array.get_length(); i++) {
                                    var move_obj = moves_array.get_object_element(i);
                                    var move = parse_move_from_json(move_obj, board_size);
                                    if (move != null) {
                                        msg.moves.add(move);
                                    }
                                }
                            }
                        }
                        return msg;

                    case NetworkMessageType.ERROR:
                        var code = root.has_member("error_code") ?
                            root.get_string_member("error_code") : "UNKNOWN";
                        var description = root.has_member("error_description") ?
                            root.get_string_member("error_description") : "Unknown error";
                        return new ErrorMessage(code, description);

                    default:
                        // For other message types, return a basic NetworkMessage
                        return new NetworkMessage(msg_type);
                }
            } catch (Error e) {
                logger.error("NetworkClient: Error parsing message: %s", e.message);
                return null;
            }
        }

        /**
         * Parse variant from string representation
         */
        private DraughtsVariant parse_variant_from_string(string variant_str) {
            switch (variant_str) {
                case "American Checkers": return DraughtsVariant.AMERICAN;
                case "International Draughts": return DraughtsVariant.INTERNATIONAL;
                case "Russian Draughts": return DraughtsVariant.RUSSIAN;
                case "Brazilian Draughts": return DraughtsVariant.BRAZILIAN;
                case "Italian Draughts": return DraughtsVariant.ITALIAN;
                case "Spanish Draughts": return DraughtsVariant.SPANISH;
                case "Czech Draughts": return DraughtsVariant.CZECH;
                case "Thai Draughts": return DraughtsVariant.THAI;
                case "German Draughts": return DraughtsVariant.GERMAN;
                case "Swedish Draughts": return DraughtsVariant.SWEDISH;
                case "Pool Checkers": return DraughtsVariant.POOL;
                case "Turkish Draughts": return DraughtsVariant.TURKISH;
                case "Armenian Draughts": return DraughtsVariant.ARMENIAN;
                case "Gothic Draughts": return DraughtsVariant.GOTHIC;
                case "Frisian Draughts": return DraughtsVariant.FRISIAN;
                case "Canadian Draughts": return DraughtsVariant.CANADIAN;
                default:
                    logger.warning("NetworkClient: Unknown variant '%s', defaulting to International", variant_str);
                    return DraughtsVariant.INTERNATIONAL;
            }
        }

        /**
         * Handle pong response for latency calculation
         */
        private void handle_pong(Json.Object root) {
            int64 now = get_monotonic_time() / 1000; // Convert to milliseconds
            int64 sent_time = root.has_member("timestamp") ?
                root.get_int_member("timestamp") : 0;

            if (sent_time > 0) {
                latency_ms = (int)(now - sent_time);
                latency_updated(latency_ms);
                logger.debug("NetworkClient: Latency: %d ms", latency_ms);
            }

            last_pong_time = now;
        }

        /**
         * Handle connection closed event
         */
        private void on_connection_closed() {
            logger.warning("NetworkClient: Connection closed unexpectedly");
            stop_ping_monitor();

            if (state == ConnectionState.CONNECTED || state == ConnectionState.CONNECTING) {
                state = ConnectionState.DISCONNECTED;
                disconnected("Connection to server lost. Attempting to reconnect...");
                schedule_reconnect();
            }
        }

        /**
         * Handle connection error event
         */
        private void on_connection_error(Error error) {
            logger.error("NetworkClient: Connection error: %s", error.message);
            state = ConnectionState.ERROR;
            error_occurred(error.message);
            schedule_reconnect();
        }

        /**
         * Start periodic ping monitoring
         */
        private void start_ping_monitor() {
            stop_ping_monitor();

            ping_timeout_id = Timeout.add(PING_INTERVAL_MS, () => {
                // Check if we've received a pong recently
                int64 now = get_monotonic_time() / 1000;
                int64 time_since_pong = now - last_pong_time;

                if (time_since_pong > PING_INTERVAL_MS * 2) {
                    logger.warning("NetworkClient: No pong received in %lld ms, connection may be dead", time_since_pong);
                    disconnect();
                    schedule_reconnect();
                    return Source.REMOVE;
                }

                send_ping();
                return Source.CONTINUE;
            });
        }

        /**
         * Stop ping monitoring
         */
        private void stop_ping_monitor() {
            if (ping_timeout_id != 0) {
                Source.remove(ping_timeout_id);
                ping_timeout_id = 0;
            }
        }

        /**
         * Schedule reconnection attempt with exponential backoff
         */
        private void schedule_reconnect() {
            // Reconnection is now handled by Window.vala
            // This method is kept for backward compatibility but does nothing
        }

        /**
         * Cancel scheduled reconnection
         */
        private void cancel_reconnect() {
            if (reconnect_timeout_id != 0) {
                Source.remove(reconnect_timeout_id);
                reconnect_timeout_id = 0;
            }
            reconnect_attempts = 0;
        }

        /**
         * Get current connection latency in milliseconds
         */
        public int get_latency() {
            return latency_ms;
        }

        /**
         * Parse DraughtsMove from JSON object
         */
        private DraughtsMove? parse_move_from_json(Json.Object move_obj, int board_size) {
            try {
                int piece_id = (int) move_obj.get_int_member("piece_id");
                int from_row = (int) move_obj.get_int_member("from_row");
                int from_col = (int) move_obj.get_int_member("from_col");
                int to_row = (int) move_obj.get_int_member("to_row");
                int to_col = (int) move_obj.get_int_member("to_col");
                bool promoted = move_obj.get_boolean_member("promoted");

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
                    move = new DraughtsMove.with_captures(piece_id, from_pos, to_pos, captured_ids);
                } else {
                    bool is_capture = move_obj.has_member("is_capture") ? move_obj.get_boolean_member("is_capture") : false;
                    MoveType move_type = is_capture ? MoveType.CAPTURE : MoveType.SIMPLE;
                    move = new DraughtsMove(piece_id, from_pos, to_pos, move_type);
                }

                move.promoted = promoted;
                return move;

            } catch (Error e) {
                logger.error("NetworkClient: Failed to parse move: %s", e.message);
                return null;
            }
        }

        /**
         * Check if currently connected
         */
        public bool is_connected() {
            return state == ConnectionState.CONNECTED && connection != null;
        }
    }
}
