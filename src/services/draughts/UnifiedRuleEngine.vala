/**
 * UnifiedRuleEngine.vala
 *
 * A single rule engine that uses GameVariant configuration to implement
 * all draughts variants. This replaces the need for 16 separate rule engine classes.
 */

using Draughts;

public class Draughts.UnifiedRuleEngine : BaseRuleEngine {
    private Logger logger;

    public UnifiedRuleEngine(GameVariant variant) {
        base(variant);
        this.logger = Logger.get_default();
    }

    public override bool is_move_legal(DraughtsGameState state, DraughtsMove move) {
        // Start with basic validation from BaseRuleEngine
        if (!is_basic_move_valid(state, move)) {
            return false;
        }

        var piece = state.get_piece_by_id(move.piece_id);
        if (piece == null) return false;

        int row_diff = (move.to_position.row - move.from_position.row).abs();
        int col_diff = (move.to_position.col - move.from_position.col).abs();

        // Validate based on piece type and variant configuration
        if (piece.piece_type == DraughtsPieceType.MAN) {
            return validate_man_move(state, piece, move, row_diff, col_diff);
        } else {
            return validate_king_move(state, piece, move, row_diff, col_diff);
        }
    }

    private bool validate_man_move(DraughtsGameState state, GamePiece piece, DraughtsMove move, int row_diff, int col_diff) {
        // Simple moves (one square diagonally)
        if (row_diff == 1 && col_diff == 1) {
            // Regular pieces can only move forward in simple moves (all variants)
            return is_forward_move(piece.color, move.from_position, move.to_position);
        }

        // Capture moves
        if (is_capture_move(row_diff, col_diff)) {
            return validate_capture_move(state, piece, move);
        }

        return false;
    }

    private bool validate_king_move(DraughtsGameState state, GamePiece piece, DraughtsMove move, int row_diff, int col_diff) {
        // Kings can always move in any diagonal direction
        if (!is_diagonal_move(move.from_position, move.to_position)) {
            return false;
        }

        if (move.move_type == MoveType.SIMPLE) {
            // Simple king moves
            if (variant.kings_can_fly) {
                // Flying kings: can move any distance if path is clear
                return is_path_clear(state, move.from_position, move.to_position);
            } else {
                // Non-flying kings: can only move one square
                return row_diff == 1 && col_diff == 1;
            }
        } else {
            // King captures
            return validate_capture_move(state, piece, move);
        }
    }

    private bool is_capture_move(int row_diff, int col_diff) {
        // Determine if this is a capture move based on distance
        if (variant.kings_can_fly) {
            // In flying variants, captures can be at various distances (including 1 square for kings)
            return row_diff == col_diff && row_diff >= 1;
        } else {
            // In non-flying variants, captures are typically 2 squares
            return row_diff == 2 && col_diff == 2;
        }
    }

    private bool validate_capture_move(DraughtsGameState state, GamePiece piece, DraughtsMove move) {
        var captured_pieces = find_captured_pieces(state, move.from_position, move.to_position);

        // Must capture at least one piece
        if (captured_pieces.size == 0) {
            return false;
        }

        // Can't capture own pieces
        foreach (var captured in captured_pieces) {
            if (captured.color == piece.color) {
                return false;
            }
        }

        // Check capture direction rules for men
        if (piece.piece_type == DraughtsPieceType.MAN && !variant.men_can_capture_backwards) {
            // Some variants (Italian, Spanish) don't allow backward captures for regular pieces
            if (!is_forward_move(piece.color, move.from_position, move.to_position)) {
                return false;
            }
        }

        // Allow multiple captures for flying kings, single capture for others
        if (piece.piece_type == DraughtsPieceType.KING && variant.kings_can_fly) {
            // Flying kings can capture multiple pieces in their path
            return captured_pieces.size >= 1;
        } else {
            // Regular pieces and non-flying kings capture exactly one piece per jump
            return captured_pieces.size == 1;
        }
    }

    private bool is_path_clear(DraughtsGameState state, BoardPosition from, BoardPosition to) {
        var squares_between = get_squares_between(from, to);
        foreach (var square in squares_between) {
            if (state.get_piece_at(square) != null) {
                return false;
            }
        }
        return true;
    }

