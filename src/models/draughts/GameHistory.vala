/**
 * GameHistory.vala
 *
 * Represents a complete game record for history and replay functionality.
 * Stores all moves, game state, players, and statistics.
 */

using Draughts;

public class Draughts.GameHistoryRecord : Object {
    public string id { get; private set; }
    public string variant_name { get; private set; }
    public string red_player_name { get; private set; }
    public string black_player_name { get; private set; }
    public PlayerType red_player_type { get; private set; }
    public PlayerType black_player_type { get; private set; }
    public AIDifficulty? red_ai_difficulty { get; private set; }
    public AIDifficulty? black_ai_difficulty { get; private set; }
    public GameStatus result { get; private set; }
    public DateTime created_at { get; private set; }
    public DateTime finished_at { get; private set; }
    public TimeSpan duration { get; private set; }
    public int total_moves { get; private set; }
    public int red_captures { get; private set; }
    public int red_promotions { get; private set; }
    public int black_captures { get; private set; }
    public int black_promotions { get; private set; }
    public DraughtsMove[] moves { get; private set; }
    public string pgn_notation { get; private set; }

    public GameHistoryRecord.from_game(Game game) {
        this.id = game.id;
        this.variant_name = game.variant.display_name;
        this.red_player_name = game.red_player.name;
        this.black_player_name = game.black_player.name;
        this.red_player_type = game.red_player.player_type;
        this.black_player_type = game.black_player.player_type;
        this.red_ai_difficulty = game.red_player.ai_difficulty;
        this.black_ai_difficulty = game.black_player.ai_difficulty;
        this.result = game.result;
        this.created_at = game.created_at;
        this.finished_at = game.finished_at ?? new DateTime.now_utc();
        this.duration = game.get_game_duration();
        this.moves = game.get_move_history();
        this.total_moves = moves.length;
        this.pgn_notation = game.to_pgn();

        // Get detailed statistics
        var stats = game.get_statistics();
        this.red_captures = stats.red_captures;
        this.red_promotions = stats.red_promotions;
        this.black_captures = stats.black_captures;
        this.black_promotions = stats.black_promotions;
    }

    public GameHistoryRecord.from_json(Json.Object json_object) {
        this.id = json_object.get_string_member("id");
        this.variant_name = json_object.get_string_member("variant_name");
        this.red_player_name = json_object.get_string_member("red_player_name");
        this.black_player_name = json_object.get_string_member("black_player_name");
        this.red_player_type = (PlayerType) json_object.get_int_member("red_player_type");
        this.black_player_type = (PlayerType) json_object.get_int_member("black_player_type");

        if (json_object.has_member("red_ai_difficulty") && !json_object.get_null_member("red_ai_difficulty")) {
            this.red_ai_difficulty = (AIDifficulty) json_object.get_int_member("red_ai_difficulty");
        } else {
            this.red_ai_difficulty = null;
        }

        if (json_object.has_member("black_ai_difficulty") && !json_object.get_null_member("black_ai_difficulty")) {
            this.black_ai_difficulty = (AIDifficulty) json_object.get_int_member("black_ai_difficulty");
        } else {
            this.black_ai_difficulty = null;
        }

        this.result = (GameStatus) json_object.get_int_member("result");
        this.created_at = new DateTime.from_unix_utc(json_object.get_int_member("created_at"));
        this.finished_at = new DateTime.from_unix_utc(json_object.get_int_member("finished_at"));
        this.duration = json_object.get_int_member("duration");
        this.total_moves = (int) json_object.get_int_member("total_moves");
        this.red_captures = (int) json_object.get_int_member("red_captures");
        this.red_promotions = (int) json_object.get_int_member("red_promotions");
        this.black_captures = (int) json_object.get_int_member("black_captures");
        this.black_promotions = (int) json_object.get_int_member("black_promotions");
        this.pgn_notation = json_object.get_string_member("pgn_notation");

        // Parse moves array
        var moves_array = json_object.get_array_member("moves");
        var moves_list = new Gee.ArrayList<DraughtsMove>();

        moves_array.foreach_element((array, index, element) => {
            var move_obj = element.get_object();
            var move = parse_move_from_json(move_obj);
            if (move != null) {
                moves_list.add(move);
            }
        });

        this.moves = moves_list.to_array();
    }

