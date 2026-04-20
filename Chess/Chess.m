#import <AppKit/AppKit.h>

// own interface
#import "Chess.h"

// components
#import "BaseBoard.h"
#import "Board.h"
#import "Board3D.h"
#import "Clock.h"	// not used
#import "ResponseMeter.h"
#import "ChessListener.h"
#import "MovingPieceStateMachine.h"

// portability layer
#import "gnuglue.h"

#ifdef CHESS_DEBUG
static int          sCDInit;
static const char * sCD;
#define chess_debug(x) if (sCD || (!sCDInit++ && (sCD = getenv("CHESS_DEBUG")))) NSLog x; else 0 
#else
#define chess_debug(x)
#endif

#define NEW @"newGame:"
#define OPEN @"openGame:"
#define SAVE @"saveGame:"
#define SAVEAS @"saveAsGame:"
#define LIST @"listGame:"

#import "ps.h"

void PScompositerect(float x, float y, float w, float h, int op);

void CL_MakeMove(const char * move)
{
	if (move[0] == (char)-1) {
		[NSApp undoMove:NSApp];
	} else {
		int r = move[1]-'1';
		int c = move[0]-'a';
		int r2= move[3]-'1';
		int c2= move[2]-'a';

		[NSApp makeMoveFrom: r : c to: r2 : c2];
	}
}

// Chess class implementations

@implementation Chess

+ (void)initialize
{
    init_gnuchess();

    return;
}

