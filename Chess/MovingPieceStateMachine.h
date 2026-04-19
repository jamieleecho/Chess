//
//  MovingPieceStateMachine.h
//  Chess
//
//  Tracks a piece sliding from one square to another. Driven by the same
//  tick as HighlightedSquareStateMachine. Carries enough identifying info
//  for either 2D (icon name) or 3D (piece type + color) to render the
//  piece in transit.
//

#import <Foundation/Foundation.h>


@interface MovingPieceStateMachine : NSObject

// Full animation duration (excluding any pre-delay).
+ (NSTimeInterval)animationDuration;

- (id)initFromRow:(int)fromRow column:(int)fromCol
            toRow:(int)toRow   column:(int)toCol
         iconName:(NSString *)iconName
        pieceType:(int)pieceType
       pieceColor:(int)pieceColor
 capturedIconName:(NSString *)capturedIconName
capturedPieceType:(int)capturedPieceType
capturedPieceColor:(int)capturedPieceColor
       afterDelay:(NSTimeInterval)delay;

- (void)tick;

- (int)fromRow;
- (int)fromColumn;
- (int)toRow;
- (int)toColumn;
- (NSString *)iconName;
- (int)pieceType;
- (int)pieceColor;

// Captured piece that was sitting on the destination square when the
// animation began. nil / 0 / 0 means no capture. Drawn at the dest
// throughout the animation; removed automatically when isDone goes YES.
- (NSString *)capturedIconName;
- (int)capturedPieceType;
- (int)capturedPieceColor;

- (double)progress;       // 0.0 (at source) .. 1.0 (at dest), eased
- (BOOL)isDone;

@end
