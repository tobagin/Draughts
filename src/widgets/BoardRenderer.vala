/**
 * BoardRenderer.vala
 *
 * Advanced board rendering system for draughts games.
 * Handles piece drawing, board visualization, animations, and visual effects.
 */

using Draughts;

public class Draughts.BoardRenderer : Object {
    private const double BOARD_MARGIN = 20.0;
    private const double PIECE_RADIUS_RATIO = 0.3938; // Increased by 12.5% (0.35 * 1.125)
    private const double KING_CROWN_RATIO = 0.6;
    private const double HIGHLIGHT_ALPHA = 0.3;
    private const double ANIMATION_DURATION = 300.0; // milliseconds

    private int board_size;
    private double square_size;
    private double piece_radius;
    private bool flip_board = false; // true = black at bottom, false = red at bottom

    // Colors
    private Gdk.RGBA dark_square_color;
    private Gdk.RGBA light_square_color;
    private Gdk.RGBA red_piece_color;
    private Gdk.RGBA black_piece_color;
    private Gdk.RGBA king_crown_color;
    private Gdk.RGBA highlight_selected_color;
    private Gdk.RGBA highlight_possible_color;
    private Gdk.RGBA highlight_last_move_color;

    // Animation state
    private Gee.HashMap<string, AnimationState?> animations;
    private uint animation_timer_id = 0;

    public BoardRenderer(int board_size) {
        this.board_size = board_size;
        this.animations = new Gee.HashMap<string, AnimationState?>();

        initialize_colors();
    }

    /**
     * Initialize color scheme
     */
    private void initialize_colors() {
        // Board colors
        dark_square_color = Gdk.RGBA();
        dark_square_color.parse("#8B4513"); // Saddle brown

        light_square_color = Gdk.RGBA();
        light_square_color.parse("#F5DEB3"); // Wheat

        // Piece colors
        red_piece_color = Gdk.RGBA();
        red_piece_color.parse("#DC143C"); // Crimson

        black_piece_color = Gdk.RGBA();
        black_piece_color.parse("#2F4F4F"); // Dark slate gray

        // King crown color
        king_crown_color = Gdk.RGBA();
        king_crown_color.parse("#FFD700"); // Gold

        // Highlight colors
        highlight_selected_color = Gdk.RGBA();
        highlight_selected_color.parse("#00FF00"); // Lime

        highlight_possible_color = Gdk.RGBA();
        highlight_possible_color.parse("#FFFF00"); // Yellow

        highlight_last_move_color = Gdk.RGBA();
        highlight_last_move_color.parse("#FF69B4"); // Hot pink
    }

    /**
     * Update theme colors based on system theme
     */
    public void update_theme_colors(bool is_dark_theme) {
        if (is_dark_theme) {
            dark_square_color.parse("#654321");
            light_square_color.parse("#D2B48C");
        } else {
            dark_square_color.parse("#8B4513");
            light_square_color.parse("#F5DEB3");
        }
    }

    /**
     * Set board perspective based on player color
     * @param player_color Color of the player viewing the board (PieceColor.RED or PieceColor.BLACK)
     */
    public void set_board_perspective(PieceColor player_color) {
        flip_board = (player_color == PieceColor.BLACK);
    }

    /**
     * Transform row coordinate based on board flip state
     */
    private int transform_row(int row) {
        return flip_board ? (board_size - 1 - row) : row;
    }

    /**
     * Transform column coordinate based on board flip state
     */
    private int transform_col(int col) {
        return flip_board ? (board_size - 1 - col) : col;
    }

    /**
     * Calculate layout dimensions based on widget size
     */
    public void calculate_layout(double widget_width, double widget_height) {
        double available_size = Math.fmin(widget_width, widget_height) - (2 * BOARD_MARGIN);
        square_size = available_size / board_size;
        piece_radius = square_size * PIECE_RADIUS_RATIO;
    }

    /**
     * Render the complete board
     */
    public void render_board(Cairo.Context cr, double widget_width, double widget_height) {
        calculate_layout(widget_width, widget_height);

        // Center the board
        double board_offset_x = (widget_width - (board_size * square_size)) / 2;
        double board_offset_y = (widget_height - (board_size * square_size)) / 2;

        cr.translate(board_offset_x, board_offset_y);

        // Draw squares
        render_board_squares(cr);

        // Draw coordinate labels
        render_coordinate_labels(cr);
    }