- (void)finishLaunching
{
	float red, green, blue, alpha;
	NSScanner * scanner;

    [super finishLaunching];

	defaults = [NSUserDefaults standardUserDefaults];

	[defaults registerDefaults:
				  [NSDictionary dictionaryWithObjectsAndKeys:
                                @"0 0 0 1", @"WhiteColor",
								@"0 0 0 1", @"BlackColor",
								[self.levelSlider objectValue], @"Level",
								@"NO", @"BothSides",
								@"YES", @"PlayerHasWhite",
								@"YES", @"SpeechRecognition",
								NULL]];

    gameBoard = self.board3D;

	scanner = [NSScanner scannerWithString:[defaults objectForKey:@"WhiteColor"]];
	[scanner scanFloat:&red];
	[scanner scanFloat:&green];
	[scanner scanFloat:&blue];
	[scanner scanFloat:&alpha];
    white_color = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
	[self.whiteColorWell setColor:white_color];

	scanner = [NSScanner scannerWithString:[defaults objectForKey:@"BlackColor"]];
	[scanner scanFloat:&red];
	[scanner scanFloat:&green];
	[scanner scanFloat:&blue];
	[scanner scanFloat:&alpha];
    black_color = [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
	[self.blackColorWell setColor:black_color];

	[self.levelSlider setIntValue:[defaults integerForKey:@"Level"]];
    [self levelSliding:self.levelSlider];
    
	if ([defaults boolForKey:@"BothSides"])
		[self.gamePopup selectItemAtIndex:2];
	else if ([defaults boolForKey:@"PlayerHasWhite"])
		[self.gamePopup selectItemAtIndex:0];
	else
		[self.gamePopup selectItemAtIndex:1];

	prefs.useSR = [defaults boolForKey:@"SpeechRecognition"];
	[self.srCheckBox setState:prefs.useSR];

	[self setWhiteColor: self];
	[self setBlackColor: self];
    [self renderColors: self];		// default color pieces

	[self chooseSide: self.whiteSideName];
    [self setPreferences: self];	// default preferences

    dirtyGame = NO;
    menusEnabled = YES;
	
	{
		NSString *	path	= 
			[[NSBundle mainBundle] pathForResource: @"SpeechHelp" ofType: @"xml"];
		NSData *	help 	= 
			[NSData dataWithContentsOfFile:path];
		CL_SetHelp([help length], [help bytes]);
	}

    [self newGame: self];

    return;
}

/*
    MainMenu responders
*/

- (void)info: (id)sender
{
    [NSApplication.sharedApplication orderFrontStandardAboutPanel: sender];
}

- (void)showGnuDisclaimer: (id)sender
{
    id  text = [self.infoScroll documentView];
    NSString  *string = [text string];
    if( ! string || [string isEqual: @""] || [string isEqual: @" "]) {
        string = copyright_text();
        [text setString: string];
        [text sizeToFit];
		//	[text setFont:[NSFont fontWithName: @"Times" size: (float)14.0]];
        [self.infoScroll display];
    }
    [self.infoPanel makeKeyAndOrderFront: sender];
    return;
}
/* Start a new game */

- (void)newGame: (id)sender
{
    if (dirtyGame) {
        if (![self alertPanelForGameChange]) return;
    }
    
    finished = 0;
    undoCount = hintCount = forceCount = 0;

    new_game();

    [self setTitle];
    [self displayResponseMeter: WHITE];
    [self displayResponseMeter: BLACK];

    if( prefs.bothsides )
		[self.startButton setEnabled: YES];
    else {
		[self.startButton setEnabled: NO];
		if( prefs.computer == WHITE )
			[self selectMove: WHITE iop: 1];
        else if (prefs.useSR)
            CL_Listen(WHITE, current_pieces(), current_colors());
    }
    dirtyGame = NO;
    if (![self.boardWindow isKeyWindow]) [self.boardWindow makeKeyAndOrderFront:self];
    return;
}

/* Read a saved game */

- (void)openGame: (id)sender
{
    id  op = [NSOpenPanel openPanel];
    finished = 0;
    [op setRequiredFileType: @"chess"];
    if( [op runModal] == NSOKButton ) {
		filename = [op filename];
		get_game( filename );
    }
    dirtyGame = NO;
    if (![self.boardWindow isVisible]) [self.boardWindow makeKeyAndOrderFront:self];
    return;
}
  
/* Save a game */

- (void)listGame: (id)sender
{
    NSSavePanel	*sp = [NSSavePanel savePanel];
    [sp setRequiredFileType: nil];
    if( [sp runModal] == NSOKButton )
		list_game( [sp filename] );
    return;
}

- (void)saveGame: (id)sender
{
    if ( filename && ! [filename isEqual: @""] )  
		save_game( filename );
    else
		[self saveAsGame: sender];
    dirtyGame = NO;
    return;
}

- (void)saveAsGame: (id)sender
{
    NSSavePanel	*sp = [NSSavePanel savePanel];
    [sp setRequiredFileType: @"chess"];
    if( [sp runModal] == NSOKButton ) {
		filename = [sp filename];
		save_game( filename );
    }
    dirtyGame = NO;
    return;
}

// Added this because it seems a little more Mac like.  If you try to start
// a new game or open a game while a game is in progress it asks you if you
// would like to save the current game first.
- (BOOL)alertPanelForGameChange
{
    int button;
    button = NSRunAlertPanel( nil,
							  NSLocalizedString(@"Would you like to save your current game first?",nil),
							  NSLocalizedString(@"Save",nil), NSLocalizedString(@"No",nil),
                              NSLocalizedString(@"Cancel",nil), nil );

    switch( button ){
	case -1:  return NO;
	case 0:  return YES;
	default:  [self saveGame:self];  return YES;
    }
}
- (void)closeGame: (id)sender
{
    if (dirtyGame) {
        if (![self alertPanelForGameChange]) return;
    }
    dirtyGame = NO;
    [self.boardWindow orderOut:self];
}
/* Give the player a hint */

- (void)hint: (id)sender
{
    if( give_hint() ){
		hintCount++;
		[self setTitle];
    }
    else
		(void)NSRunAlertPanel( nil, NSLocalizedString(@"no_hint",nil), nil, nil, nil ); 
    return;
}

- (void)showPosition: (id)sender
{
    [gameBoard highlightSquareAt: currentRow : currentCol];
    [gameBoard flashSquareAt: currentRow : currentCol]; 
    return;
}

/* Undo last two half moves */

- (void)undoMove: (id)sender
{
    if( game_count() >= 0 ){
		undo_move();
		undo_move();
		undoCount++;
		[self setTitle];
		if (prefs.useSR)
			CL_Listen(prefs.opponent, current_pieces(), current_colors());
    }
    else
		(void)NSRunAlertPanel( nil, NSLocalizedString(@"no_undo",nil), nil, nil, nil ); 
    return;
}

- (void)view2D: (id)sender
{
	[self.menu2D setState: NSOnState];
	[self.menu3D setState: NSOffState];
    if( gameBoard == self.board3D ) {
		short  *pieces = current_pieces();
		short  *colors = current_colors();

        [(NSView *)gameBoard setHidden: YES];
		gameBoard = self.board2D;
        [(NSView *)gameBoard setHidden: NO];
		[gameBoard layoutBoard: pieces color: colors];

		[self disableClockPanel];
    }
    return;
}

- (void)view3D: (id)sender
{
	[self.menu2D setState: NSOffState];
	[self.menu3D setState: NSOnState];
    if( gameBoard == self.board2D ) {
		short  *pieces = current_pieces();
		short  *colors = current_colors();

        [(NSView *)gameBoard setHidden: YES];
        gameBoard = self.board3D;
        [(NSView *)gameBoard setHidden: NO];
		[gameBoard layoutBoard: pieces color: colors];

		[self enableClockPanel];
    }
    return;
}

- (void)print: (id)sender
{
    [gameBoard print: sender];
    return;
}

/*
    ClockPanel responders
*/

- (void)setWhiteColor: (id)sender
{
    NSString	*path;
    NSImage	*image1;
    NSImage	*image2;
    NSRect  r;
    NSPoint pt;

    path   = [[NSBundle mainBundle] pathForImageResource: @"3d_white_sample"];
    image1 = [[NSImage alloc] initWithContentsOfFile: path];
    image2 = [self.whiteSample image];
    r.origin = NSZeroPoint;
    r.size   = [image2 size];
    pt = NSZeroPoint;

    [image2 lockFocus];
    [image1 compositeToPoint: pt fromRect: r operation: NSCompositingOperationCopy];
    [image2 unlockFocus];

    [image1 lockFocus];
    [[self.whiteColorWell color] set];
    PScompositerect( pt.x, pt.y,
					 r.size.width, r.size.height, NSCompositingOperationColor );
    [image1 unlockFocus];

    [image2 lockFocus];
    [image1 compositeToPoint: pt fromRect: r operation: NSCompositingOperationSourceAtop];
    [image2 unlockFocus];

    [self.whiteSample display];

    if( ! [white_color isEqual: [self.whiteColorWell color]] )
		[self.colorSetButton setEnabled: YES];
    return;
}

- (void)setBlackColor: (id)sender
{
    NSString	*path;
    NSImage	*image1;
    NSImage	*image2;
    NSRect  r;
    NSPoint pt;

    path   = [[NSBundle mainBundle] pathForImageResource: @"3d_black_sample"];
    image1 = [[NSImage alloc] initWithContentsOfFile: path];
    image2 = [self.blackSample image];
    r.origin = NSZeroPoint;
    r.size   = [image2 size];
    pt = NSZeroPoint;

    [image2 lockFocus];
    [image1 compositeToPoint: pt fromRect: r operation: NSCompositingOperationCopy];
    [image2 unlockFocus];

    [image1 lockFocus];
    [[self.blackColorWell color] set];
    PScompositerect( pt.x, pt.y,
                     r.size.width, r.size.height, NSCompositingOperationColor );
    [image1 unlockFocus];

    [image2 lockFocus];
    [image1 compositeToPoint: pt fromRect: r operation: NSCompositingOperationSourceAtop];
    [image2 unlockFocus];

    self.blackSample.image = image2;
    [self.blackSample display];

    if( ! [black_color isEqual: [self.blackColorWell color]] )
		[self.colorSetButton setEnabled: YES];
    return;
}

- (void)renderColors: (id)sender
{
    NSString  *path;
    NSImage   *image1;
    NSImage   *image2;
    NSRect  r;
    NSPoint pt;

    if( gameBoard != self.board3D )
        return;

    path   = [[NSBundle mainBundle] pathForImageResource: @"3d_pieces"];
    image1 = [[NSImage alloc] initWithContentsOfFile: path];
    image2 = [gameBoard piecesBitmap];
    r.origin = NSZeroPoint;
    r.size   = [image2 size];
    pt = NSZeroPoint;

    if( ! [white_color isEqual: [self.whiteColorWell color]] ) {
		CGFloat red, green, blue, alpha;
		white_color = [self.whiteColorWell color];
		[white_color getRed:&red green:&green blue:&blue alpha:&alpha];
		[defaults setObject:[NSString stringWithFormat:@"%1.3f %1.3f %1.3f %1.3f", red, green, blue, alpha] forKey:@"WhiteColor"];
    }
    if( ! [black_color isEqual: [self.blackColorWell color]] ) {
        CGFloat red, green, blue, alpha;
		black_color = [self.blackColorWell color];
		[black_color getRed:&red green:&green blue:&blue alpha:&alpha];
		[defaults setObject:[NSString stringWithFormat:@"%1.3f %1.3f %1.3f %1.3f", red, green, blue, alpha] forKey:@"BlackColor"];
    }

    [image2 lockFocus];
    [image1 drawInRect: r fromRect: r operation: NSCompositingOperationCopy fraction:1.0f];
    [image2 unlockFocus];

    [image1 lockFocus];
    [white_color set];
    PScompositerect( pt.x, pt.y,
					 (float)336.0, r.size.height, NSCompositingOperationColor);
    [black_color set];
    PScompositerect( (float)336.0, pt.y,
					 (float)336.0, r.size.height, NSCompositingOperationColor);
    [image1 unlockFocus];

    [image2 lockFocus];
    
    [image1 drawInRect: r fromRect: r operation: NSCompositingOperationSourceAtop fraction:1.0f];
    [image2 unlockFocus];

    [gameBoard display];

    [self.colorSetButton setEnabled: NO];
    return;
}

- (void)startGame: (id)sender
{
    if( [sender state] == 1 ) {
		// This is the loop that makes the computer play.  It can be terminated
		// by several conditions.  The "Stop" button may be clicked, cmd-. may
		// be pressed, or the game may end.

		[self setMainMenuEnabled: NO];
		[self disablePrefPanel];
		[self disableClockPanel];
		run_computer_game();
		[sender setState: 0];
    }
    else {
		stop_computer_game();
		[self enableClockPanel];
		[self enablePrefPanel];
		[self setMainMenuEnabled: YES];
    }
    return;
}

- (void)forceMove: (id)sender
{
    set_timeout( YES );
    return;
}

/*
    PrefPanel responders
*/

/* Change the text displayed below the level slider to indicate
   what the level means */

- (void)levelSliding: (id)sender
{
    NSString  *format, *string;
    int  moves, minutes;
    int  level = [sender intValue];

    interpret_level( level, &moves, &minutes );

    if( moves > 1 )
		format = NSLocalizedString( @"%d moves in %d minutes", nil );
    else
		format = NSLocalizedString( @"%d move in %d minutes", nil );
    string = [NSString stringWithFormat: format, moves, minutes];
    [self.levelText setStringValue: string];

    if( level != game_level() )
		[self.prefSetButton setEnabled: YES];
    return;
}

/* Set the text fields next to the side matrices */

- (void)chooseSide: (id)sender
{
	switch ([self.gamePopup indexOfSelectedItem]) {
	case 0: /* Human vs. Computer */
		[self.whiteSideName setStringValue: user_fullname()];
		[self.blackSideName setStringValue: NSLocalizedString(@"Computer",nil)];
		if ( !( !prefs.bothsides && prefs.computer == BLACK))
			[self.prefSetButton setEnabled: YES];
		break;
	case 1: /* Computer vs. Human */
		[self.whiteSideName setStringValue: NSLocalizedString(@"Computer",nil)];
		[self.blackSideName setStringValue: user_fullname()];
		if ( !( !prefs.bothsides && prefs.computer == WHITE))
			[self.prefSetButton setEnabled: YES];
		break;
	case 2: /* Computer vs. Computer */
		[self.whiteSideName setStringValue: NSLocalizedString(@"Computer",nil)];
		[self.blackSideName setStringValue: NSLocalizedString(@"Computer",nil)];
		if ( !prefs.bothsides )
			[self.prefSetButton setEnabled: YES];
		break;
	}
	if (prefs.useSR != [self.srCheckBox state])
		[self.prefSetButton setEnabled: YES];
	if( ! [prefs.white_name isEqual: [self.whiteSideName stringValue]]  )
		[self.prefSetButton setEnabled: YES];
	if( ! [prefs.black_name isEqual: [self.blackSideName stringValue]] )
		[self.prefSetButton setEnabled: YES];
    return;
}

/* TextField delegate */

- (void)controlTextDidBeginEditing: (NSNotification *)notification
{
    id  txField = [notification object];
    if( txField == self.whiteSideName || txField == self.blackSideName ) {
		[self.prefSetButton setEnabled: YES];
    }
    return;
}

/* Actually set the preferences */

- (void)setPreferences: (id)sender
{
    int  button;
    int  level = [self.levelSlider intValue];

    set_game_level ( level );
    interpret_level( level, &prefs.time_cntl_moves, &prefs.time_cntl_minutes );

	switch ([self.gamePopup indexOfSelectedItem]) {
	case 0:
		prefs.bothsides = NO;
		prefs.opponent  = WHITE;
		prefs.computer  = BLACK;
		break;
	case 1:
		prefs.bothsides = NO;
		prefs.opponent  = BLACK;
		prefs.computer  = WHITE;
		break;
	case 2:
		prefs.bothsides = YES;
		prefs.opponent  = WHITE;
		prefs.computer  = BLACK;
		break;
    }

	if (prefs.useSR && ![self.srCheckBox state])
		CL_DontListen();
	prefs.useSR = [self.srCheckBox state];
    prefs.cheat = YES;		// always YES?

    if( ! [prefs.white_name isEqual: [self.whiteSideName stringValue]] ) {
		prefs.white_name = [self.whiteSideName stringValue];
		[self.whiteClockText setStringValue: prefs.white_name];
    }
    if( ! [prefs.black_name isEqual: [self.blackSideName stringValue]] ) {
		prefs.black_name = [self.blackSideName stringValue];
		[self.blackClockText setStringValue: prefs.black_name];
    }

    set_preferences( &prefs );
    [self.prefSetButton setEnabled: NO];

    if( sender == self )	return;		// default setting

	[defaults setInteger:[self.levelSlider intValue] forKey:@"Level"];
	[defaults setBool:prefs.bothsides forKey:@"BothSides"];
	[defaults setBool:prefs.computer  forKey:@"PlayerHasWhite"];
	[defaults setBool:prefs.useSR forKey:@"SpeechRecognition"];
	
    reset_response_time();
    [self displayResponseMeter: WHITE];
    [self displayResponseMeter: BLACK];

    button = NSRunAlertPanel( nil, NSLocalizedString(@"new_game",nil), NSLocalizedString(@"Yes",nil), NSLocalizedString(@"No",nil), nil );
    if ( button == NSAlertDefaultReturn ) {
        dirtyGame = NO;
        [self newGame: self];
    } else {
		if( prefs.bothsides )
			[self.startButton setEnabled: YES];
		else {
			[self.startButton setEnabled: NO];
			if( current_player() == WHITE && prefs.computer == WHITE )
				[self selectMove: WHITE iop: 1];
			else if( current_player() == BLACK && prefs.computer == BLACK )
				[self selectMove: BLACK iop: 1];
		}
    }
    return;
}

/*
    invoked by Board.m & Board3D.m
*/

- (BOOL)bothsides
{
    return prefs.bothsides;
}

- (int)finished
{
    return finished;
}

- (void)finishedAlert
{
    NSString *msg;
    chess_debug(( @"finished %d", finished ));
    switch( finished ){
	case DRAW_GAME     :  msg = @"draw_game";  break;
	case WHITE_MATE    :  msg = @"black_win";  break;
	case BLACK_MATE    :  msg = @"white_win";  break;
	case OPPONENT_MATE :  msg = @"you_win";    break;
	default            :  return;
    }
    (void)NSRunAlertPanel( nil, NSLocalizedString(msg,nil), nil, nil, nil );
    return;
}

- (BOOL)makeMoveFrom: (int)row1 : (int)col1 to: (int)row2 : (int)col2
{ 
    NSString *move;
    short oldguy, newguy;
    BOOL verified;
    short  *pieces, *colors;

    dirtyGame = YES;
    oldguy = [gameBoard pieceAt: row1 : col1];
    move = convert_rowcol( row1, col1, row2, col2, oldguy );

    verified = verify_move( move );
    if( ! verified ) {
		[self setTitleMessage: @"Illegal move"];
		NSBeep();
		return( NO );
    }

    newguy = [gameBoard pieceAt: row2 : col2];
    if ( (newguy == QUEEN) && (oldguy == PAWN) ) {
		chess_debug (( @"pawn becomes queen..." ));
		set_game_queen( PAWN );
    }
    else
		set_game_queen( NO_PIECE );

    chess_debug(( @"<<< opponent move time %d move %@", move_time(), move ));
    [self updateClocks: prefs.opponent];
    in_check();
    PSWait();

    pieces = current_pieces();
    colors = current_colors();
    [gameBoard layoutBoard: pieces color: colors];
	//  [gameBoard display];
    PSWait();

    select_computer_move();
    return( YES );
}

/*
    invoked by gnuglue.m
*/

- (void)peekAndGetLeftMouseDownEvent
{
    NSEvent *event;
    if( event = [NSApp nextEventMatchingMask: NSLeftMouseDownMask untilDate: [NSDate date] inMode: NSEventTrackingRunLoopMode dequeue: NO] ) {
		event = [NSApp nextEventMatchingMask: NSLeftMouseDownMask untilDate: [NSDate date] inMode: NSEventTrackingRunLoopMode dequeue: YES];
		[NSApp sendEvent: event];
    }
    return;
}

- (void)selectMove: (int)side iop: (int)iop
{
    if( side == WHITE )
		[self setTitleMessage: @"White's move"];
    else
		[self setTitleMessage: @"Black's move"];

    [self setMainMenuEnabled: NO];
    [self disablePrefPanel];
    [self disableClockPanel];
    [gameBoard setEnabled: NO];
    [self.forceButton setEnabled: YES];
	if (prefs.useSR)
		CL_DontListen();
    PSWait();

    select_move_start( side, iop );
    while( ! select_loop_end() )
		select_loop();
    select_move_end();

    [self setTitle];

    [self updateClocks: prefs.computer];
    in_check();
    PSWait();

    [self.forceButton setEnabled: NO];
    [gameBoard setEnabled: YES];
    [self enableClockPanel];
    [self enablePrefPanel];
    [self setMainMenuEnabled: YES];

    reset_response_time();
    [self displayResponseMeter: WHITE];
    [self displayResponseMeter: BLACK];

    if (prefs.bothsides) {
        BaseBoard *bb = (BaseBoard *)gameBoard;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 5.0];
        while ([bb hasActiveAnimations] && [deadline timeIntervalSinceNow] > 0) {
            [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
                                     beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
        }
    }

	if (prefs.useSR)
		CL_Listen(!side, current_pieces(), current_colors());

    return;
}

- (void)setFinished: (int)flag
{
    finished = flag;
    if( flag == 0 )  return;
    NSTimeInterval delay = 2 * [MovingPieceStateMachine animationDuration];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self finishedAlert];
    });
    return;
}

