/**
 * AIDifficultyManager.vala
 *
 * Manages AI player creation with appropriate difficulty levels.
 */

using Draughts;

public class Draughts.AIDifficultyManager : Object {

    /**
     * Creates an AI player with the specified difficulty level.
     *
     * @param difficulty The difficulty level for the AI
     * @return An AI player configured for the specified difficulty
     */
    public IAIPlayer create_ai_player(AIDifficulty difficulty) {
        return new MinimaxAI(difficulty);
    }

    /**
     * Gets a human-readable description of what each difficulty level does.
     *
     * @param difficulty The difficulty level
     * @return A description of the AI's behavior at this level
     */
    public string get_difficulty_description(AIDifficulty difficulty) {
        switch (difficulty) {
            case AIDifficulty.BEGINNER:
                return "Level 1: Random moves";

            case AIDifficulty.EASY:
                return "Level 2: Prefers captures";

            case AIDifficulty.MEDIUM:
                return "Level 3: Avoids obvious mistakes";

            case AIDifficulty.NOVICE:
                return "Level 4: Basic positional play";

            case AIDifficulty.INTERMEDIATE:
                return "Level 5: Looks ahead 1 move";

            case AIDifficulty.HARD:
                return "Level 6: Looks ahead 2 moves";

            case AIDifficulty.ADVANCED:
                return "Level 7: Looks ahead 3 moves";

            case AIDifficulty.EXPERT:
                return "Level 8: Looks ahead 4 moves";

            case AIDifficulty.MASTER:
                return "Level 9: Looks ahead 5 moves";

            case AIDifficulty.GRANDMASTER:
                return "Level 10: Looks ahead 7+ moves";

            default:
                return "Unknown difficulty";
        }
    }

    /**
     * Gets the recommended time limit for a given difficulty level.
     * Returns time in milliseconds.
     *
     * @param difficulty The difficulty level
     * @return Recommended time limit in milliseconds
     */
    public uint get_recommended_time_limit(AIDifficulty difficulty) {
        switch (difficulty) {
            case AIDifficulty.BEGINNER:
            case AIDifficulty.EASY:
            case AIDifficulty.MEDIUM:
            case AIDifficulty.NOVICE:
                return 100; // Very fast for simple levels

            case AIDifficulty.INTERMEDIATE:
                return 500; // 0.5 seconds

            case AIDifficulty.HARD:
                return 1000; // 1 second

            case AIDifficulty.ADVANCED:
                return 2000; // 2 seconds

            case AIDifficulty.EXPERT:
                return 3000; // 3 seconds

            case AIDifficulty.MASTER:
                return 5000; // 5 seconds

            case AIDifficulty.GRANDMASTER:
                return 10000; // 10 seconds

            default:
                return 1000;
        }
    }
}
