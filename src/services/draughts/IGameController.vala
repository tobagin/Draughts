using Draughts;
public interface Draughts.IGameController : Object {
    public abstract Game start_new_game(GameVariant variant, GamePlayer red_player, GamePlayer black_player, Timer? timer_config);
    public abstract bool make_move(DraughtsMove move);
    public abstract bool undo_last_move();
    public abstract bool redo_last_move();
    public abstract bool can_undo();
    public abstract bool can_redo();
    public abstract DraughtsGameState get_current_state();
    public abstract Game get_current_game();
    public abstract void set_game_paused(bool paused);
    public abstract bool is_move_legal(DraughtsMove move);
    // History viewing methods (read-only, don't modify state)
    public abstract DraughtsGameState? view_history_at_position(int position);
    public abstract int get_history_size();
    public abstract int get_history_position();
    public abstract bool is_at_latest_position();
    public signal void game_state_changed(DraughtsGameState new_state, DraughtsMove? last_move);
    public signal void game_finished(GameStatus result, string reason);
    public signal void timer_updated(uint64 red_time_remaining, uint64 black_time_remaining);
}