- (void)movePieceFrom: (int)row1 : (int)col1 to: (int)row2 : (int)col2
{
    NSString *move;
    short oldguy;
    short  *pieces = current_pieces();
    short  *colors = current_colors();

    oldguy = [gameBoard pieceAt: row1 : col1];
    move = convert_rowcol( row1, col1, row2, col2, oldguy );
    chess_debug( (@">>> computer move time %d move %@", move_time(), move) );

    dirtyGame = YES;

    NSTimeInterval blinkDur = [HighlightedSquareStateMachine blinkDuration];
    // Lead the dest blink slightly — the target square starts announcing
    // itself just before the piece lands on it.
    NSTimeInterval destLead = 0.125;

    [gameBoard highlightSquareAt: row1 : col1];
    [gameBoard animatePieceFrom: row1 : col1 to: row2 : col2
                     afterDelay: 0.0];
    [self storePosition: row2 : col2];
    [gameBoard layoutBoard: pieces color: colors];
    PSWait();
    [gameBoard highlightSquareAt: row2 : col2
                      afterDelay: blinkDur - destLead];
    return;
}

- (void)updateBoard
{
    short  *pieces = current_pieces();
    short  *colors = current_colors();
    [gameBoard layoutBoard: pieces color: colors];
    [gameBoard display];
    return;
}