    public Json.Object to_json() {
        var json_object = new Json.Object();

        json_object.set_string_member("id", id);
        json_object.set_string_member("variant_name", variant_name);
        json_object.set_string_member("red_player_name", red_player_name);
        json_object.set_string_member("black_player_name", black_player_name);
        json_object.set_int_member("red_player_type", red_player_type);
        json_object.set_int_member("black_player_type", black_player_type);

        if (red_ai_difficulty != null) {
            json_object.set_int_member("red_ai_difficulty", red_ai_difficulty);
        } else {
            json_object.set_null_member("red_ai_difficulty");
        }

        if (black_ai_difficulty != null) {
            json_object.set_int_member("black_ai_difficulty", black_ai_difficulty);
        } else {
            json_object.set_null_member("black_ai_difficulty");
        }

        json_object.set_int_member("result", result);
        json_object.set_int_member("created_at", created_at.to_unix());
        json_object.set_int_member("finished_at", finished_at.to_unix());
        json_object.set_int_member("duration", duration);
        json_object.set_int_member("total_moves", total_moves);
        json_object.set_int_member("red_captures", red_captures);
        json_object.set_int_member("red_promotions", red_promotions);
        json_object.set_int_member("black_captures", black_captures);
        json_object.set_int_member("black_promotions", black_promotions);
        json_object.set_string_member("pgn_notation", pgn_notation);

        // Serialize moves array
        var moves_array = new Json.Array();
        foreach (var move in moves) {
            moves_array.add_object_element(move_to_json(move));
        }
        json_object.set_array_member("moves", moves_array);

        return json_object;
    }

    private Json.Object move_to_json(DraughtsMove move) {
        var move_obj = new Json.Object();
        move_obj.set_int_member("piece_id", move.piece_id);
        move_obj.set_int_member("from_row", move.from_position.row);
        move_obj.set_int_member("from_col", move.from_position.col);
        move_obj.set_int_member("to_row", move.to_position.row);
        move_obj.set_int_member("to_col", move.to_position.col);
        move_obj.set_boolean_member("promoted", move.promoted);
        move_obj.set_int_member("move_type", move.move_type);

        // Serialize captured pieces array
        var captured_array = new Json.Array();
        foreach (var piece_id in move.captured_pieces) {
            captured_array.add_int_element(piece_id);
        }
        move_obj.set_array_member("captured_pieces", captured_array);

        if (move.timestamp != null) {
            move_obj.set_int_member("timestamp", move.timestamp.to_unix());
        } else {
            move_obj.set_null_member("timestamp");
        }

        return move_obj;
    }

    private DraughtsMove? parse_move_from_json(Json.Object move_obj) {
        try {
            int piece_id = (int) move_obj.get_int_member("piece_id");
            int from_row = (int) move_obj.get_int_member("from_row");
            int from_col = (int) move_obj.get_int_member("from_col");
            int to_row = (int) move_obj.get_int_member("to_row");
            int to_col = (int) move_obj.get_int_member("to_col");
            bool promoted = move_obj.get_boolean_member("promoted");
            MoveType move_type = (MoveType) move_obj.get_int_member("move_type");

            // Parse captured pieces
            var captured_array = move_obj.get_array_member("captured_pieces");
            var captured_pieces = new int[captured_array.get_length()];
            for (int i = 0; i < captured_array.get_length(); i++) {
                captured_pieces[i] = (int) captured_array.get_int_element(i);
            }

            // Get board size based on variant
            int board_size = get_board_size_for_variant(variant_name);
            var from_pos = new BoardPosition(from_row, from_col, board_size);
            var to_pos = new BoardPosition(to_row, to_col, board_size);
            var move = new DraughtsMove.with_captures(piece_id, from_pos, to_pos, captured_pieces);
            move.promoted = promoted;

            if (move_obj.has_member("timestamp") && !move_obj.get_null_member("timestamp")) {
                move.timestamp = new DateTime.from_unix_utc(move_obj.get_int_member("timestamp"));
            }

            return move;
        } catch (Error e) {
            var logger = Logger.get_default();
            logger.debug("Error parsing move from JSON: %s", e.message);
            return null;
        }
    }

