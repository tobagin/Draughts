/**
 * GameSessionManager.vala
 *
 * Manages game sessions, including save/load functionality, session state persistence,
 * and game history management for the draughts application.
 */

using Draughts;

public class Draughts.GameSessionManager : Object {
    private static GameSessionManager? instance;

    // Session storage
    private File sessions_directory;
    private File autosave_file;
    private Gee.HashMap<string, GameSession> loaded_sessions;

    // Current session state
    private GameSession? current_session;
    private bool auto_save_enabled = true;
    private uint auto_save_interval = 30; // seconds
    private uint auto_save_timer_id = 0;

    // Signals
    public signal void session_loaded(GameSession session);
    public signal void session_saved(GameSession session);
    public signal void session_created(GameSession session);
    public signal void session_deleted(string session_id);
    public signal void autosave_completed();

    public GameSessionManager() {
        loaded_sessions = new Gee.HashMap<string, GameSession>();
        setup_storage_directories();
        start_autosave_timer();
    }

    /**
     * Get singleton instance
     */
    public static GameSessionManager get_default() {
        if (instance == null) {
            instance = new GameSessionManager();
        }
        return instance;
    }

    /**
     * Setup storage directories
     */
    private void setup_storage_directories() {
        // Use XDG data directory for session storage
        var data_dir = Environment.get_user_data_dir();
        sessions_directory = File.new_for_path(Path.build_filename(data_dir, "draughts", "sessions"));

        // Create directory if it doesn't exist
        try {
            sessions_directory.make_directory_with_parents();
        } catch (Error e) {
            if (!(e is IOError.EXISTS)) {
                warning("Failed to create sessions directory: %s", e.message);
            }
        }

        autosave_file = sessions_directory.get_child("autosave.json");
    }

    /**
     * Create a new game session
     */
    public GameSession create_new_session(DraughtsVariant variant, GamePlayer red_player, GamePlayer black_player, Timer? timer = null) {
        var session_id = generate_session_id();
        var session = new GameSession(session_id, variant);

        session.set_players(red_player, black_player);
        if (timer != null) {
            session.set_timer_configuration(timer);
        }

        current_session = session;
        loaded_sessions[session_id] = session;

        session_created(session);
        return session;
    }

    /**
     * Save current session to file
     */
    public bool save_current_session(string? custom_name = null) {
        if (current_session == null) {
            warning("No current session to save");
            return false;
        }

        return save_session(current_session, custom_name);
    }

    /**
     * Save a specific session to file
     */
    public bool save_session(GameSession session, string? custom_name = null) {
        try {
            string filename;
            if (custom_name != null) {
                filename = @"$(sanitize_filename(custom_name)).json";
            } else {
                var timestamp = new DateTime.now_local().format("%Y%m%d_%H%M%S");
                filename = @"$(session.session_id)_$(timestamp).json";
            }

            var save_file = sessions_directory.get_child(filename);
            var session_data = serialize_session(session);

            // Write to file
            var output_stream = save_file.create(FileCreateFlags.REPLACE_DESTINATION);
            var data_stream = new DataOutputStream(output_stream);
            data_stream.put_string(session_data);
            data_stream.close();

            session.mark_as_saved();
            session_saved(session);

            debug("Session saved: %s", save_file.get_path());
            return true;

        } catch (Error e) {
            warning("Failed to save session: %s", e.message);
            return false;
        }
    }

    /**
     * Load session from file
     */
    public GameSession? load_session(File session_file) {
        try {
            // Read file content
            var input_stream = session_file.read();
            var data_stream = new DataInputStream(input_stream);

            var session_data = new StringBuilder();
            string line;
            while ((line = data_stream.read_line()) != null) {
                session_data.append_printf("%s\n", line);
            }

            data_stream.close();

            // Deserialize session
            var session = deserialize_session(session_data.str);
            if (session != null) {
                loaded_sessions[session.session_id] = session;
                session_loaded(session);
                return session;
            }

        } catch (Error e) {
            warning("Failed to load session: %s", e.message);
        }

        return null;
    }

    /**
     * Load session by filename
     */
    public GameSession? load_session_by_name(string filename) {
        var session_file = sessions_directory.get_child(filename);
        return load_session(session_file);
    }

