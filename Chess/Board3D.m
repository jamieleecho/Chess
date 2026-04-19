//#import <AppKit/AppKit.h>

#import <AppKit/NSPrintOperation.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSPrintInfo.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSGraphics.h>		// NSBeep
#import <Foundation/NSBundle.h>
#import <Foundation/NSGeometry.h>	// NSMakeSize, NSZeroPoint
#import <Foundation/NSException.h>

#include <math.h>

// own interface
#import "Board3D.h"

// messaging objects
#import "Square3D.h"
#import "Chess.h"			// NSApp

// portability layer
#import "gnuglue.h"			// floor_value, sleep_microsecs, ...

#import "ps.h"

// piece size
#define PIECE_WIDTH_3D		(float)55.0
#define PIECE_HEIGHT_3D		(float)95.0

// back store size
#define BACK_STORE_WIDTH	(float)80.0
#define BACK_STORE_HEIGHT	(float)110.0

/*  Each set of points describes the vertical lines along the board. */
struct NXLine {
  NSPoint a, b;
};

#define BASE_X 89

static struct NXLine vertical[] = {
  {{BASE_X,122},    {BASE_X+61, 467}},
  {{BASE_X+71,122}, {BASE_X+111,467}},
  {{BASE_X+135,122},{BASE_X+162,467}},
  {{BASE_X+200,122},{BASE_X+212,467}},
  {{BASE_X+265,122},{BASE_X+265,467}},
  {{BASE_X+330,122},{BASE_X+316,467}},
  {{BASE_X+393,122},{BASE_X+367,467}},
  {{BASE_X+459,122},{BASE_X+419,467}},
  {{BASE_X+524,122},{BASE_X+469,467}}
};

/* Each coordinate describes the y value of each line of the board. */
#define BASE_Y  132

static float horizontal[] = {
  BASE_Y, BASE_Y+54, BASE_Y+106, BASE_Y+153,
  BASE_Y+196, BASE_Y+237, BASE_Y+277, BASE_Y+312, BASE_Y+345
};


// private functions

static void squareOrigin( int r, int c, float *x, float *y )
{
    float dx, m, b;

    dx = (vertical[c].a.x -  vertical[c].b.x);
    m  = (vertical[c].a.y -  vertical[c].b.y) / dx;
    b  =  vertical[c].b.y - (vertical[c].b.x  * m);
    *x = (dx) ? ((horizontal[r] - b) / m) : vertical[c].a.x;
    *y = horizontal[r];
    return;
}

static void squareBounds( int r, int c, NSPoint *p1, NSPoint *p2, NSPoint *p3, NSPoint *p4 )
/*
   (p2)----(p4)
    |        |
    |        |
   (p1)----(p3)
*/
{
    float dx, m, b;

    dx = (vertical[c].a.x -  vertical[c].b.x);
    m  = (vertical[c].a.y -  vertical[c].b.y) / dx;
    b  =  vertical[c].b.y - (vertical[c].b.x  * m);
    p1->x = (dx) ? ((horizontal[r] - b) / m) : vertical[c].a.x;
    p1->x = (float) floor_value( (double)p1->x );
    p1->y = (float) floor_value( (double)horizontal[r] );

    p2->x = (dx) ? ((horizontal[r+1] - b) / m) : vertical[c].a.x;
    p2->x = (float) floor_value( (double)p2->x );
    p2->y = (float) floor_value( (double)horizontal[r+1] );

    dx = (vertical[c+1].a.x -  vertical[c+1].b.x);
    m  = (vertical[c+1].a.y -  vertical[c+1].b.y) / dx;
    b  =  vertical[c+1].b.y - (vertical[c+1].b.x  * m);
    p3->x = (dx) ? ((horizontal[r] - b) / m) : vertical[c+1].a.x;
    p3->x = (float) floor_value( (double)p3->x );
    p3->y = (float) floor_value( (double)horizontal[r] );

    p4->x = (dx) ? ((horizontal[r+1] - b) / m) : vertical[c+1].a.x;
    p4->x = (float) floor_value( (double)p4->x );
    p4->y = (float) floor_value( (double)horizontal[r+1] );

    return;
}

