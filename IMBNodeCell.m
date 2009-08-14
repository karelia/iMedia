/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBNodeCell.h"
#import "IMBNode.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

#define kIconImageSize		16.0
#define kImageOriginXOffset 3
#define kImageOriginYOffset 0
#define kTextOriginXOffset	2
#define kTextOriginYOffset	1
#define kTextHeightAdjust	4


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBNodeCell

@synthesize image = _image;
@synthesize badgeType = _badgeType;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		[self setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
	}
	
	return self;
}


- (id) copyWithZone:(NSZone*)inZone
{
    IMBNodeCell* cell = (IMBNodeCell*) [super copyWithZone:inZone];
    cell->_image = [_image retain];
    cell->_badgeType = _badgeType;
    return cell;
}


- (void) dealloc
{
	IMBRelease(_image);
    [super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (NSRect) imageRectForBounds:(NSRect)inBounds flipped:(BOOL)inFlipped
{	
	NSRect imageRect = inBounds;
	
	imageRect.origin.x += kImageOriginXOffset;
	imageRect.origin.y -= kImageOriginYOffset;
	imageRect.size = [_image size];

	if (inFlipped)
		imageRect.origin.y += ceil(0.5 * (inBounds.size.height + imageRect.size.height));
	else
		imageRect.origin.y += ceil(0.5 * (inBounds.size.height - imageRect.size.height));

	return imageRect;
}


- (NSRect) titleRectForBounds:(NSRect)inBounds flipped:(BOOL)inFlipped
{	
	// the cell has an image: draw the normal item cell
	NSRect imageFrame;

	NSSize imageSize = [_image size];
	NSDivideRect(inBounds, &imageFrame, &inBounds, 3 + imageSize.width, NSMinXEdge);

	imageFrame.origin.x += kImageOriginXOffset;
	imageFrame.origin.y -= kImageOriginYOffset;
	imageFrame.size = imageSize;
	
	imageFrame.origin.y += ceil((inBounds.size.height - imageFrame.size.height) / 2);
	
	NSRect titleRect = inBounds;
	titleRect.origin.x += kTextOriginXOffset;
	titleRect.origin.y += kTextOriginYOffset;
	titleRect.size.width -= 19.0;
	titleRect.size.height -= kTextHeightAdjust;

	return titleRect;
}


- (NSRect) badgeRectForBounds:(NSRect)inBounds flipped:(BOOL)inFlipped
{	
	NSRect badgeRect = inBounds;
	
	badgeRect.origin.x = NSMaxX(inBounds) - kImageOriginXOffset - 16.0;
	badgeRect.origin.y -= kImageOriginYOffset;
	badgeRect.size = NSMakeSize(16.0,16.0);

	if (inFlipped)
		badgeRect.origin.y += ceil(0.5 * (inBounds.size.height + badgeRect.size.height));
	else
		badgeRect.origin.y += ceil(0.5 * (inBounds.size.height - badgeRect.size.height));

	return badgeRect;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) isGroupCell
{
    return (self.image == nil && self.title.length > 0);
}


//----------------------------------------------------------------------------------------------------------------------


- (NSSize) cellSize
{
    NSSize cellSize = [super cellSize];
    cellSize.width += (_image ? [_image size].width : 0) + 3;
    return cellSize;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


//----------------------------------------------------------------------------------------------------------------------


- (void) drawWithFrame:(NSRect)inFrame inView:(NSView*)inControlView
{
	BOOL isFlipped = inControlView.isFlipped;

	// If we have an image then draw cell contents in several steps...
	
	if (_image)
	{
		NSRect imageRect = [self imageRectForBounds:inFrame flipped:isFlipped];
		[_image compositeToPoint:imageRect.origin operation:NSCompositeSourceOver];

		NSRect titleRect = [self titleRectForBounds:inFrame flipped:isFlipped];
		[super drawWithFrame:titleRect inView:inControlView];
 
   }
	
	// Otherwise let the superclass do the drawing (but center the text vertically)...
	
	else 
	{
//		if ([self isGroupCell])
//		{
			CGFloat yOffset = -2.0;
			inFrame.origin.y -= 2.0;
			[super drawWithFrame:inFrame inView:inControlView];
//		}
	}

	// Add the spinning wheel subview if we are currently loading a node...
	
//	NSRect badgeRect = [self badgeRectForBounds:inFrame flipped:isFlipped];
//	NSImage* badge = [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];
//	[badge compositeToPoint:badgeRect.origin operation:NSCompositeSourceOver fraction:0.5];
}


//----------------------------------------------------------------------------------------------------------------------

- (void) editWithFrame:(NSRect)inFrame inView:(NSView*)inControlView editor:(NSText*)inText delegate:(id)inDelegate event:(NSEvent*)inEvent
{
	NSRect titleRect = [self titleRectForBounds:inFrame];
	[super editWithFrame:titleRect inView:inControlView editor:inText delegate:inDelegate event:inEvent];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) selectWithFrame:(NSRect)inFrame inView:(NSView*)inControlView editor:(NSText*)inText delegate:(id)inDelegate start:(int)inStart length:(int)inLength
{
	NSRect titleRect = [self titleRectForBounds:inFrame];
	[super selectWithFrame:titleRect inView:inControlView editor:inText delegate:inDelegate start:inStart length:inLength];
}


//----------------------------------------------------------------------------------------------------------------------


// In 10.5, we need you to implement this method for blocking drag and drop of a given cell. So NSCell hit testing 
// will determine if a row can be dragged or not. NSTableView calls this cell method when starting a drag, if the 
// hit cell returns NSCellHitTrackableArea, the particular row will be tracked instead of dragged...

- (NSUInteger) hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
	NSInteger result = NSCellHitContentArea;
	
//	NSOutlineView* hostingOutlineView = (NSOutlineView*)[self controlView];
//	if (hostingOutlineView)
//	{
//		NSInteger selectedRow = [hostingOutlineView selectedRow];
//		BaseNode* node = [[hostingOutlineView itemAtRow:selectedRow] representedObject];
//
//		if (![node isDraggable])	// is the node isDraggable (i.e. non-file system based objects)
//			result = NSCellHitTrackableArea;
//	}
		
	return result;
}


//----------------------------------------------------------------------------------------------------------------------


@end

