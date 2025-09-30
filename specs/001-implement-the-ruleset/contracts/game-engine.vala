/**
 * Game Engine Contract - Core game logic interfaces
 *
 * This contract defines the main interfaces for the draughts game engine,
 * covering rule validation, move generation, and game state management.
 */

namespace Draughts.Contracts {

    /**
     * Primary interface for variant-specific rule implementations
     */
    public interface IRuleEngine : Object {
        /**
         * Get the variant configuration this engine implements
         */
        public abstract GameVariant get_variant();

        /**
         * Generate all legal moves for the current player
         * @param state Current game state
         * @return Array of valid Move objects, empty if no moves available
         */
        public abstract Move[] generate_legal_moves(GameState state);

        /**
         * Validate if a specific move is legal in the current position
         * @param state Current game state
         * @param move Proposed move to validate
         * @return true if move is legal, false otherwise
         */
        public abstract bool is_move_legal(GameState state, Move move);

        /**
         * Execute a move and return the resulting game state
         * @param state Current game state
         * @param move Move to execute (must be legal)
         * @return New game state after move execution
         * @throws InvalidMoveError if move is illegal
         */
        public abstract GameState execute_move(GameState state, Move move) throws InvalidMoveError;

        /**
         * Check if the current position is a winning position
         * @param state Game state to evaluate
         * @return WIN_RED, WIN_BLACK, DRAW, or IN_PROGRESS
         */
        public abstract GameResult check_game_result(GameState state);

        /**
         * Detect draw conditions specific to this variant
         * @param state Current game state
         * @param move_history Array of recent moves for repetition detection
         * @return DRAW reason or null if no draw
         */
        public abstract DrawReason? check_draw_conditions(GameState state, Move[] move_history);
    }

    /**
     * Interface for AI player implementations
     */
    public interface IAIPlayer : Object {
        /**
         * Get the difficulty level of this AI
         */
        public abstract int get_difficulty_level();

        /**
         * Calculate the best move for the current position
         * @param state Current game state
         * @param rule_engine Rule engine for move validation
         * @param time_limit Maximum calculation time in milliseconds
         * @return Best move found, or null if no legal moves
         */
        public abstract Move? calculate_best_move(
            GameState state,
            IRuleEngine rule_engine,
            uint time_limit_ms
        );

        /**
         * Evaluate a position from the perspective of the specified color
         * @param state Position to evaluate
         * @param color Color to evaluate for (RED or BLACK)
         * @return Evaluation score (positive = good for color, negative = bad)
         */
        public abstract double evaluate_position(GameState state, PieceColor color);

        /**
         * Check if AI is currently calculating
         */
        public abstract bool is_thinking();

        /**
         * Cancel current calculation if in progress
         */
        public abstract void cancel_calculation();
    }

    /**
     * Interface for game session management
     */
    public interface IGameController : Object {
        /**
         * Start a new game with specified configuration
         * @param variant Draughts variant to play
         * @param red_player Red player configuration
         * @param black_player Black player configuration
         * @param timer_config Time control settings, null for untimed
         * @return New Game object
         */
        public abstract Game start_new_game(
            GameVariant variant,
            Player red_player,
            Player black_player,
            TimerConfig? timer_config
        );

        /**
         * Make a move in the current game
         * @param move Move to execute
         * @return true if move was successful, false if illegal
         */
        public abstract bool make_move(Move move);

        /**
         * Undo the last move if possible
         * @return true if undo was successful, false if not possible
         */
        public abstract bool undo_last_move();

        /**
         * Get the current game state
         */
        public abstract GameState get_current_state();

        /**
         * Get the current game instance
         */
        public abstract Game get_current_game();

        /**
         * Pause/resume game timers
         * @param paused true to pause, false to resume
         */
        public abstract void set_game_paused(bool paused);

        /**
         * Check if a move is legal without executing it
         * @param move Move to validate
         * @return true if legal, false otherwise
         */
        public abstract bool is_move_legal(Move move);

        /**
         * Signal emitted when game state changes
         * @param new_state Updated game state
         * @param last_move Move that caused the change, null for new game
         */
        public signal void game_state_changed(GameState new_state, Move? last_move);

        /**
         * Signal emitted when game ends
         * @param result Final game result
         * @param reason Human-readable reason for game end
         */
        public signal void game_finished(GameResult result, string reason);

        /**
         * Signal emitted when timer updates
         * @param red_time_remaining Time left for red player in milliseconds
         * @param black_time_remaining Time left for black player in milliseconds
         */
        public signal void timer_updated(uint64 red_time_remaining, uint64 black_time_remaining);
    }

    /**
     * Interface for board position validation
     */
    public interface IBoardValidator : Object {
        /**
         * Validate that a position is legal on the board
         * @param position Position to check
         * @param board_size Size of the board (8, 10, or 12)
         * @return true if position is valid, false otherwise
         */
        public abstract bool is_position_valid(Position position, int board_size);

        /**
         * Check if a position is on a dark square
         * @param position Position to check
         * @return true if on dark square, false otherwise
         */
        public abstract bool is_dark_square(Position position);

        /**
         * Calculate distance between two positions
         * @param from Starting position
         * @param to Ending position
         * @return Distance in squares
         */
        public abstract int calculate_distance(Position from, Position to);

        /**
         * Get all positions between two points (exclusive)
         * @param from Starting position
         * @param to Ending position
         * @return Array of positions on the path, empty if adjacent or invalid
         */
        public abstract Position[] get_path_between(Position from, Position to);
    }

    /**
     * Error types for game engine operations
     */
    public errordomain GameEngineError {
        INVALID_MOVE,
        INVALID_POSITION,
        GAME_ALREADY_FINISHED,
        NO_MOVES_AVAILABLE,
        TIMER_ERROR,
        RULE_ENGINE_ERROR
    }

    public class InvalidMoveError : GameEngineError {
        public Move attempted_move;
        public string reason;

        public InvalidMoveError.with_details(Move move, string reason) {
            this.attempted_move = move;
            this.reason = reason;
        }
    }
}