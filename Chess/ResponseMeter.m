#import <AppKit/AppKit.h>

// own interface
#import "ResponseMeter.h"

// PS
#import <AppKit/NSGraphics.h>

// portability layer
#import "gnuglue.h"		// response_time, elapsed_time

#import "ps.h"

@implementation ResponseMeter {
    float _maxRatio;
}

- (void)displayFilled
{
	NSRect f = [self bounds];

    _maxRatio = 1.0;

    [self lockFocus];
    PSgsave();

    PSsetgray( NSWhite );
    PSrectfill(0.0, 0.0, f.size.width, f.size.height);

    PSsetlinewidth( (float)2.0 );
    PSsetgray( NSBlack );
    PSrectstroke(0.0, 0.0, f.size.width, f.size.height);

    PSgrestore();
    [[self window] flushWindow];
    [self unlockFocus];

    return;
}

- (void)drawRect: (NSRect)f
{
    int res_time;

    f = self.frame;

    PSgsave();
    PSsetgray( (float)0.5 );
    PSrectfill(0.0, 0.0, f.size.width, f.size.height);

    if( res_time = response_time() ) {
	float ratio = elapsed_time() / (float)res_time;
	if( ratio > 1.0 )  ratio = 1.0;
	// ExtraTime can grow mid-search and drop the raw ratio. Clamp to a
	// per-move high-water mark so the bar only ever advances.
	if( ratio < _maxRatio )  ratio = _maxRatio;
	else                     _maxRatio = ratio;
	PSsetgray( NSWhite );
	PSrectfill( (float)0.0, (float)0.0,
			(float)( f.size.width * ratio ), f.size.height );
    }
    else {
	_maxRatio = 0.0;
    }

    PSsetlinewidth( (float)2.0 );
    PSsetgray( NSBlack );
    PSrectstroke(0.0, 0.0, f.size.width, f.size.height);
    PSgrestore();

    return;
}

@end