    /**
     * Render board squares
     */
    private void render_board_squares(Cairo.Context cr) {
        for (int row = 0; row < board_size; row++) {
            for (int col = 0; col < board_size; col++) {
                int display_row = transform_row(row);
                int display_col = transform_col(col);

                double x = display_col * square_size;
                double y = display_row * square_size;

                // Determine square color (use original coordinates for pattern)
                bool is_dark = (row + col) % 2 == 1;
                var color = is_dark ? dark_square_color : light_square_color;

                // Draw square
                cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                cr.rectangle(x, y, square_size, square_size);
                cr.fill();

                // Draw border
                cr.set_source_rgba(0, 0, 0, 0.2);
                cr.set_line_width(1.0);
                cr.rectangle(x, y, square_size, square_size);
                cr.stroke();
            }
        }
    }

    /**
     * Render coordinate labels (a-h, 1-8)
     */
    private void render_coordinate_labels(Cairo.Context cr) {
        cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size(12);
        cr.set_source_rgba(0, 0, 0, 0.7);

        // Column labels (a, b, c, ...)
        for (int col = 0; col < board_size; col++) {
            int display_col = transform_col(col);
            string label = ((char)('a' + col)).to_string();
            double x = display_col * square_size + square_size / 2;
            double y = board_size * square_size + 15;

            Cairo.TextExtents extents;
            cr.text_extents(label, out extents);
            cr.move_to(x - extents.width / 2, y);
            cr.show_text(label);
        }

        // Row labels (1, 2, 3, ...)
        for (int row = 0; row < board_size; row++) {
            int display_row = transform_row(row);
            string label = (board_size - row).to_string();
            double x = -15;
            double y = display_row * square_size + square_size / 2;

            Cairo.TextExtents extents;
            cr.text_extents(label, out extents);
            cr.move_to(x - extents.width / 2, y + extents.height / 2);
            cr.show_text(label);
        }
    }

    /**
     * Render a game piece
     */
    public void render_piece(Cairo.Context cr, Draughts.PieceType piece_type, int row, int col, double alpha = 1.0) {
        int display_row = transform_row(row);
        int display_col = transform_col(col);

        double center_x = display_col * square_size + square_size / 2;
        double center_y = display_row * square_size + square_size / 2;

        var piece_color = get_piece_color(piece_type);
        bool is_king = (piece_type == Draughts.PieceType.RED_KING || piece_type == Draughts.PieceType.BLACK_KING);

        // Draw piece shadow
        cr.set_source_rgba(0, 0, 0, 0.3 * alpha);
        cr.arc(center_x + 2, center_y + 2, piece_radius, 0, 2 * Math.PI);
        cr.fill();

        // Draw piece body
        cr.set_source_rgba(piece_color.red, piece_color.green, piece_color.blue, alpha);
        cr.arc(center_x, center_y, piece_radius, 0, 2 * Math.PI);
        cr.fill();

        // Draw piece border
        cr.set_source_rgba(0, 0, 0, 0.8 * alpha);
        cr.set_line_width(2.0);
        cr.arc(center_x, center_y, piece_radius, 0, 2 * Math.PI);
        cr.stroke();

        // Draw king crown if needed
        if (is_king) {
            render_king_crown(cr, center_x, center_y, alpha);
        }
    }

    /**
     * Render king crown
     */
    private void render_king_crown(Cairo.Context cr, double center_x, double center_y, double alpha) {
        double crown_radius = piece_radius * KING_CROWN_RATIO;

        // Draw crown outline
        cr.set_source_rgba(king_crown_color.red, king_crown_color.green, king_crown_color.blue, alpha);
        cr.arc(center_x, center_y, crown_radius, 0, 2 * Math.PI);
        cr.fill();

        // Draw crown border
        cr.set_source_rgba(0, 0, 0, 0.8 * alpha);
        cr.set_line_width(1.5);
        cr.arc(center_x, center_y, crown_radius, 0, 2 * Math.PI);
        cr.stroke();

        // Draw crown symbol (simple cross)
        cr.set_line_width(2.0);
        cr.move_to(center_x - crown_radius * 0.5, center_y);
        cr.line_to(center_x + crown_radius * 0.5, center_y);
        cr.move_to(center_x, center_y - crown_radius * 0.5);
        cr.line_to(center_x, center_y + crown_radius * 0.5);
        cr.stroke();
    }

