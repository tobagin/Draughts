# Quickstart Guide: Draughts Game Rulesets

## Overview
This guide provides step-by-step instructions for testing the draughts game ruleset implementation across all 16 supported variants.

## Prerequisites
- Built application with all 16 variants implemented
- Test game states for each variant
- AI opponent functional at multiple difficulty levels
- Timer system operational

## Quick Validation Tests

### 1. Basic Game Flow Test
**Objective**: Verify core game mechanics work across variants

**Steps**:
1. Launch application
2. Select "International Draughts" variant
3. Start game: Human vs AI (Easy difficulty)
4. Make a legal forward move with a man piece
5. Verify AI responds within 100ms
6. Attempt an illegal backward move with man piece
7. Verify move is rejected with clear feedback
8. Continue until a piece reaches promotion row
9. Verify automatic promotion to king
10. Verify king can move backwards

**Expected Results**:
- All moves validate correctly according to International Draughts rules
- AI responds promptly with legal moves
- Illegal moves are rejected with explanatory messages
- Promotion occurs automatically and correctly
- King movement rules are enforced

### 2. Variant Rule Verification Test
**Objective**: Confirm variant-specific rules are correctly implemented

**Steps**:
1. Test American Checkers:
   - Verify 8x8 board
   - Confirm kings cannot "fly" (multi-square moves)
   - Test backward capture restrictions
2. Test Russian Draughts:
   - Verify 8x8 board
   - Confirm kings can "fly" multiple squares
   - Test unique promotion rules
3. Test International Draughts:
   - Verify 10x10 board
   - Confirm flying kings
   - Test mandatory capture rules
4. Test Canadian Draughts:
   - Verify 12x12 board
   - Confirm largest board variant works

**Expected Results**:
- Each variant enforces its specific movement rules
- Board sizes display correctly (8x8, 10x10, 12x12)
- Flying vs non-flying king behavior differs between variants
- Capture rules vary appropriately per variant

### 3. AI Difficulty Progression Test
**Objective**: Verify AI difficulty levels provide meaningful progression

**Steps**:
1. Start International Draughts game
2. Test Beginner AI (Level 1):
   - Should make moves quickly (<50ms)
   - Should make obvious blunders
   - Should be easily beatable
3. Test Intermediate AI (Level 4):
   - Should take longer to think (50-100ms)
   - Should avoid obvious blunders
   - Should provide moderate challenge
4. Test Expert AI (Level 7):
   - Should use full thinking time (~100ms)
   - Should play strong, tactical moves
   - Should be difficult to beat

**Expected Results**:
- Clear difficulty progression from beginner to expert
- Thinking time increases with difficulty level
- Move quality improves significantly at higher levels
- All difficulty levels complete moves within 100ms limit

### 4. Timer System Test
**Objective**: Verify comprehensive timing controls work correctly

**Steps**:
1. Start new game with Blitz timing (3+2):
   - Verify both players start with 3 minutes
   - Make a move and confirm 2-second increment
   - Verify timer switches between players
2. Test Classical timing (60+30):
   - Confirm longer base time allocation
   - Verify 30-second increment per move
3. Test untimed game:
   - Confirm no time pressure
   - Verify game proceeds normally without timers

**Expected Results**:
- Timers count down accurately
- Increments add correctly after each move
- Time warnings appear at appropriate thresholds
- Games end correctly when time expires

### 5. Accessibility Verification Test
**Objective**: Ensure keyboard navigation and screen reader support

**Steps**:
1. Navigate game board using only keyboard:
   - Use arrow keys to move selection cursor
   - Use Space to select pieces
   - Use Enter to confirm moves
2. Test with screen reader (if available):
   - Verify piece positions are announced
   - Confirm move descriptions are clear
   - Check that game status is announced
3. Test high contrast mode:
   - Verify pieces remain distinguishable
   - Confirm board squares are clearly defined

**Expected Results**:
- All game functions accessible via keyboard
- Screen reader provides clear, useful information
- High contrast mode maintains usability
- Focus indicators are clearly visible

### 6. Undo Functionality Test
**Objective**: Verify basic undo system works correctly

**Steps**:
1. Start any game variant
2. Make 3-4 moves alternating between players
3. Click "Undo" button
4. Verify last move is reversed correctly
5. Verify it's the previous player's turn
6. Attempt to undo when no moves available
7. Verify undo is disabled appropriately

**Expected Results**:
- Last move can be undone successfully
- Game state reverts to previous position exactly
- Turn switches back to previous player
- Undo disabled when no moves to undo
- Timer state reverts correctly (if applicable)

### 7. Draw Condition Test
**Objective**: Verify variant-specific draw detection

**Steps**:
1. Set up test positions for different draw types:
   - Position with no legal moves (stalemate)
   - Position with insufficient material
   - Position with repetition potential
2. Test each condition across multiple variants
3. Verify draw detection varies by variant rules
4. Confirm draw announcements are clear

**Expected Results**:
- Draw conditions detected accurately
- Variant-specific rules applied correctly
- Clear notification of draw reason
- Game ends appropriately with draw result

## Performance Benchmarks

### Response Time Targets
- **UI Updates**: Maintain 60fps during all animations
- **Move Validation**: Complete within 10ms for any position
- **AI Calculation**: Complete within 100ms at all difficulty levels
- **Board Rendering**: Smooth scaling for different window sizes

### Memory Usage Targets
- **Baseline**: <50MB memory usage for new game
- **Extended Play**: <100MB after 100+ moves
- **Variant Switching**: No memory leaks when changing variants
- **AI Calculation**: Temporary memory released after move calculation

## Troubleshooting Common Issues

### Game Logic Problems
- **Illegal moves accepted**: Check variant-specific rule implementation
- **Incorrect promotion**: Verify promotion row calculation for board size
- **Wrong capture behavior**: Review mandatory capture rules for variant

### Performance Issues
- **Slow AI response**: Check algorithm efficiency and depth limits
- **UI lag**: Verify rendering optimizations and frame rate
- **Memory growth**: Look for object leaks in move generation

### Accessibility Issues
- **Poor keyboard navigation**: Check focus management and key bindings
- **Missing announcements**: Verify screen reader integration
- **Low contrast**: Test with different themes and accessibility settings

## Success Criteria

### Functional Requirements Met
- ✅ All 16 variants implemented with correct rules
- ✅ AI difficulty progression from 1-8+ levels
- ✅ Comprehensive timing controls (untimed, blitz, rapid, classical, Fischer)
- ✅ Basic undo functionality working
- ✅ Variant-specific draw condition detection

### Non-Functional Requirements Met
- ✅ <100ms AI response time at all difficulty levels
- ✅ 60fps UI performance during gameplay
- ✅ Full keyboard accessibility
- ✅ Screen reader compatibility
- ✅ GNOME Human Interface Guidelines compliance

### Quality Assurance Passed
- ✅ No illegal moves accepted by any variant
- ✅ All game-ending conditions detected correctly
- ✅ Timer system accurate and reliable
- ✅ Memory usage stable during extended play
- ✅ Accessibility features functional

## Next Steps After Validation
1. Conduct user acceptance testing with draughts players
2. Performance optimization based on real-world usage
3. Advanced features: game saving, tournament modes, online play
4. Localization for international users
5. Additional accessibility enhancements based on user feedback