    /**
     * Get list of available saved sessions
     */
    public Gee.List<SessionInfo> get_saved_sessions() {
        var session_list = new Gee.ArrayList<SessionInfo>();

        try {
            var enumerator = sessions_directory.enumerate_children(
                FileAttribute.STANDARD_NAME + "," + FileAttribute.TIME_MODIFIED,
                FileQueryInfoFlags.NONE
            );

            FileInfo file_info;
            while ((file_info = enumerator.next_file()) != null) {
                var filename = file_info.get_name();
                if (filename.has_suffix(".json") && filename != "autosave.json") {
                    var session_info = create_session_info(filename, file_info);
                    session_list.add(session_info);
                }
            }

            enumerator.close();

        } catch (Error e) {
            warning("Failed to enumerate saved sessions: %s", e.message);
        }

        // Sort by modification time (newest first)
        session_list.sort((a, b) => {
            return (int)(b.modified_time.compare(a.modified_time));
        });

        return session_list;
    }

    /**
     * Delete a saved session
     */
    public bool delete_session(string filename) {
        try {
            var session_file = sessions_directory.get_child(filename);
            bool success = session_file.delete();

            if (success) {
                session_deleted(filename);
                debug("Session deleted: %s", filename);
            }

            return success;

        } catch (Error e) {
            warning("Failed to delete session: %s", e.message);
            return false;
        }
    }

    /**
     * Auto-save current session
     */
    public bool autosave_current_session() {
        if (!auto_save_enabled || current_session == null) {
            return false;
        }

        try {
            var session_data = serialize_session(current_session);

            // Write to autosave file
            var output_stream = autosave_file.create(FileCreateFlags.REPLACE_DESTINATION);
            var data_stream = new DataOutputStream(output_stream);
            data_stream.put_string(session_data);
            data_stream.close();

            autosave_completed();
            debug("Autosave completed");
            return true;

        } catch (Error e) {
            warning("Autosave failed: %s", e.message);
            return false;
        }
    }

    /**
     * Load autosaved session
     */
    public GameSession? load_autosaved_session() {
        if (!autosave_file.query_exists()) {
            return null;
        }

        return load_session(autosave_file);
    }

    /**
     * Check if autosave exists
     */
    public bool has_autosaved_session() {
        return autosave_file.query_exists();
    }

    /**
     * Clear autosave
     */
    public void clear_autosave() {
        try {
            if (autosave_file.query_exists()) {
                autosave_file.delete();
                debug("Autosave cleared");
            }
        } catch (Error e) {
            warning("Failed to clear autosave: %s", e.message);
        }
    }

    /**
     * Set current session
     */
    public void set_current_session(GameSession session) {
        current_session = session;
        if (!loaded_sessions.has_key(session.session_id)) {
            loaded_sessions[session.session_id] = session;
        }
    }

    /**
     * Get current session
     */
    public GameSession? get_current_session() {
        return current_session;
    }

    /**
     * Serialize session to JSON
     */
    private string serialize_session(GameSession session) {
        var json_builder = new Json.Builder();

        json_builder.begin_object();

        // Basic session info
        json_builder.set_member_name("session_id");
        json_builder.add_string_value(session.session_id);

        json_builder.set_member_name("variant");
        json_builder.add_string_value(session.variant.to_string());

        json_builder.set_member_name("created_time");
        json_builder.add_string_value(session.created_time.to_iso8601_string());

        json_builder.set_member_name("modified_time");
        json_builder.add_string_value(session.modified_time.to_iso8601_string());

        // Players
        json_builder.set_member_name("players");
        json_builder.begin_object();

        json_builder.set_member_name("red_player");
        serialize_player(json_builder, session.red_player);

        json_builder.set_member_name("black_player");
        serialize_player(json_builder, session.black_player);

        json_builder.end_object();

        // Game state
        json_builder.set_member_name("game_state");
        if (session.current_game_state != null) {
            serialize_game_state(json_builder, session.current_game_state);
        } else {
            json_builder.add_null_value();
        }

        // Move history
        json_builder.set_member_name("move_history");
        json_builder.begin_array();
        foreach (var move in session.move_history) {
            serialize_move(json_builder, move);
        }
        json_builder.end_array();

        // Timer configuration
        json_builder.set_member_name("timer_config");
        if (session.timer_configuration != null) {
            serialize_timer(json_builder, session.timer_configuration);
        } else {
            json_builder.add_null_value();
        }

        // Session metadata
        json_builder.set_member_name("total_moves");
        json_builder.add_int_value(session.total_moves);

        json_builder.set_member_name("game_duration");
        json_builder.add_int_value(session.game_duration);

        json_builder.set_member_name("is_finished");
        json_builder.add_boolean_value(session.is_finished);

        if (session.result != null) {
            json_builder.set_member_name("result");
            json_builder.add_string_value(session.result.to_string());
        }

        json_builder.end_object();

        // Generate JSON
        var generator = new Json.Generator();
        generator.set_root(json_builder.get_root());
        generator.pretty = true;

        return generator.to_data(null);
    }