    /**
     * Render square highlight
     */
    public void render_highlight(Cairo.Context cr, int row, int col, string highlight_type) {
        int display_row = transform_row(row);
        int display_col = transform_col(col);

        double x = display_col * square_size;
        double y = display_row * square_size;

        Gdk.RGBA color;
        switch (highlight_type) {
            case "selected":
                color = highlight_selected_color;
                break;
            case "possible":
                color = highlight_possible_color;
                break;
            case "last_move":
                color = highlight_last_move_color;
                break;
            default:
                return;
        }

        // Draw highlight overlay
        cr.set_source_rgba(color.red, color.green, color.blue, HIGHLIGHT_ALPHA);
        cr.rectangle(x, y, square_size, square_size);
        cr.fill();

        // Draw highlight border
        cr.set_source_rgba(color.red, color.green, color.blue, 0.8);
        cr.set_line_width(3.0);
        cr.rectangle(x + 1.5, y + 1.5, square_size - 3, square_size - 3);
        cr.stroke();
    }

    /**
     * Get piece color based on piece type
     */
    private Gdk.RGBA get_piece_color(Draughts.PieceType piece_type) {
        switch (piece_type) {
            case Draughts.PieceType.RED_REGULAR:
            case Draughts.PieceType.RED_KING:
                return red_piece_color;
            case Draughts.PieceType.BLACK_REGULAR:
            case Draughts.PieceType.BLACK_KING:
                return black_piece_color;
            default:
                return black_piece_color;
        }
    }

    /**
     * Start piece animation
     */
    public void start_piece_animation(Draughts.PieceType piece_type, int from_row, int from_col, int to_row, int to_col) {
        string animation_id = @"move_$(from_row)_$(from_col)_$(to_row)_$(to_col)";

        var animation = AnimationState() {
            piece_type = piece_type,
            from_row = from_row,
            from_col = from_col,
            to_row = to_row,
            to_col = to_col,
            start_time = get_monotonic_time(),
            duration = (int64)(ANIMATION_DURATION * 1000), // Convert to microseconds
            progress = 0.0
        };

        animations[animation_id] = animation;

        if (animation_timer_id == 0) {
            animation_timer_id = Timeout.add(16, update_animations); // ~60 FPS
        }
    }

    /**
     * Update all active animations
     */
    private bool update_animations() {
        bool has_active_animations = false;
        var completed_animations = new Gee.ArrayList<string>();

        foreach (var entry in animations.entries) {
            var animation = entry.value;
            int64 current_time = get_monotonic_time();
            int64 elapsed = current_time - animation.start_time;

            animation.progress = (double)elapsed / animation.duration;

            if (animation.progress >= 1.0) {
                animation.progress = 1.0;
                completed_animations.add(entry.key);
            } else {
                has_active_animations = true;
            }
        }

        // Remove completed animations
        foreach (string id in completed_animations) {
            animations.unset(id);
        }

        if (!has_active_animations) {
            animation_timer_id = 0;
            return false; // Stop timer
        }

        return true; // Continue timer
    }

    /**
     * Render animated pieces
     */
    public void render_animations(Cairo.Context cr) {
        foreach (var animation in animations.values) {
            // Interpolate position
            double t = ease_in_out_cubic(animation.progress);
            double current_row = animation.from_row + (animation.to_row - animation.from_row) * t;
            double current_col = animation.from_col + (animation.to_col - animation.from_col) * t;

            render_piece(cr, animation.piece_type, (int)Math.round(current_row), (int)Math.round(current_col));
        }
    }

    /**
     * Easing function for smooth animations
     */
    private double ease_in_out_cubic(double t) {
        return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
    }

    /**
     * Check if any animations are active
     */
    public bool has_active_animations() {
        return animations.size > 0;
    }

    /**
     * Clear all animations
     */
    public void clear_animations() {
        animations.clear();
        if (animation_timer_id != 0) {
            Source.remove(animation_timer_id);
            animation_timer_id = 0;
        }
    }

    /**
     * Convert board coordinates to screen coordinates
     */
    public void board_to_screen_coords(int row, int col, out double x, out double y) {
        int display_row = transform_row(row);
        int display_col = transform_col(col);

        x = display_col * square_size + square_size / 2;
        y = display_row * square_size + square_size / 2;
    }

    /**
     * Convert screen coordinates to board coordinates
     */
    public bool screen_to_board_coords(double x, double y, out int row, out int col) {
        int display_row = (int)(y / square_size);
        int display_col = (int)(x / square_size);

        // Transform back to logical coordinates
        row = flip_board ? (board_size - 1 - display_row) : display_row;
        col = flip_board ? (board_size - 1 - display_col) : display_col;

        return row >= 0 && row < board_size && col >= 0 && col < board_size;
    }

    /**
     * Get square size for external calculations
     */
    public double get_square_size() {
        return square_size;
    }
}

/**
 * Animation state structure
 */
public struct AnimationState {
    public Draughts.PieceType piece_type;
    public int from_row;
    public int from_col;
    public int to_row;
    public int to_col;
    public int64 start_time;
    public int64 duration;
    public double progress;
}