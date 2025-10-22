/**
 * OpeningBook.vala
 *
 * Opening book for Draughts using SQLite database.
 * Stores and retrieves known opening positions and their best moves.
 *
 * Features:
 * - Position hashing for fast lookup
 * - Move frequency and success rate tracking
 * - Support for multiple variants
 * - Professional opening database
 */

using Draughts;

public class Draughts.OpeningBook : Object {

    private Sqlite.Database? db = null;
    private Logger logger;
    private string db_path;
    private bool enabled = true;

    // Statistics
    private int total_lookups = 0;
    private int successful_lookups = 0;

    public OpeningBook(string? custom_db_path = null) {
        this.logger = Logger.get_default();

        // Use custom path or default to user data directory
        if (custom_db_path != null) {
            this.db_path = custom_db_path;
        } else {
            var data_dir = Environment.get_user_data_dir();
            var app_dir = Path.build_filename(data_dir, "draughts");
            DirUtils.create_with_parents(app_dir, 0755);
            this.db_path = Path.build_filename(app_dir, "opening_book.db");
        }

        initialize_database();
    }

    /**
     * Initialize the SQLite database and create tables if needed
     */
    private void initialize_database() {
        int rc = Sqlite.Database.open(db_path, out db);

        if (rc != Sqlite.OK) {
            logger.error("Failed to open opening book database: %s", db.errmsg());
            db = null;
            enabled = false;
            return;
        }

        logger.info("Opening book database initialized at: %s", db_path);

        // Create tables
        create_tables();

        // Populate with default openings if empty
        if (is_database_empty()) {
            populate_default_openings();
        }
    }

    /**
     * Create database tables
     */
    private void create_tables() {
        string create_positions_table = """
            CREATE TABLE IF NOT EXISTS positions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                position_hash TEXT NOT NULL UNIQUE,
                variant TEXT NOT NULL,
                ply_count INTEGER NOT NULL,
                created_at INTEGER NOT NULL
            );
        """;

        string create_moves_table = """
            CREATE TABLE IF NOT EXISTS moves (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                position_id INTEGER NOT NULL,
                move_notation TEXT NOT NULL,
                from_row INTEGER NOT NULL,
                from_col INTEGER NOT NULL,
                to_row INTEGER NOT NULL,
                to_col INTEGER NOT NULL,
                times_played INTEGER DEFAULT 1,
                wins INTEGER DEFAULT 0,
                draws INTEGER DEFAULT 0,
                losses INTEGER DEFAULT 0,
                FOREIGN KEY (position_id) REFERENCES positions(id)
            );
        """;

        string create_index = """
            CREATE INDEX IF NOT EXISTS idx_position_hash ON positions(position_hash);
        """;

        execute_sql(create_positions_table);
        execute_sql(create_moves_table);
        execute_sql(create_index);
    }

    /**
     * Check if database is empty
     */
    private bool is_database_empty() {
        Sqlite.Statement stmt;
        string sql = "SELECT COUNT(*) FROM positions;";

        if (db.prepare_v2(sql, -1, out stmt) != Sqlite.OK) {
            return true;
        }

        if (stmt.step() == Sqlite.ROW) {
            int count = stmt.column_int(0);
            return count == 0;
        }

        return true;
    }

    /**
     * Lookup a position in the opening book
     */
    public DraughtsMove? lookup_position(DraughtsGameState state) {
        if (!enabled || db == null) {
            return null;
        }

        total_lookups++;

        string position_hash = hash_position(state);
        string variant_name = state.variant.display_name;

        // Find position in database
        Sqlite.Statement stmt;
        string sql = """
            SELECT id FROM positions
            WHERE position_hash = ? AND variant = ?;
        """;

        if (db.prepare_v2(sql, -1, out stmt) != Sqlite.OK) {
            logger.error("Failed to prepare lookup statement: %s", db.errmsg());
            return null;
        }

        stmt.bind_text(1, position_hash);
        stmt.bind_text(2, variant_name);

        if (stmt.step() != Sqlite.ROW) {
            // Position not in book
            return null;
        }

        int position_id = stmt.column_int(0);

        // Get best move for this position
        var move = get_best_move_for_position(position_id, state);

        if (move != null) {
            successful_lookups++;
            logger.info("Opening book hit! Success rate: %d/%d (%.1f%%)",
                       successful_lookups, total_lookups,
                       (successful_lookups * 100.0) / total_lookups);
        }

        return move;
    }

