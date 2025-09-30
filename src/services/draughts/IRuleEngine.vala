/**
 * IRuleEngine.vala
 *
 * Interface for draughts rule engine implementations.
 * Defines the contract that all variant-specific rule engines must implement.
 */

using Draughts;

public interface Draughts.IRuleEngine : Object {

    /**
     * Get the variant configuration this engine implements
     */
    public abstract GameVariant get_variant();

    /**
     * Generate all legal moves for the current player
     * @param state Current game state
     * @return Array of valid DraughtsMove objects, empty if no moves available
     */
    public abstract DraughtsMove[] generate_legal_moves(DraughtsGameState state);

    /**
     * Validate if a specific move is legal in the current position
     * @param state Current game state
     * @param move Proposed move to validate
     * @return true if move is legal, false otherwise
     */
    public abstract bool is_move_legal(DraughtsGameState state, DraughtsMove move);

    /**
     * Execute a move and return the resulting game state
     * @param state Current game state
     * @param move DraughtsMove to execute (must be legal)
     * @return New game state after move execution
     * @throws Error if move is illegal
     */
    public abstract DraughtsGameState execute_move(DraughtsGameState state, DraughtsMove move) throws Error;

    /**
     * Check if the current position is a winning position
     * @param state Game state to evaluate
     * @return GameStatus indicating current game result
     */
    public abstract GameStatus check_game_result(DraughtsGameState state);

    /**
     * Detect draw conditions specific to this variant
     * @param state Current game state
     * @param move_history Array of recent moves for repetition detection
     * @return DrawReason or null if no draw
     */
    public abstract DrawReason? check_draw_conditions(DraughtsGameState state, DraughtsMove[] move_history);
}