- (int)pieceTypeAt: (int)row : (int)col
{
    return [gameBoard pieceAt: row : col];
}

- (void)highlightSquareAt: (int)row : (int)col
{
    [gameBoard highlightSquareAt: row : col];
    return;
}

- (void)highlightSquareAt: (int)row : (int)col afterDelay: (NSTimeInterval)delay
{
    [gameBoard highlightSquareAt: row : col afterDelay: delay];
    return;
}

- (void)displayResponseMeter: (int)side
{
    if( [self.clockPanel isVisible] ) {
		if( side == WHITE )
			[self.whiteMeter display];
		else
			[self.blackMeter display];
		PSWait();
    }
    return;
}

- (void)fillResponseMeter: (int)side
{
    if( [self.clockPanel isVisible] ) {
		if( side == WHITE )
			[self.whiteMeter displayFilled];
		else
			[self.blackMeter displayFilled];
		PSWait();
    }
    return;
}

- (void)setTitleMessage: (NSString *)msg
{
    NSMutableString *buf;
    [self setTitle];
    buf = [NSMutableString stringWithCapacity: (unsigned)0];
    [buf appendString: [self.boardWindow title]];
    [buf appendString: NSLocalizedString(@"   :   ", nil)];
    [buf appendString: NSLocalizedString(msg, nil)];
    [self.boardWindow setTitle: buf];
    return;
}