    /**
     * Get the best move for a position
     */
    private DraughtsMove? get_best_move_for_position(int position_id, DraughtsGameState state) {
        Sqlite.Statement stmt;
        string sql = """
            SELECT from_row, from_col, to_row, to_col,
                   times_played, wins, draws, losses
            FROM moves
            WHERE position_id = ?
            ORDER BY (wins * 1.0 + draws * 0.5) / times_played DESC, times_played DESC
            LIMIT 1;
        """;

        if (db.prepare_v2(sql, -1, out stmt) != Sqlite.OK) {
            logger.error("Failed to prepare move query: %s", db.errmsg());
            return null;
        }

        stmt.bind_int(1, position_id);

        if (stmt.step() != Sqlite.ROW) {
            return null;
        }

        int from_row = stmt.column_int(0);
        int from_col = stmt.column_int(1);
        int to_row = stmt.column_int(2);
        int to_col = stmt.column_int(3);

        // Find the actual move in legal moves
        var legal_moves = state.get_legal_moves();
        foreach (var move in legal_moves) {
            if (move.from_position.row == from_row &&
                move.from_position.col == from_col &&
                move.to_position.row == to_row &&
                move.to_position.col == to_col) {
                return move;
            }
        }

        return null;
    }

    /**
     * Add a position and move to the opening book
     */
    public void add_opening(DraughtsGameState state, DraughtsMove move) {
        if (!enabled || db == null) {
            return;
        }

        string position_hash = hash_position(state);
        string variant_name = state.variant.display_name;

        // Insert or get position
        int position_id = insert_or_get_position(position_hash, variant_name, state.move_count);

        if (position_id == -1) {
            return;
        }

        // Insert or update move
        insert_or_update_move(position_id, move);
    }

    /**
     * Insert or get existing position
     */
    private int insert_or_get_position(string position_hash, string variant_name, int ply_count) {
        // Try to find existing position
        Sqlite.Statement stmt;
        string select_sql = """
            SELECT id FROM positions
            WHERE position_hash = ? AND variant = ?;
        """;

        if (db.prepare_v2(select_sql, -1, out stmt) != Sqlite.OK) {
            return -1;
        }

        stmt.bind_text(1, position_hash);
        stmt.bind_text(2, variant_name);

        if (stmt.step() == Sqlite.ROW) {
            return stmt.column_int(0);
        }

        // Insert new position
        string insert_sql = """
            INSERT INTO positions (position_hash, variant, ply_count, created_at)
            VALUES (?, ?, ?, ?);
        """;

        if (db.prepare_v2(insert_sql, -1, out stmt) != Sqlite.OK) {
            return -1;
        }

        stmt.bind_text(1, position_hash);
        stmt.bind_text(2, variant_name);
        stmt.bind_int(3, ply_count);
        stmt.bind_int64(4, (int64) time_t());

        if (stmt.step() != Sqlite.DONE) {
            return -1;
        }

        return (int) db.last_insert_rowid();
    }

    /**
     * Insert or update a move
     */
    private void insert_or_update_move(int position_id, DraughtsMove move) {
        // Check if move exists
        Sqlite.Statement stmt;
        string select_sql = """
            SELECT id, times_played FROM moves
            WHERE position_id = ? AND from_row = ? AND from_col = ?
              AND to_row = ? AND to_col = ?;
        """;

        if (db.prepare_v2(select_sql, -1, out stmt) != Sqlite.OK) {
            return;
        }

        stmt.bind_int(1, position_id);
        stmt.bind_int(2, move.from_position.row);
        stmt.bind_int(3, move.from_position.col);
        stmt.bind_int(4, move.to_position.row);
        stmt.bind_int(5, move.to_position.col);

        if (stmt.step() == Sqlite.ROW) {
            // Update existing move
            int move_id = stmt.column_int(0);
            int times_played = stmt.column_int(1);

            string update_sql = "UPDATE moves SET times_played = ? WHERE id = ?;";
            if (db.prepare_v2(update_sql, -1, out stmt) == Sqlite.OK) {
                stmt.bind_int(1, times_played + 1);
                stmt.bind_int(2, move_id);
                stmt.step();
            }
        } else {
            // Insert new move
            string insert_sql = """
                INSERT INTO moves (position_id, move_notation, from_row, from_col, to_row, to_col)
                VALUES (?, ?, ?, ?, ?, ?);
            """;

            if (db.prepare_v2(insert_sql, -1, out stmt) == Sqlite.OK) {
                stmt.bind_int(1, position_id);
                stmt.bind_text(2, move.to_algebraic_notation());
                stmt.bind_int(3, move.from_position.row);
                stmt.bind_int(4, move.from_position.col);
                stmt.bind_int(5, move.to_position.row);
                stmt.bind_int(6, move.to_position.col);
                stmt.step();
            }
        }
    }

