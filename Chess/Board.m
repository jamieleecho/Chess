//#import <AppKit/AppKit.h>

#import <AppKit/NSImage.h>
#import <AppKit/NSPrintInfo.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSGraphics.h>		// NSBeep
#import <Foundation/NSString.h>
#import <Foundation/NSGeometry.h>	// NSZeroPoint
#import <Foundation/NSException.h>

#include <math.h>

// own interface
#import "Board.h"

// messaging objects
#import "Square.h"
#import "Chess.h"			// NSApp

// portability layer
#import "gnuglue.h"			// floor_value

#import "ps.h"

// square colors
#define BLACK_SQUARE_COLOR  (0.5)
#define WHITE_SQUARE_COLOR  (5.0 / 6.0)

// private functions

static NSString  *whitePiece( p )
short  p;
{
    switch( p ) {
	case PAWN:	return @"white_pawn";
	case ROOK:	return @"white_rook";
	case KNIGHT:	return @"white_knight";
	case BISHOP:	return @"white_bishop";
	case KING:	return @"white_king";
	case QUEEN:	return @"white_queen";
	default:	break;
    }
    return nil;
}

static NSString  *blackPiece( p )
short  p;
{
    switch( p ) {
	case PAWN:	return @"black_pawn";
	case ROOK:	return @"black_rook";
	case KNIGHT:	return @"black_knight";
	case BISHOP:	return @"black_bishop";
	case KING:	return @"black_king";
	case QUEEN:	return @"black_queen";
	default:	break;
    }
    return nil;
}

// Board implementations

@implementation Board

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame: (NSRect) f {
    if (self = [super initWithFrame:f]) {
        [self commonInit];
    }
    return self;
}

- (void)animatePieceFrom:(int)fromRow :(int)fromCol
                      to:(int)toRow   :(int)toCol
              afterDelay:(NSTimeInterval)delay
{
    NSString *icon = [square[fromRow][fromCol] imageName];
    if ([icon isEqual:@""]) icon = nil;
    if (!icon) return;
    NSString *capIcon = [square[toRow][toCol] imageName];
    if ([capIcon isEqual:@""]) capIcon = nil;
    MovingPieceStateMachine *mp =
        [[MovingPieceStateMachine alloc] initFromRow:fromRow column:fromCol
                                               toRow:toRow   column:toCol
                                            iconName:icon
                                           pieceType:0
                                          pieceColor:0
                                    capturedIconName:capIcon
                                   capturedPieceType:0
                                  capturedPieceColor:0
                                          afterDelay:delay];
    [self enqueueMovingPiece:mp];
}


- (void)commonInit
{
	int r, c;
	NSSize size;

    self.enabled = YES;
    NSRect f = self.frame;
	[self allocateGState];
	size.width  = f.size.width  / 8.0;
	size.height = f.size.height / 8.0;
	backBitmap = [[NSImage alloc] initWithSize: size];

	for( r = 0; r < 8; r++ ) {
            for( c = 0; c < 8; c++ ) {
		Square  *aSquare;
		BOOL  even;
		float  bk;
		aSquare = [[Square alloc] init];
		even = ( ! ((r + c) % 2) );
		bk = ( even ) ? BLACK_SQUARE_COLOR : WHITE_SQUARE_COLOR;
		[aSquare setBackground: bk];
		square[r][c] = aSquare;
	    }
	}
	[self setupPieces];
}

- (void) setupPieces
{
    short  *pieces = default_pieces();
    short  *colors = default_colors();
    [self layoutBoard: pieces color: colors];
    return;
}

- (void) layoutBoard: (short *)p color: (short *)c
{
    int  sq;
    for( sq = 0; sq < SQUARE_COUNT; sq++ ) {
	int  row = sq / 8;
	int  col = sq % 8;
	[self placePiece: p[sq] at: row: col color: c[sq]];
    }
    return;
}

- (void) placePiece:  (short)p at: (int)row : (int)col color: (short)c
{
    Square    *theSquare = square[row][col];
    NSString  *piece = ( c == WHITE ) ? whitePiece( p ) : blackPiece( p );
    NSImage   *image = ( piece ) ? [NSImage imageNamed: piece] : nil;
    [theSquare setImage: image];
    return;
}

