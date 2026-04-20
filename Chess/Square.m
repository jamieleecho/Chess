#import "Square.h"

// portability layer
#import "gnuglue.h"			// sleep_microsecs, floor_value

#import "ps.h"

@implementation Square

/*
  This class represents one square on a chess board.  It has a color
  and may contain a piece.
*/

- (void) setBackground: (float)b
{
    background = b;
    return;
}

- (float) background
{
    return background;
}

- (void) setImage: (NSImage *)i
{
    icon = [i name];
    return;
}

- (NSImage *) image
{
    return [NSImage imageNamed: icon];
}

- (NSString *)imageName
{
    if (icon) return icon;
    else return @"";
}
- (void) setPieceType: (int)t
{
    pieceType = t;
    return;
}

- (int) pieceType
{
    return pieceType;
}

- (void) drawWithFrame: (NSRect)f inView: (NSView *)v
{
    PSsetgray( background );
    PSrectfill( f.origin.x, f.origin.y, f.size.width, f.size.height );
    [self drawInteriorWithFrame:f inView:v];
    return;
}

- (void) drawBackground: (NSRect)f inView: (NSView *)v
{
    PSsetgray( background );
    PSrectfill( f.origin.x, f.origin.y, f.size.width, f.size.height );
    return;
}

- (void) highlight: (NSRect)f inView: (NSView *)v
{
    f = NSInsetRect(f, (float)1.0 , (float)1.0);
    PSgsave();
    PSsetlinewidth( (float)2.0 );
    PSsetgray( 1.0 );
    PSrectstroke ( f.origin.x, f.origin.y, f.size.width, f.size.height );
    PSWait();
    sleep_microsecs( (unsigned)15000 );

    PSsetgray( 0.0 );
    PSrectstroke ( f.origin.x, f.origin.y, f.size.width, f.size.height );
    PSWait();
    sleep_microsecs( (unsigned)15000 );

    PSsetgray( 1.0 );
    PSrectstroke ( f.origin.x, f.origin.y, f.size.width, f.size.height );
    PSWait();
    sleep_microsecs( (unsigned)15000 );

    PSsetgray( background );
    PSrectstroke ( f.origin.x, f.origin.y, f.size.width, f.size.height );
    PSWait();

    PSgrestore();
    return;
}

- (void) drawInteriorWithFrame: (NSRect)r inView: (NSView *)v
/*
  Draw the chess piece.
*/
{
    NSPoint p;
    NSSize  s;
    NSImage *bitmap;

    if( !icon )
	return;

    /* Composite the piece icon in the center of the rect. */
    bitmap = [NSImage imageNamed: icon];
    if ( ! bitmap ) {
	NSString  *path = [[NSBundle mainBundle] pathForImageResource: icon];
	bitmap = [[NSImage alloc] initWithContentsOfFile: path];
	[bitmap setName: icon];
    }

    s = [bitmap size];
    p.x = (float) floor_value( (double)(((r.size.width  - s.width)  / 2.0) + r.origin.x) );
    p.y = (float) floor_value( (double)(((r.size.height - s.height) / 2.0) + r.origin.y) );
    [bitmap compositeToPoint: p operation: NSCompositingOperationSourceOver];
    return;
}

@end