    public override DraughtsMove[] generate_legal_moves(DraughtsGameState state) {
        var legal_moves = new Gee.ArrayList<DraughtsMove>();
        var active_pieces = state.get_pieces_by_color(state.active_player);

        // Check for captures first (mandatory in most variants)
        if (variant.mandatory_capture) {
            var capture_moves = generate_all_captures(state, active_pieces);
            logger.debug("MandatoryCapture: Found %d capture moves", capture_moves.size);
            if (capture_moves.size > 0) {
                var filtered = filter_captures_by_priority(state, capture_moves);
                logger.debug(" %d captures", filtered.length);
                return filtered;
            }
            logger.debug(" none");
        }

        // Generate simple moves
        logger.debug("GenSimple: Active pieces count: %d", active_pieces.size);
        foreach (var piece in active_pieces) {
            logger.debug("Processing piece: %s %s at (%d,%d)",
                  piece.color.to_string(), piece.piece_type.to_string(),
                  piece.position.row, piece.position.col);
            generate_simple_moves_for_piece(state, piece, legal_moves);
        }
        logger.debug(" complete");

        return legal_moves.to_array();
    }

    private Gee.ArrayList<DraughtsMove> generate_all_captures(DraughtsGameState state, Gee.ArrayList<GamePiece> pieces) {
        var captures = new Gee.ArrayList<DraughtsMove>();

        foreach (var piece in pieces) {
            generate_captures_for_piece(state, piece, captures);
        }

        return captures;
    }

    private void generate_captures_for_piece(DraughtsGameState state, GamePiece piece, Gee.ArrayList<DraughtsMove> moves) {
        // Generate captures using the four diagonal directions
        int[] row_dirs = {-1, -1, 1, 1};
        int[] col_dirs = {-1, 1, -1, 1};

        for (int dir = 0; dir < 4; dir++) {
            // Check if this direction is valid for this piece's captures
            if (!is_valid_capture_direction_for_piece(piece, row_dirs[dir], col_dirs[dir])) {
                continue;
            }

            if (variant.kings_can_fly && piece.piece_type == DraughtsPieceType.KING) {
                // Flying kings can capture at various distances
                generate_flying_captures(state, piece, row_dirs[dir], col_dirs[dir], moves);
            } else {
                // Regular pieces and non-flying kings capture at fixed distance
                generate_short_range_capture(state, piece, row_dirs[dir], col_dirs[dir], moves);
            }
        }
    }

    private void generate_simple_moves_for_piece(DraughtsGameState state, GamePiece piece, Gee.ArrayList<DraughtsMove> moves) {
        // Generate simple moves using the four diagonal directions
        int[] row_dirs = {-1, -1, 1, 1};
        int[] col_dirs = {-1, 1, -1, 1};

        // DEBUG: Print flying king status
        if (piece.piece_type == DraughtsPieceType.KING) {
            logger.debug(" K%d@(%d,%d) %s", piece.id, piece.position.row, piece.position.col, variant.kings_can_fly ? "flying" : "short");
        } else {
            logger.debug(" M%d@(%d,%d)", piece.id, piece.position.row, piece.position.col);
        }

        for (int dir = 0; dir < 4; dir++) {
            // Check if this direction is valid for this piece
            if (!is_valid_direction_for_piece(piece, row_dirs[dir], col_dirs[dir])) {
                continue;
            }

            if (variant.kings_can_fly && piece.piece_type == DraughtsPieceType.KING) {
                // Flying kings can move multiple squares
                generate_flying_moves(state, piece, row_dirs[dir], col_dirs[dir], moves);
            } else {
                // Regular pieces and non-flying kings move one square
                generate_short_range_move(state, piece, row_dirs[dir], col_dirs[dir], moves);
            }
        }
    }

    private bool is_valid_direction_for_piece(GamePiece piece, int row_dir, int col_dir) {
        if (piece.piece_type == DraughtsPieceType.KING) {
            return true; // Kings can move in all diagonal directions
        }

        // For regular pieces, check if forward movement only
        bool is_forward = false;
        if (piece.color == PieceColor.RED) {
            is_forward = row_dir < 0; // Red moves toward black side (decreasing row numbers)
        } else {
            is_forward = row_dir > 0; // Black moves toward red side (increasing row numbers)
        }

        return is_forward; // Regular pieces can only move forward in simple moves
    }