- (BOOL)canFinishGame
{
    int sts = NSRunAlertPanel( nil, NSLocalizedString(@"exit_chess",nil), NSLocalizedString(@"Yes",nil), NSLocalizedString(@"No",nil), nil );
    return ( sts == NSAlertDefaultReturn ) ? YES : NO;
}

/*
    Support methods
*/

- (void)setTitle
	/*
  Change the board windows title to display the number of cheat commands
  issued.
*/
{
    NSMutableString *str = [NSMutableString stringWithCapacity: 0];
    if( undoCount || hintCount ) {
		[str appendString: NSLocalizedString(@"Chess:  ", nil)];
		if( undoCount == 1 )
			[str appendString: NSLocalizedString(@"1 Undo  ",  nil)];
		else if( undoCount )
			[str appendFormat: NSLocalizedString(@"%d Undos  ",nil),undoCount];
		if( hintCount == 1 )
			[str appendString: NSLocalizedString(@"1 Hint", nil)];
		else if( hintCount )
			[str appendFormat: NSLocalizedString(@"%d Hints",nil),hintCount];
    }
    else
		[str appendString: NSLocalizedString(@"Chess", nil)];
    [self.boardWindow setTitle: str];
    return;
}

- (void)storePosition: (int) row : (int) col
{
    currentRow = row;
    currentCol = col;
    return;
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    //[item action]
    if (!menusEnabled) {
        NSString *selector = NSStringFromSelector([item action]);
        if ([selector isEqual:NEW]) return NO;
        else if ([selector isEqual:OPEN]) return NO;
        else if ([selector isEqual:SAVE]) return NO;
        else if ([selector isEqual:SAVEAS]) return NO;
        else if ([selector isEqual:LIST]) return NO;
        else return YES;
    }
    return YES;
}
- (void)setMainMenuEnabled: (BOOL)flag
{
    menusEnabled = flag;
    return;
}

