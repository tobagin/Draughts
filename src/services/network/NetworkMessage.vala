/**
 * NetworkMessage.vala
 *
 * Defines the JSON-based protocol for multiplayer communication.
 * Handles serialization and deserialization of game messages.
 */

using Draughts;
using Json;

namespace Draughts {

    /**
     * Message types for client-server communication
     */
    public enum NetworkMessageType {
        // Client → Server
        CREATE_ROOM,
        JOIN_ROOM,
        QUICK_MATCH,
        CANCEL_QUICK_MATCH,
        MAKE_MOVE,
        RESIGN,
        OFFER_DRAW,
        ACCEPT_DRAW,
        REJECT_DRAW,
        CHAT_MESSAGE,
        PING,
        PAUSE_GAME,
        UNPAUSE_GAME,

        // Server → Client
        ROOM_CREATED,
        OPPONENT_JOINED,
        GAME_STARTED,
        MOVE_MADE,
        GAME_ENDED,
        DRAW_OFFERED,
        DRAW_RESPONSE,
        ERROR,
        PONG,
        OPPONENT_DISCONNECTED,
        OPPONENT_RECONNECTED,
        GAME_PAUSED,
        GAME_UNPAUSED,
        QUICK_MATCH_SEARCHING,
        QUICK_MATCH_FOUND;

        public string to_string() {
            switch (this) {
                case CREATE_ROOM: return "create_room";
                case JOIN_ROOM: return "join_room";
                case MAKE_MOVE: return "make_move";
                case RESIGN: return "resign";
                case OFFER_DRAW: return "offer_draw";
                case ACCEPT_DRAW: return "accept_draw";
                case REJECT_DRAW: return "reject_draw";
                case CHAT_MESSAGE: return "chat_message";
                case PING: return "ping";
                case QUICK_MATCH: return "quick_match";
                case CANCEL_QUICK_MATCH: return "cancel_quick_match";
                case PAUSE_GAME: return "pause_game";
                case UNPAUSE_GAME: return "unpause_game";
                case ROOM_CREATED: return "room_created";
                case OPPONENT_JOINED: return "opponent_joined";
                case GAME_STARTED: return "game_started";
                case MOVE_MADE: return "move_made";
                case GAME_ENDED: return "game_ended";
                case DRAW_OFFERED: return "draw_offered";
                case DRAW_RESPONSE: return "draw_response";
                case ERROR: return "error";
                case PONG: return "pong";
                case OPPONENT_DISCONNECTED: return "opponent_disconnected";
                case OPPONENT_RECONNECTED: return "opponent_reconnected";
                case GAME_PAUSED: return "game_paused";
                case GAME_UNPAUSED: return "game_unpaused";
                case QUICK_MATCH_SEARCHING: return "quick_match_searching";
                case QUICK_MATCH_FOUND: return "quick_match_found";
                default: return "unknown";
            }
        }

        public static NetworkMessageType from_string(string str) {
            switch (str) {
                case "create_room": return CREATE_ROOM;
                case "join_room": return JOIN_ROOM;
                case "make_move": return MAKE_MOVE;
                case "resign": return RESIGN;
                case "offer_draw": return OFFER_DRAW;
                case "accept_draw": return ACCEPT_DRAW;
                case "reject_draw": return REJECT_DRAW;
                case "chat_message": return CHAT_MESSAGE;
                case "ping": return PING;
                case "quick_match": return QUICK_MATCH;
                case "cancel_quick_match": return CANCEL_QUICK_MATCH;
                case "pause_game": return PAUSE_GAME;
                case "unpause_game": return UNPAUSE_GAME;
                case "room_created": return ROOM_CREATED;
                case "opponent_joined": return OPPONENT_JOINED;
                case "game_started": return GAME_STARTED;
                case "move_made": return MOVE_MADE;
                case "game_ended": return GAME_ENDED;
                case "draw_offered": return DRAW_OFFERED;
                case "draw_response": return DRAW_RESPONSE;
                case "error": return ERROR;
                case "pong": return PONG;
                case "opponent_disconnected": return OPPONENT_DISCONNECTED;
                case "opponent_reconnected": return OPPONENT_RECONNECTED;
                case "game_paused": return GAME_PAUSED;
                case "game_unpaused": return GAME_UNPAUSED;
                case "quick_match_searching": return QUICK_MATCH_SEARCHING;
                case "quick_match_found": return QUICK_MATCH_FOUND;
                default: return ERROR;
            }
        }
    }