static float check_point( struct NXLine *l, NSPoint *p )
{
    float dx  = l->a.x - l->b.x;
    float dy  = l->a.y - l->b.y;
    float dx1 = p->x   - l->a.x;
    float dy1 = p->y   - l->a.y;
    return( dx*dy1 - dy*dx1 );
}

static void convert_point( NSPoint *p, int *r, int *c )
{
    int i;
    for( i = 0; i < 8; i++ ) {
        if( p->y >= horizontal[i] && p->y <= horizontal[i+1] ) {
            *r = i;
            break;
        }
    }
    for( i = 0; i < 8; i++ ) {
        float m1 = check_point( &vertical[i], p );
        float m2 = check_point( &vertical[i+1], p );
        if( m1 > 0 && m2 < 0 ) {
            *c = i;
            break;
        }
    }
    return;
}

// Board3D implementations

@implementation Board3D

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame: (NSRect)f {
    if (self = [super initWithFrame:f]) {
        [self commonInit];
    }
    return self;
}

- (void)animatePieceFrom:(int)fromRow :(int)fromCol
                      to:(int)toRow   :(int)toCol
              afterDelay:(NSTimeInterval)delay
{
    Square3D *src = square[fromRow][fromCol];
    int type  = [src pieceType];
    int color = [src colorVal];
    if (!type) return;

    Square3D *dst = square[toRow][toCol];
    int capType  = [dst pieceType];
    int capColor = [dst colorVal];

    MovingPieceStateMachine *mp =
        [[MovingPieceStateMachine alloc] initFromRow:fromRow column:fromCol
                                               toRow:toRow   column:toCol
                                            iconName:nil
                                           pieceType:type
                                          pieceColor:color
                                    capturedIconName:nil
                                   capturedPieceType:capType
                                  capturedPieceColor:capColor
                                          afterDelay:delay];
    [self enqueueMovingPiece:mp];
    [mp release];
}

- (void)commonInit {
    NSBundle  *bundle;
    NSString  *path1, *path2;
    NSSize  size;
    int r, c;
    
    self.enabled = YES;
    [self allocateGState];
    bundle = [NSBundle mainBundle];
    path1 = [bundle pathForImageResource: @"3d_board"];
    _background = [[NSImage alloc] initWithContentsOfFile: path1];
    path2 = [bundle pathForImageResource: @"3d_pieces"];
    _pieces = [[NSImage alloc] initWithContentsOfFile: path2];
    size = NSMakeSize( BACK_STORE_WIDTH, BACK_STORE_HEIGHT );
    backBitmap = [[NSImage alloc] initWithSize: size];
    
    for( r = 0; r < 8; r++ ) {
        for( c = 0; c < 8; c++ )
            square[r][c] = [[Square3D alloc] init];
    }
    [self setupPieces];
}

- (void)setBackgroundBitmap: (NSImage *) bitmap
{
    if( _background )
        [_background release];
    _background = [bitmap retain];
    return;
}

- (id) backgroundBitmap
{
    return _background;
}

- (void)setPiecesBitmap: (NSImage *) bitmap
{
    if( _pieces )
        [_pieces release];
    _pieces = [bitmap retain];
    return;
}

- (NSImage *)piecesBitmap
{
    return _pieces;
}

- (void)setupPieces
{
    short  *pieces = default_pieces();
    short  *colors = default_colors();
    [self layoutBoard: pieces color: colors];
    return;
}

- (void)layoutBoard: (short *)p color: (short *)c
{
    int  sq;
    PSgsave();
    PSrotate( (float)10.0 );
    for( sq = 0; sq < SQUARE_COUNT; sq++ ) {
        int  row = sq / 8;
        int  col = sq % 8;
        [self placePiece: p[sq] at: row: col color: c[sq]];
    }
    PSgrestore();
    return;
}