- (void)enablePrefPanel
{
    [self.levelSlider setEnabled: YES];
    [self.levelText setTextColor: [NSColor blackColor]];
    [self.gamePopup setEnabled: YES];
    [self.whiteSideName setEnabled: YES];
    [self.blackSideName setEnabled: YES];
    if( [self.levelSlider intValue] != game_level() ||
		! [prefs.white_name isEqual: [self.whiteSideName stringValue]] ||
		! [prefs.black_name isEqual: [self.blackSideName stringValue]] ) {
		[self.prefSetButton setEnabled: YES];
    }
    return;
}

- (void)disablePrefPanel
{
    [self.levelSlider setEnabled: NO];
    [self.levelText setTextColor: [NSColor darkGrayColor]];
    [self.gamePopup setEnabled: NO];
    [self.whiteSideName setEnabled: NO];
    [self.blackSideName setEnabled: NO];
    [self.prefSetButton setEnabled: NO];
    return;
}

- (void)enableClockPanel
{
    if( gameBoard == self.board3D ) {
		[self.whiteColorWell setEnabled: YES];
		[self.blackColorWell setEnabled: YES];
		if( ! [white_color isEqual: [self.whiteColorWell color]] ||
			! [black_color isEqual: [self.blackColorWell color]] ) {
			[self.colorSetButton setEnabled: YES];
		}
    }
    return;
}

- (void)disableClockPanel
{
    [self.whiteColorWell setEnabled: NO];
    [self.blackColorWell setEnabled: NO];
    [self.colorSetButton setEnabled: NO];
    return;
}

- (int)whiteTime
{
    return whiteTime;
}

- (int)blackTime
{
    return blackTime;
}

- (void)updateClocks: (int)side
{
    if( ! self.blackClock || ! self.whiteClock )
		return;
    if( side == WHITE ) {
		whiteTime += move_time();
		if( [self.clockPanel isVisible] ) {
			[self.whiteClock setSeconds: whiteTime];
			[self.whiteClock display];
		}
    }
    else {
		blackTime += move_time();
		if( [self.clockPanel isVisible] ) {
			[self.blackClock setSeconds: blackTime];
			[self.blackClock display];
		}
    }
    return;
}

/*
    Application delegate
*/

- (int)application: (NSApplication *)sender openFile: (NSString *)path withType: (NSString *)type
{
    chess_debug( (@"Open file: %@ type: %@", path, type) );
    if( type && [type isEqual: @"chess"] ) {
		filename = path;
		get_game( filename );
		return (int)YES;
    }
    return (int)NO;
}

@end
