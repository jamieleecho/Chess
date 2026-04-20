/* Glue software for gnuchess.c & Chess.app */

#import <Foundation/NSObjCRuntime.h>

@class NSString;
struct Preferences;


/*
    constant definitions

	Note: These constants are the same as defined in gnuchess.h.
	This file is created for not importing gnuchess.h in main modules
	of Chess.app.
*/

/* players */
enum {
    WHITE = 0,
    BLACK,
    NEUTRAL
};

/* pieces */
enum {
    NO_PIECE = 0,
    PAWN,
    KNIGHT,
    BISHOP,
    ROOK,
    QUEEN,
    KING
};

/* board layout */
#define ROW_COUNT	8
#define COLUMN_COUNT	8
#define SQUARE_COUNT	(ROW_COUNT*COLUMN_COUNT)

/*
    function declarations
*/

/* invoked by gnuchess.c modules */
extern void OutputMove(void);
extern void SelectLevel(void);
extern void UpdateClocks(void);
extern void ElapsedTime( int ) ;
extern void SetTimeControl(void);
extern void ShowResults( short, unsigned short [], char );
extern void GameEnd( short );
extern void ClrScreen(void);
extern void UpdateDisplay( int, int, int, int );
extern void GetOpenings(void);
extern void ShowDepth( char );
extern void ShowCurrentMove( short, short, short );
extern void ShowSidetomove(void);
extern void ShowMessage( const char * );
extern void SearchStartStuff( short );

/* invoked by Chess.app modules */
extern void init_gnuchess(void);
extern void new_game(void);
extern void in_check(void);

extern void get_game ( NSString * );
extern int  save_game( NSString * );
extern int  list_game( NSString * );

extern void undo_move(void);
extern int  give_hint(void);

extern NSString *convert_rowcol( int, int, int, int, int );
extern BOOL verify_move( NSString * );

extern void select_move_start( int, int );
extern void select_move_end(void);
extern BOOL select_loop_end(void);
extern void select_loop(void);

extern void run_computer_game(void);
extern void stop_computer_game(void);
extern void select_computer_move(void);

extern int  current_player(void);
extern int  game_count(void);
extern int  move_time(void);
extern int  response_time(void);
extern void reset_response_time(void);
extern int  elapsed_time(void);
extern short *default_pieces(void);
extern short *default_colors(void);
extern short *current_pieces(void);
extern short *current_colors(void);

extern int  game_level(void);
extern void set_game_level( int );
extern void interpret_level( int, int *, int * );

extern void set_preferences(struct Preferences *);

extern void set_timeout( BOOL );
extern void set_game_queen( int );

extern NSString *copyright_text(void);
extern NSString *user_fullname(void);
extern void sleep_microsecs( unsigned );
extern int  floor_value( double );
