using Draughts;

/**
 * GameController manages draughts game sessions and coordinates
 * between the game engine and the UI.
 */
public class Draughts.GameController : Object, IGameController {
    private Game? current_game;
    private bool is_paused = false;
    private SoundManager sound_manager;

    public GameController() {
        sound_manager = SoundManager.get_instance();
    }

    /**
     * Start a new draughts game with the specified variant and players
     */
    public Game start_new_game(GameVariant variant, GamePlayer red_player, GamePlayer black_player, Timer? timer_config) {
        current_game = new Game("game_" + new DateTime.now_utc().to_unix().to_string(), variant, red_player, black_player);
        // Clear move history when starting a new game
        current_game.clear_move_history();
        is_paused = false;

        // Play game start sound
        sound_manager.play_sound(SoundEffect.GAME_START);

        return current_game;
    }

    /**
     * Make a move in the current game
     */
    public bool make_move(DraughtsMove move) {
        if (current_game == null || is_paused) {
            return false;
        }

        // Delegate to the Game's make_move method which handles
        // move execution, timers, and state management
        return current_game.make_move(move);
    }

    /**
     * Undo the last move
     */
    public bool undo_last_move() {
        if (current_game == null || is_paused) {
            return false;
        }

        return current_game.undo_last_move();
    }

    /**
     * Redo the last undone move
     */
    public bool redo_last_move() {
        if (current_game == null || is_paused) {
            return false;
        }

        return current_game.redo_last_move();
    }

    /**
     * Check if undo is available
     */
    public bool can_undo() {
        if (current_game == null) {
            return false;
        }

        return current_game.can_undo();
    }

    /**
     * Check if redo is available
     */
    public bool can_redo() {
        if (current_game == null) {
            return false;
        }

        return current_game.can_redo();
    }

    /**
     * Get the current game state
     */
    public DraughtsGameState get_current_state() {
        if (current_game != null) {
            return current_game.current_state;
        }

        // Return empty state if no game is active
        return new DraughtsGameState(new Gee.ArrayList<GamePiece>(), PieceColor.RED, 8);
    }

    /**
     * Get the current game instance
     */
    public Game get_current_game() {
        if (current_game != null) {
            return current_game;
        }

        // Return a default game if none exists
        return new Game("default", new GameVariant(DraughtsVariant.AMERICAN),
                       GamePlayer.create_default_human(PieceColor.RED),
                       GamePlayer.create_default_human(PieceColor.BLACK));
    }

    /**
     * Pause or unpause the current game
     */
    public void set_game_paused(bool paused) {
        is_paused = paused;
    }

    /**
     * Check if a move is legal in the current game state
     */
    public bool is_move_legal(DraughtsMove move) {
        if (current_game == null) {
            return false;
        }

        // Would need to implement move validation logic
        return false;
    }
}