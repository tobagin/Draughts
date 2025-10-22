/**
 * AnimationController.vala
 *
 * Handles piece animations on the board.
 * Responsible for:
 * - Single move animations
 * - Multi-jump sequences
 * - Animation timing and completion
 */

using Draughts;

public class Draughts.AnimationController : Object {

    private DraughtsBoard board_widget;
    private Logger logger;

    // Animation state
    private bool is_animating = false;
    private DraughtsMove? pending_move = null;
    private DraughtsMove[]? multi_jump_sequence = null;
    private int multi_jump_index = 0;

    // Signals
    public signal void animation_completed(DraughtsMove move);

    public AnimationController(DraughtsBoard board_widget) {
        this.board_widget = board_widget;
        this.logger = Logger.get_default();

        // Connect to board animation completion
        board_widget.animation_completed.connect(on_board_animation_completed);
    }

    /**
     * Check if animation is currently in progress
     */
    public bool is_animation_in_progress() {
        return is_animating;
    }

    /**
     * Animate a move on the board
     */
    public void animate_move(DraughtsMove move, DraughtsGameState state) {
        logger.debug("Animating move: %s", move.to_algebraic_notation());

        // Check if this is a multi-jump move
        if (move.is_capture() && move.captured_positions != null && move.captured_positions.length > 1) {
            animate_multi_jump(move, state);
        } else {
            animate_single_move(move, state);
        }
    }

    /**
     * Animate a simple single move
     */
    private void animate_single_move(DraughtsMove move, DraughtsGameState state) {
        is_animating = true;
        pending_move = move;

        board_widget.animate_move(
            move.from_position.row,
            move.from_position.col,
            move.to_position.row,
            move.to_position.col
        );
    }

    /**
     * Animate a multi-jump sequence
     */
    private void animate_multi_jump(DraughtsMove move, DraughtsGameState state) {
        logger.debug("Animating multi-jump with %d jumps", move.captured_positions.length);

        is_animating = true;
        pending_move = move;

        // Calculate individual jump segments
        multi_jump_sequence = calculate_jump_segments(move);
        multi_jump_index = 0;

        // Start first segment
        if (multi_jump_sequence.length > 0) {
            animate_jump_segment(multi_jump_sequence[0]);
        }
    }

    /**
     * Animate a single jump segment
     */
    private void animate_jump_segment(DraughtsMove segment) {
        board_widget.animate_move(
            segment.from_position.row,
            segment.from_position.col,
            segment.to_position.row,
            segment.to_position.col
        );
    }

    /**
     * Calculate individual jump segments from a multi-jump move
     */
    private DraughtsMove[] calculate_jump_segments(DraughtsMove move) {
        var segments = new Gee.ArrayList<DraughtsMove>();

        if (move.captured_positions == null || move.captured_positions.length == 0) {
            // Not a capture, just one segment
            segments.add(move);
            return segments.to_array();
        }

        var current_pos = move.from_position;

        // Create a segment for each jump
        foreach (var captured_pos in move.captured_positions) {
            // Calculate landing position (one square past the captured piece)
            int row_delta = captured_pos.row - current_pos.row;
            int col_delta = captured_pos.col - current_pos.col;

            var landing_pos = new BoardPosition(
                captured_pos.row + (row_delta > 0 ? 1 : -1),
                captured_pos.col + (col_delta > 0 ? 1 : -1),
                move.from_position.board_size
            );

            var segment = new DraughtsMove(
                move.piece_id,
                current_pos,
                landing_pos
            );

            segments.add(segment);
            current_pos = landing_pos;
        }

        return segments.to_array();
    }

    /**
     * Handle board animation completion
     */
    private void on_board_animation_completed() {
        // Check if we're in a multi-jump sequence
        if (multi_jump_sequence != null && multi_jump_index < multi_jump_sequence.length - 1) {
            // Continue with next jump segment
            multi_jump_index++;
            animate_jump_segment(multi_jump_sequence[multi_jump_index]);
            return;
        }

        // Animation complete
        is_animating = false;
        multi_jump_sequence = null;
        multi_jump_index = 0;

        if (pending_move != null) {
            var completed_move = pending_move;
            pending_move = null;
            animation_completed(completed_move);
        }
    }

    /**
     * Cancel current animation
     */
    public void cancel_animation() {
        is_animating = false;
        pending_move = null;
        multi_jump_sequence = null;
        multi_jump_index = 0;
    }
}
