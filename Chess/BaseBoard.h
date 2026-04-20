//
//  BaseBoard.h
//  Chess
//
//  Created by Jamie Cho on 4/7/26.
//

#import <Cocoa/Cocoa.h>
#import "HighlightedSquareStateMachine.h"
#import "MovingPieceStateMachine.h"


@interface BaseBoard : NSControl {
    NSMutableArray *_highlights;      // of HighlightedSquareStateMachine
    NSMutableArray *_movingPieces;    // of MovingPieceStateMachine
    NSTimer        *_animationTimer;  // runloop retains; we hold a weak ref
    BOOL            _isDragging;
    int             _dragRow;
    int             _dragCol;
    NSPoint         _dragPoint;       // cursor, view coords
    NSPoint         _dragOffset;      // cursorPoint - squareOrigin at pickup
}

- (void)highlightSquareAt:(int)row :(int)col;
- (void)highlightSquareAt:(int)row :(int)col afterDelay:(NSTimeInterval)delay;
- (void)flashSquareAt:(int)row :(int)col;
- (void)unhighlightSquareAt:(int)row :(int)col;

- (NSArray *)activeHighlights;       // for subclass drawRect:
- (NSArray *)activeMovingPieces;     // for subclass drawRect:
- (BOOL)hasActiveAnimations;

// Subclasses implement this — they know how to read piece info out of
// their own Square/Square3D at (fromRow, fromCol) and construct a
// MovingPieceStateMachine.
- (void)animatePieceFrom:(int)fromRow :(int)fromCol
                      to:(int)toRow   :(int)toCol
              afterDelay:(NSTimeInterval)delay;

// Used by subclass implementations of animatePieceFrom:to:afterDelay: to
// enqueue a state machine once they've constructed it.
- (void)enqueueMovingPiece:(MovingPieceStateMachine *)mp;

// Drag state — subclass drawRect: reads these to render the piece at the
// cursor and skip its home-square piece.
- (BOOL)isDragging;
- (int)draggedRow;
- (int)draggedColumn;
- (NSPoint)dragPoint;
- (NSPoint)dragOffset;

- (void)beginDragFromRow:(int)row column:(int)col
             cursorPoint:(NSPoint)point
                  offset:(NSPoint)offset;
- (void)updateDragPoint:(NSPoint)point;
- (void)endDrag;

@end