    /**
     * Base class for network messages
     */
    public class NetworkMessage : GLib.Object {
        public NetworkMessageType message_type { get; set; }
        public int64 timestamp { get; set; }
        public string? error_message { get; set; }

        public NetworkMessage(NetworkMessageType type) {
            this.message_type = type;
            this.timestamp = new DateTime.now_utc().to_unix();
        }

        /**
         * Serialize message to JSON string
         */
        public virtual string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value(message_type.to_string());
            builder.set_member_name("timestamp");
            builder.add_int_value(timestamp);
            builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.set_pretty(false);
            return generator.to_data(null);
        }

        /**
         * Parse message from JSON string
         */
        public static NetworkMessage? from_json(string json_str) {
            try {
                var parser = new Json.Parser();
                parser.load_from_data(json_str);

                var root = parser.get_root().get_object();
                if (!root.has_member("type")) {
                    warning("NetworkMessage: No 'type' field in JSON");
                    return null;
                }

                var type_str = root.get_string_member("type");
                var msg_type = NetworkMessageType.from_string(type_str);

                var message = new NetworkMessage(msg_type);
                if (root.has_member("timestamp")) {
                    message.timestamp = root.get_int_member("timestamp");
                }

                return message;
            } catch (Error e) {
                warning("Failed to parse NetworkMessage: %s", e.message);
                return null;
            }
        }
    }

    /**
     * Create room message
     */
    public class CreateRoomMessage : NetworkMessage {
        public DraughtsVariant variant { get; set; }
        public bool use_timer { get; set; }
        public int minutes_per_side { get; set; }
        public int increment_seconds { get; set; }
        public string clock_type { get; set; }
        public string player_name { get; set; }

        public CreateRoomMessage(DraughtsVariant variant, string player_name) {
            base(NetworkMessageType.CREATE_ROOM);
            this.variant = variant;
            this.player_name = player_name;
            this.use_timer = false;
            this.minutes_per_side = 5;
            this.increment_seconds = 0;
            this.clock_type = "Fischer";
        }

        public override string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value(message_type.to_string());
            builder.set_member_name("timestamp");
            builder.add_int_value(timestamp);
            builder.set_member_name("variant");
            builder.add_string_value(variant.to_string());
            builder.set_member_name("use_timer");
            builder.add_boolean_value(use_timer);
            builder.set_member_name("minutes_per_side");
            builder.add_int_value(minutes_per_side);
            builder.set_member_name("increment_seconds");
            builder.add_int_value(increment_seconds);
            builder.set_member_name("clock_type");
            builder.add_string_value(clock_type);
            builder.set_member_name("player_name");
            builder.add_string_value(player_name);
            builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.set_pretty(false);
            return generator.to_data(null);
        }
    }

    /**
     * Join room message
     */
    public class JoinRoomMessage : NetworkMessage {
        public string room_code { get; set; }
        public string player_name { get; set; }

        public JoinRoomMessage(string room_code, string player_name) {
            base(NetworkMessageType.JOIN_ROOM);
            this.room_code = room_code;
            this.player_name = player_name;
        }

        public override string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value(message_type.to_string());
            builder.set_member_name("timestamp");
            builder.add_int_value(timestamp);
            builder.set_member_name("room_code");
            builder.add_string_value(room_code);
            builder.set_member_name("player_name");
            builder.add_string_value(player_name);
            builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.set_pretty(false);
            return generator.to_data(null);
        }
    }

    /**
     * Quick match message
     */
    public class QuickMatchMessage : NetworkMessage {
        public DraughtsVariant variant { get; set; }
        public string player_name { get; set; }

        public QuickMatchMessage(DraughtsVariant variant, string player_name) {
            base(NetworkMessageType.QUICK_MATCH);
            this.variant = variant;
            this.player_name = player_name;
        }

        public override string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value(message_type.to_string());
            builder.set_member_name("timestamp");
            builder.add_int_value(timestamp);
            builder.set_member_name("variant");
            builder.add_string_value(variant.to_string());
            builder.set_member_name("player_name");
            builder.add_string_value(player_name);
            builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.set_pretty(false);
            return generator.to_data(null);
        }
    }

    /**
     * Make move message
     */
    public class MakeMoveMessage : NetworkMessage {
        public DraughtsMove move { get; set; }

        public MakeMoveMessage(DraughtsMove move) {
            base(NetworkMessageType.MAKE_MOVE);
            this.move = move;
        }

        public override string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value(message_type.to_string());
            builder.set_member_name("timestamp");
            builder.add_int_value(timestamp);

            // Serialize move
            builder.set_member_name("move");
            builder.begin_object();
            builder.set_member_name("piece_id");
            builder.add_int_value(move.piece_id);
            builder.set_member_name("from_row");
            builder.add_int_value(move.from_position.row);
            builder.set_member_name("from_col");
            builder.add_int_value(move.from_position.col);
            builder.set_member_name("to_row");
            builder.add_int_value(move.to_position.row);
            builder.set_member_name("to_col");
            builder.add_int_value(move.to_position.col);
            builder.set_member_name("is_capture");
            builder.add_boolean_value(move.is_capture());
            builder.set_member_name("promoted");
            builder.add_boolean_value(move.promoted);

            // Serialize captured pieces
            builder.set_member_name("captured_pieces");
            builder.begin_array();
            foreach (var piece_id in move.captured_pieces) {
                builder.add_int_value(piece_id);
            }
            builder.end_array();

            builder.end_object();
            builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.set_pretty(false);
            return generator.to_data(null);
        }
    }

    /**
     * Room created response message
     */
    public class RoomCreatedMessage : NetworkMessage {
        public string room_code { get; set; }
        public PieceColor player_color { get; set; }

        public RoomCreatedMessage() {
            base(NetworkMessageType.ROOM_CREATED);
        }

        public override string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value(message_type.to_string());
            builder.set_member_name("timestamp");
            builder.add_int_value(timestamp);
            builder.set_member_name("room_code");
            builder.add_string_value(room_code);
            builder.set_member_name("player_color");
            builder.add_string_value(player_color.to_string());
            builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.set_pretty(false);
            return generator.to_data(null);
        }
    }

    /**
     * Game started message
     */
    public class GameStartedMessage : NetworkMessage {
        public PieceColor your_color { get; set; }
        public DraughtsVariant variant { get; set; }
        public string opponent_name { get; set; }
        public Gee.ArrayList<DraughtsMove>? moves { get; set; default = null; }

        public GameStartedMessage() {
            base(NetworkMessageType.GAME_STARTED);
        }

        public override string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value(message_type.to_string());
            builder.set_member_name("timestamp");
            builder.add_int_value(timestamp);
            builder.set_member_name("your_color");
            builder.add_string_value(your_color.to_string());
            builder.set_member_name("variant");
            builder.add_string_value(variant.to_string());
            builder.set_member_name("opponent_name");
            builder.add_string_value(opponent_name);
            builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.set_pretty(false);
            return generator.to_data(null);
        }
    }

    /**
     * Error message
     */
    public class ErrorMessage : NetworkMessage {
        public string error_code { get; set; }
        public string error_description { get; set; }

        public ErrorMessage(string code, string description) {
            base(NetworkMessageType.ERROR);
            this.error_code = code;
            this.error_description = description;
        }

        public override string to_json() {
            var builder = new Json.Builder();
            builder.begin_object();
            builder.set_member_name("type");
            builder.add_string_value(message_type.to_string());
            builder.set_member_name("timestamp");
            builder.add_int_value(timestamp);
            builder.set_member_name("error_code");
            builder.add_string_value(error_code);
            builder.set_member_name("error_description");
            builder.add_string_value(error_description);
            builder.end_object();

            var generator = new Json.Generator();
            generator.set_root(builder.get_root());
            generator.set_pretty(false);
            return generator.to_data(null);
        }
    }
}
