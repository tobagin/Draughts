/**
 * DraughtsConstants.vala
 *
 * Constants and enumerations for the draughts game system.
 * Defines core game types, states, and configuration values.
 */

namespace Draughts {

    /**
     * Draughts game variants supported by the application
     */
    public enum DraughtsVariant {
        AMERICAN,
        INTERNATIONAL,
        RUSSIAN,
        BRAZILIAN,
        ITALIAN,
        SPANISH,
        CZECH,
        THAI,
        GERMAN,
        SWEDISH,
        POOL,
        TURKISH,
        ARMENIAN,
        GOTHIC,
        FRISIAN,
        CANADIAN;

        public string to_string() {
            switch (this) {
                case AMERICAN: return "American Checkers";
                case INTERNATIONAL: return "International Draughts";
                case RUSSIAN: return "Russian Draughts";
                case BRAZILIAN: return "Brazilian Draughts";
                case ITALIAN: return "Italian Draughts";
                case SPANISH: return "Spanish Draughts";
                case CZECH: return "Czech Draughts";
                case THAI: return "Thai Draughts";
                case GERMAN: return "German Draughts";
                case SWEDISH: return "Swedish Draughts";
                case POOL: return "Pool Checkers";
                case TURKISH: return "Turkish Draughts";
                case ARMENIAN: return "Armenian Draughts";
                case GOTHIC: return "Gothic Draughts";
                case FRISIAN: return "Frisian Draughts";
                case CANADIAN: return "Canadian Draughts";
                default: return "Unknown";
            }
        }

        public string get_id() {
            switch (this) {
                case AMERICAN: return "american";
                case INTERNATIONAL: return "international";
                case RUSSIAN: return "russian";
                case BRAZILIAN: return "brazilian";
                case ITALIAN: return "italian";
                case SPANISH: return "spanish";
                case CZECH: return "czech";
                case THAI: return "thai";
                case GERMAN: return "german";
                case SWEDISH: return "swedish";
                case POOL: return "pool";
                case TURKISH: return "turkish";
                case ARMENIAN: return "armenian";
                case GOTHIC: return "gothic";
                case FRISIAN: return "frisian";
                case CANADIAN: return "canadian";
                default: return "unknown";
            }
        }

        public int get_variant_board_size() {
            switch (this) {
                case INTERNATIONAL:
                case FRISIAN:
                    return 10;
                case CANADIAN:
                    return 12;
                default:
                    return 8;
            }
        }
    }

    /**
     * Piece colors in the game
     */
    public enum PieceColor {
        RED,
        BLACK;

        public string to_string() {
            switch (this) {
                case RED: return "Red";
                case BLACK: return "Black";
                default: return "Unknown";
            }
        }

        public PieceColor get_opposite() {
            return (this == RED) ? BLACK : RED;
        }
    }

    /**
     * Types of game pieces
     */
    public enum DraughtsPieceType {
        MAN,
        KING;

        public string to_string() {
            switch (this) {
                case MAN: return "Man";
                case KING: return "King";
                default: return "Unknown";
            }
        }
    }

    /**
     * Types of moves that can be made
     */
    public enum MoveType {
        SIMPLE,
        CAPTURE,
        MULTI_CAPTURE,
        MULTIPLE_CAPTURE;

        public string to_string() {
            switch (this) {
                case SIMPLE: return "Simple Move";
                case CAPTURE: return "Capture";
                case MULTI_CAPTURE: return "Multi-Capture";
                case MULTIPLE_CAPTURE: return "Multiple Capture";
                default: return "Unknown";
            }
        }
    }

    /**
     * Current state of the game
     */
    public enum GameStatus {
        NOT_STARTED,
        IN_PROGRESS,
        ACTIVE,
        RED_WIN,
        RED_WINS,
        BLACK_WIN,
        BLACK_WINS,
        DRAW;

        public string to_string() {
            switch (this) {
                case NOT_STARTED: return "Not Started";
                case IN_PROGRESS: return "In Progress";
                case ACTIVE: return "Active";
                case RED_WIN: return "Red Wins";
                case RED_WINS: return "Red Wins";
                case BLACK_WIN: return "Black Wins";
                case BLACK_WINS: return "Black Wins";
                case DRAW: return "Draw";
                default: return "Unknown";
            }
        }
    }

    /**
     * Reasons for a draw game
     */
    public enum DrawReason {
        STALEMATE,
        REPETITION,
        INSUFFICIENT_MATERIAL,
        AGREEMENT,
        TIME_LIMIT;