    private bool is_valid_capture_direction_for_piece(GamePiece piece, int row_dir, int col_dir) {
        if (piece.piece_type == DraughtsPieceType.KING) {
            return true; // Kings can capture in all diagonal directions
        }

        // For regular pieces, check capture rules
        if (variant.men_can_capture_backwards) {
            return true; // Can capture in any diagonal direction
        }

        // Only forward captures allowed
        bool is_forward = false;
        if (piece.color == PieceColor.RED) {
            is_forward = row_dir < 0; // Red moves toward black side (decreasing row numbers)
        } else {
            is_forward = row_dir > 0; // Black moves toward red side (increasing row numbers)
        }

        return is_forward;
    }

    private void generate_flying_captures(DraughtsGameState state, GamePiece piece, int row_dir, int col_dir, Gee.ArrayList<DraughtsMove> moves) {
        if (!is_valid_capture_direction_for_piece(piece, row_dir, col_dir)) {
            return;
        }

        logger.debug("FlyingCapture K@(%d,%d) dir(%d,%d):", piece.position.row, piece.position.col, row_dir, col_dir);

        // Look for pieces to capture along this direction
        for (int distance = 1; distance < variant.board_size; distance++) {
            var check_pos = new BoardPosition(
                piece.position.row + row_dir * distance,
                piece.position.col + col_dir * distance,
                variant.board_size
            );

            if (!is_position_on_board(check_pos)) break;

            var piece_at_pos = state.get_piece_at(check_pos);

            if (piece_at_pos == null) {
                // Empty square, continue searching
                continue;
            } else if (piece_at_pos.color == piece.color) {
                // Own piece blocks further movement
                logger.debug(" own@(%d,%d)", check_pos.row, check_pos.col);
                break;
            } else {
                // Found opponent piece, check if we can capture it
                logger.debug(" opp@(%d,%d)", check_pos.row, check_pos.col);

                // Look for empty landing squares beyond this piece
                for (int landing_distance = distance + 1; landing_distance < variant.board_size; landing_distance++) {
                    var landing_pos = new BoardPosition(
                        piece.position.row + row_dir * landing_distance,
                        piece.position.col + col_dir * landing_distance,
                        variant.board_size
                    );

                    if (!is_position_on_board(landing_pos)) break;

                    var piece_at_landing = state.get_piece_at(landing_pos);
                    if (piece_at_landing != null) {
                        // Landing square occupied, can't land here
                        logger.debug(" land-occ@(%d,%d)", landing_pos.row, landing_pos.col);
                        break;
                    } else {
                        // Found valid landing square, create capture move
                        logger.debug(" land@(%d,%d)", landing_pos.row, landing_pos.col);

                        var captured_pieces = find_captured_pieces(state, piece.position, landing_pos);
                        if (captured_pieces.size > 0) {
                            // Validate that all captured pieces are opponents
                            bool valid_capture = true;
                            foreach (var captured_piece in captured_pieces) {
                                if (captured_piece.color == piece.color) {
                                    logger.debug(" !own@(%d,%d)", captured_piece.position.row, captured_piece.position.col);
                                    valid_capture = false;
                                    break;
                                }
                            }

                            if (valid_capture) {
                                int[] captured_ids = new int[captured_pieces.size];
                                for (int i = 0; i < captured_pieces.size; i++) {
                                    captured_ids[i] = captured_pieces[i].id;
                                    logger.debug(" cap%d@(%d,%d)", captured_pieces[i].id, captured_pieces[i].position.row, captured_pieces[i].position.col);
                                }

                                var move = new DraughtsMove.with_captures(piece.id, piece.position, landing_pos, captured_ids);
                                if (should_promote_piece(piece, landing_pos)) {
                                    move.promoted = true;
                                }
                                logger.debug(" +move");
                                moves.add(move);
                            }
                        }
                    }
                }

                // After finding an opponent piece, we can't jump over it to capture other pieces
                break;
            }
        }
    }

