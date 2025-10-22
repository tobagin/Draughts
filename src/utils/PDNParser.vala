/**
 * PDNParser.vala
 *
 * Parser for Portable Draughts Notation (PDN) files.
 *
 * Supports parsing:
 * - PDN headers ([Event], [Date], [Red], [Black], [Variant], [Result])
 * - Move notation in algebraic format
 * - Game metadata
 *
 * Example PDN format:
 * [Event "Draughts Game"]
 * [Date "2025.10.22"]
 * [Red "Player 1"]
 * [Black "Player 2"]
 * [Variant "American Checkers"]
 * [Result "1-0"]
 *
 * 1. e3-f4 d6-e5 2. f4xd6 ...
 */

using Draughts;

public class Draughts.PDNParser : Object {

    private Logger logger;

    public PDNParser() {
        this.logger = Logger.get_default();
    }

    /**
     * Parse a PDN string and extract game information
     */
    public PDNGameData? parse(string pdn_content) {
        try {
            var game_data = new PDNGameData();

            // Split into lines
            string[] lines = pdn_content.split("\n");

            var move_lines = new Gee.ArrayList<string>();
            bool in_headers = true;

            foreach (var line in lines) {
                var trimmed = line.strip();

                if (trimmed.length == 0) {
                    if (in_headers) {
                        in_headers = false;
                    }
                    continue;
                }

                // Parse header lines
                if (trimmed.has_prefix("[")) {
                    parse_header(trimmed, game_data);
                } else {
                    // This is a move line
                    move_lines.add(trimmed);
                }
            }

            // Parse all move lines together
            if (move_lines.size > 0) {
                string moves_text = string.joinv(" ", move_lines.to_array());
                game_data.moves_notation = parse_moves(moves_text);
            }

            return game_data;

        } catch (Error e) {
            logger.error("Failed to parse PDN: %s", e.message);
            return null;
        }
    }