        public string to_string() {
            switch (this) {
                case STALEMATE: return "Stalemate";
                case REPETITION: return "Position Repetition";
                case INSUFFICIENT_MATERIAL: return "Insufficient Material";
                case AGREEMENT: return "Agreement";
                case TIME_LIMIT: return "Time Limit";
                default: return "Unknown";
            }
        }
    }

    /**
     * Player types
     */
    public enum PlayerType {
        HUMAN,
        AI;

        public string to_string() {
            switch (this) {
                case HUMAN: return "Human";
                case AI: return "AI";
                default: return "Unknown";
            }
        }
    }

    /**
     * AI difficulty levels
     */
    public enum AIDifficulty {
        BEGINNER = 1,
        EASY = 2,
        MEDIUM = 3,
        NOVICE = 4,
        INTERMEDIATE = 5,
        HARD = 6,
        ADVANCED = 7,
        EXPERT = 8,
        MASTER = 9,
        GRANDMASTER = 10;

        public string to_string() {
            switch (this) {
                case BEGINNER: return "Beginner";
                case EASY: return "Easy";
                case MEDIUM: return "Medium";
                case NOVICE: return "Novice";
                case INTERMEDIATE: return "Intermediate";
                case HARD: return "Hard";
                case ADVANCED: return "Advanced";
                case EXPERT: return "Expert";
                case MASTER: return "Master";
                case GRANDMASTER: return "Grandmaster";
                default: return "Unknown";
            }
        }

        public int get_search_depth() {
            return (int) this; // Difficulty level maps directly to search depth
        }
    }

    /**
     * Timer modes for game timing
     */
    public enum TimerMode {
        UNTIMED,
        COUNTDOWN,
        FISCHER,
        FISCHER_INCREMENT,
        DELAY;

        public string to_string() {
            switch (this) {
                case UNTIMED: return "Untimed";
                case COUNTDOWN: return "Countdown";
                case FISCHER: return "Fischer Increment";
                case FISCHER_INCREMENT: return "Fischer Increment";
                case DELAY: return "Delay";
                default: return "Unknown";
            }
        }
    }

    /**
     * Capture priority rules for variants with multiple capture options
     */
    public enum CapturePriority {
        LONGEST_SEQUENCE,
        MOST_PIECES,
        CHOICE;

        public string to_string() {
            switch (this) {
                case LONGEST_SEQUENCE: return "Longest Sequence";
                case MOST_PIECES: return "Most Pieces";
                case CHOICE: return "Player Choice";
                default: return "Unknown";
            }
        }
    }

    /**
     * Game constants
     */
    public class DraughtsGameConstants {
        // Performance targets
        public const int MAX_AI_THINKING_TIME_MS = 100;
        public const int TARGET_FPS = 60;
        public const int MAX_MOVE_VALIDATION_TIME_MS = 10;

        // Board constraints
        public const int MIN_BOARD_SIZE = 8;
        public const int MAX_BOARD_SIZE = 12;
        public const int SQUARES_PER_ROW_8X8 = 8;
        public const int SQUARES_PER_ROW_10X10 = 10;
        public const int SQUARES_PER_ROW_12X12 = 12;

        // Game limits
        public const int MAX_PIECES_PER_SIDE = 20; // For 10x10 board
        public const int MAX_CAPTURE_SEQUENCE = 12; // Theoretical maximum
        public const int MAX_MOVE_HISTORY = 1000; // For repetition detection

        // AI parameters
        public const int MIN_AI_DIFFICULTY = 1;
        public const int MAX_AI_DIFFICULTY = 8;
        public const int DEFAULT_TRANSPOSITION_TABLE_SIZE = 1000000;

        // Timer defaults (in milliseconds)
        public const int BLITZ_BASE_TIME = 180000; // 3 minutes
        public const int BLITZ_INCREMENT = 2000; // 2 seconds
        public const int RAPID_BASE_TIME = 600000; // 10 minutes
        public const int RAPID_INCREMENT = 10000; // 10 seconds
        public const int CLASSICAL_BASE_TIME = 3600000; // 60 minutes
        public const int CLASSICAL_INCREMENT = 30000; // 30 seconds

        // UI constants
        public const int ANIMATION_DURATION_MS = 300;
        public const int HIGHLIGHT_ALPHA = 128;
        public const double PIECE_SIZE_RATIO = 0.9; // Piece size relative to square (increased by 12.5%)
        public const double BORDER_WIDTH_RATIO = 0.02; // Border width relative to square

        // Accessibility
        public const int KEYBOARD_NAVIGATION_DELAY_MS = 150;
        public const int SCREEN_READER_PAUSE_MS = 500;
    }
}