    /**
     * Serialize player information
     */
    private void serialize_player(Json.Builder builder, GamePlayer player) {
        builder.begin_object();

        builder.set_member_name("name");
        builder.add_string_value(player.name);

        builder.set_member_name("color");
        builder.add_string_value(player.color.to_string());

        builder.set_member_name("player_type");
        builder.add_string_value(player.player_type.to_string());

        if (player.ai_difficulty != null) {
            builder.set_member_name("ai_difficulty");
            builder.add_string_value(player.ai_difficulty.to_string());
        }

        builder.end_object();
    }

    /**
     * Serialize game state
     */
    private void serialize_game_state(Json.Builder builder, DraughtsGameState state) {
        builder.begin_object();

        builder.set_member_name("active_player");
        builder.add_string_value(state.active_player.to_string());

        builder.set_member_name("move_count");
        builder.add_int_value(state.move_count);

        builder.set_member_name("game_status");
        builder.add_string_value(state.game_status.to_string());

        // Serialize pieces
        builder.set_member_name("pieces");
        builder.begin_array();
        foreach (var piece in state.pieces) {
            serialize_piece(builder, piece);
        }
        builder.end_array();

        builder.end_object();
    }

    /**
     * Serialize game piece
     */
    private void serialize_piece(Json.Builder builder, GamePiece piece) {
        builder.begin_object();

        builder.set_member_name("id");
        builder.add_int_value(piece.id);

        builder.set_member_name("color");
        builder.add_string_value(piece.color.to_string());

        builder.set_member_name("piece_type");
        builder.add_string_value(piece.piece_type.to_string());

        builder.set_member_name("position");
        builder.begin_object();
        builder.set_member_name("row");
        builder.add_int_value(piece.position.row);
        builder.set_member_name("col");
        builder.add_int_value(piece.position.col);
        builder.end_object();

        builder.end_object();
    }

    /**
     * Serialize move
     */
    private void serialize_move(Json.Builder builder, DraughtsMove move) {
        builder.begin_object();

        builder.set_member_name("piece_id");
        builder.add_int_value(move.piece_id);

        builder.set_member_name("from_position");
        builder.begin_object();
        builder.set_member_name("row");
        builder.add_int_value(move.from_position.row);
        builder.set_member_name("col");
        builder.add_int_value(move.from_position.col);
        builder.end_object();

        builder.set_member_name("to_position");
        builder.begin_object();
        builder.set_member_name("row");
        builder.add_int_value(move.to_position.row);
        builder.set_member_name("col");
        builder.add_int_value(move.to_position.col);
        builder.end_object();

        builder.set_member_name("move_type");
        builder.add_string_value(move.move_type.to_string());

        builder.set_member_name("is_promotion");
        builder.add_boolean_value(move.is_promotion);

        builder.set_member_name("time_taken");
        builder.add_int_value(move.time_taken);

        builder.end_object();
    }

    /**
     * Serialize timer configuration
     */
    private void serialize_timer(Json.Builder builder, Timer timer) {
        builder.begin_object();

        builder.set_member_name("mode");
        builder.add_string_value(timer.mode.to_string());

        builder.set_member_name("initial_time");
        builder.add_int_value(timer.get_initial_time());

        builder.set_member_name("remaining_time");
        builder.add_int_value(timer.get_remaining_time());

        if (timer.mode == TimerMode.FISCHER_INCREMENT) {
            builder.set_member_name("increment");
            builder.add_int_value(timer.increment);
        }

        if (timer.mode == TimerMode.DELAY) {
            builder.set_member_name("delay");
            builder.add_int_value(timer.delay);
        }

        builder.end_object();
    }

