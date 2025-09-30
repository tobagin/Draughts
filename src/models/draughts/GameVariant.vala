/**
 * GameVariant.vala
 *
 * Represents a specific draughts variant configuration.
 * Defines rules, board size, and gameplay characteristics for each variant.
 */

using Draughts;

public class Draughts.GameVariant : Object {
    public DraughtsVariant variant { get; private set; }
    public string id { get; private set; }
    public string display_name { get; private set; }
    public int board_size { get; private set; }
    public bool men_can_capture_backwards { get; private set; }
    public bool kings_can_fly { get; private set; }
    public bool mandatory_capture { get; private set; }
    public CapturePriority capture_priority { get; private set; }
    public int promotion_row_red { get; private set; }
    public int promotion_row_black { get; private set; }
    public string starting_position { get; private set; }
    public int initial_piece_count { get { return get_starting_piece_count(); } }

    public GameVariant(DraughtsVariant variant) {
        this.variant = variant;
        this.id = variant.get_id();
        this.display_name = variant.to_string();
        this.board_size = variant.get_variant_board_size();

        // Configure variant-specific rules
        configure_variant_rules();
    }

    /**
     * Configure rules specific to each variant
     */
    private void configure_variant_rules() {
        switch (variant) {
            case DraughtsVariant.AMERICAN:
                men_can_capture_backwards = false;
                kings_can_fly = false;
                mandatory_capture = true;
                capture_priority = CapturePriority.CHOICE;
                break;

            case DraughtsVariant.INTERNATIONAL:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.RUSSIAN:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.BRAZILIAN:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.ITALIAN:
                men_can_capture_backwards = false;
                kings_can_fly = false;
                mandatory_capture = true;
                capture_priority = CapturePriority.MOST_PIECES;
                break;

            case DraughtsVariant.SPANISH:
                men_can_capture_backwards = true;
                kings_can_fly = false;
                mandatory_capture = true;
                capture_priority = CapturePriority.CHOICE;
                break;

            case DraughtsVariant.CZECH:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.THAI:
                men_can_capture_backwards = false;
                kings_can_fly = false;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.GERMAN:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.SWEDISH:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.POOL:
                men_can_capture_backwards = false;
                kings_can_fly = false;
                mandatory_capture = true;
                capture_priority = CapturePriority.CHOICE;
                break;

            case DraughtsVariant.TURKISH:
                men_can_capture_backwards = false;
                kings_can_fly = false;
                mandatory_capture = true;
                capture_priority = CapturePriority.MOST_PIECES;
                break;

            case DraughtsVariant.ARMENIAN:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.GOTHIC:
                men_can_capture_backwards = false;
                kings_can_fly = false;
                mandatory_capture = true;
                capture_priority = CapturePriority.CHOICE;
                break;

            case DraughtsVariant.FRISIAN:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            case DraughtsVariant.CANADIAN:
                men_can_capture_backwards = false;
                kings_can_fly = true;
                mandatory_capture = true;
                capture_priority = CapturePriority.LONGEST_SEQUENCE;
                break;

            default:
                // Default to American rules
                men_can_capture_backwards = false;
                kings_can_fly = false;
                mandatory_capture = true;
                capture_priority = CapturePriority.CHOICE;
                break;
        }

        // Set promotion rows based on board size
        promotion_row_red = board_size - 1; // Red promotes at top row
        promotion_row_black = 0;             // Black promotes at bottom row

        // Generate starting position
        starting_position = generate_starting_position();
    }

    /**
     * Generate the starting position for this variant
     */
    private string generate_starting_position() {
        var builder = new StringBuilder();

        // Standard starting setup: pieces on first 3 rows for each side
        int setup_rows = (board_size == 12) ? 5 : 3;

        for (int row = 0; row < board_size; row++) {
            for (int col = 0; col < board_size; col++) {
                var pos = new BoardPosition(row, col, board_size);

                if (!pos.is_dark_square()) {
                    continue; // Skip light squares
                }

                if (row < setup_rows) {
                    // Black pieces at bottom
                    builder.append("b");
                } else if (row >= board_size - setup_rows) {
                    // Red pieces at top
                    builder.append("r");
                } else {
                    // Empty square
                    builder.append(".");
                }
            }
        }

        return builder.str;
    }

    /**
     * Check if a piece should be promoted when reaching the specified position
     */
    public bool should_promote_piece(GamePiece piece, BoardPosition destination) {
        if (piece.piece_type == DraughtsPieceType.KING) {
            return false; // Already a king
        }

        if (piece.color == PieceColor.RED) {
            return destination.row == promotion_row_red;
        } else {
            return destination.row == promotion_row_black;
        }
    }

