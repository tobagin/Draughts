using Draughts;
public class Draughts.AIDifficultyManager : Object {
    public IAIPlayer create_ai_player(AIDifficulty difficulty) { return new MinimaxAI(); }
}