    /**
     * Deserialize session from JSON
     */
    private GameSession? deserialize_session(string json_data) {
        try {
            var parser = new Json.Parser();
            parser.load_from_data(json_data);

            var root_object = parser.get_root().get_object();

            // Basic session info
            string session_id = root_object.get_string_member("session_id");
            var variant_str = root_object.get_string_member("variant");
            var variant = DraughtsVariant.AMERICAN; // Default fallback

            // Parse variant enum
            var variant_values = typeof(DraughtsVariant).get_values();
            foreach (var enum_value in variant_values) {
                if (enum_value.get_nick() == variant_str.down()) {
                    variant = (DraughtsVariant)enum_value.get_value();
                    break;
                }
            }

            var session = new GameSession(session_id, variant);

            // Load timestamps
            if (root_object.has_member("created_time")) {
                session.created_time = new DateTime.from_iso8601(
                    root_object.get_string_member("created_time"), null
                );
            }

            if (root_object.has_member("modified_time")) {
                session.modified_time = new DateTime.from_iso8601(
                    root_object.get_string_member("modified_time"), null
                );
            }

            // Load players
            if (root_object.has_member("players")) {
                var players_obj = root_object.get_object_member("players");

                if (players_obj.has_member("red_player")) {
                    session.red_player = deserialize_player(players_obj.get_object_member("red_player"));
                }

                if (players_obj.has_member("black_player")) {
                    session.black_player = deserialize_player(players_obj.get_object_member("black_player"));
                }
            }

            // Load session metadata
            if (root_object.has_member("total_moves")) {
                session.total_moves = (int)root_object.get_int_member("total_moves");
            }

            if (root_object.has_member("game_duration")) {
                session.game_duration = root_object.get_int_member("game_duration");
            }

            if (root_object.has_member("is_finished")) {
                session.is_finished = root_object.get_boolean_member("is_finished");
            }

            // TODO: Deserialize game state, move history, and timer configuration
            // This would require more complex deserialization logic

            return session;

        } catch (Error e) {
            warning("Failed to deserialize session: %s", e.message);
            return null;
        }
    }

    /**
     * Deserialize player
     */
    private GamePlayer deserialize_player(Json.Object player_obj) {
        string name = player_obj.get_string_member("name");
        var color_str = player_obj.get_string_member("color");
        var type_str = player_obj.get_string_member("player_type");

        var color = (color_str == "RED") ? PieceColor.RED : PieceColor.BLACK;
        var player_type = (type_str == "HUMAN") ? PlayerType.HUMAN : PlayerType.AI;

        var player = new GamePlayer(name, color, player_type);

        if (player_obj.has_member("ai_difficulty")) {
            var difficulty_str = player_obj.get_string_member("ai_difficulty");
            // Parse difficulty enum similar to variant parsing
            player.ai_difficulty = AIDifficulty.MEDIUM; // Default fallback
        }

        return player;
    }

    /**
     * Generate unique session ID
     */
    private string generate_session_id() {
        var timestamp = new DateTime.now_local().format("%Y%m%d_%H%M%S");
        var random = Random.int_range(1000, 9999);
        return @"session_$(timestamp)_$(random)";
    }

    /**
     * Create session info from file
     */
    private SessionInfo create_session_info(string filename, FileInfo file_info) {
        var session_info = new SessionInfo();
        session_info.filename = filename;
        session_info.display_name = extract_display_name(filename);
        session_info.modified_time = new DateTime.from_unix_local(
            (int64)file_info.get_modification_time().tv_sec
        );
        session_info.file_size = file_info.get_size();

        return session_info;
    }

    /**
     * Extract display name from filename
     */
    private string extract_display_name(string filename) {
        string base_name = filename;
        if (base_name.has_suffix(".json")) {
            base_name = base_name.substring(0, base_name.length - 5);
        }

        // Try to extract meaningful name from session filename
        if (base_name.contains("_")) {
            var parts = base_name.split("_");
            if (parts.length >= 3) {
                return @"$(parts[1]) $(parts[2])";
            }
        }

        return base_name;
    }

    /**
     * Sanitize filename for cross-platform compatibility
     */
    private string sanitize_filename(string name) {
        string sanitized = name;

        // Replace invalid characters
        sanitized = sanitized.replace("/", "_");
        sanitized = sanitized.replace("\\", "_");
        sanitized = sanitized.replace(":", "_");
        sanitized = sanitized.replace("*", "_");
        sanitized = sanitized.replace("?", "_");
        sanitized = sanitized.replace("\"", "_");
        sanitized = sanitized.replace("<", "_");
        sanitized = sanitized.replace(">", "_");
        sanitized = sanitized.replace("|", "_");

        // Limit length
        if (sanitized.length > 100) {
            sanitized = sanitized.substring(0, 100);
        }

        return sanitized;
    }

    /**
     * Start autosave timer
     */
    private void start_autosave_timer() {
        if (!auto_save_enabled || auto_save_timer_id != 0) {
            return;
        }

        auto_save_timer_id = Timeout.add_seconds(auto_save_interval, () => {
            autosave_current_session();
            return true; // Continue timer
        });
    }

    /**
     * Stop autosave timer
     */
    private void stop_autosave_timer() {
        if (auto_save_timer_id != 0) {
            Source.remove(auto_save_timer_id);
            auto_save_timer_id = 0;
        }
    }

    /**
     * Configuration methods
     */
    public void set_autosave_enabled(bool enabled) {
        auto_save_enabled = enabled;
        if (enabled) {
            start_autosave_timer();
        } else {
            stop_autosave_timer();
        }
    }

    public void set_autosave_interval(uint seconds) {
        auto_save_interval = seconds;
        if (auto_save_enabled) {
            stop_autosave_timer();
            start_autosave_timer();
        }
    }

    /**
     * Cleanup
     */
    public override void dispose() {
        stop_autosave_timer();
        base.dispose();
    }
}

/**
 * Game session information for listing saved sessions
 */
public class SessionInfo : Object {
    public string filename { get; set; }
    public string display_name { get; set; }
    public DateTime modified_time { get; set; }
    public int64 file_size { get; set; }
}

/**
 * Game session data structure
 */
public class GameSession : Object {
    public string session_id { get; private set; }
    public DraughtsVariant variant { get; private set; }
    public DateTime created_time { get; set; }
    public DateTime modified_time { get; set; }

    public GamePlayer red_player { get; set; }
    public GamePlayer black_player { get; set; }
    public Timer? timer_configuration { get; set; }

    public DraughtsGameState? current_game_state { get; set; }
    public Gee.List<DraughtsMove> move_history { get; private set; }

    public int total_moves { get; set; }
    public int64 game_duration { get; set; }
    public bool is_finished { get; set; }
    public GameStatus? result { get; set; }

    private bool is_saved = false;

    public GameSession(string session_id, DraughtsVariant variant) {
        this.session_id = session_id;
        this.variant = variant;
        this.created_time = new DateTime.now_local();
        this.modified_time = this.created_time;
        this.move_history = new Gee.ArrayList<DraughtsMove>();

        // Create default players
        this.red_player = GamePlayer.create_default_human(PieceColor.RED);
        this.black_player = GamePlayer.create_default_human(PieceColor.BLACK);
    }

    public void set_players(GamePlayer red_player, GamePlayer black_player) {
        this.red_player = red_player;
        this.black_player = black_player;
        mark_as_modified();
    }

    public void set_timer_configuration(Timer timer) {
        this.timer_configuration = timer;
        mark_as_modified();
    }

    public void add_move(DraughtsMove move) {
        move_history.add(move);
        total_moves++;
        mark_as_modified();
    }

    public void update_game_state(DraughtsGameState state) {
        current_game_state = state;
        mark_as_modified();
    }

    public void mark_as_finished(GameStatus result) {
        this.is_finished = true;
        this.result = result;
        mark_as_modified();
    }

    public void mark_as_saved() {
        is_saved = true;
    }

    public void mark_as_modified() {
        modified_time = new DateTime.now_local();
        is_saved = false;
    }

    public bool needs_saving() {
        return !is_saved;
    }

    public GamePlayer get_player_by_color(PieceColor color) {
        return (color == PieceColor.RED) ? red_player : black_player;
    }
}