/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
*/


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBOutlineView.h"
#import "IMBNodeViewController.h"
#import "IMBLibraryController.h"
#import "IMBNode.h"
#import "IMBTextFieldCell.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBOutlineView

@synthesize draggingPrompt = _draggingPrompt;
@synthesize textCell = _textCell;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithFrame:(NSRect)inFrame
{
	if (self = [super initWithFrame:inFrame])
	{
		_subviewsInVisibleRows = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		_subviewsInVisibleRows = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}


- (void) awakeFromNib
{
	self.draggingPrompt = NSLocalizedStringWithDefaultValue(
		@"IMBOutlineView.draggingPrompt",
		nil,IMBBundle(),
		@"Drag additional folders here",
		@"String that is displayed in the IMBOutlineView");

	CGFloat size = [NSFont systemFontSizeForControlSize:NSSmallControlSize];
	NSFont* font = [NSFont boldSystemFontOfSize:size];
	
	self.textCell = [[[IMBTextFieldCell alloc] initTextCell:@""] autorelease];
	[self.textCell setAlignment:NSCenterTextAlignment];
	[self.textCell setVerticalAlignment:kIMBBottomTextAlignment];
	[self.textCell setFont:font];
	[self.textCell setTextColor:[NSColor grayColor]];

	// We need to save preferences before tha app quits...
	
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_redraw) 
		name:kIMBNodesWillReloadNotification 
		object:nil];

	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_redraw) 
		name:kIMBNodesDidChangeNotification 
		object:nil];
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	IMBRelease(_subviewsInVisibleRows);
	IMBRelease(_draggingPrompt);
	IMBRelease(_textCell);
 
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// Calculate the frame rect for progress indicator wheels...

- (NSRect) badgeRectForRow:(NSInteger)inRow
{
	NSRect cellRect = NSIntersectionRect([self rectOfRow:inRow],self.visibleRect);
	
	NSRect badgeRect = cellRect;
	badgeRect.size.width = 16.0;
	badgeRect.size.height = 16.0;
	badgeRect.origin.x = NSMaxX(cellRect) - badgeRect.size.width - 4.0;
	badgeRect.origin.y += floor(0.5*(cellRect.size.height-badgeRect.size.height));
		
	return badgeRect;	
}


//----------------------------------------------------------------------------------------------------------------------


- (void) _redraw
{
	[self setNeedsDisplay:YES];
}


- (void) viewWillDraw
{
	[super viewWillDraw];

	// First get rid of any progress indicators that are not currently visible or no longer needed...
	
	NSRect visibleRect = self.visibleRect;
	NSRange visibleRows = [self rowsInRect:visibleRect];
	NSMutableArray* keysToRemove = [NSMutableArray array];
	
	for (NSString* row in _subviewsInVisibleRows)
	{
		NSInteger i = [row intValue];
		id item = [self itemAtRow:i];
		IMBNode* node = [item representedObject];
		
		if (!NSLocationInRange(i,visibleRows) || node.badgeTypeNormal != kIMBBadgeTypeLoading)
		{
			NSProgressIndicator* wheel = [_subviewsInVisibleRows objectForKey:row];
			[wheel stopAnimation:nil];
			[wheel removeFromSuperview];
			[keysToRemove addObject:row];
		}
	}
	
	[_subviewsInVisibleRows removeObjectsForKeys:keysToRemove];

	// Then add progress indicators for all nodes that need one (currently loading) and are currently visible...
	
	for (NSInteger i=visibleRows.location; i<visibleRows.location+visibleRows.length; i++)
	{
		id item = [self itemAtRow:i];
		IMBNode* node = [item representedObject];
		NSString* row = [NSString stringWithFormat:@"%d",i];
		NSProgressIndicator* wheel = [_subviewsInVisibleRows objectForKey:row];
		
		if (wheel == nil && node != nil && node.badgeTypeNormal == kIMBBadgeTypeLoading)
		{
			NSRect badgeRect = [self badgeRectForRow:i];
			NSProgressIndicator* wheel = [[NSProgressIndicator alloc] initWithFrame:badgeRect];
			
			[wheel setAutoresizingMask:NSViewNotSizable];
			[wheel setStyle:NSProgressIndicatorSpinningStyle];
			[wheel setControlSize:NSSmallControlSize];
			[wheel setUsesThreadedAnimation:YES];
			[wheel setIndeterminate:YES];
			
			[_subviewsInVisibleRows setObject:wheel forKey:row];
			[self addSubview:wheel];
			[wheel startAnimation:nil];
			[wheel release];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) drawRect:(NSRect)inRect	
{
	// First draw the NSOutlineView...
	
	[super drawRect:inRect];
	
	// Then draw the prompt string at the bottom...
	
	const CGFloat MARGIN_BELOW = 15.0;
	const CGFloat FADE_AREA = 35.0;
	CGFloat viewHeight = self.bounds.size.height;
	CGFloat dataHeight = self.rowHeight * self.numberOfRows;	
	
	if (dataHeight+MARGIN_BELOW <= viewHeight)
	{
		CGFloat fadeHeight = MIN(viewHeight-dataHeight,MARGIN_BELOW+FADE_AREA) - MARGIN_BELOW;
		CGFloat alpha = (float)fadeHeight / FADE_AREA;

		NSTextFieldCell* textCell = self.textCell;
		[textCell setTextColor:[NSColor colorWithCalibratedWhite:0.66667 alpha:alpha]];
		[textCell setStringValue:self.draggingPrompt];
		
		NSRect textRect = NSInsetRect([self visibleRect], 12.0, 12.0);
		[textCell drawWithFrame:textRect inView:self];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Ask the IMBNodeViewController (which is our delegate) to return a context menu for the clicked node. If  
// the user clicked on the background node is nil...

- (NSMenu*) menuForEvent:(NSEvent*)inEvent
{
	NSPoint mouse = [self convertPoint:[inEvent locationInWindow] fromView:nil];
	NSInteger i = [self rowAtPoint:mouse];
	NSInteger n = [self numberOfRows];
	IMBNode* node = nil;
	
	if (i>=0 && i<n)
	{
		id item = [self itemAtRow:i];
		node = [item representedObject];
	}

	IMBNodeViewController* controller = (IMBNodeViewController*) self.delegate;
	[controller selectNode:node];
	return [controller menuForNode:node];
}
			

//----------------------------------------------------------------------------------------------------------------------


@end
