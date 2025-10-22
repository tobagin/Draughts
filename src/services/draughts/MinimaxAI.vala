/**
 * MinimaxAI.vala
 *
 * Advanced AI engine for Draughts using minimax algorithm with alpha-beta pruning.
 *
 * Features:
 * - Minimax algorithm with alpha-beta pruning
 * - Transposition table for position caching
 * - 10 difficulty levels (BEGINNER to GRANDMASTER)
 * - Move ordering for better pruning efficiency
 * - Time limit handling
 * - Cancellation support for responsive UI
 */

using Draughts;

public class Draughts.MinimaxAI : Object, IAIPlayer {

    private AIDifficulty difficulty;
    private PositionEvaluator evaluator;
    private bool is_calculating;
    private bool should_cancel;
    private int64 start_time_ms;
    private uint time_limit_ms;

    // Transposition table for position caching
    private Gee.HashMap<string, TranspositionEntry?> transposition_table;
    private const int MAX_TRANSPOSITION_TABLE_SIZE = 100000;

    // Statistics for debugging/analysis
    private int nodes_evaluated;
    private int transposition_hits;

    /**
     * Constructor
     */
    public MinimaxAI(AIDifficulty difficulty = AIDifficulty.MEDIUM) {
        this.difficulty = difficulty;
        this.evaluator = new PositionEvaluator();
        this.is_calculating = false;
        this.should_cancel = false;
        this.transposition_table = new Gee.HashMap<string, TranspositionEntry?>();
    }

    /**
     * Get the current difficulty level
     */
    public int get_difficulty_level() {
        return (int) difficulty;
    }

    /**
     * Calculate the best move for the current position
     */
    public DraughtsMove? calculate_best_move(
        DraughtsGameState state,
        IRuleEngine rule_engine,
        uint time_limit_ms
    ) {
        this.is_calculating = true;
        this.should_cancel = false;
        this.start_time_ms = GLib.get_monotonic_time() / 1000;
        this.time_limit_ms = time_limit_ms;
        this.nodes_evaluated = 0;
        this.transposition_hits = 0;

        var legal_moves = rule_engine.generate_legal_moves(state);

        if (legal_moves.length == 0) {
            this.is_calculating = false;
            return null;
        }

        if (legal_moves.length == 1) {
            // Only one legal move, no need to search
            this.is_calculating = false;
            return legal_moves[0];
        }

        DraughtsMove? best_move = select_ai_move_by_difficulty(
            legal_moves,
            state,
            rule_engine
        );

        debug("AI evaluated %d nodes, %d transposition hits",
              nodes_evaluated, transposition_hits);

        this.is_calculating = false;
        return best_move;
    }

    /**
     * Evaluate a position from the AI's perspective
     */
    public double evaluate_position(DraughtsGameState state, PieceColor color) {
        return evaluator.evaluate(state, color);
    }

    /**
     * Check if the AI is currently thinking
     */
    public bool is_thinking() {
        return is_calculating;
    }

    /**
     * Cancel the current calculation
     */
    public void cancel_calculation() {
        this.should_cancel = true;
    }

    /**
     * Select move based on difficulty level
     */
    private DraughtsMove select_ai_move_by_difficulty(
        DraughtsMove[] legal_moves,
        DraughtsGameState state,
        IRuleEngine rule_engine
    ) {
        switch (difficulty) {
            case AIDifficulty.BEGINNER:
                return select_beginner_move(legal_moves);

            case AIDifficulty.EASY:
                return select_easy_move(legal_moves, state);

            case AIDifficulty.MEDIUM:
                return select_medium_move(legal_moves, state);

            case AIDifficulty.NOVICE:
                return select_novice_move(legal_moves, state);

            case AIDifficulty.INTERMEDIATE:
                return select_search_move(legal_moves, state, rule_engine, 1);

            case AIDifficulty.HARD:
                return select_search_move(legal_moves, state, rule_engine, 2);

            case AIDifficulty.ADVANCED:
                return select_search_move(legal_moves, state, rule_engine, 3);

            case AIDifficulty.EXPERT:
                return select_search_move(legal_moves, state, rule_engine, 4);

            case AIDifficulty.MASTER:
                return select_search_move(legal_moves, state, rule_engine, 5);

            case AIDifficulty.GRANDMASTER:
                return select_search_move(legal_moves, state, rule_engine, 7);

            default:
                return select_medium_move(legal_moves, state);
        }
    }

    /**
     * BEGINNER (Level 1): Completely random moves
     */
    private DraughtsMove select_beginner_move(DraughtsMove[] legal_moves) {
        var random_index = Random.int_range(0, legal_moves.length);
        return legal_moves[random_index];
    }

