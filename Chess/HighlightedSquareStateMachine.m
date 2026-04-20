//
//  HighlightedSquareStateMachine.m
//  Chess
//
//  Created by Jamie Cho on 4/7/26.
//

#import "HighlightedSquareStateMachine.h"
#import <QuartzCore/QuartzCore.h>


#define BLINK_INTERVAL  0.125   // seconds per on/off phase
#define PAUSE_INTERVAL  0.15    // pause (off) between cycle 1 and cycle 2
#define SEQUENCE_GAP    0.20    // extra gap between sequenced highlights


@implementation HighlightedSquareStateMachine {
    CFTimeInterval _startTime;
    NSTimeInterval _delay;
}

+ (NSTimeInterval)blinkDuration {
    // on + off + pause + on + off
    return BLINK_INTERVAL * 4 + PAUSE_INTERVAL;
}

+ (NSTimeInterval)delayForNextInSequence {
    return [self blinkDuration] + SEQUENCE_GAP;
}

+ (NSTimeInterval)sequenceGap {
    return SEQUENCE_GAP;
}

- (instancetype)initWithRow:(int)row column:(int)column {
    return [self initWithRow:row column:column afterDelay:0.0];
}

- (instancetype)initWithRow:(int)row column:(int)column afterDelay:(NSTimeInterval)delay {
    if (self = [super init]) {
        _row = row;
        _column = column;
        _delay = (delay > 0.0) ? delay : 0.0;
        _isHighlighted = (_delay == 0.0);
        _startTime = CACurrentMediaTime();
    }
    return self;
}

- (void)tick {
    CFTimeInterval elapsed = CACurrentMediaTime() - _startTime;
    if (elapsed < _delay) {
        _isHighlighted = NO;
        _isDone = NO;
        return;
    }
    CFTimeInterval t  = elapsed - _delay;
    CFTimeInterval t1 = BLINK_INTERVAL;                 // end of cycle 1 on
    CFTimeInterval t2 = t1 + BLINK_INTERVAL;            // end of cycle 1 off
    CFTimeInterval t3 = t2 + PAUSE_INTERVAL;            // end of mid pause
    CFTimeInterval t4 = t3 + BLINK_INTERVAL;            // end of cycle 2 on
    CFTimeInterval t5 = t4 + BLINK_INTERVAL;            // end of cycle 2 off

    if (t >= t5) {
        _isHighlighted = NO;
        _isDone = YES;
    } else if (t < t1 || (t >= t3 && t < t4)) {
        _isHighlighted = YES;
        _isDone = NO;
    } else {
        _isHighlighted = NO;
        _isDone = NO;
    }
}

@end
