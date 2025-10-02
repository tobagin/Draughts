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
    private bool red_timer_started = false;
    private bool black_timer_started = false;

    // Signal for timer updates
    public signal void timer_updated(string subtitle_text);
    public signal void dual_timer_updated(string red_time, string black_time);
    public signal void time_expired(Player player);

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
     * Start the game timer (but don't actually start counting until first move)
     */
    public void start_game_timer() {
        game_start_time = get_monotonic_time();
        red_timer_started = false;
        black_timer_started = false;

        // Don't start timers yet - wait for first move of each player
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
        // Start the current player's timer on their first move
        if (current_player == Player.RED && red_timer != null && !red_timer_started) {
            red_timer.start();
            red_timer_started = true;
        } else if (current_player == Player.BLACK && black_timer != null && !black_timer_started) {
            black_timer.start();
            black_timer_started = true;
        }

        // Pause current player's timer and add increment (Fischer mode)
        if (red_timer != null && current_player == Player.RED) {
            red_timer.pause();
            // Add Fischer increment after completing the move
            red_timer.add_increment();
        }
        if (black_timer != null && current_player == Player.BLACK) {
            black_timer.pause();
            // Add Fischer increment after completing the move
            black_timer.add_increment();
        }

        // Switch to the other player
        current_player = (current_player == Player.RED) ? Player.BLACK : Player.RED;

        // Resume the new current player's timer (if they've started)
        if (current_player == Player.RED && red_timer != null && red_timer_started) {
            red_timer.resume();
        } else if (current_player == Player.BLACK && black_timer != null && black_timer_started) {
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
        string subtitle = "";

        if (!timer_enabled) {
            // No configured timers - show infinity symbol
            if (game_start_time > 0) {
                int64 elapsed = get_monotonic_time() - game_start_time;
                subtitle = format_time(elapsed);
            } else {
                subtitle = "";
            }
            timer_updated(subtitle);
            // Emit dual timer with infinity symbols (no time limit)
            dual_timer_updated("∞", "∞");
            return;
        }

        // Get individual timer strings
        string red_time = "--:--";
        string black_time = "--:--";

        if (red_timer != null) {
            red_time = format_time(red_timer.get_current_time_remaining());
        }
        if (black_timer != null) {
            black_time = format_time(black_timer.get_current_time_remaining());
        }

        // Emit dual timer signal
        dual_timer_updated(red_time, black_time);

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

        // Check if time has run out
        if (total_seconds <= 0) {
            check_time_expired();
            return "0:00";
        }

        int minutes = total_seconds / 60;
        int seconds = total_seconds % 60;

        return @"$(minutes):$(seconds < 10 ? "0" : "")$(seconds)";
    }

    /**
     * Check if any timer has expired
     */
    private void check_time_expired() {
        if (!timer_enabled) {
            return;
        }

        // Check red timer
        if (red_timer != null && red_timer_started) {
            var red_time = red_timer.get_current_time_remaining();
            if (red_time <= 0) {
                time_expired(Player.RED);
                return;
            }
        }

        // Check black timer
        if (black_timer != null && black_timer_started) {
            var black_time = black_timer.get_current_time_remaining();
            if (black_time <= 0) {
                time_expired(Player.BLACK);
                return;
            }
        }
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
        game_start_time = 0;
        red_timer_started = false;
        black_timer_started = false;
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