    /**
     * Get the initial piece setup for this variant
     */
    public Gee.ArrayList<GamePiece> create_initial_setup() {
        var pieces = new Gee.ArrayList<GamePiece>();
        int piece_id = 1;

        int setup_rows = (board_size == 12) ? 5 : 3;

        for (int row = 0; row < board_size; row++) {
            for (int col = 0; col < board_size; col++) {
                var pos = new BoardPosition(row, col, board_size);

                if (!pos.is_dark_square()) {
                    continue;
                }

                if (row < setup_rows) {
                    // Black pieces
                    pieces.add(new GamePiece(PieceColor.BLACK, DraughtsPieceType.MAN, pos, piece_id++));
                } else if (row >= board_size - setup_rows) {
                    // Red pieces
                    pieces.add(new GamePiece(PieceColor.RED, DraughtsPieceType.MAN, pos, piece_id++));
                }
            }
        }

        return pieces;
    }

    /**
     * Get all supported variants
     */
    public static GameVariant[] get_all_variants() {
        var variants = new Gee.ArrayList<GameVariant>();

        DraughtsVariant[] all_variants = {
            DraughtsVariant.AMERICAN, DraughtsVariant.INTERNATIONAL, DraughtsVariant.RUSSIAN, DraughtsVariant.BRAZILIAN,
            DraughtsVariant.ITALIAN, DraughtsVariant.SPANISH, DraughtsVariant.CZECH, DraughtsVariant.THAI,
            DraughtsVariant.GERMAN, DraughtsVariant.SWEDISH, DraughtsVariant.POOL, DraughtsVariant.TURKISH,
            DraughtsVariant.ARMENIAN, DraughtsVariant.GOTHIC, DraughtsVariant.FRISIAN, DraughtsVariant.CANADIAN
        };

        foreach (DraughtsVariant v in all_variants) {
            variants.add(new GameVariant(v));
        }

        return variants.to_array();
    }

    /**
     * Find variant by ID
     */
    public static GameVariant? find_by_id(string id) {
        DraughtsVariant[] all_variants = {
            DraughtsVariant.AMERICAN, DraughtsVariant.INTERNATIONAL, DraughtsVariant.RUSSIAN, DraughtsVariant.BRAZILIAN,
            DraughtsVariant.ITALIAN, DraughtsVariant.SPANISH, DraughtsVariant.CZECH, DraughtsVariant.THAI,
            DraughtsVariant.GERMAN, DraughtsVariant.SWEDISH, DraughtsVariant.POOL, DraughtsVariant.TURKISH,
            DraughtsVariant.ARMENIAN, DraughtsVariant.GOTHIC, DraughtsVariant.FRISIAN, DraughtsVariant.CANADIAN
        };

        foreach (DraughtsVariant v in all_variants) {
            var variant = new GameVariant(v);
            if (variant.id == id) {
                return variant;
            }
        }
        return null;
    }

    /**
     * Get string representation
     */
    public string to_string() {
        return @"$display_name ($board_size×$board_size)";
    }

    /**
     * Get detailed description of variant rules
     */
    public string get_rules_description() {
        var desc = new StringBuilder();

        desc.append(@"$display_name Rules:\n");
        desc.append(@"• Board size: $board_size×$board_size\n");
        desc.append(@"• Kings can fly: $(kings_can_fly ? "Yes" : "No")\n");
        desc.append(@"• Men can capture backwards: $(men_can_capture_backwards ? "Yes" : "No")\n");
        desc.append(@"• Mandatory capture: $(mandatory_capture ? "Yes" : "No")\n");
        desc.append(@"• Capture priority: $(capture_priority.to_string())\n");

        return desc.str;
    }

    /**
     * Check if this variant equals another
     */
    public bool equals(GameVariant other) {
        return this.variant == other.variant;
    }

    /**
     * Get the number of pieces each side starts with
     */
    public int get_starting_piece_count() {
        int setup_rows = (board_size == 12) ? 5 : 3;
        int dark_squares_per_row = board_size / 2;
        return setup_rows * dark_squares_per_row;
    }

    /**
     * Check if backward captures are allowed for men in this variant
     */
    public bool allows_backward_captures() {
        return men_can_capture_backwards;
    }

    /**
     * Check if flying kings are allowed in this variant
     */
    public bool allows_flying_kings() {
        return kings_can_fly;
    }

    /**
     * Check if captures are mandatory in this variant
     */
    public bool requires_mandatory_captures() {
        return mandatory_capture;
    }

    /**
     * Create the unified rule engine configured for this variant
     */
    public IRuleEngine create_rule_engine() {
        return new UnifiedRuleEngine(this);
    }
}