/**
 * TimerDisplay.vala
 *
 * Timer controller for headerbar subtitle display.
 * Manages game timing without its own UI widgets.
 */

using Draughts;

public class Draughts.TimerDisplay : GLib.Object {
    // Timer state
    private Timer? red_timer;
    private Timer? black_timer;
    private Player current_player = Player.RED;
    private bool timer_enabled = false;
    private int64 game_start_time = 0;
    private uint timer_update_id = 0;

    // Signal for timer updates
    public signal void timer_updated(string subtitle_text);

    public TimerDisplay() {
        start_update_timer();
    }

    /**
     * Set timer configuration
     */
    public void set_timers(Timer? red_timer, Timer? black_timer) {
        this.red_timer = red_timer;
        this.black_timer = black_timer;
        this.timer_enabled = (red_timer != null || black_timer != null);

        update_display();
    }

    /**
     * Set the active player (whose timer is running)
     */
    public void set_active_player(Player player) {
        current_player = player;
        update_display();
    }

    /**
     * Start the game timer
     */
    public void start_game_timer() {
        game_start_time = get_monotonic_time();

        if (red_timer != null) {
            red_timer.start();
        }
        if (black_timer != null) {
            black_timer.start();
        }

        update_display();
    }

    /**
     * Pause all timers
     */
    public void pause_timers() {
        if (red_timer != null) {
            red_timer.pause();
        }
        if (black_timer != null) {
            black_timer.pause();
        }

        update_display();
    }

    /**
     * Resume timers
     */
    public void resume_timers() {
        if (red_timer != null && current_player == Player.RED) {
            red_timer.resume();
        }
        if (black_timer != null && current_player == Player.BLACK) {
            black_timer.resume();
        }

        update_display();
    }

    /**
     * Switch active timer between players
     */
    public void switch_player() {
        if (red_timer != null) {
            red_timer.pause();
        }
        if (black_timer != null) {
            black_timer.pause();
        }

        current_player = (current_player == Player.RED) ? Player.BLACK : Player.RED;

        if (current_player == Player.RED && red_timer != null) {
            red_timer.resume();
        } else if (current_player == Player.BLACK && black_timer != null) {
            black_timer.resume();
        }

        update_display();
    }

    /**
     * Start periodic timer updates
     */
    private void start_update_timer() {
        if (timer_update_id > 0) {
            Source.remove(timer_update_id);
        }

        timer_update_id = Timeout.add(1000, () => {
            update_display();
            return true;
        });
    }

    /**
     * Update the display (emit signal with subtitle text)
     */
    private void update_display() {
        if (!timer_enabled) {
            // No timer - show game variant or nothing
            timer_updated("");
            return;
        }

        string subtitle = "";

        if (red_timer != null && black_timer != null) {
            // Both timers - show current player's time
            var active_timer = (current_player == Player.RED) ? red_timer : black_timer;
            var player_name = (current_player == Player.RED) ? "Red" : "Black";

            subtitle = @"$player_name: $(format_time(active_timer.get_current_time_remaining()))";
        } else if (red_timer != null) {
            subtitle = @"Red: $(format_time(red_timer.get_current_time_remaining()))";
        } else if (black_timer != null) {
            subtitle = @"Black: $(format_time(black_timer.get_current_time_remaining()))";
        }

        timer_updated(subtitle);
    }

    /**
     * Format time as MM:SS
     */
    private string format_time(TimeSpan time_span) {
        int total_seconds = (int)(time_span / TimeSpan.SECOND);
        int minutes = total_seconds / 60;
        int seconds = total_seconds % 60;

        return @"$(minutes):$(seconds.to_string().printf("%02d"))";
    }

    /**
     * Reset timers to initial state
     */
    public void reset_timers() {
        if (red_timer != null) {
            red_timer.reset();
        }
        if (black_timer != null) {
            black_timer.reset();
        }
        current_player = Player.RED;
        update_display();
    }

    /**
     * Cleanup
     */
    ~TimerDisplay() {
        if (timer_update_id > 0) {
            Source.remove(timer_update_id);
        }
    }
}