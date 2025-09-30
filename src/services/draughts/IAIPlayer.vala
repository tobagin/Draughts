/**
 * IAIPlayer.vala
 *
 * Interface for AI player implementations.
 */

using Draughts;

public interface Draughts.IAIPlayer : Object {
    public abstract int get_difficulty_level();
    public abstract DraughtsMove? calculate_best_move(DraughtsGameState state, IRuleEngine rule_engine, uint time_limit_ms);
    public abstract double evaluate_position(DraughtsGameState state, PieceColor color);
    public abstract bool is_thinking();
    public abstract void cancel_calculation();
}