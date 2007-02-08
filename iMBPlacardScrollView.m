#import "iMBPlacardScrollView.h"

@implementation iMBPlacardScrollView

/*"	iMBPlacardScrollView is used to place a small view to the left or right of a horizontal scrollbar, or top or bottom of a vertical scrollbar, in a scrollview. Replace #NSScrollView with #iMBPlacardScrollView and then hook up a view to the "placard" outlet.  (The view should be 16 pixels high or wide.)
"*/

/*"	Release all the objects held by self, then call superclass.
"*/

- (void) dealloc
{
	[placard release];
	[super dealloc];
}

/*"	Set the side (!{PLACARD_TOP_LEFT} or !{PLACARD_BOTTOM_RIGHT}) that the placard will appear on.
"*/

- (void) setSide:(int) inSide
{
	_side = inSide;
}

/*"	This setter puts it into the superview.  Therefore, if you hook it up from Interface Builder,
	the view will be installed automagically. "*/

- (void) setPlacard:(NSView *)inView
{
	[inView retain];
	if (nil != placard)
	{
		[placard removeFromSuperview];
		[placard release];
	}
	placard = inView;
	[self addSubview:placard];
}

/*"	Return the placard view
"*/

- (NSView *) placard
{
	return placard;
}

/*"	Tile the view.  This invokes super to do most of its work, but then fits the placard into place.
"*/

- (void)tile
{
	[super tile];
	
	// horizontal placard is the usual case, so give this priority.  If we have both and we want it on the vertical, we're SOL without a rewrite.
	
	if (placard && [self hasHorizontalScroller])
	{
		NSScroller *horizScroller;
		NSRect horizScrollerFrame, placardFrame;

		horizScroller = [self horizontalScroller];
		horizScrollerFrame = [horizScroller frame];
		placardFrame = [placard frame];

		// Now we'll just adjust the horizontal scroller size and set the placard size and location.
		horizScrollerFrame.size.width -= placardFrame.size.width;
		[horizScroller setFrameSize:horizScrollerFrame.size];

		if (PLACARD_TOP_LEFT == _side)
		{
			// Put placard where the horizontal scroller is
			placardFrame.origin.x = NSMinX(horizScrollerFrame);
			
			// Move horizontal scroller over to the right of the placard
			horizScrollerFrame.origin.x = NSMaxX(placardFrame);
			[horizScroller setFrameOrigin:horizScrollerFrame.origin];
		}
		else	// on right
		{
			// Put placard to the right of the new scroller frame
			placardFrame.origin.x = NSMaxX(horizScrollerFrame);
		}
		// Adjust height of placard
		placardFrame.size.height = horizScrollerFrame.size.height + 1.0;
		placardFrame.origin.y = [self bounds].size.height - placardFrame.size.height + 1.0;
		
		// Move the placard into place
		[placard setFrame:placardFrame];
	}

	else if (placard && [self hasVerticalScroller])
	{
		NSScroller *vertScroller = [self verticalScroller];
		NSRect vertScrollerFrame = [vertScroller frame];
			NSRect placardFrame = [placard frame];
		
		// Now we'll just adjust the vertical scroller size and set the placard size and location.
		vertScrollerFrame.size.height -= placardFrame.size.height;
		[vertScroller setFrameSize:vertScrollerFrame.size];
		
		if (PLACARD_TOP_LEFT == _side)
		{
			// Put placard where the vertical scroller is
			placardFrame.origin.y = NSMinY(vertScrollerFrame);
			
			// Move vertical scroller over to the right of the placard
			vertScrollerFrame.origin.y = NSMaxY(placardFrame);
			[vertScroller setFrameOrigin:vertScrollerFrame.origin];
		}
		else	// on bottom
		{
			// Put placard to the right of the new scroller frame
			placardFrame.origin.y = NSMaxY(vertScrollerFrame);
		}
		// Adjust WIDTH of placard
		placardFrame.size.width = vertScrollerFrame.size.width;
		placardFrame.origin.x = [self bounds].size.width - placardFrame.size.width - 1.0;
		
		// Move the placard into place
		[placard setFrame:placardFrame];
	}
}

@end