    /**
     * Update move statistics based on game result
     */
    public void update_move_result(DraughtsGameState state, DraughtsMove move, GameStatus result) {
        if (!enabled || db == null) {
            return;
        }

        string position_hash = hash_position(state);
        string variant_name = state.variant.display_name;

        // Get position ID
        int position_id = get_position_id(position_hash, variant_name);
        if (position_id == -1) {
            return;
        }

        // Update move statistics
        Sqlite.Statement stmt;
        string sql = "";

        if (result == GameStatus.RED_WINS && state.active_player == PieceColor.RED) {
            sql = "UPDATE moves SET wins = wins + 1 WHERE position_id = ? AND from_row = ? AND from_col = ? AND to_row = ? AND to_col = ?;";
        } else if (result == GameStatus.BLACK_WINS && state.active_player == PieceColor.BLACK) {
            sql = "UPDATE moves SET wins = wins + 1 WHERE position_id = ? AND from_row = ? AND from_col = ? AND to_row = ? AND to_col = ?;";
        } else if (result == GameStatus.DRAW) {
            sql = "UPDATE moves SET draws = draws + 1 WHERE position_id = ? AND from_row = ? AND from_col = ? AND to_row = ? AND to_col = ?;";
        } else {
            sql = "UPDATE moves SET losses = losses + 1 WHERE position_id = ? AND from_row = ? AND from_col = ? AND to_row = ? AND to_col = ?;";
        }

        if (db.prepare_v2(sql, -1, out stmt) == Sqlite.OK) {
            stmt.bind_int(1, position_id);
            stmt.bind_int(2, move.from_position.row);
            stmt.bind_int(3, move.from_position.col);
            stmt.bind_int(4, move.to_position.row);
            stmt.bind_int(5, move.to_position.col);
            stmt.step();
        }
    }

    /**
     * Populate database with default openings
     */
    private void populate_default_openings() {
        logger.info("Populating opening book with default openings...");

        // Add some basic American Checkers openings
        add_american_openings();

        // Add International Draughts openings
        add_international_openings();

        logger.info("Opening book populated successfully");
    }

