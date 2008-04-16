/*
 iMedia Browser <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
 Redistributions of source code must retain the original terms stated here,
 including this list of conditions, the disclaimer noted below, and the
 following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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


#import "iMBVerticallyAlignedTextCell.h"


@interface iMBVerticallyAlignedTextCell (Private)
- (void)drawVerticallyCenteredWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (void)drawAtBottomOfCellWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
@end


@implementation iMBVerticallyAlignedTextCell

- (id)initTextCell:(NSString *)aString
{
	[super initTextCell:aString];
	[self setVerticalAlignment:iMBVerticalCenterTextAlignment];
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	[super initWithCoder:decoder];
	[self setVerticalAlignment:iMBVerticalCenterTextAlignment];
	return self;
}

// We don't need to implement copyWithZone: since only instance variable is not an object

# pragma mark *** Accessors ***

- (iMBVerticalTextAlignment)verticalAlignment { return myVerticalAlignment; }

- (void)setVerticalAlignment:(iMBVerticalTextAlignment)alignment
{
	myVerticalAlignment = alignment;
}

# pragma mark *** Drawing ***

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	switch ([self verticalAlignment])
	{
			// If vertically aligned to the top, just do the normal drawing
		case iMBTopTextAlignment:
			[super drawWithFrame: cellFrame inView: controlView];
			break;
			
		case iMBVerticalCenterTextAlignment:
			[self drawVerticallyCenteredWithFrame: cellFrame inView: controlView];
			break;
			
		case iMBBottomTextAlignment:
			[self drawAtBottomOfCellWithFrame: cellFrame inView: controlView];
			break;
	}
}

- (void)drawVerticallyCenteredWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize textSize = [self cellSizeForBounds: cellFrame];
	float verticalOffset = (cellFrame.size.height - textSize.height) / 2;
	NSRect centeredCellFrame = NSInsetRect(cellFrame, 0.0, verticalOffset);
	
	[super drawWithFrame: centeredCellFrame inView: controlView];
}

- (void)drawAtBottomOfCellWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize textSize = [self cellSizeForBounds: cellFrame];
	
	// The y co-ordinate depends on the view being flipped or not
	float y = cellFrame.origin.y;
	if ([controlView isFlipped]) {
		y = cellFrame.origin.y + cellFrame.size.height - textSize.height;
	}
	
	NSRect bottomFrame = NSMakeRect(cellFrame.origin.x,
									y,
									cellFrame.size.width,
									textSize.height);
	
	[super drawWithFrame: bottomFrame inView: controlView];
}

@end
