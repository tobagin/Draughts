/**
 * PDNConverter.vala
 *
 * Converts PDN (Portable Draughts Notation) to actual game states.
 * Responsible for:
 * - Converting algebraic notation to DraughtsMove objects
 * - Building game state from move sequence
 * - Creating GameHistoryRecord from PDN
 */

using Draughts;

public class Draughts.PDNConverter : Object {

    private Logger logger;
    private PDNParser parser;

    public PDNConverter() {
        this.logger = Logger.get_default();
        this.parser = new PDNParser();
    }

    /**
     * Convert PDN content to a playable game history record
     */
    public GameHistoryRecord? convert_pdn_to_game_record(string pdn_content) {
        // Parse PDN
        var game_data = parser.parse(pdn_content);
        if (game_data == null) {
            logger.error("Failed to parse PDN content");
            return null;
        }

        // Get variant
        var variant = parser.get_variant_from_name(game_data.variant);
        var game_variant = new GameVariant(variant);

        // Create initial game state
        var initial_state = DraughtsGameState.create_initial_state(variant);
        var rule_engine = new UnifiedRuleEngine(variant);

        // Track all moves and states
        var moves = new Gee.ArrayList<DraughtsMove>();
        var current_state = initial_state;
        int move_number = 0;

        // Apply each move from PDN
        foreach (var move_notation in game_data.moves_notation) {
            move_number++;

            // Find and apply the move
            var move = find_move_from_notation(
                move_notation,
                current_state,
                rule_engine
            );

            if (move == null) {
                logger.warning("Could not convert move %d: %s", move_number, move_notation);
                // If we can't convert a move, return what we have so far
                break;
            }

            moves.add(move);

            // Apply move to get next state
            current_state = current_state.apply_move(move);
        }

        // Create game record
        return create_game_record_from_moves(
            game_data,
            variant,
            moves.to_array()
        );
    }

    /**
     * Find a move that matches the algebraic notation
     */
    private DraughtsMove? find_move_from_notation(
        string notation,
        DraughtsGameState state,
        IRuleEngine rule_engine
    ) {
        // Parse the notation to get from/to positions
        var positions = parse_move_notation(notation, state.variant.board_size);
        if (positions == null) {
            return null;
        }

        var from_pos = positions.from_pos;
        var to_pos = positions.to_pos;
        bool is_capture = positions.is_capture;

        // Get all legal moves for current state
        var legal_moves = rule_engine.generate_legal_moves(state);

        // Find matching move
        foreach (var legal_move in legal_moves) {
            if (legal_move.from_position.equals(from_pos) &&
                legal_move.to_position.equals(to_pos)) {
                return legal_move;
            }
        }

        // If exact match not found, try to find by from position only
        // (for cases where notation might be ambiguous)
        if (legal_moves.length == 1) {
            return legal_moves[0];
        }

        return null;
    }

    /**
     * Parse move notation into positions
     */
    private MovePositions? parse_move_notation(string notation, int board_size) {
        // Handle different notation formats
        // e3-f4 (simple move)
        // f4xd6 (capture)
        // f4:d6 (capture with colon)

        string separator = "-";
        bool is_capture = false;

        if (notation.contains("x")) {
            separator = "x";
            is_capture = true;
        } else if (notation.contains(":")) {
            separator = ":";
            is_capture = true;
        }

        string[] parts = notation.split(separator);
        if (parts.length != 2) {
            logger.warning("Invalid move notation: %s", notation);
            return null;
        }

        var from_pos = parser.parse_position(parts[0].strip(), board_size);
        var to_pos = parser.parse_position(parts[1].strip(), board_size);

        if (from_pos == null || to_pos == null) {
            logger.warning("Could not parse positions from: %s", notation);
            return null;
        }

        return new MovePositions() {
            from_pos = from_pos,
            to_pos = to_pos,
            is_capture = is_capture
        };
    }

