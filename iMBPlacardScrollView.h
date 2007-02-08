#import <Cocoa/Cocoa.h>

enum {
    PLACARD_TOP_LEFT		= 0,		// default
    PLACARD_BOTTOM_RIGHT	= 1
};

@interface iMBPlacardScrollView : NSScrollView {
    IBOutlet NSView *placard;
	int	_side;
}

- (void) setPlacard:(NSView *)inView;
- (NSView *) placard;
- (void) setSide:(int) inSide;

@end
