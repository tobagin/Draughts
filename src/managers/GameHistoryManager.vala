/**
 * GameHistoryManager.vala
 *
 * Manages game history persistence, storage, and retrieval.
 * Stores game history in JSON format in user data directory.
 */

using Draughts;

public class Draughts.GameHistoryManager : Object {
    private static GameHistoryManager? _instance = null;
    private Gee.ArrayList<GameHistoryRecord> _game_history;
    private string _history_file_path;
    private Logger logger;
    private SettingsManager settings_manager;

    private const int MAX_HISTORY_ENTRIES = 100;

    public static GameHistoryManager get_default() {
        if (_instance == null) {
            _instance = new GameHistoryManager();
        }
        return _instance;
    }

    private GameHistoryManager() {
        logger = Logger.get_default();
        settings_manager = SettingsManager.get_instance();
        _game_history = new Gee.ArrayList<GameHistoryRecord>();
        _history_file_path = get_history_file_path();
        load_history();
    }

    /**
     * Get the path to the game history file
     */
    private string get_history_file_path() {
        string data_dir = Environment.get_user_data_dir();
        string app_data_dir = Path.build_filename(data_dir, "draughts");

        // Ensure the directory exists
        try {
            File dir = File.new_for_path(app_data_dir);
            if (!dir.query_exists()) {
                dir.make_directory_with_parents();
                logger.debug(@"Created data directory: $app_data_dir");
            }
        } catch (Error e) {
            logger.warning(@"Failed to create data directory: $(e.message)");
        }

        return Path.build_filename(app_data_dir, "game_history.json");
    }

    /**
     * Add a completed game to history
     */
    public void add_game(Game game) {
        // Check if game history is enabled
        if (!settings_manager.get_enable_game_history()) {
            logger.debug("Game history is disabled, not recording game");
            return;
        }

        if (!game.is_game_over()) {
            logger.warning("Attempted to add incomplete game to history");
            return;
        }

        var history_record = new GameHistoryRecord.from_game(game);
        _game_history.insert(0, history_record); // Add to beginning for most recent first

        // Limit history size
        while (_game_history.size > MAX_HISTORY_ENTRIES) {
            _game_history.remove_at(_game_history.size - 1);
        }

        save_history();
        logger.info(@"Added game to history: $(history_record.get_display_title())");
    }

    /**
     * Get all game history records
     */
    public GameHistoryRecord[] get_all_games() {
        return _game_history.to_array();
    }

    /**
     * Get game history filtered by criteria
     */
    public GameHistoryRecord[] get_filtered_games(string? variant_filter = null,
                                                  GameStatus? result_filter = null,
                                                  PlayerType? player_type_filter = null) {
        var filtered = new Gee.ArrayList<GameHistoryRecord>();

        foreach (var record in _game_history) {
            bool matches = true;

            if (variant_filter != null && record.variant_name != variant_filter) {
                matches = false;
            }

            if (result_filter != null && record.result != result_filter) {
                matches = false;
            }

            if (player_type_filter != null) {
                bool has_player_type = record.red_player_type == player_type_filter ||
                                     record.black_player_type == player_type_filter;
                if (!has_player_type) {
                    matches = false;
                }
            }

            if (matches) {
                filtered.add(record);
            }
        }

        return filtered.to_array();
    }

    /**
     * Get game by ID
     */
    public GameHistoryRecord? get_game_by_id(string game_id) {
        foreach (var record in _game_history) {
            if (record.id == game_id) {
                return record;
            }
        }
        return null;
    }

    /**
     * Delete game from history
     */
    public bool delete_game(string game_id) {
        for (int i = 0; i < _game_history.size; i++) {
            if (_game_history[i].id == game_id) {
                _game_history.remove_at(i);
                save_history();
                logger.info(@"Deleted game from history: $game_id");
                return true;
            }
        }
        return false;
    }

    /**
     * Clear all game history
     */
    public void clear_history() {
        _game_history.clear();
        save_history();
        logger.info("Cleared all game history");
    }

    /**
     * Get history statistics
     */
    public HistoryStatistics get_statistics() {
        int total_games = _game_history.size;
        int red_wins = 0;
        int black_wins = 0;
        int draws = 0;
        int human_games = 0;
        int ai_games = 0;
        TimeSpan total_play_time = 0;

        foreach (var record in _game_history) {
            switch (record.result) {
                case GameStatus.RED_WINS:
                    red_wins++;
                    break;
                case GameStatus.BLACK_WINS:
                    black_wins++;
                    break;
                case GameStatus.DRAW:
                    draws++;
                    break;
            }

            if (record.red_player_type == PlayerType.AI || record.black_player_type == PlayerType.AI) {
                ai_games++;
            } else {
                human_games++;
            }

            total_play_time += record.duration;
        }

        return new HistoryStatistics(total_games, red_wins, black_wins, draws,
                                   human_games, ai_games, total_play_time);
    }