    /**
     * EASY (Level 2): Prefer captures if available, otherwise random
     */
    private DraughtsMove select_easy_move(DraughtsMove[] legal_moves, DraughtsGameState state) {
        var capture_moves = new Gee.ArrayList<DraughtsMove>();

        foreach (var move in legal_moves) {
            if (move.is_capture()) {
                capture_moves.add(move);
            }
        }

        if (capture_moves.size > 0) {
            var random_index = Random.int_range(0, capture_moves.size);
            return capture_moves[random_index];
        } else {
            return select_beginner_move(legal_moves);
        }
    }

    /**
     * MEDIUM (Level 3): Prefer captures, avoid obvious traps
     */
    private DraughtsMove select_medium_move(DraughtsMove[] legal_moves, DraughtsGameState state) {
        var capture_moves = new Gee.ArrayList<DraughtsMove>();
        var safe_moves = new Gee.ArrayList<DraughtsMove>();
        int board_size = state.variant.board_size;

        foreach (var move in legal_moves) {
            if (move.is_capture()) {
                capture_moves.add(move);
            }

            // Simple safety check: avoid moves to edge if possible
            if (move.to_position.row != 0 && move.to_position.row != board_size - 1 &&
                move.to_position.col != 0 && move.to_position.col != board_size - 1) {
                safe_moves.add(move);
            }
        }

        // Prefer captures first
        if (capture_moves.size > 0) {
            var random_index = Random.int_range(0, capture_moves.size);
            return capture_moves[random_index];
        }

        // Then prefer safe moves
        if (safe_moves.size > 0) {
            var random_index = Random.int_range(0, safe_moves.size);
            return safe_moves[random_index];
        }

        return select_beginner_move(legal_moves);
    }

    /**
     * NOVICE (Level 4): Basic positional awareness
     */
    private DraughtsMove select_novice_move(DraughtsMove[] legal_moves, DraughtsGameState state) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();
        int board_size = state.variant.board_size;