    /**
     * Parse a header line like [Event "Draughts Game"]
     */
    private void parse_header(string line, PDNGameData game_data) {
        // Format: [Key "Value"]
        var regex_pattern = /\[([^\]]+)\s+"([^"]+)"\]/;
        MatchInfo match_info;

        if (regex_pattern.match(line, 0, out match_info)) {
            string key = match_info.fetch(1).strip();
            string value = match_info.fetch(2).strip();

            switch (key) {
                case "Event":
                    game_data.event = value;
                    break;

                case "Date":
                    game_data.date = value;
                    break;

                case "Red":
                case "White":
                    game_data.red_player = value;
                    break;

                case "Black":
                    game_data.black_player = value;
                    break;

                case "Variant":
                    game_data.variant = value;
                    break;

                case "Result":
                    game_data.result = value;
                    break;

                case "Site":
                    game_data.site = value;
                    break;

                case "Round":
                    game_data.round = value;
                    break;

                default:
                    // Store other headers in metadata
                    game_data.metadata[key] = value;
                    break;
            }
        }
    }

    /**
     * Parse move notation
     * Example: "1. e3-f4 d6-e5 2. f4xd6 c7-d6"
     */
    private string[] parse_moves(string moves_text) {
        var moves = new Gee.ArrayList<string>();

        // Remove result markers (1-0, 0-1, 1/2-1/2, *)
        moves_text = moves_text.replace("1-0", "");
        moves_text = moves_text.replace("0-1", "");
        moves_text = moves_text.replace("1/2-1/2", "");
        moves_text = moves_text.replace("*", "");

        // Split by whitespace
        string[] tokens = moves_text.split_set(" \t\n");

        foreach (var token in tokens) {
            var trimmed = token.strip();

            if (trimmed.length == 0) {
                continue;
            }

            // Skip move numbers (e.g., "1.", "2.", etc.)
            if (trimmed.has_suffix(".")) {
                continue;
            }

            // Check if this looks like a move (contains - or x)
            if (trimmed.contains("-") || trimmed.contains("x") || trimmed.contains(":")) {
                moves.add(trimmed);
            }
        }

        return moves.to_array();
    }

    /**
     * Parse algebraic notation to board position
     * Examples: "e3", "f4", "32" (numeric notation)
     */
    public BoardPosition? parse_position(string notation, int board_size) {
        notation = notation.strip();

        // Check if numeric notation (e.g., "32" for International draughts)
        if (notation.length > 0 && notation[0].isdigit()) {
            return parse_numeric_position(notation, board_size);
        }

        // Algebraic notation (e.g., "e3")
        if (notation.length >= 2) {
            char col_char = notation[0];
            string row_str = notation.substring(1);

            int col = col_char - 'a';
            int row;

            if (!int.try_parse(row_str, out row)) {
                return null;
            }

            // PDN uses 1-based row numbering from bottom
            row = board_size - row;

            if (row >= 0 && row < board_size && col >= 0 && col < board_size) {
                return new BoardPosition(row, col, board_size);
            }
        }

        return null;
    }

    /**
     * Parse numeric notation (used in International draughts)
     * Example: "32" maps to a specific square on 10x10 board
     */
    private BoardPosition? parse_numeric_position(string notation, int board_size) {
        int square_num;
        if (!int.try_parse(notation, out square_num)) {
            return null;
        }

        // Convert square number to row/col
        // This is a simplified version - actual conversion depends on variant
        // For 10x10 International draughts, squares are numbered 1-50

        if (board_size == 10) {
            // International draughts numbering
            if (square_num < 1 || square_num > 50) {
                return null;
            }

            // Convert to 0-based row/col
            // Squares are numbered from top-left, only dark squares
            int dark_square_index = square_num - 1;
            int row = dark_square_index / 5;
            int col = (dark_square_index % 5) * 2;

            // Adjust for row parity
            if (row % 2 == 1) {
                col += 1;
            }

            return new BoardPosition(row, col, board_size);
        }

        return null;
    }

    /**
     * Convert PDN variant name to DraughtsVariant enum
     */
    public DraughtsVariant get_variant_from_name(string variant_name) {
        string lower = variant_name.down();

        if (lower.contains("american") || lower.contains("english") || lower.contains("checkers")) {
            return DraughtsVariant.AMERICAN;
        } else if (lower.contains("international")) {
            return DraughtsVariant.INTERNATIONAL;
        } else if (lower.contains("russian")) {
            return DraughtsVariant.RUSSIAN;
        } else if (lower.contains("brazilian")) {
            return DraughtsVariant.BRAZILIAN;
        } else if (lower.contains("italian")) {
            return DraughtsVariant.ITALIAN;
        } else if (lower.contains("spanish")) {
            return DraughtsVariant.SPANISH;
        } else if (lower.contains("czech")) {
            return DraughtsVariant.CZECH;
        } else if (lower.contains("thai")) {
            return DraughtsVariant.THAI;
        } else if (lower.contains("german")) {
            return DraughtsVariant.GERMAN;
        } else if (lower.contains("swedish")) {
            return DraughtsVariant.SWEDISH;
        } else if (lower.contains("turkish")) {
            return DraughtsVariant.TURKISH;
        } else if (lower.contains("frisian")) {
            return DraughtsVariant.FRISIAN;
        } else if (lower.contains("canadian")) {
            return DraughtsVariant.CANADIAN;
        } else if (lower.contains("pool")) {
            return DraughtsVariant.POOL;
        } else if (lower.contains("armenian")) {
            return DraughtsVariant.ARMENIAN;
        } else if (lower.contains("sri lankan")) {
            return DraughtsVariant.SRI_LANKAN;
        }

        // Default to American
        return DraughtsVariant.AMERICAN;
    }

    /**
     * Parse result string to GameStatus
     */
    public GameStatus parse_result(string result) {
        result = result.strip();

        if (result == "1-0" || result.down().contains("red wins") || result.down().contains("white wins")) {
            return GameStatus.RED_WINS;
        } else if (result == "0-1" || result.down().contains("black wins")) {
            return GameStatus.BLACK_WINS;
        } else if (result == "1/2-1/2" || result.down().contains("draw")) {
            return GameStatus.DRAW;
        }

        return GameStatus.IN_PROGRESS;
    }
}

/**
 * Data class for parsed PDN game information
 */
public class Draughts.PDNGameData : Object {
    public string event { get; set; default = "Draughts Game"; }
    public string date { get; set; default = ""; }
    public string red_player { get; set; default = "Red"; }
    public string black_player { get; set; default = "Black"; }
    public string variant { get; set; default = "American Checkers"; }
    public string result { get; set; default = "*"; }
    public string site { get; set; default = ""; }
    public string round { get; set; default = ""; }
    public string[] moves_notation { get; set; default = new string[0]; }
    public Gee.HashMap<string, string> metadata { get; set; default = new Gee.HashMap<string, string>(); }

    public PDNGameData() {
        metadata = new Gee.HashMap<string, string>();
    }

    public string to_string() {
        var sb = new StringBuilder();
        sb.append(@"PDN Game: $(event)\n");
        sb.append(@"Date: $(date)\n");
        sb.append(@"Players: $(red_player) vs $(black_player)\n");
        sb.append(@"Variant: $(variant)\n");
        sb.append(@"Result: $(result)\n");
        sb.append(@"Moves: $(moves_notation.length)\n");
        return sb.str;
    }
}