- (void)placePiece:  (short)p at: (int)row : (int)col color: (short)c
{
    int  col2;
    float  m, b, dx, x;
    NSRect  loc;
    Square3D  *theSquare = square[row][col];
    
    [theSquare setPieceType: p color: c];
    [theSquare setRow: row];
    dx = (vertical[col].a.x -  vertical[col].b.x);
    m  = (vertical[col].a.y -  vertical[col].b.y) / dx;
    b  =  vertical[col].b.y - (vertical[col].b.x  * m);
    x  = (dx) ? ((horizontal[row] - b) / m) : vertical[col].a.x;
    loc.origin.x = x;
    loc.origin.y = horizontal[row];
    
    col2 = col + 1;
    dx = (vertical[col2].a.x -  vertical[col2].b.x);
    m  = (vertical[col2].a.y -  vertical[col2].b.y) / dx;
    b  =  vertical[col2].b.y - (vertical[col2].b.x  * m);
    x  = (dx) ? ((horizontal[row] - b) / m) : vertical[col2].a.x;
    loc.size.width  = x - loc.origin.x;
    loc.size.height = 99999;
    
    [theSquare setLocation: loc];
    return;
}

- (void)slidePieceFrom: (int)row1 : (int)col1 to: (int)row2 : (int)col2
{
    Square3D  *theSquare;
    int  pieceType, color;
    NSRect  oldLocation;
    NSPoint  backP, endP, roundedBackP;
    int  controlGState;
    float  incX, incY;
    int  increments, i;
    
    theSquare = square[row1][col1];
    pieceType = [theSquare pieceType];
    if( ! pieceType )
        return;
    color = [theSquare colorVal];
    oldLocation = [theSquare location];
    
    squareOrigin( row2, col2, &endP.x, &endP.y );
    
    /* Remove piece and then save background */
    [theSquare setPieceType: NO_PIECE color: NEUTRAL];
    [self drawRect: [self frame]];
    
    squareOrigin( row1, col1, &backP.x, &backP.y );
    controlGState = [self gState];
    
    [backBitmap lockFocus];
    PSgsave();
    PScomposite( roundedBackP.x = floor(backP.x), roundedBackP.y = floor(backP.y),
                BACK_STORE_WIDTH, BACK_STORE_HEIGHT, controlGState,
                (float)0.0, (float)0.0, NSCompositeCopy );
    PSgrestore();
    [backBitmap unlockFocus];
    
    [self lockFocus];
    [theSquare setPieceType: pieceType color: color];
    [theSquare drawInteriorWithFrame: [self frame] inView: self];
    [theSquare setMoving: YES];
    [[self window] flushWindow];
    
    incX = endP.x - backP.x;
    incY = endP.y - backP.y;
    increments = (int) MAX( ABS(incX), ABS(incY) ) / 7;	// was 5 gcr
    incX = incX / increments;
    incY = incY / increments;
    
    for( i = 0; i < increments; i++ ) {
        int  dr, dc;
        NSRect  newLocation;
        
        /* Restore old background */
        [self lockFocus];
        [backBitmap compositeToPoint: roundedBackP operation: NSCompositeCopy];
        [self unlockFocus];
        
        backP.x += incX;
        backP.y += incY;
        convert_point( &backP, &dr, &dc );
        
        /* Save new background */
        [backBitmap lockFocus];
        PSgsave();
        PScomposite( roundedBackP.x = floor(backP.x), roundedBackP.y = floor(backP.y),
                    BACK_STORE_WIDTH, BACK_STORE_HEIGHT, controlGState,
                    (float)0.0, (float)0.0, NSCompositeCopy );
        PSgrestore();
        [backBitmap unlockFocus];
        
        /* Draw piece at new location. */
        [theSquare setRow: dr];
        newLocation.origin = backP;
        newLocation.size   = NSMakeSize( PIECE_WIDTH_3D, PIECE_HEIGHT_3D );
        [theSquare setLocation: newLocation];
        [theSquare drawInteriorWithFrame: [self frame] inView: self];
        [[self window] flushWindow];
    }
    
    [theSquare setMoving: NO];
    [self unlockFocus];
    return;
}

