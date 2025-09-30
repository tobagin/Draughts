/**
 * Timer.vala
 *
 * Manages time controls for draughts games.
 * Supports various timing modes including Fischer increment and delay.
 */

using Draughts;

public class Draughts.Timer : Object {
    public TimerMode mode { get; private set; }
    public TimeSpan base_time { get; private set; }
    public TimeSpan increment { get; private set; }
    public TimeSpan delay { get; private set; }
    public TimeSpan time_remaining { get; set; }
    public bool is_running { get; private set; }
    public DateTime? last_started { get; private set; }

    private TimeSpan _time_when_started;

    /**
     * Create an untimed timer
     */
    public Timer.untimed() {
        this.mode = TimerMode.UNTIMED;
        this.base_time = 0;
        this.increment = 0;
        this.delay = 0;
        this.time_remaining = 0;
        this.is_running = false;
        this.last_started = null;
    }

    /**
     * Create a countdown timer
     */
    public Timer.countdown(TimeSpan base_time) {
        this.mode = TimerMode.COUNTDOWN;
        this.base_time = base_time;
        this.increment = 0;
        this.delay = 0;
        this.time_remaining = base_time;
        this.is_running = false;
        this.last_started = null;
    }

    /**
     * Create a Fischer increment timer
     */
    public Timer.fischer(TimeSpan base_time, TimeSpan increment) {
        this.mode = TimerMode.FISCHER;
        this.base_time = base_time;
        this.increment = increment;
        this.delay = 0;
        this.time_remaining = base_time;
        this.is_running = false;
        this.last_started = null;
    }

    /**
     * Create a delay timer
     */
    public Timer.with_delay(TimeSpan base_time, TimeSpan delay_time) {
        this.mode = TimerMode.DELAY;
        this.base_time = base_time;
        this.increment = 0;
        this.delay = delay_time;
        this.time_remaining = base_time;
        this.is_running = false;
        this.last_started = null;
    }

    /**
     * Start the timer
     */
    public void start() {
        if (mode == TimerMode.UNTIMED) {
            return;
        }

        if (!is_running) {
            last_started = new DateTime.now_utc();
            _time_when_started = time_remaining;
            is_running = true;
        }
    }

    /**
     * Stop the timer and update remaining time
     */
    public TimeSpan stop() {
        if (!is_running || mode == TimerMode.UNTIMED) {
            return 0;
        }

        var elapsed = calculate_elapsed_time();
        time_remaining = _time_when_started - elapsed;

        // Ensure time doesn't go negative
        if (time_remaining < 0) {
            time_remaining = 0;
        }

        is_running = false;
        last_started = null;

        return elapsed;
    }

    /**
     * Pause the timer
     */
    public void pause() {
        if (is_running) {
            stop();
        }
    }

    /**
     * Resume the timer
     */
    public void resume() {
        if (!is_running && time_remaining > 0) {
            start();
        }
    }

    /**
     * Reset timer to initial state
     */
    public void reset() {
        stop();
        time_remaining = base_time;
    }

    /**
     * Add increment time (Fischer mode)
     */
    public void add_increment() {
        if (mode == TimerMode.FISCHER) {
            time_remaining += increment;
        }
    }

    /**
     * Get current time remaining (accounting for running timer)
     */
    public TimeSpan get_current_time_remaining() {
        if (!is_running || mode == TimerMode.UNTIMED) {
            return time_remaining;
        }

        var elapsed = calculate_elapsed_time();
        var current_remaining = _time_when_started - elapsed;

        return (current_remaining < 0) ? 0 : current_remaining;
    }

    /**
     * Get remaining time (alias for get_current_time_remaining for compatibility)
     */
    public TimeSpan get_remaining_time() {
        return get_current_time_remaining();
    }

    /**
     * Get initial time for this timer
     */
    public TimeSpan get_initial_time() {
        return base_time;
    }

    /**
     * Check if time has expired
     */
    public bool is_time_expired() {
        return mode != TimerMode.UNTIMED && get_current_time_remaining() <= 0;
    }

    /**
     * Check if timer is in warning zone
     */
    public bool is_in_warning_zone(TimeSpan warning_threshold) {
        return get_current_time_remaining() <= warning_threshold;
    }

