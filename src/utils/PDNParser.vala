/**
 * PDNParser.vala
 *
 * Utility class for parsing Portable Draughts Notation (PDN) files.
 * Supports parsing headers and move lists.
 */

using Draughts;

namespace Draughts {

    public class ParsedPDN {
        public Gee.HashMap<string, string> tags { get; private set; }
        public Gee.ArrayList<string> moves { get; private set; }
        public GameVariant? variant { get; set; }
        public string result { get; set; }

        public ParsedPDN() {
            tags = new Gee.HashMap<string, string>();
            moves = new Gee.ArrayList<string>();
            result = "*";
        }
    }

    public class PDNParser : Object {
        private Logger logger;

        public PDNParser() {
            logger = Logger.get_default();
        }

        /**
         * Parse a PDN file from a file path
         */
        public ParsedPDN parse_file(string file_path) throws Error {
            var file = File.new_for_path(file_path);
            if (!file.query_exists()) {
                throw new IOError.NOT_FOUND("PDN file not found: %s", file_path);
            }

            var dis = new DataInputStream(file.read());
            string line;
            var pdn = new ParsedPDN();
            
            while ((line = dis.read_line(null)) != null) {
                line = line.strip();
                if (line.length == 0) continue;

                if (line.has_prefix("[")) {
                    parse_tag(line, pdn);
                } else {
                    // Accumulate move lines (they can be span multiple lines)
                    // We'll parse the accumulated moves string after reading the whole file
                    // But for simplicity in this initial implementation, we might just assume 
                    // moves start after tags.
                    parse_moves_line(line, pdn);
                }
            }

            // Post-process to detect variant if not explicit
            detect_variant(pdn);

            return pdn;
        }

        /**
         * Parse a single PDN tag line like [Event "..."]
         */
        private void parse_tag(string line, ParsedPDN pdn) {
            // Remove brackets
            string content = line.substring(1, line.length - 2).strip();
            
            // Split by first space
            int space_idx = content.index_of(" ");
            if (space_idx > 0) {
                string key = content.substring(0, space_idx);
                string value = content.substring(space_idx + 1).replace("\"", "");
                pdn.tags[key] = value;
                
                logger.debug("Parsed PDN Tag: %s = %s", key, value);

                if (key == "Result") {
                    pdn.result = value;
                }
            }
        }

        /**
         * Parse a line containing moves
         * Standard PDN moves look like: 1. 11-15 23-19 2. 8-11 22-17 ...
         */
        private void parse_moves_line(string line, ParsedPDN pdn) {
            // Remove comments usually enclosed in {}
            var clean_line = remove_comments(line);
            if (clean_line.length == 0) return;

            // Split by space
            var tokens = clean_line.split(" ");
            foreach (string token in tokens) {
                token = token.strip();
                if (token.length == 0) continue;

                // Skip move numbers (e.g., "1.")
                if (token.has_suffix(".")) continue;

                // Handle result at the end (e.g. 1-0)
                if (token == "1-0" || token == "0-1" || token == "1/2-1/2" || token == "*") {
                    pdn.result = token;
                    continue;
                }

                // It's a move!
                pdn.moves.add(token);
            }
        }

        private string remove_comments(string line) {
            var regex = /\{.*?\}/;
            try {
                return regex.replace(line, -1, 0, "");
            } catch (Error e) {
                return line;
            }
        }

        private void detect_variant(ParsedPDN pdn) {
            string? game_type = pdn.tags["GameType"];
            if (game_type != null) {
                // Determine variant from GameType tag
                // 20: International
                // 21: English/American
                // 22: Russian
                // 23: Brazilian
                // etc.
                int type = int.parse(game_type);
                switch (type) {
                    case 20: pdn.variant = new GameVariant(DraughtsVariant.INTERNATIONAL); break;
                    case 21: pdn.variant = new GameVariant(DraughtsVariant.AMERICAN); break;
                    case 22: pdn.variant = new GameVariant(DraughtsVariant.RUSSIAN); break;
                    case 23: pdn.variant = new GameVariant(DraughtsVariant.BRAZILIAN); break;
                    // Default to American if unknown for now
                    default: pdn.variant = new GameVariant(DraughtsVariant.AMERICAN); break; 
                }
            } else {
                // Attempt heuristics or default
                // If board size is 10x10 moves, it's likely International
                // But parsing moves to determine valid range is complex here.
                // Defaulting to American/English for 8x8 is safe for now.
                pdn.variant = new GameVariant(DraughtsVariant.AMERICAN);
            }
        }

        /**
         * Convert PDN square number to BoardPosition
         * @param square 1-based square number
         * @param board_size Board size (e.g. 8 or 10)
         * @return BoardPosition or null if invalid
         */
        public static BoardPosition? square_to_position(int square, int board_size) {
            if (square < 1 || square > (board_size * board_size) / 2) {
                return null;
            }

            int squares_per_row = board_size / 2;
            int row = (square - 1) / squares_per_row;
            int col_index = (square - 1) % squares_per_row;
            
            // Determine column offset based on row
            // If row 0 (top) starts with a dark square at col 1:
            // Row 0: 1, 3, 5, 7 (Offset 1)
            // Row 1: 0, 2, 4, 6 (Offset 0)
            int offset = (row % 2 == 0) ? 1 : 0;
            
            int col = (col_index * 2) + offset;
            
            return new BoardPosition(row, col, board_size);
        }

