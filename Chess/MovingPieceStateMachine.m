//
//  MovingPieceStateMachine.m
//  Chess
//

#import "MovingPieceStateMachine.h"
#import "HighlightedSquareStateMachine.h"
#import <QuartzCore/QuartzCore.h>


@implementation MovingPieceStateMachine {
    int _fromRow, _fromColumn;
    int _toRow,   _toColumn;
    NSString *_iconName;
    int _pieceType;
    int _pieceColor;
    NSString *_capturedIconName;
    int _capturedPieceType;
    int _capturedPieceColor;
    CFTimeInterval _startTime;
    NSTimeInterval _delay;
    double _progress;
    BOOL   _isDone;
}

+ (NSTimeInterval)animationDuration {
    // Synced with the source/dest blink so the piece arrives as the
    // source blink completes and the dest blink begins.
    return [HighlightedSquareStateMachine blinkDuration];
}

- (id)initFromRow:(int)fromRow column:(int)fromCol
            toRow:(int)toRow   column:(int)toCol
         iconName:(NSString *)iconName
        pieceType:(int)pieceType
       pieceColor:(int)pieceColor
 capturedIconName:(NSString *)capturedIconName
capturedPieceType:(int)capturedPieceType
capturedPieceColor:(int)capturedPieceColor
       afterDelay:(NSTimeInterval)delay {
    if (self = [super init]) {
        _fromRow = fromRow;
        _fromColumn = fromCol;
        _toRow = toRow;
        _toColumn = toCol;
        _iconName = [iconName copy];
        _pieceType = pieceType;
        _pieceColor = pieceColor;
        _capturedIconName = [capturedIconName copy];
        _capturedPieceType = capturedPieceType;
        _capturedPieceColor = capturedPieceColor;
        _delay = (delay > 0.0) ? delay : 0.0;
        _startTime = CACurrentMediaTime();
        _progress = 0.0;
        _isDone = NO;
    }
    return self;
}

- (void)tick {
    CFTimeInterval elapsed = CACurrentMediaTime() - _startTime;
    if (elapsed < _delay) {
        _progress = 0.0;
        _isDone = NO;
        return;
    }
    CFTimeInterval t = elapsed - _delay;
    NSTimeInterval dur = [[self class] animationDuration];
    if (t >= dur) {
        _progress = 1.0;
        _isDone = YES;
        return;
    }
    double p = t / dur;
    // Smoothstep ease in/out: 3p^2 - 2p^3
    _progress = p * p * (3.0 - 2.0 * p);
    _isDone = NO;
}

- (int)fromRow        { return _fromRow; }
- (int)fromColumn     { return _fromColumn; }
- (int)toRow          { return _toRow; }
- (int)toColumn       { return _toColumn; }
- (NSString *)iconName          { return _iconName; }
- (int)pieceType                { return _pieceType; }
- (int)pieceColor               { return _pieceColor; }
- (NSString *)capturedIconName  { return _capturedIconName; }
- (int)capturedPieceType        { return _capturedPieceType; }
- (int)capturedPieceColor       { return _capturedPieceColor; }
- (double)progress              { return _progress; }
- (BOOL)isDone                  { return _isDone; }

@end