    public string get_display_title() {
        return @"$red_player_name vs $black_player_name";
    }

    public string get_display_subtitle() {
        string result_text = get_result_text();
        string duration_text = format_duration(duration);
        string ai_info = get_ai_difficulty_text();

        if (ai_info.length > 0) {
            return @"$(variant_name) • $(ai_info) • $(result_text) • $(duration_text)";
        } else {
            return @"$(variant_name) • $(result_text) • $(duration_text)";
        }
    }

    public string get_result_text() {
        switch (result) {
            case GameStatus.RED_WINS:
                return @"$red_player_name wins";
            case GameStatus.BLACK_WINS:
                return @"$black_player_name wins";
            case GameStatus.DRAW:
                return "Draw";
            default:
                return "Game ended";
        }
    }

    public string get_statistics_summary() {
        int red_moves = (total_moves + 1) / 2;
        int black_moves = total_moves / 2;

        return @"Moves: $total_moves • Red: $(red_moves)m/$(red_captures)c/$(red_promotions)p • Black: $(black_moves)m/$(black_captures)c/$(black_promotions)p";
    }

    private string format_duration(TimeSpan duration) {
        int total_seconds = (int)(duration / TimeSpan.SECOND);
        int minutes = total_seconds / 60;
        int seconds = total_seconds % 60;
        return "%d:%02d".printf(minutes, seconds);
    }

    public string get_date_played() {
        return created_at.format("%Y-%m-%d %H:%M");
    }

    public string get_ai_difficulty_text() {
        var ai_parts = new Gee.ArrayList<string>();

        if (red_player_type == PlayerType.AI && red_ai_difficulty != null) {
            ai_parts.add(@"Red: $(get_difficulty_display_name(red_ai_difficulty))");
        }

        if (black_player_type == PlayerType.AI && black_ai_difficulty != null) {
            ai_parts.add(@"Black: $(get_difficulty_display_name(black_ai_difficulty))");
        }

        if (ai_parts.size == 0) {
            return "";
        } else if (ai_parts.size == 1) {
            return ai_parts[0];
        } else {
            return string.joinv(", ", ai_parts.to_array());
        }
    }

    private string get_difficulty_display_name(AIDifficulty difficulty) {
        switch (difficulty) {
            case AIDifficulty.BEGINNER: return "Beginner";
            case AIDifficulty.EASY: return "Easy";
            case AIDifficulty.MEDIUM: return "Medium";
            case AIDifficulty.NOVICE: return "Novice";
            case AIDifficulty.INTERMEDIATE: return "Intermediate";
            case AIDifficulty.HARD: return "Hard";
            case AIDifficulty.ADVANCED: return "Advanced";
            case AIDifficulty.EXPERT: return "Expert";
            case AIDifficulty.MASTER: return "Master";
            case AIDifficulty.GRANDMASTER: return "Grandmaster";
            default: return "Medium";
        }
    }

    private int get_board_size_for_variant(string variant_name) {
        switch (variant_name.down()) {
            case "international draughts":
            case "frisian draughts":
                return 10;
            case "canadian draughts":
                return 12;
            default:
                return 8; // All other variants including Brazilian Draughts
        }
    }
}