    /**
     * Calculate elapsed time since timer started
     */
    private TimeSpan calculate_elapsed_time() {
        if (last_started == null) {
            return 0;
        }

        var now = new DateTime.now_utc();
        var elapsed = now.difference(last_started);

        // Handle delay mode
        if (mode == TimerMode.DELAY && elapsed < delay) {
            return 0;
        } else if (mode == TimerMode.DELAY) {
            return elapsed - delay;
        }

        return elapsed;
    }

    /**
     * Get formatted time string
     */
    public string format_time(TimeSpan time = -1) {
        if (time == -1) {
            time = get_current_time_remaining();
        }

        if (mode == TimerMode.UNTIMED) {
            return "∞";
        }

        int total_seconds = (int) (time / TimeSpan.SECOND);

        if (total_seconds < 0) {
            return "0:00";
        }

        int hours = total_seconds / 3600;
        int minutes = (total_seconds % 3600) / 60;
        int seconds = total_seconds % 60;

        if (hours > 0) {
            return "%d:%02d:%02d".printf(hours, minutes, seconds);
        } else {
            return "%d:%02d".printf(minutes, seconds);
        }
    }

    /**
     * Create a copy of this timer
     */
    public Timer clone() {
        Timer copy;

        switch (mode) {
            case TimerMode.UNTIMED:
                copy = new Timer.untimed();
                break;
            case TimerMode.COUNTDOWN:
                copy = new Timer.countdown(base_time);
                break;
            case TimerMode.FISCHER:
                copy = new Timer.fischer(base_time, increment);
                break;
            case TimerMode.DELAY:
                copy = new Timer.with_delay(base_time, delay);
                break;
            default:
                copy = new Timer.untimed();
                break;
        }

        copy.time_remaining = this.time_remaining;
        copy.is_running = false; // Don't copy running state
        return copy;
    }

    /**
     * Check if this timer equals another timer
     */
    public bool equals(Timer other) {
        return this.mode == other.mode &&
               this.base_time == other.base_time &&
               this.increment == other.increment &&
               this.delay == other.delay;
    }

    /**
     * Get string representation
     */
    public string to_string() {
        switch (mode) {
            case TimerMode.UNTIMED:
                return "Untimed";
            case TimerMode.COUNTDOWN:
                return "Countdown: " + format_time(base_time);
            case TimerMode.FISCHER:
                return "Fischer: " + format_time(base_time) + " + " + format_time(increment);
            case TimerMode.DELAY:
                return "Delay: " + format_time(base_time) + " (" + format_time(delay) + " delay)";
            default:
                return "Unknown timer mode";
        }
    }

    /**
     * Create timer from preset configuration
     */
    public static Timer create_preset(string preset_name) {
        switch (preset_name.down()) {
            case "blitz_3+2":
                return new Timer.fischer(TimeSpan.SECOND *(180), TimeSpan.SECOND *(2));
            case "blitz_5+0":
                return new Timer.countdown(TimeSpan.SECOND *(300));
            case "rapid_10+0":
                return new Timer.countdown(TimeSpan.SECOND *(600));
            case "rapid_15+10":
                return new Timer.fischer(TimeSpan.SECOND *(900), TimeSpan.SECOND *(10));
            case "classical_60+30":
                return new Timer.fischer(TimeSpan.SECOND *(3600), TimeSpan.SECOND *(30));
            case "untimed":
            default:
                return new Timer.untimed();
        }
    }

    /**
     * Get available preset configurations
     */
    public static string[] get_presets() {
        return {
            "untimed",
            "blitz_3+2",
            "blitz_5+0",
            "rapid_10+0",
            "rapid_15+10",
            "classical_60+30"
        };
    }

    /**
     * Validate timer configuration
     */
    public bool is_valid() {
        switch (mode) {
            case TimerMode.UNTIMED:
                return true;
            case TimerMode.COUNTDOWN:
                return base_time > 0;
            case TimerMode.FISCHER:
                return base_time > 0 && increment >= 0;
            case TimerMode.DELAY:
                return base_time > 0 && delay >= 0;
            default:
                return false;
        }
    }
}