- (void) slidePieceFrom: (int)row1 : (int)col1 to: (int)row2 : (int)col2
{
    Square  *theSquare;
    NSString *icon;
    int  controlGState;
    NSRect  pieceRect;
    NSPoint  backP, endP, winP, roundedBackP;
    float  incX, incY;
    int  i, increments;

    theSquare = square[row1][col1];
    //icon = [[theSquare image] name];
    icon = [theSquare imageName];
    if( [icon isEqual: @""] )
	icon = nil;		// ?
    if( ! icon )
	return;
    controlGState = [self gState];

    pieceRect.size.width  = (float)floor_value( (double)([self frame].size.width  / 8.0) );
    pieceRect.size.height = (float)floor_value( (double)([self frame].size.height / 8.0) );

    backP.x = ( (float)col1 * pieceRect.size.width  );
    backP.y = ( (float)row1 * pieceRect.size.height );
    endP.x  = ( (float)col2 * pieceRect.size.width  );
    endP.y  = ( (float)row2 * pieceRect.size.height );

    [self lockFocus];
    PSgsave();
    
    /* Draw over the piece we are moving. */
    pieceRect.origin.x = col1 * pieceRect.size.width;
    pieceRect.origin.y = row1 * pieceRect.size.height;
    [theSquare drawBackground: pieceRect inView: self];

    /* Save background */ 
    [backBitmap lockFocus];
    PSgsave();
	roundedBackP.x = floor(backP.x); 
	roundedBackP.y = floor(backP.y);
	winP = [[self superview] convertPoint: roundedBackP fromView: self];
    PScomposite( winP.x, winP.y, pieceRect.size.width, pieceRect.size.height,
	controlGState, (float)0.0, (float)0.0, NSCompositeCopy );
    PSgrestore();
    [backBitmap unlockFocus];

    incX = endP.x - backP.x;
    incY = endP.y - backP.y;
    increments = (int) MAX( ABS(incX), ABS(incY) ) / 7;
    incX = incX / increments;
    incY = incY / increments;

    for( i = 0; i < increments; i++ ){

	/* Restore old background */
	[self lockFocus];
	[backBitmap compositeToPoint: backP operation: NSCompositeCopy];
	[self unlockFocus];
	[[self window] flushWindow];

	/* Save new background */
	backP.x += incX;
	backP.y += incY;

	[backBitmap lockFocus];
	PSgsave();
	roundedBackP.x = floor(backP.x); 
	roundedBackP.y = floor(backP.y);
	pieceRect.origin = roundedBackP;
	winP = [[self superview] convertPoint: roundedBackP fromView: self];
	PScomposite( winP.x, winP.y, pieceRect.size.width,
			pieceRect.size.height, controlGState, (float)0.0,
			(float)0.0, NSCompositeCopy );
	PSgrestore();
	[backBitmap unlockFocus];

	/* Draw piece at new location. */
	[theSquare drawInteriorWithFrame: pieceRect inView: self];
	[[self window] flushWindow];
	PSsetgray( NSBlack );
	PSsetlinewidth( (float)2.0 );
	PSclippath();
	PSstroke();
	[[self window] flushWindow];
    }
 
    PSgrestore();
    [self unlockFocus];
    return;
}

- (int) pieceAt: (int)row : (int)col
{
    if( row >= 0 && col >= 0 ) {
	Square  *theSquare = square[row][col];
	return( [theSquare pieceType] );
    }
    return (int)NO_PIECE;
}

- (void) print: (id)sender
{
    NSPrintInfo	*pi = [NSPrintInfo sharedPrintInfo];
    NSSize ps = [pi paperSize];
    NSSize fs = [self frame].size;
    float hm = (ps.width  - fs.width)  / 2.0;
    float vm = (ps.height - fs.height) / 2.0;

    [pi setLeftMargin:   hm];
    [pi setRightMargin:  hm];
    [pi setTopMargin:    vm];
    [pi setBottomMargin: vm];

    [self lockFocus];
    printImage = [[NSBitmapImageRep alloc] initWithFocusedViewRect: [self bounds]];
    [self unlockFocus];

    [super print: sender];
    printImage = nil;
    return;
}