    /**
     * Save history to file
     */
    private void save_history() {
        try {
            var json_object = new Json.Object();
            var games_array = new Json.Array();

            foreach (var record in _game_history) {
                games_array.add_object_element(record.to_json());
            }

            json_object.set_array_member("games", games_array);
            json_object.set_string_member("version", "1.0");
            json_object.set_int_member("saved_at", new DateTime.now_utc().to_unix());

            var generator = new Json.Generator();
            generator.set_root(new Json.Node.alloc().init_object(json_object));
            generator.pretty = true;

            string json_data = generator.to_data(null);
            FileUtils.set_contents(_history_file_path, json_data);

            logger.debug(@"Saved game history to: $(_history_file_path)");
        } catch (Error e) {
            logger.error(@"Failed to save game history: $(e.message)");
        }
    }

    /**
     * Load history from file
     */
    private void load_history() {
        try {
            if (!FileUtils.test(_history_file_path, FileTest.EXISTS)) {
                logger.debug("No existing game history file found");
                return;
            }

            string json_data;
            FileUtils.get_contents(_history_file_path, out json_data);

            var parser = new Json.Parser();
            parser.load_from_data(json_data);

            var root_object = parser.get_root().get_object();
            if (!root_object.has_member("games")) {
                logger.warning("Invalid game history file format");
                return;
            }

            var games_array = root_object.get_array_member("games");
            _game_history.clear();

            games_array.foreach_element((array, index, element) => {
                try {
                    var game_obj = element.get_object();
                    var record = new GameHistoryRecord.from_json(game_obj);
                    _game_history.add(record);
                } catch (Error e) {
                    logger.warning(@"Failed to parse game record: $(e.message)");
                }
            });

            logger.info(@"Loaded $((_game_history.size)) games from history");
        } catch (Error e) {
            logger.error(@"Failed to load game history: $(e.message)");
        }
    }

    /**
     * Export history to PGN format
     */
    public string export_to_pgn() {
        var pgn_builder = new StringBuilder();

        foreach (var record in _game_history) {
            pgn_builder.append(record.pgn_notation);
            pgn_builder.append("\n\n");
        }

        return pgn_builder.str;
    }

    /**
     * Get recent games (last N games)
     */
    public GameHistoryRecord[] get_recent_games(int count = 10) {
        int actual_count = int.min(count, _game_history.size);
        var recent = new GameHistoryRecord[actual_count];

        for (int i = 0; i < actual_count; i++) {
            recent[i] = _game_history[i];
        }

        return recent;
    }
}

/**
 * Game history statistics
 */
public class HistoryStatistics : Object {
    public int total_games { get; private set; }
    public int red_wins { get; private set; }
    public int black_wins { get; private set; }
    public int draws { get; private set; }
    public int human_games { get; private set; }
    public int ai_games { get; private set; }
    public TimeSpan total_play_time { get; private set; }

    public HistoryStatistics(int total_games, int red_wins, int black_wins, int draws,
                           int human_games, int ai_games, TimeSpan total_play_time) {
        this.total_games = total_games;
        this.red_wins = red_wins;
        this.black_wins = black_wins;
        this.draws = draws;
        this.human_games = human_games;
        this.ai_games = ai_games;
        this.total_play_time = total_play_time;
    }

    public string get_win_rate_text() {
        if (total_games == 0) return "No games played";

        double red_rate = (double) red_wins / total_games * 100;
        double black_rate = (double) black_wins / total_games * 100;
        double draw_rate = (double) draws / total_games * 100;

        return @"Red: %.1f%% • Black: %.1f%% • Draw: %.1f%%".printf(red_rate, black_rate, draw_rate);
    }

    public string get_total_play_time_text() {
        int total_seconds = (int)(total_play_time / TimeSpan.SECOND);
        int hours = total_seconds / 3600;
        int minutes = (total_seconds % 3600) / 60;

        if (hours > 0) {
            return @"$(hours)h $(minutes)m";
        } else {
            return @"$(minutes)m";
        }
    }
}