    private void generate_short_range_capture(DraughtsGameState state, GamePiece piece, int row_dir, int col_dir, Gee.ArrayList<DraughtsMove> moves) {
        if (!is_valid_capture_direction_for_piece(piece, row_dir, col_dir)) {
            return;
        }

        var target_pos = new BoardPosition(
            piece.position.row + row_dir * 2,
            piece.position.col + col_dir * 2,
            variant.board_size
        );

        if (is_position_on_board(target_pos)) {
            // Find captured pieces for this move
            var captured_pieces = find_captured_pieces(state, piece.position, target_pos);
            int[] captured_ids = new int[captured_pieces.size];
            for (int i = 0; i < captured_pieces.size; i++) {
                captured_ids[i] = captured_pieces[i].id;
            }

            var move = new DraughtsMove.with_captures(piece.id, piece.position, target_pos, captured_ids);
            if (is_move_legal(state, move)) {
                if (should_promote_piece(piece, target_pos)) {
                    move.promoted = true;
                }
                moves.add(move);
            }
        }
    }

    private void generate_flying_moves(DraughtsGameState state, GamePiece piece, int row_dir, int col_dir, Gee.ArrayList<DraughtsMove> moves) {
        logger.debug("FlyingSimple K@(%d,%d) dir(%d,%d):", piece.position.row, piece.position.col, row_dir, col_dir);

        for (int distance = 1; distance < variant.board_size; distance++) {
            var target_pos = new BoardPosition(
                piece.position.row + row_dir * distance,
                piece.position.col + col_dir * distance,
                variant.board_size
            );

            if (!is_position_on_board(target_pos)) {
                logger.debug(" off-board");
                break;
            }

            if (state.get_piece_at(target_pos) != null) {
                logger.debug(" blocked");
                break;
            }

            var move = new DraughtsMove(piece.id, piece.position, target_pos, MoveType.SIMPLE);
            moves.add(move);
            logger.debug(" +%d@(%d,%d)", distance, target_pos.row, target_pos.col);
        }
        logger.debug("");
    }

    private void generate_short_range_move(DraughtsGameState state, GamePiece piece, int row_dir, int col_dir, Gee.ArrayList<DraughtsMove> moves) {
        var target_pos = new BoardPosition(
            piece.position.row + row_dir,
            piece.position.col + col_dir,
            variant.board_size
        );

        if (is_position_on_board(target_pos) && state.get_piece_at(target_pos) == null) {
            var move = new DraughtsMove(piece.id, piece.position, target_pos, MoveType.SIMPLE);
            if (should_promote_piece(piece, target_pos)) {
                move.promoted = true;
            }
            moves.add(move);
        }
    }

    private DraughtsMove[] filter_captures_by_priority(DraughtsGameState state, Gee.ArrayList<DraughtsMove> captures) {
        // Apply capture priority rules based on variant configuration
        switch (variant.capture_priority) {
            case CapturePriority.MOST_PIECES:
                return filter_by_most_captures(state, captures);
            case CapturePriority.LONGEST_SEQUENCE:
                return filter_by_longest_sequence(captures);
            case CapturePriority.CHOICE:
            default:
                return captures.to_array();
        }
    }

    private DraughtsMove[] filter_by_most_captures(DraughtsGameState state, Gee.ArrayList<DraughtsMove> captures) {
        // Find moves that capture the most pieces
        int max_captures = 0;
        foreach (var move in captures) {
            var captured = find_captured_pieces(state, move.from_position, move.to_position);
            max_captures = int.max(max_captures, captured.size);
        }

        var best_moves = new Gee.ArrayList<DraughtsMove>();
        foreach (var move in captures) {
            var captured = find_captured_pieces(state, move.from_position, move.to_position);
            if (captured.size == max_captures) {
                best_moves.add(move);
            }
        }

        return best_moves.to_array();
    }

    private DraughtsMove[] filter_by_longest_sequence(Gee.ArrayList<DraughtsMove> captures) {
        // For now, just return all captures - implementing full sequence analysis
        // would require recursive move generation
        return captures.to_array();
    }

    public override DraughtsGameState execute_move(DraughtsGameState state, DraughtsMove move) throws Error {
        if (!is_move_legal(state, move)) {
            throw new Error(Quark.from_string("INVALID_MOVE"), 1, "Move is not legal according to variant rules");
        }

        return state.apply_move(move);
    }

