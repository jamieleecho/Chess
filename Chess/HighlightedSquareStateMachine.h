//
//  HighlightedSquareStateMachine.h
//  Chess
//
//  Created by Jamie Cho on 4/7/26.
//

#import <Foundation/Foundation.h>


@interface HighlightedSquareStateMachine : NSObject

@property (nonatomic, readonly) int row;
@property (nonatomic, readonly) int column;
@property (nonatomic, readonly) BOOL isHighlighted;
@property (nonatomic, readonly) BOOL isDone;

// Full duration of a single blink animation (both on-off cycles plus the
// mid-cycle pause).
+ (NSTimeInterval)blinkDuration;

// Delay to use for a follow-on highlight in a sequence (source → dest):
// blinkDuration plus an extra visual gap.
+ (NSTimeInterval)delayForNextInSequence;

// Just the extra visual gap — useful when composing with other animations
// (e.g. highlight → move → highlight).
+ (NSTimeInterval)sequenceGap;

- (instancetype)initWithRow:(int)row column:(int)column;
- (instancetype)initWithRow:(int)row column:(int)column afterDelay:(NSTimeInterval)delay;
- (void)tick;

@end