- (void) drawRect: (NSRect)f
{
    if( ! printImage ) {
	int r, c;
	NSRect cr;

	PSgsave();
	cr.size.width  = self.frame.size.width  / 8.0;
	cr.size.height = self.frame.size.height / 8.0;
	int dR = [self isDragging] ? [self draggedRow]    : -1;
	int dC = [self isDragging] ? [self draggedColumn] : -1;
	NSArray *moving = [self activeMovingPieces];
	for( r = 0; r < 8; r++ ) {
	    cr.origin.y = r * cr.size.height;
	    for( c = 0; c < 8; c++ ) {
		Square  *theSquare = square[r][c];
		cr.origin.x = c * cr.size.width;
		BOOL skip = (r == dR && c == dC);
		if (!skip) {
		    for (MovingPieceStateMachine *mp in moving) {
			if ((r == [mp fromRow] && c == [mp fromColumn]) ||
			    (r == [mp toRow]   && c == [mp toColumn])) {
			    skip = YES; break;
			}
		    }
		}
		if (skip) {
		    [theSquare drawBackground: cr inView: self];
		} else {
		    [theSquare drawWithFrame: cr inView: self];
		}
	    }
	}
	PSsetgray( NSBlack );
	PSsetlinewidth( (float)2.0 );
	PSclippath();
	PSstroke();
	PSgrestore();

	float hw = self.frame.size.width  / 8.0;
	float hh = self.frame.size.height / 8.0;
	for (HighlightedSquareStateMachine *h in [self activeHighlights]) {
	    if (!h.isHighlighted) continue;
	    NSRect hr = NSInsetRect(NSMakeRect(h.column * hw, h.row * hh, hw, hh), 2.0, 2.0);
	    [[NSColor whiteColor] set];
	    NSBezierPath *hp = [NSBezierPath bezierPathWithRect:hr];
	    [hp setLineWidth:4.0];
	    [hp stroke];
	}

	for (MovingPieceStateMachine *mp in moving) {
	    // Captured piece (if any) stays visible at dest until the
	    // animation completes — drawn before the attacker so the
	    // attacker covers it as it arrives.
	    NSString *capIcon = [mp capturedIconName];
	    if (capIcon && ![capIcon isEqual:@""]) {
		NSImage *capImg = [NSImage imageNamed:capIcon];
		if (capImg) {
		    float cx = (float)[mp toColumn] * hw;
		    float cy = (float)[mp toRow]    * hh;
		    NSSize csz = [capImg size];
		    NSPoint co;
		    co.x = floor((hw - csz.width)  / 2.0 + cx);
		    co.y = floor((hh - csz.height) / 2.0 + cy);
		    [capImg drawAtPoint: co
			       fromRect: NSZeroRect
			      operation: NSCompositingOperationSourceOver
			       fraction: 1.0];
		}
	    }

	    NSString *icon = [mp iconName];
	    if (!icon || [icon isEqual:@""]) continue;
	    NSImage *img = [NSImage imageNamed:icon];
	    if (!img) continue;
	    double p = [mp progress];
	    float srcX = (float)[mp fromColumn] * hw;
	    float srcY = (float)[mp fromRow]    * hh;
	    float dstX = (float)[mp toColumn]   * hw;
	    float dstY = (float)[mp toRow]      * hh;
	    float px = srcX + (float)(p * (dstX - srcX));
	    float py = srcY + (float)(p * (dstY - srcY));
	    NSSize sz = [img size];
	    NSPoint origin;
	    origin.x = floor((hw - sz.width)  / 2.0 + px);
	    origin.y = floor((hh - sz.height) / 2.0 + py);
	    [img drawAtPoint: origin
		    fromRect: NSZeroRect
		   operation: NSCompositingOperationSourceOver
		    fraction: 1.0];
	}

	if ([self isDragging]) {
	    NSPoint dp  = [self dragPoint];
	    int dropR = floor_value((double)(dp.y / hh));
	    int dropC = floor_value((double)(dp.x / hw));
	    if (dropR >= 0 && dropR < 8 && dropC >= 0 && dropC < 8) {
		NSRect dr = NSInsetRect(NSMakeRect(dropC * hw, dropR * hh, hw, hh), 2.0, 2.0);
		[[NSColor whiteColor] set];
		NSBezierPath *dp2 = [NSBezierPath bezierPathWithRect:dr];
		[dp2 setLineWidth:4.0];
		[dp2 stroke];
	    }

	    Square *ds = square[dR][dC];
	    NSImage *img = [ds image];
	    if (img) {
		NSPoint off = [self dragOffset];
		NSSize sz = [img size];
		NSPoint imgOrigin;
		imgOrigin.x = floor((hw - sz.width)  / 2.0 + dp.x - off.x);
		imgOrigin.y = floor((hh - sz.height) / 2.0 + dp.y - off.y);
		[img drawAtPoint: imgOrigin
			fromRect: NSZeroRect
		       operation: NSCompositingOperationSourceOver
			fraction: 1.0];
	    }
	}
    }
    else {
	[printImage draw];
    }
    return;
}

- (void) mouseDown: (NSEvent *)event
{
    if ([NSApp bothsides]) { NSBeep(); return; }
    if ([NSApp finished])  { [NSApp finishedAlert]; return; }
    if (![self isEnabled]) return;

    float cw = self.frame.size.width  / 8.0;
    float ch = self.frame.size.height / 8.0;
    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    int r = floor_value((double)(p.y / ch));
    int c = floor_value((double)(p.x / cw));
    if (r < 0 || r > 7 || c < 0 || c > 7) return;

    Square *theSquare = square[r][c];
    NSString *icon = [theSquare imageName];
    if ([icon isEqual:@""] || !icon) return;

    NSPoint offset = NSMakePoint(p.x - (float)c * cw, p.y - (float)r * ch);
    [self beginDragFromRow:r column:c cursorPoint:p offset:offset];

    NSException *exception = nil;
    NS_DURING
	while ([event type] != NSEventTypeLeftMouseUp) {
	    NSEventMask mask = NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged;
	    event = [[self window] nextEventMatchingMask:mask];
	    p = [self convertPoint:[event locationInWindow] fromView:nil];
	    [self updateDragPoint:p];
	}
    NS_HANDLER
	exception = localException;
    NS_ENDHANDLER

    int r2 = floor_value((double)(p.y / ch));
    int c2 = floor_value((double)(p.x / cw));
    [self endDrag];

    if (r2 != r || c2 != c) {
	if (r2 >= 0 && r2 < 8 && c2 >= 0 && c2 < 8) {
	    if (![NSApp makeMoveFrom:r :c to:r2 :c2]) {
		PSWait();
	    }
	}
    }
    [self display];

    if (exception) [exception raise];
    return;
}

@end

// Local Variables:
// tab-width: 8
// End:
