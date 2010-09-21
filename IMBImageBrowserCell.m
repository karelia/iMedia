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


// Author: Peter Baumgartner, Dan Wood


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBImageBrowserCell.h"
#import "IMBObject.h"
#import "IMBNode.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


@interface IKImageBrowserCell ()

- (void) setDataSource:(id)inDataSource;
- (void) drawShadow;
- (void) drawImageOutline;
- (NSRect) usedRectInCellFrame:(NSRect)inFrame;
- (NSRect) imageContainerFrame;
- (IKImageBrowserView*) imageBrowserView;	// To shut up the compiler when using 10.5.sdk

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBImageBrowserCell

@synthesize imbShouldDrawOutline = _imbShouldDrawOutline;
@synthesize imbShouldDrawShadow = _imbShouldDrawShadow;
@synthesize imbShouldDisableTitle = _imbShouldDisableTitle;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		_imbShouldDrawOutline = YES;
		_imbShouldDrawShadow = YES;
		_imbShouldDisableTitle = NO;
	}
	
	return self;
}


//----------------------------------------------------------------------------------------------------------------------


// Disable outline and shadow drawing for certion objects...

- (void) setDataSource:(id)inDataSource
{
	[super setDataSource:inDataSource];
	
	if ([inDataSource isKindOfClass:[IMBObject class]])
	{
		IMBObject* object = (IMBObject*)inDataSource;
		_imbShouldDrawOutline = object.shouldDrawAdornments;
		_imbShouldDrawShadow = object.shouldDrawAdornments;
		_imbShouldDisableTitle = object.shouldDisableTitle;
	}
}

//----------------------------------------------------------------------------------------------------------------------


// Drawing outlines and shadows should be suppress in some cases (e.g. for IMBNodeObjects which are displayed 
// as non-rectangular folder icons)...

- (void) drawShadow
{
	if (_imbShouldDrawShadow)
	{
		[super drawShadow];	
	}
}


- (void) drawImageOutline
{
	if (_imbShouldDrawOutline)
	{
		[super drawImageOutline];	
	}	
}


// Draw the image itself. In the case of an IMBNodeObject (which is represented as a large folder icon)
// we should draw a small badge icon on top of the large folder icon. This si used to distinguish various 
// kinds of subnodes visually (e.g. iPhoto events, albums, etc)...

//- (void) drawImage:(id)inImage
//{
//	[super drawImage:inImage];
//	
//	id datasource = self.dataSource;
//	
//	if ([datasource isKindOfClass:[IMBNodeObject class]])
//	{
//		IMBNode* node = (IMBNode*) datasource;
//		NSImage* icon = node.icon;
//		NSRect frame = [self imageFrame];
//		CGFloat x0 = 20; //NSMidX(frame);
//		CGFloat y0 = 20; //NSMidY(frame);
//		CGFloat dx = 16.0;
//		CGFloat dy = 16.0;
//		frame = NSMakeRect(x0-0.5*dx,y0-0.5*dy,dx,dy);
//		[icon drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
//	}
//}


//----------------------------------------------------------------------------------------------------------------------


- (CGFloat) pointSize
{
	CGFloat points = 0;
	CGFloat width = [((id)self) size].width;
	if (width < 60) points = 9;
	else if (width < 70) points = 10;
	else points = 11;

	return points;
}


// Is there any smarter way to do this?

- (void) setTitleColors
{
	CGFloat points = [self pointSize];	// we need to get the whole font thing since we have to set the whole attributes
	
	NSMutableDictionary *attributes1 = [NSMutableDictionary dictionaryWithObject:[NSFont systemFontOfSize:points] forKey:NSFontAttributeName];
	NSMutableDictionary *attributes2 = [NSMutableDictionary dictionaryWithDictionary:attributes1];
	
	// Now set the title color.  Try to match what we see in table views. 
	// Enabled: Black, white if Selected; Disabled: grayed out.
	
	if (_imbShouldDisableTitle)
	{
		[attributes1 setObject:[NSColor colorWithCalibratedWhite:0.0 alpha:0.4] forKey:NSForegroundColorAttributeName];
		[attributes2 setObject:[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] forKey:NSForegroundColorAttributeName];
	}
	else
	{
		[attributes1 setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
		[attributes2 setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	}

	if (IMBRunningOnSnowLeopardOrNewer())
	{
		[[((id)self) imageBrowserView] setValue:attributes1  forKey:IKImageBrowserCellsTitleAttributesKey];
		[[((id)self) imageBrowserView] setValue:attributes2 forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];
	}
	else
	{
		[[((id)self) parent] setValue:attributes1  forKey:IKImageBrowserCellsTitleAttributesKey];
		[[((id)self) parent] setValue:attributes2 forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];
	}	
}


- (void) drawTitle
{
	[self setTitleColors];
	[super drawTitle];
}


//----------------------------------------------------------------------------------------------------------------------


//- (BOOL) wantsRollover
//{
//	return [super wantsRollover];
//}
//
//
//- (void) mouseEntered:(NSEvent*)inEvent
//{
//	[super mouseEntered:(NSEvent*)inEvent];
//}
//
//
//- (void) mouseExited:(NSEvent*)inEvent
//{
//	[super mouseExited:(NSEvent*)inEvent];
//}


//----------------------------------------------------------------------------------------------------------------------


@end