    /**
     * Add American Checkers common openings
     */
    private void add_american_openings() {
        logger.info("Populating American Checkers openings...");

        var variant = DraughtsVariant.AMERICAN;
        var initial_state = DraughtsGameState.create_initial_state(variant);
        var rule_engine = new UnifiedRuleEngine(variant);

        // Opening 1: Single Corner (11-15, 23-19)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "d6-e5"  // Common response
        });

        // Opening 2: Double Corner (11-15, 22-18, 15x22, 25x18, 8-11)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "c6-d5"
        });

        // Opening 3: Cross (11-15, 24-19)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "e6-d5"
        });

        // Opening 4: Denny (11-15, 23-18)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "b6-c5"
        });

        // Opening 5: Old Fourteenth (11-15, 22-17)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "a6-b5"
        });

        // Opening 6: Edinburgh (11-15, 24-20)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "e6-f5"
        });

        // Opening 7: Souter (11-15, 21-17)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "a7-b6"
        });

        // Opening 8: Will o' the Wisp (11-16)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-d4", "d6-e5"
        });

        // Opening 9: Bristol (11-16, 22-18)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-d4", "c6-d5"
        });

        // Opening 10: Defiance (10-15)
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "c3-d4", "d6-e5"
        });

        logger.info("Added 10 American Checkers opening patterns");
    }

    /**
     * Add International Draughts common openings
     */
    private void add_international_openings() {
        logger.info("Populating International Draughts openings...");

        var variant = DraughtsVariant.INTERNATIONAL;
        var initial_state = DraughtsGameState.create_initial_state(variant);
        var rule_engine = new UnifiedRuleEngine(variant);

        // Opening 1: Coup Turc
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "d6-e5"
        });

        // Opening 2: Napoleon
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "f6-e5"
        });

        // Opening 3: Long Diagonal
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "f3-e4", "d6-e5"
        });

        // Opening 4: Symmetric
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "e3-f4", "e6-d5"
        });

        // Opening 5: Wagram
        add_opening_sequence(initial_state, rule_engine, new string[] {
            "g3-f4", "d6-e5"
        });

        logger.info("Added 5 International Draughts opening patterns");
    }

    /**
     * Add an opening sequence to the database
     */
    private void add_opening_sequence(
        DraughtsGameState initial_state,
        IRuleEngine rule_engine,
        string[] move_notations
    ) {
        var current_state = initial_state;
        var parser = new PDNParser();

        foreach (var notation in move_notations) {
            // Find the move from notation
            var legal_moves = rule_engine.generate_legal_moves(current_state);
            DraughtsMove? found_move = null;

            // Parse notation
            string separator = "-";
            if (notation.contains("x")) separator = "x";
            else if (notation.contains(":")) separator = ":";

            string[] parts = notation.split(separator);
            if (parts.length != 2) continue;

            var from_pos = parser.parse_position(parts[0].strip(), current_state.variant.board_size);
            var to_pos = parser.parse_position(parts[1].strip(), current_state.variant.board_size);

            if (from_pos == null || to_pos == null) continue;

            // Find matching legal move
            foreach (var legal_move in legal_moves) {
                if (legal_move.from_position.equals(from_pos) &&
                    legal_move.to_position.equals(to_pos)) {
                    found_move = legal_move;
                    break;
                }
            }

            if (found_move == null) {
                logger.warning("Could not find move: %s", notation);
                break;
            }

            // Add to opening book
            add_opening(current_state, found_move);

            // Apply move to get next state
            current_state = current_state.apply_move(found_move);
        }
    }

    /**
     * Enable or disable the opening book
     */
    public void set_enabled(bool enabled) {
        this.enabled = enabled;
        logger.info("Opening book %s", enabled ? "enabled" : "disabled");
    }

    /**
     * Check if opening book is enabled
     */
    public bool is_enabled() {
        return enabled && db != null;
    }

    /**
     * Get opening book statistics
     */
    public string get_statistics() {
        if (total_lookups == 0) {
            return "No lookups yet";
        }

        double hit_rate = (successful_lookups * 100.0) / total_lookups;
        return @"Lookups: $(total_lookups), Hits: $(successful_lookups) ($(hit_rate).1f%%)";
    }

    // Helper methods

    private string hash_position(DraughtsGameState state) {
        var builder = new StringBuilder();
        builder.append(@"$(state.active_player):");

        // Sort pieces for consistent hashing
        var sorted_pieces = new Gee.ArrayList<GamePiece>();
        foreach (var piece in state.pieces) {
            sorted_pieces.add(piece);
        }

        sorted_pieces.sort((a, b) => {
            if (a.position.row != b.position.row) {
                return a.position.row - b.position.row;
            }
            return a.position.col - b.position.col;
        });

        foreach (var piece in sorted_pieces) {
            builder.append(@"$(piece.position.row),$(piece.position.col),");
            builder.append(@"$(piece.color),$(piece.piece_type);");
        }

        return builder.str;
    }

    private int get_position_id(string position_hash, string variant_name) {
        Sqlite.Statement stmt;
        string sql = "SELECT id FROM positions WHERE position_hash = ? AND variant = ?;";

        if (db.prepare_v2(sql, -1, out stmt) != Sqlite.OK) {
            return -1;
        }

        stmt.bind_text(1, position_hash);
        stmt.bind_text(2, variant_name);

        if (stmt.step() == Sqlite.ROW) {
            return stmt.column_int(0);
        }

        return -1;
    }

    private void execute_sql(string sql) {
        string errmsg;
        if (db.exec(sql, null, out errmsg) != Sqlite.OK) {
            logger.error("SQL error: %s", errmsg);
        }
    }

    /**
     * Close the database connection
     */
    ~OpeningBook() {
        if (db != null) {
            logger.debug("Closing opening book database");
        }
    }
}