- (int) pieceAt: (int)row : (int)col
{
    if( row >= 0 && col >= 0 ) {
        Square3D  *theSquare = square[row][col];
        return [theSquare pieceType];
    }
    return (int)NO_PIECE;
}

- (int) colorAt: (int)row : (int)col
{
    if( row >= 0 && col >= 0 ) {
        Square3D  *theSquare = square[row][col];
        return [theSquare colorVal];
    }
    return (int)NEUTRAL;
}

- (void) drawRows: (int)row from: (int)col
{
    while( row >= 0 ) {
        Square3D  *theSquare = square[row][col];
        if( [self pieceAt: row : col] && ! [theSquare isMoving] )
            [theSquare drawInteriorWithFrame: [self frame] inView: self];
        row--;
    }
    return;
}

- (void) print: (id)sender
{
    NSPrintInfo	*pi = [NSPrintInfo sharedPrintInfo];
    NSSize	ps  = [pi paperSize];
    NSSize	fs  = [self frame].size;
    float	hm  = (ps.width  - fs.width)  / 2.0;
    float	vm  = (ps.height - fs.height) / 2.0;
    
    [pi setLeftMargin: hm];
    [pi setRightMargin: hm];
    [pi setTopMargin: vm];
    [pi setBottomMargin: vm];

    [self lockFocus];
    printImage = [[NSBitmapImageRep alloc] initWithFocusedViewRect: [self bounds]];
    [self unlockFocus];
    
    [super print: sender];
    [printImage release];
    printImage = nil;
    return;
}

