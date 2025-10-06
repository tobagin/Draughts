-- Draughts Multiplayer Server - Supabase Database Schema
-- This schema stores game history, statistics, and analytics

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Games table - stores individual game records
CREATE TABLE games (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_code TEXT NOT NULL,
    variant TEXT NOT NULL,
    host_name TEXT NOT NULL,
    guest_name TEXT NOT NULL,
    winner TEXT, -- 'red_wins', 'black_wins', 'draw'
    result_reason TEXT, -- 'no_moves', 'resignation', 'timeout', 'inactivity', 'disconnect_timeout', 'draw_agreement'
    move_count INTEGER DEFAULT 0,
    duration_seconds INTEGER, -- Game duration in seconds
    use_timer BOOLEAN DEFAULT false,
    minutes_per_side INTEGER,
    increment_seconds INTEGER,
    clock_type TEXT, -- 'Fischer' or 'Delay'
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Moves table - stores individual moves for game replay (optional)
CREATE TABLE moves (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    game_id UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    move_number INTEGER NOT NULL,
    player_color TEXT NOT NULL, -- 'red' or 'black'
    move_data JSONB NOT NULL, -- Full move object from client
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Daily stats table - aggregated statistics per day
CREATE TABLE daily_stats (
    date DATE PRIMARY KEY,
    total_games INTEGER DEFAULT 0,
    games_by_variant JSONB DEFAULT '{}',
    games_by_result JSONB DEFAULT '{}',
    avg_game_duration INTEGER, -- Average duration in seconds
    peak_concurrent_games INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_games_started_at ON games(started_at DESC);
CREATE INDEX idx_games_variant ON games(variant);
CREATE INDEX idx_games_room_code ON games(room_code);
CREATE INDEX idx_moves_game_id ON moves(game_id, move_number);
CREATE INDEX idx_daily_stats_date ON daily_stats(date DESC);

-- View for game statistics summary
CREATE VIEW game_stats_summary AS
SELECT
    COUNT(*) as total_games,
    COUNT(CASE WHEN winner = 'red_wins' THEN 1 END) as red_wins,
    COUNT(CASE WHEN winner = 'black_wins' THEN 1 END) as black_wins,
    COUNT(CASE WHEN winner = 'draw' THEN 1 END) as draws,
    COUNT(CASE WHEN result_reason = 'resignation' THEN 1 END) as resignations,
    COUNT(CASE WHEN result_reason = 'timeout' THEN 1 END) as timeouts,
    COUNT(CASE WHEN result_reason = 'inactivity' THEN 1 END) as inactivity_abandonments,
    AVG(duration_seconds) as avg_duration_seconds,
    AVG(move_count) as avg_move_count
FROM games;

-- View for variant popularity
CREATE VIEW variant_stats AS
SELECT
    variant,
    COUNT(*) as game_count,
    AVG(duration_seconds) as avg_duration,
    AVG(move_count) as avg_moves,
    COUNT(CASE WHEN winner = 'red_wins' THEN 1 END) as red_wins,
    COUNT(CASE WHEN winner = 'black_wins' THEN 1 END) as black_wins,
    COUNT(CASE WHEN winner = 'draw' THEN 1 END) as draws
FROM games
GROUP BY variant
ORDER BY game_count DESC;

-- View for recent games
CREATE VIEW recent_games AS
SELECT
    id,
    room_code,
    variant,
    host_name,
    guest_name,
    winner,
    result_reason,
    move_count,
    duration_seconds,
    started_at,
    ended_at
FROM games
ORDER BY ended_at DESC
LIMIT 100;

-- Function to update daily stats
CREATE OR REPLACE FUNCTION update_daily_stats()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO daily_stats (date, total_games, games_by_variant, games_by_result)
    VALUES (
        DATE(NEW.ended_at),
        1,
        jsonb_build_object(NEW.variant, 1),
        jsonb_build_object(NEW.result_reason, 1)
    )
    ON CONFLICT (date) DO UPDATE SET
        total_games = daily_stats.total_games + 1,
        games_by_variant = daily_stats.games_by_variant ||
            jsonb_build_object(
                NEW.variant,
                COALESCE((daily_stats.games_by_variant->>NEW.variant)::integer, 0) + 1
            ),
        games_by_result = daily_stats.games_by_result ||
            jsonb_build_object(
                NEW.result_reason,
                COALESCE((daily_stats.games_by_result->>NEW.result_reason)::integer, 0) + 1
            ),
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update daily stats when game ends
CREATE TRIGGER trigger_update_daily_stats
    AFTER INSERT ON games
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_stats();

-- Comments
COMMENT ON TABLE games IS 'Stores completed multiplayer game records';
COMMENT ON TABLE moves IS 'Stores individual moves for game replay functionality';
COMMENT ON TABLE daily_stats IS 'Aggregated daily statistics for analytics';
COMMENT ON VIEW game_stats_summary IS 'Overall game statistics summary';
COMMENT ON VIEW variant_stats IS 'Statistics grouped by game variant';
COMMENT ON VIEW recent_games IS 'Most recent 100 completed games';
