/**
 * Player.vala
 *
 * Represents a player in a draughts game.
 * Handles both human and AI players with their specific configurations.
 */

using Draughts;

public class Draughts.GamePlayer : Object {
    public string id { get; private set; }
    public PlayerType player_type { get; private set; }
    public string name { get; set; }
    public AIDifficulty? ai_difficulty;
    public PieceColor color { get; set; }
    public TimeSpan time_used { get; set; }

    /**
     * Create a human player
     */
    public GamePlayer.human(string id, string name, PieceColor color) {
        this.id = id;
        this.player_type = PlayerType.HUMAN;
        this.name = name;
        this.color = color;
        this.ai_difficulty = null;
        this.time_used = 0;
    }

    /**
     * Create an AI player
     */
    public GamePlayer.ai(string id, string name, PieceColor color, AIDifficulty difficulty) {
        this.id = id;
        this.player_type = PlayerType.AI;
        this.name = name;
        this.color = color;
        this.ai_difficulty = difficulty;
        this.time_used = 0;
    }

    /**
     * Create a network remote player
     */
    public GamePlayer.network_remote(string id, string name, PieceColor color) {
        this.id = id;
        this.player_type = PlayerType.NETWORK_REMOTE;
        this.name = name;
        this.color = color;
        this.ai_difficulty = null;
        this.time_used = 0;
    }

    /**
     * Check if this is a human player
     */
    public bool is_human() {
        return player_type == PlayerType.HUMAN;
    }

    /**
     * Check if this is an AI player
     */
    public bool is_ai() {
        return player_type == PlayerType.AI;
    }

    /**
     * Check if this is a network remote player
     */
    public bool is_network_remote() {
        return player_type == PlayerType.NETWORK_REMOTE;
    }

    /**
     * Get AI difficulty level (for AI players only)
     */
    public int get_ai_level() {
        if (!is_ai() || ai_difficulty == null) {
            return 0;
        }
        return (int) ai_difficulty;
    }

    /**
     * Set AI difficulty (for AI players only)
     */
    public void set_ai_difficulty(AIDifficulty difficulty) {
        if (is_ai()) {
            this.ai_difficulty = difficulty;
        }
    }

    /**
     * Add time used by this player
     */
    public void add_time_used(TimeSpan time) {
        time_used += time;
    }

    /**
     * Reset time used
     */
    public void reset_time_used() {
        time_used = 0;
    }

    /**
     * Get formatted time used string
     */
    public string get_time_used_string() {
        int total_seconds = (int) (time_used / TimeSpan.SECOND);
        int minutes = total_seconds / 60;
        int seconds = total_seconds % 60;

        if (minutes > 0) {
            return "%d:%02d".printf(minutes, seconds);
        } else {
            return "%ds".printf(seconds);
        }
    }

    /**
     * Check if this player equals another player
     */
    public bool equals(GamePlayer other) {
        return this.id == other.id &&
               this.player_type == other.player_type &&
               this.color == other.color;
    }

    /**
     * Create a copy of this player
     */
    public GamePlayer clone() {
        GamePlayer copy;

        if (is_ai()) {
            copy = new GamePlayer.ai(id, name, color, ai_difficulty);
        } else if (is_network_remote()) {
            copy = new GamePlayer.network_remote(id, name, color);
        } else {
            copy = new GamePlayer.human(id, name, color);
        }

        copy.time_used = this.time_used;
        return copy;
    }

    /**
     * Get string representation
     */
    public string to_string() {
        string type_str;
        if (is_ai()) {
            type_str = @"AI ($(ai_difficulty))";
        } else if (is_network_remote()) {
            type_str = "Network";
        } else {
            type_str = "Human";
        }
        return @"$name ($type_str, $(color))";
    }

    /**
     * Get display name with type info
     */
    public string get_display_name() {
        if (is_ai()) {
            return @"$name ($(ai_difficulty))";
        } else if (is_network_remote()) {
            return @"$name (Online)";
        } else {
            return name;
        }
    }

    /**
     * Validate player configuration
     */
    public bool is_valid() {
        // Name cannot be empty
        if (name == null || name.strip() == "") {
            return false;
        }

        // AI players must have difficulty set
        if (is_ai() && ai_difficulty == null) {
            return false;
        }

        // Human players should not have AI difficulty
        if (is_human() && ai_difficulty != null) {
            return false;
        }

        return true;
    }

    /**
     * Get player statistics summary
     */
    public PlayerStats get_statistics() {
        return new PlayerStats(
            name,
            player_type,
            color,
            time_used,
            ai_difficulty
        );
    }

    /**
     * Create default human player
     */
    public static GamePlayer create_default_human(PieceColor color) {
        string name = (color == PieceColor.RED) ? "Red Player" : "Black Player";
        string id = @"human_$(color.to_string().down())";
        return new GamePlayer.human(id, name, color);
    }

    /**
     * Create default AI player
     */
    public static GamePlayer create_default_ai(PieceColor color, AIDifficulty difficulty = AIDifficulty.INTERMEDIATE) {
        string name = @"AI $(difficulty)";
        string id = @"ai_$(color.to_string().down())_$(difficulty)";
        return new GamePlayer.ai(id, name, color, difficulty);
    }
}

/**
 * Player statistics structure
 */
public class PlayerStats : Object {
    public string name { get; private set; }
    public PlayerType player_type { get; private set; }
    public PieceColor color { get; private set; }
    public TimeSpan time_used { get; private set; }
    public AIDifficulty? difficulty;

    public PlayerStats(string name, PlayerType player_type, PieceColor color, TimeSpan time_used, AIDifficulty? ai_difficulty) {
        this.name = name;
        this.player_type = player_type;
        this.color = color;
        this.time_used = time_used;
        this.difficulty = ai_difficulty;
    }

    public string to_string() {
        var str = @"$name ($(player_type), $(color))";
        if (player_type == PlayerType.AI && difficulty != null) {
            str += @" - Level $(difficulty)";
        }
        str += @" - Time: $(format_time(time_used))";
        return str;
    }

    private string format_time(TimeSpan time) {
        int total_seconds = (int) (time / TimeSpan.SECOND);
        int minutes = total_seconds / 60;
        int seconds = total_seconds % 60;
        return "%d:%02d".printf(minutes, seconds);
    }
}