- (void) drawRect: (NSRect)f
{
    if( ! printImage ) {
        int  r, c;
        NSPoint  p = NSZeroPoint;

        PSgsave();
        [_background compositeToPoint: p operation: NSCompositeCopy];
        int dR = [self isDragging] ? [self draggedRow]    : -1;
        int dC = [self isDragging] ? [self draggedColumn] : -1;
        NSArray *moving = [self activeMovingPieces];
        for( r = 7; r >= 0; r-- ) {
            for( c = 7; c >= 0; c-- ) {
                if (r == dR && c == dC) continue;

                // See if this square is an endpoint of some moving piece.
                BOOL isFrom = NO;
                MovingPieceStateMachine *toHere = nil;
                for (MovingPieceStateMachine *mp in moving) {
                    if (r == [mp fromRow] && c == [mp fromColumn]) { isFrom = YES; break; }
                    if (r == [mp toRow]   && c == [mp toColumn])   { toHere = mp;  break; }
                }
                if (isFrom) continue;

                Square3D *theSquare = square[r][c];
                if (toHere) {
                    int capType = [toHere capturedPieceType];
                    if (capType) {
                        int savedType  = [theSquare pieceType];
                        int savedColor = [theSquare colorVal];
                        [theSquare setPieceType:capType color:[toHere capturedPieceColor]];
                        [theSquare drawWithFrame:self.frame inView:self];
                        [theSquare setPieceType:savedType color:savedColor];
                    }
                    continue;
                }

                [theSquare drawWithFrame:self.frame inView:self];
            }
        }
        PSgrestore();

        for (HighlightedSquareStateMachine *h in [self activeHighlights]) {
            if (!h.isHighlighted) continue;
            NSPoint p1, p2, p3, p4;
            squareBounds(h.row, h.column, &p1, &p2, &p3, &p4);
            NSBezierPath *path = [NSBezierPath bezierPath];
            [path moveToPoint:p1];
            [path lineToPoint:p2];
            [path lineToPoint:p4];
            [path lineToPoint:p3];
            [path closePath];
            [[NSColor whiteColor] set];
            [path setLineWidth:3.0];
            [path stroke];
        }

        for (MovingPieceStateMachine *mp in moving) {
            Square3D *src = square[[mp fromRow]][[mp fromColumn]];
            NSRect savedLoc = [src location];
            int    savedRow = [src row];
            int    savedType  = [src pieceType];
            int    savedColor = [src colorVal];

            float srcX, srcY, dstX, dstY;
            squareOrigin([mp fromRow], [mp fromColumn], &srcX, &srcY);
            squareOrigin([mp toRow],   [mp toColumn],   &dstX, &dstY);
            double pr = [mp progress];
            NSRect newLoc;
            newLoc.origin.x = srcX + (float)(pr * (dstX - srcX));
            newLoc.origin.y = srcY + (float)(pr * (dstY - srcY));
            newLoc.size.width  = PIECE_WIDTH_3D;
            newLoc.size.height = PIECE_HEIGHT_3D;

            // Perspective row = row under the piece's base point.
            NSPoint base;
            base.x = newLoc.origin.x + PIECE_WIDTH_3D  / 2.0;
            base.y = newLoc.origin.y + PIECE_HEIGHT_3D / 4.0;
            int hoverR = -1, hoverC = -1;
            convert_point(&base, &hoverR, &hoverC);
            if (hoverR < 0) hoverR = 0;
            if (hoverR > 7) hoverR = 7;

            [src setLocation:newLoc];
            [src setRow:hoverR];
            [src setPieceType:[mp pieceType] color:[mp pieceColor]];
            [src drawInteriorWithFrame:self.frame inView:self];
            [src setLocation:savedLoc];
            [src setRow:savedRow];
            [src setPieceType:savedType color:savedColor];
        }

        if ([self isDragging]) {
            Square3D *ds = square[dR][dC];
            NSRect   savedLoc = [ds location];
            int      savedRow = [ds row];

            NSPoint dp  = [self dragPoint];
            NSPoint off = [self dragOffset];
            NSRect newLoc;
            newLoc.origin.x = dp.x - off.x;
            newLoc.origin.y = dp.y - off.y;
            newLoc.size.width  = PIECE_WIDTH_3D;
            newLoc.size.height = PIECE_HEIGHT_3D;

            NSPoint base;
            base.x = newLoc.origin.x + PIECE_WIDTH_3D  / 2.0;
            base.y = newLoc.origin.y + PIECE_HEIGHT_3D / 4.0;
            int hoverR = -1, hoverC = -1;
            convert_point(&base, &hoverR, &hoverC);

            if (hoverR >= 0 && hoverR <= 7 && hoverC >= 0 && hoverC <= 7) {
                NSPoint p1, p2, p3, p4;
                squareBounds(hoverR, hoverC, &p1, &p2, &p3, &p4);
                NSBezierPath *path = [NSBezierPath bezierPath];
                [path moveToPoint:p1];
                [path lineToPoint:p2];
                [path lineToPoint:p4];
                [path lineToPoint:p3];
                [path closePath];
                [[NSColor whiteColor] set];
                [path setLineWidth:3.0];
                [path stroke];
            }

            int drawRow = hoverR;
            if (drawRow < 0) drawRow = 0;
            if (drawRow > 7) drawRow = 7;
            [ds setLocation:newLoc];
            [ds setRow:drawRow];
            [ds drawInteriorWithFrame:self.frame inView:self];
            [ds setLocation:savedLoc];
            [ds setRow:savedRow];
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

    NSPoint p = [self convertPoint:[event locationInWindow] fromView:nil];
    int r = -1, c = -1;
    convert_point(&p, &r, &c);
    if (r < 0 || c < 0 || r > 7 || c > 7) return;

    Square3D *theSquare = square[r][c];
    if (![theSquare pieceType]) return;

    float sx, sy;
    squareOrigin(r, c, &sx, &sy);
    NSPoint offset = NSMakePoint(p.x - sx, p.y - sy);
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

    NSPoint base;
    base.x = p.x - offset.x + PIECE_WIDTH_3D  / 2.0;
    base.y = p.y - offset.y + PIECE_HEIGHT_3D / 4.0;
    int r2 = -1, c2 = -1;
    convert_point(&base, &r2, &c2);
    [self endDrag];

    if (r2 >= 0 && c2 >= 0 && r2 <= 7 && c2 <= 7 && (r2 != r || c2 != c)) {
        if (![NSApp makeMoveFrom:r :c to:r2 :c2]) {
            PSWait();
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