        /**
         * Parse a PDN move string (e.g. "11-15" or "24x19")
         * returns a tuple of (from_square, to_square, is_capture)
         */
        public static PdnMoveTuple? parse_move_string(string move_str) {
            bool is_capture = move_str.contains("x");
            string separator = is_capture ? "x" : "-";
            
            var parts = move_str.split(separator);
            if (parts.length != 2) {
                return null;
            }
            
            int from_sq = int.parse(parts[0]);
            int to_sq = int.parse(parts[1]);
            
            return new PdnMoveTuple(from_sq, to_sq, is_capture);
        }
        /**
         * Convert BoardPosition to PDN square number
         */
        public static int position_to_square(BoardPosition pos, int board_size) {
            int squares_per_row = board_size / 2;
            // logic: square = row * squares_per_row + col_index + 1
            // col_index needs to be derived from actual col.
            // On standard board:
            // Row 0 (top): . 1 . 2 . 3 . 4  (cols 1,3,5,7) -> 1,2,3,4
            // Row 1: 5 . 6 . 7 . 8 . (cols 0,2,4,6) -> 5,6,7,8
            
            // Offset for row: if row is even, dark squares are at 1,3,5,7. If odd, at 0,2,4,6.
            // The col index (0..3) is roughly col / 2.
            
            int col_index = pos.col / 2;
            return (pos.row * squares_per_row) + col_index + 1;
        }

        /**
         * Generate PDN string from a Game object
         */
        public static string generate_pdn(Game game) {
            var sb = new StringBuilder();
            
            // Headers
            sb.append("[Event \"Draughts Game\"]\n");
            sb.append("[Date \"%s\"]\n".printf(game.created_at.format("%Y.%m.%d")));
            if (game.finished_at != null) {
                // sb.append("[Date \"%s\"]\n".printf(game.finished_at.format("%Y.%m.%d")));
            }
            sb.append("[Black \"%s\"]\n".printf(game.black_player.name)); // PDN standard: Black first? Or just tags.
            sb.append("[White \"%s\"]\n".printf(game.red_player.name)); // PDN uses White/Red usually. adapting.
            
            // GameType tag for variant
            int gametype = 0;
            if (game.variant.variant == DraughtsVariant.INTERNATIONAL) gametype = 20;
            else if (game.variant.variant == DraughtsVariant.AMERICAN) gametype = 21;
            else if (game.variant.variant == DraughtsVariant.RUSSIAN) gametype = 22;
            else if (game.variant.variant == DraughtsVariant.BRAZILIAN) gametype = 23;
            
            if (gametype > 0) {
                sb.append("[GameType \"%d\"]\n".printf(gametype));
            }
            
            string result = "*";
            if (game.result == GameStatus.RED_WINS) result = "1-0"; // Assuming Red is White/First usually? 
            // Warning: in International, White moves first. In American, Black (usually Red pieces) moves first.
            // Draughts engine: RED moves first usually? 
            // Valid Check: Game.vala doesn't explicitly state. But usually RED/WHITE moves first.
            // Let's stick to standard result notation relative to first player.
            else if (game.result == GameStatus.BLACK_WINS) result = "0-1";
            else if (game.result == GameStatus.DRAW) result = "1/2-1/2";
            
            sb.append("[Result \"%s\"]\n".printf(result));
            sb.append("\n"); // Empty line after headers
            
            // Moves
            var moves = game.get_move_history();
            for (int i = 0; i < moves.length; i++) {
                if (i % 2 == 0) {
                    sb.append("%d. ".printf((i / 2) + 1));
                }
                
                var move = moves[i];
                int from_sq = position_to_square(move.from_position, game.variant.board_size);
                int to_sq = position_to_square(move.to_position, game.variant.board_size);
                
                string sep = move.is_capture() ? "x" : "-";
                // Note: Multi-captures should ideally list all steps, but DraughtsMove might simplify to start-end.
                // If DraughtsMove stores path, we could traverse it. 
                // Currently assuming start-end for simplicity unless get_path() is used.
                // PDN allows 24x15x6 etc.
                
                sb.append("%d%s%d".printf(from_sq, sep, to_sq));
                
                if (i < moves.length - 1 || result != "*") {
                    sb.append(" ");
                }
            }
            
            sb.append(result);
            
            return sb.str;
        }
    }

    public class PdnMoveTuple {
        public int from_sq;
        public int to_sq;
        public bool is_capture;
        
        public PdnMoveTuple(int from, int to, bool capture) {
            this.from_sq = from;
            this.to_sq = to;
            this.is_capture = capture;
        }
    }
}