        foreach (var move in legal_moves) {
            int score = 0;

            // Prioritize captures
            if (move.is_capture()) {
                score += 100;
            }

            // Advance pieces toward promotion
            if (state.active_player == PieceColor.RED) {
                if (move.to_position.row > move.from_position.row) {
                    score += 10;
                }
            } else {
                if (move.to_position.row < move.from_position.row) {
                    score += 10;
                }
            }

            // Prefer center control
            var center_distance = calculate_center_distance(move.to_position, board_size);
            score += (8 - center_distance);

            scored_moves.add(ScoredMove() { move = move, score = score });
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * INTERMEDIATE to GRANDMASTER: Use minimax search with varying depth
     */
    private DraughtsMove select_search_move(
        DraughtsMove[] legal_moves,
        DraughtsGameState state,
        IRuleEngine rule_engine,
        int depth
    ) {
        var scored_moves = new Gee.ArrayList<ScoredMove?>();
        var ai_color = state.active_player;

        // Order moves for better alpha-beta pruning
        var ordered_moves = order_moves(legal_moves, state);

        int alpha = int.MIN;
        int beta = int.MAX;

        foreach (var move in ordered_moves) {
            if (should_cancel || has_exceeded_time_limit()) {
                break;
            }

            var new_state = state.apply_move(move);
            int score = -minimax(
                new_state,
                rule_engine,
                depth - 1,
                -beta,
                -alpha,
                ai_color
            );

            scored_moves.add(ScoredMove() { move = move, score = score });

            alpha = int.max(alpha, score);
        }

        return select_best_scored_move(scored_moves);
    }

    /**
     * Minimax algorithm with alpha-beta pruning and transposition table
     */
    private int minimax(
        DraughtsGameState state,
        IRuleEngine rule_engine,
        int depth,
        int alpha,
        int beta,
        PieceColor ai_color
    ) {
        nodes_evaluated++;

        // Check time limit and cancellation
        if (should_cancel || has_exceeded_time_limit()) {
            return 0;
        }

        // Check transposition table
        string state_hash = hash_state(state);
        if (transposition_table.has_key(state_hash)) {
            var entry = transposition_table[state_hash];
            if (entry.depth >= depth) {
                transposition_hits++;
                return entry.score;
            }
        }

        // Terminal conditions
        if (depth == 0 || state.is_game_over()) {
            int score = (int) evaluator.evaluate(state, ai_color);
            cache_position(state_hash, score, depth);
            return score;
        }

        var legal_moves = rule_engine.generate_legal_moves(state);

        if (legal_moves.length == 0) {
            // No moves available - game over
            int score = (int) evaluator.evaluate(state, ai_color);
            cache_position(state_hash, score, depth);
            return score;
        }

        // Order moves for better pruning
        var ordered_moves = order_moves(legal_moves, state);

        int max_score = int.MIN;

        foreach (var move in ordered_moves) {
            if (should_cancel || has_exceeded_time_limit()) {
                break;
            }

            var new_state = state.apply_move(move);
            int score = -minimax(
                new_state,
                rule_engine,
                depth - 1,
                -beta,
                -alpha,
                ai_color
            );

            max_score = int.max(max_score, score);
            alpha = int.max(alpha, score);

            if (alpha >= beta) {
                break; // Alpha-beta pruning
            }
        }

        cache_position(state_hash, max_score, depth);
        return max_score;
    }

    /**
     * Order moves to improve alpha-beta pruning efficiency
     * Captures and promotions are searched first
     */
    private DraughtsMove[] order_moves(DraughtsMove[] moves, DraughtsGameState state) {
        var move_list = new Gee.ArrayList<DraughtsMove>();
        foreach (var move in moves) {
            move_list.add(move);
        }

        move_list.sort((a, b) => {
            int score_a = score_move_for_ordering(a);
            int score_b = score_move_for_ordering(b);
            return score_b - score_a; // Higher scores first
        });

        DraughtsMove[] ordered = new DraughtsMove[move_list.size];
        for (int i = 0; i < move_list.size; i++) {
            ordered[i] = move_list[i];
        }

        return ordered;
    }

    /**
     * Score a move for move ordering (not evaluation)
     */
    private int score_move_for_ordering(DraughtsMove move) {
        int score = 0;

        if (move.is_capture()) {
            score += 1000;
            // Multi-captures are even better
            if (move.captured_positions != null) {
                score += move.captured_positions.length * 100;
            }
        }

        if (move.promoted) {
            score += 500;
        }

        return score;
    }

    /**
     * Helper struct for scoring moves
     */
    private struct ScoredMove {
        DraughtsMove move;
        int score;
    }

    /**
     * Transposition table entry
     */
    private struct TranspositionEntry {
        int score;
        int depth;
    }

    /**
     * Calculate distance from center of board
     */
    private int calculate_center_distance(BoardPosition pos, int board_size) {
        int center = board_size / 2;
        int dx = (pos.row - center).abs();
        int dy = (pos.col - center).abs();
        return dx + dy;
    }

    /**
     * Select the best move from scored moves (with some randomness for same scores)
     */
    private DraughtsMove select_best_scored_move(Gee.ArrayList<ScoredMove?> scored_moves) {
        if (scored_moves.size == 0) {
            assert_not_reached();
        }

        // Find the highest score
        int max_score = int.MIN;
        foreach (var scored_move in scored_moves) {
            if (scored_move.score > max_score) {
                max_score = scored_move.score;
            }
        }

        // Collect all moves with the highest score
        var best_moves = new Gee.ArrayList<DraughtsMove>();
        foreach (var scored_move in scored_moves) {
            if (scored_move.score == max_score) {
                best_moves.add(scored_move.move);
            }
        }

        // Randomly select among the best moves to add some variety
        var random_index = Random.int_range(0, best_moves.size);
        return best_moves[random_index];
    }

    /**
     * Create a hash of the game state for transposition table
     */
    private string hash_state(DraughtsGameState state) {
        var builder = new StringBuilder();
        builder.append(@"$(state.active_player):");

        foreach (var piece in state.pieces) {
            builder.append(@"$(piece.position.row),$(piece.position.col),");
            builder.append(@"$(piece.color),$(piece.piece_type);");
        }

        return builder.str;
    }

    /**
     * Cache a position evaluation in the transposition table
     */
    private void cache_position(string state_hash, int score, int depth) {
        // Limit table size to prevent memory bloat
        if (transposition_table.size >= MAX_TRANSPOSITION_TABLE_SIZE) {
            transposition_table.clear();
        }

        transposition_table[state_hash] = TranspositionEntry() {
            score = score,
            depth = depth
        };
    }

    /**
     * Check if time limit has been exceeded
     */
    private bool has_exceeded_time_limit() {
        if (time_limit_ms == 0) {
            return false; // No time limit
        }

        int64 current_time_ms = GLib.get_monotonic_time() / 1000;
        int64 elapsed_ms = current_time_ms - start_time_ms;

        return elapsed_ms >= time_limit_ms;
    }
}
