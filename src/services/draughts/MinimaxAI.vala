using Draughts;
public class Draughts.MinimaxAI : Object, IAIPlayer {
    public int get_difficulty_level() { return 1; }
    public DraughtsMove? calculate_best_move(DraughtsGameState state, IRuleEngine rule_engine, uint time_limit_ms) { return null; }
    public double evaluate_position(DraughtsGameState state, PieceColor color) { return 0.0; }
    public bool is_thinking() { return false; }
    public void cancel_calculation() { }
}