    public override GameStatus check_game_result(DraughtsGameState state) {
        var red_pieces = state.get_pieces_by_color(PieceColor.RED);
        var black_pieces = state.get_pieces_by_color(PieceColor.BLACK);

        // Check for piece elimination
        if (red_pieces.size == 0) return GameStatus.BLACK_WINS;
        if (black_pieces.size == 0) return GameStatus.RED_WINS;

        // Check for no legal moves (stalemate = loss in draughts)
        var legal_moves = generate_legal_moves(state);
        if (legal_moves.length == 0) {
            return state.active_player == PieceColor.RED ? GameStatus.BLACK_WINS : GameStatus.RED_WINS;
        }

        return GameStatus.IN_PROGRESS;
    }

    public override DrawReason? check_draw_conditions(DraughtsGameState state, DraughtsMove[] move_history) {
        logger.debug("DRAW CHECK: R=%d B=%d moves=%d",
              state.get_pieces_by_color(PieceColor.RED).size,
              state.get_pieces_by_color(PieceColor.BLACK).size,
              move_history.length);

        // Check for insufficient material (king vs king)
        var red_pieces = state.get_pieces_by_color(PieceColor.RED);
        var black_pieces = state.get_pieces_by_color(PieceColor.BLACK);

        if (red_pieces.size == 1 && black_pieces.size == 1) {
            var red_piece = red_pieces[0];
            var black_piece = black_pieces[0];

            logger.debug("DRAW CHECK: 1v1 - R=%s B=%s flying=%s",
                  red_piece.piece_type.to_string(),
                  black_piece.piece_type.to_string(),
                  variant.kings_can_fly.to_string());

            // Both are kings - check variant-specific insufficient material rules
            if (red_piece.piece_type == DraughtsPieceType.KING &&
                black_piece.piece_type == DraughtsPieceType.KING) {

                // Most draughts variants do NOT have automatic insufficient material draws
                // Only American Checkers has this rule, and even then it's not automatic
                switch (variant.variant) {
                    case DraughtsVariant.AMERICAN:
                        // American Checkers: King vs King is theoretically drawn but not automatic
                        // Let the move limit decide (40 moves rule)
                        logger.debug("AMERICAN: King vs King - using move limit");
                        break;

                    case DraughtsVariant.INTERNATIONAL:
                    case DraughtsVariant.RUSSIAN:
                    case DraughtsVariant.BRAZILIAN:
                    default:
                        // These variants use move counting rules, not insufficient material
                        logger.debug("VARIANT %s: King vs King - using move limit (%d)",
                              variant.variant.to_string(), get_draw_move_limit(state));
                        break;
                }
            }
        }

        // Apply variant-specific draw rules based on move count
        int move_limit = get_draw_move_limit(state);

        if (move_history.length >= move_limit * 2) { // * 2 because each "move" is actually a ply
            bool has_recent_capture = false;
            int check_moves = move_limit;

            for (int i = move_history.length - check_moves; i < move_history.length; i++) {
                if (move_history[i].move_type == MoveType.CAPTURE) {
                    has_recent_capture = true;
                    break;
                }
            }

            if (!has_recent_capture) {
                return DrawReason.TIME_LIMIT;
            }
        }

        return null;
    }

    private int get_draw_move_limit(DraughtsGameState state) {
        // Official draw rules by variant
        switch (variant.variant) {
            case DraughtsVariant.INTERNATIONAL:
                // FMJD Official Rules: 25 moves without capture or pawn movement when only kings remain
                return only_kings_remaining(state) ? 25 : 50;

            case DraughtsVariant.RUSSIAN:
                // Russian Draughts: 15 moves when only kings remain, 30 otherwise
                return only_kings_remaining(state) ? 15 : 30;

            case DraughtsVariant.AMERICAN:
                // American Checkers: No official king-only rule, standard 40 moves
                return 40;

            case DraughtsVariant.BRAZILIAN:
                // Same as International
                return only_kings_remaining(state) ? 25 : 50;

            default:
                // Default to 50 moves standard, 25 for king endgames
                return only_kings_remaining(state) ? 25 : 50;
        }
    }

    private bool only_kings_remaining(DraughtsGameState state) {
        var red_pieces = state.get_pieces_by_color(PieceColor.RED);
        var black_pieces = state.get_pieces_by_color(PieceColor.BLACK);

        // Check if all pieces are kings
        foreach (var piece in red_pieces) {
            if (piece.piece_type != DraughtsPieceType.KING) {
                return false;
            }
        }

        foreach (var piece in black_pieces) {
            if (piece.piece_type != DraughtsPieceType.KING) {
                return false;
            }
        }

        return true;
    }
}