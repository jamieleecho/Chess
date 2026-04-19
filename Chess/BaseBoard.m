//
//  BaseBoard.m
//  Chess
//
//  Created by Jamie Cho on 4/7/26.
//

#import "BaseBoard.h"


#define ANIMATION_TICK_HZ 30.0


@implementation BaseBoard

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) [self baseInit];
    return self;
}

- (id)initWithFrame:(NSRect)f {
    if (self = [super initWithFrame:f]) [self baseInit];
    return self;
}

- (void)baseInit {
    _highlights = [[NSMutableArray alloc] init];
    _movingPieces = [[NSMutableArray alloc] init];
}

- (void)dealloc {
    [_animationTimer invalidate];
    [_highlights release];
    [_movingPieces release];
    [super dealloc];
}

- (NSArray *)activeHighlights   { return _highlights; }
- (NSArray *)activeMovingPieces { return _movingPieces; }

- (void)ensureTimerRunning {
    if (!_animationTimer) {
        _animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / ANIMATION_TICK_HZ
                                                           target:self
                                                         selector:@selector(animationTick:)
                                                         userInfo:nil
                                                          repeats:YES];
    }
}

- (void)highlightSquareAt:(int)row :(int)col {
    [self highlightSquareAt:row :col afterDelay:0.0];
}

- (void)highlightSquareAt:(int)row :(int)col afterDelay:(NSTimeInterval)delay {
    HighlightedSquareStateMachine *h =
        [[HighlightedSquareStateMachine alloc] initWithRow:row
                                                    column:col
                                                afterDelay:delay];
    [_highlights addObject:h];
    [h release];
    [self ensureTimerRunning];
    [self setNeedsDisplay:YES];
}

- (void)flashSquareAt:(int)row :(int)col {
    // no-op for now. Called from Board3D.mouseDown: on every drag event as a
    // hover cue; forwarding to highlightSquareAt: accumulated blinking
    // state machines faster than they could decay. Rewire when the drag
    // path is ported off lockFocus.
}

- (void)unhighlightSquareAt:(int)row :(int)col {
    // no-op for now — see flashSquareAt:.
}

// Subclasses override; default does nothing so it's safe if ever called on
// a plain BaseBoard.
- (void)animatePieceFrom:(int)fromRow :(int)fromCol
                      to:(int)toRow   :(int)toCol
              afterDelay:(NSTimeInterval)delay {
}

- (void)enqueueMovingPiece:(MovingPieceStateMachine *)mp {
    if (!mp) return;
    [_movingPieces addObject:mp];
    [self ensureTimerRunning];
    [self setNeedsDisplay:YES];
}

- (BOOL)isDragging        { return _isDragging; }
- (int)draggedRow         { return _dragRow; }
- (int)draggedColumn      { return _dragCol; }
- (NSPoint)dragPoint      { return _dragPoint; }
- (NSPoint)dragOffset     { return _dragOffset; }

- (void)beginDragFromRow:(int)row column:(int)col
             cursorPoint:(NSPoint)point
                  offset:(NSPoint)offset {
    _isDragging = YES;
    _dragRow = row;
    _dragCol = col;
    _dragPoint = point;
    _dragOffset = offset;
    [self setNeedsDisplay:YES];
}

- (void)updateDragPoint:(NSPoint)point {
    _dragPoint = point;
    [self setNeedsDisplay:YES];
}

- (void)endDrag {
    _isDragging = NO;
    [self setNeedsDisplay:YES];
}

- (void)animationTick:(NSTimer *)t {
    NSMutableIndexSet *doneHL = [NSMutableIndexSet indexSet];
    NSUInteger i = 0;
    for (HighlightedSquareStateMachine *h in _highlights) {
        [h tick];
        if (h.isDone) [doneHL addIndex:i];
        i++;
    }
    [_highlights removeObjectsAtIndexes:doneHL];

    NSMutableIndexSet *doneMP = [NSMutableIndexSet indexSet];
    i = 0;
    for (MovingPieceStateMachine *mp in _movingPieces) {
        [mp tick];
        if ([mp isDone]) [doneMP addIndex:i];
        i++;
    }
    [_movingPieces removeObjectsAtIndexes:doneMP];

    [self setNeedsDisplay:YES];
    if (_highlights.count == 0 && _movingPieces.count == 0) {
        [_animationTimer invalidate];
        _animationTimer = nil;
    }
}

@end