    /**
     * Create a game history record from moves
     */
    private GameHistoryRecord create_game_record_from_moves(
        PDNGameData game_data,
        DraughtsVariant variant,
        DraughtsMove[] moves
    ) {
        // Create a mock game ID
        string game_id = "pdn_" + new DateTime.now_utc().to_unix().to_string();

        // Parse date
        DateTime created_at;
        try {
            // PDN date format: "YYYY.MM.DD"
            var date_parts = game_data.date.split(".");
            if (date_parts.length == 3) {
                int year = int.parse(date_parts[0]);
                int month = int.parse(date_parts[1]);
                int day = int.parse(date_parts[2]);
                created_at = new DateTime.utc(year, month, day, 0, 0, 0);
            } else {
                created_at = new DateTime.now_utc();
            }
        } catch (Error e) {
            created_at = new DateTime.now_utc();
        }

        // Determine result
        GameStatus result = parser.parse_result(game_data.result);

        // Calculate statistics
        int red_captures = 0;
        int black_captures = 0;
        int red_promotions = 0;
        int black_promotions = 0;

        bool is_red_turn = true;
        foreach (var move in moves) {
            if (move.is_capture() && move.captured_pieces.length > 0) {
                if (is_red_turn) {
                    red_captures += move.captured_pieces.length;
                } else {
                    black_captures += move.captured_pieces.length;
                }
            }

            if (move.promoted) {
                if (is_red_turn) {
                    red_promotions++;
                } else {
                    black_promotions++;
                }
            }

            is_red_turn = !is_red_turn;
        }

        // Create game history record manually
        var record = new PDNGameRecord(
            game_id,
            variant,
            game_data.red_player,
            game_data.black_player,
            result,
            created_at,
            moves,
            red_captures,
            red_promotions,
            black_captures,
            black_promotions
        );

        return record;
    }

    /**
     * Helper struct for move positions
     */
    private struct MovePositions {
        BoardPosition from_pos;
        BoardPosition to_pos;
        bool is_capture;
    }
}

/**
 * Custom GameHistoryRecord for PDN-imported games
 */
public class Draughts.PDNGameRecord : GameHistoryRecord {

    public PDNGameRecord(
        string id,
        DraughtsVariant variant,
        string red_player,
        string black_player,
        GameStatus result,
        DateTime created_at,
        DraughtsMove[] moves,
        int red_captures,
        int red_promotions,
        int black_captures,
        int black_promotions
    ) {
        Object();

        this.id = id;
        this.variant_name = new GameVariant(variant).display_name;
        this.red_player_name = red_player;
        this.black_player_name = black_player;
        this.red_player_type = PlayerType.HUMAN;
        this.black_player_type = PlayerType.HUMAN;
        this.red_ai_difficulty = null;
        this.black_ai_difficulty = null;
        this.result = result;
        this.created_at = created_at;
        this.finished_at = created_at;
        this.duration = 0; // Unknown for imported games
        this.moves = moves;
        this.total_moves = moves.length;
        this.red_captures = red_captures;
        this.red_promotions = red_promotions;
        this.black_captures = black_captures;
        this.black_promotions = black_promotions;

        // Generate PGN notation
        var pgn_builder = new StringBuilder();
        pgn_builder.append("[Event \"Imported from PDN\"]\n");
        pgn_builder.append(@"[Date \"$(created_at.format("%Y.%m.%d"))\"]\n");
        pgn_builder.append(@"[Red \"$(red_player)\"]\n");
        pgn_builder.append(@"[Black \"$(black_player)\"]\n");
        pgn_builder.append(@"[Variant \"$(variant_name)\"]\n");
        pgn_builder.append("\n");

        for (int i = 0; i < moves.length; i++) {
            if (i % 2 == 0) {
                pgn_builder.append(@"$((i / 2) + 1). ");
            }
            pgn_builder.append(@"$(moves[i].to_algebraic_notation()) ");
        }

        this.pgn_notation = pgn_builder.str;
    }
}
