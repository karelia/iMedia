/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBNodeCell.h"
#import "IMBNode.h"
#import "IMBAlertPopover.h"
#import "IMBNodeViewController.h"
#import "IMBLibraryController.h"
#import "IMBAccessRightsController.h"
#import "IMBAccessRightsViewController.h"
#import "IMBOutlineView.h"
#import "SBUtilities.h"
#import "IMBParserMessenger.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

#define kIconImageSize		16.0
#define kImageOriginXOffset 3.0
#define kImageOriginYOffset 0.0
#define kTextOriginXOffset	3.0
#define kTextOriginYOffset	2.0
#define kTextHeightAdjust	4.0


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBNodeCell

@synthesize isGroupCell = _isGroupCell;
@synthesize node = _node;
@synthesize icon = _icon;
@synthesize badgeIcon = _badgeIcon;
@synthesize badgeError = _badgeError;
@synthesize badgeType = _badgeType;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		[self setTruncatesLastVisibleLine:YES];
		
		_badgeType = 0;
		_clickedRect = NSZeroRect;
		
		[self setTarget:self];
		[self setAction:@selector(showPopover:)];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_node);
	IMBRelease(_icon);
 	IMBRelease(_badgeIcon);
 	IMBRelease(_badgeError);
	
   [super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
    IMBNodeCell* cell = (IMBNodeCell*) [super copyWithZone:inZone];
	
    cell->_isGroupCell = _isGroupCell;
    cell->_node = [_node retain];
    cell->_icon = [_icon retain];
	cell->_badgeIcon = [_badgeIcon retain];
	cell->_badgeError = [_badgeError retain];
	cell->_badgeType = _badgeType;
	cell->_clickedRect = _clickedRect;
	
    return cell;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) drawWithFrame:(NSRect)inFrame inView:(NSView*)inControlView
{
	BOOL isFlipped = inControlView.isFlipped;

	// Set title font and color...
	
	if ([self isGroupCell])
	{
		self.font = [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]];
		self.textColor = [NSColor disabledControlTextColor];
	}
	else
	{
		self.font = [NSFont systemFontOfSize:[NSFont systemFontSize]];
		self.textColor = [NSColor controlTextColor];
	}

	// Draw the image...
	
	if (_icon)
	{
		NSRect iconRect = [self imageRectForBounds:inFrame flipped:isFlipped];
		[_icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:isFlipped hints:nil];
	}
	
	// Draw the title...
	
	NSRect titleRect = [self titleRectForBounds:inFrame flipped:isFlipped];
	[super drawWithFrame:titleRect inView:inControlView];
	
	// Draw the badge...
	
	if (_badgeIcon != nil && !_isGroupCell)
	{
		NSRect badgeRect = [self badgeRectForBounds:inFrame flipped:isFlipped];
		[_badgeIcon drawInRect:badgeRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:isFlipped hints:nil];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (NSRect) imageRectForBounds:(NSRect)inBounds flipped:(BOOL)inFlipped
{	
	NSRect imageRect = inBounds;
	
	imageRect.origin.x += kImageOriginXOffset;
	imageRect.origin.y -= kImageOriginYOffset;
	imageRect.size = NSMakeSize(kIconImageSize,kIconImageSize);

	if (inFlipped)
	{
		imageRect.origin.y += ceil(0.5 * (inBounds.size.height - imageRect.size.height));
	}
	else
	{
		imageRect.origin.y -= ceil(0.5 * (inBounds.size.height - imageRect.size.height));
	}

	return imageRect;
}


- (NSRect) titleRectForBounds:(NSRect)inBounds flipped:(BOOL)inFlipped
{	
	NSRect titleRect = inBounds;

	if (self.isGroupCell)
	{
		titleRect.origin.x -= 3.0;
		titleRect.origin.y += inFlipped ? 4.0 : -4.0;
		titleRect.size.height -= kTextHeightAdjust;
	}
	else
	{
		titleRect.origin.x += kTextOriginXOffset + kIconImageSize + kTextOriginXOffset;
		titleRect.origin.y += kTextOriginYOffset;
		titleRect.size.width -= kIconImageSize + kTextOriginXOffset;
		titleRect.size.height -= kTextHeightAdjust;
		
		if (_badgeIcon)
		{
			titleRect.size.width -= kIconImageSize + kTextOriginXOffset;
		}
	}

	return titleRect;
}


- (NSRect) badgeRectForBounds:(NSRect)inBounds flipped:(BOOL)inFlipped
{	
	NSRect badgeRect = inBounds;
	badgeRect.origin.x = NSMaxX(inBounds) - kIconImageSize + kImageOriginXOffset;
	badgeRect.origin.y -= kImageOriginYOffset;
	badgeRect.size = NSMakeSize(kIconImageSize,kIconImageSize);

	if (inFlipped)
	{
		badgeRect.origin.y += ceil(0.5 * (inBounds.size.height - badgeRect.size.height));
	}
	else
	{
		badgeRect.origin.y -= ceil(0.5 * (inBounds.size.height - badgeRect.size.height));
	}
	
	return badgeRect;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) isGroupCell
{
	return _isGroupCell;
//    return (self.icon == nil && self.title.length > 0);
}


//----------------------------------------------------------------------------------------------------------------------


- (NSSize) cellSize
{
    NSSize cellSize = [super cellSize];
    cellSize.width += (_icon ? [_icon size].width : 0) + 3;
    return cellSize;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


//- (void) editWithFrame:(NSRect)inFrame inView:(NSView*)inControlView editor:(NSText*)inText delegate:(id)inDelegate event:(NSEvent*)inEvent
//{
//	NSRect titleRect = [self titleRectForBounds:inFrame];
//	[super editWithFrame:titleRect inView:inControlView editor:inText delegate:inDelegate event:inEvent];
//}


//----------------------------------------------------------------------------------------------------------------------


//- (void) selectWithFrame:(NSRect)inFrame inView:(NSView*)inControlView editor:(NSText*)inText delegate:(id)inDelegate start:(NSInteger)inStart length:(NSInteger)inLength
//{
//	NSRect titleRect = [self titleRectForBounds:inFrame];
//	[super selectWithFrame:titleRect inView:inControlView editor:inText delegate:inDelegate start:inStart length:inLength];
//}


//----------------------------------------------------------------------------------------------------------------------


// Check if we clicked on a badge icon...

- (NSUInteger) hitTestForEvent:(NSEvent*)inEvent inRect:(NSRect)inCellFrame ofView:(NSView*)inControlView
{
	if (_badgeIcon)
	{
		NSPoint mouse = [inControlView convertPoint:[inEvent locationInWindow] fromView:nil];
		NSRect badgeRect = [self badgeRectForBounds:inCellFrame flipped:inControlView.isFlipped];
		
		if (NSPointInRect(mouse,badgeRect))
		{
			return NSCellHitContentArea | NSCellHitTrackableArea;
		}
	}
	
	return NSCellHitNone;
}


+ (BOOL) prefersTrackingUntilMouseUp
{
     return YES;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) trackMouse:(NSEvent*)inEvent inRect:(NSRect)inCellFrame ofView:(NSView*)inControlView untilMouseUp:(BOOL)flag
{
    [self setControlView:inControlView];
 
	BOOL isFlipped = inControlView.isFlipped;
	NSRect badgeRect = [self badgeRectForBounds:inCellFrame flipped:isFlipped];
	BOOL inside = NO;
	
    while ([inEvent type] != NSLeftMouseUp)
	{
        NSPoint point = [inControlView convertPoint:[inEvent locationInWindow] fromView:nil];
        inside = NSMouseInRect(point,badgeRect,isFlipped);

        if ([inEvent type] == NSMouseEntered || [inEvent type] == NSMouseExited)
		{
            [NSApp sendEvent:inEvent];
        }

        inEvent = [[inControlView window] nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseEnteredMask | NSMouseExitedMask)];
    }
 
    if (inside)
	{
		_clickedRect = badgeRect;

		if (_badgeType == kIMBBadgeTypeNoAccessRights)
		{
			[self showAccessRightsPopover:nil];
		}
		else if (_badgeError)
		{
			[self showErrorPopover:nil];
		}
    }
 
    return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// If so then display an alert. On Lion we'll use a modeless popover, on earlier system just use a modal NSAlert...

- (IBAction) showErrorPopover:(id)inSender
{
	if (IMBRunningOnLionOrNewer())
	{
		NSString* title = [[_badgeError userInfo] objectForKey:@"title"];
		NSString* description = [[_badgeError userInfo] objectForKey:NSLocalizedDescriptionKey];
		NSString* ok = @"   OK   ";

		IMBAlertPopover* alert = [IMBAlertPopover warningPopoverWithHeader:title body:description footer:nil];
		
		[alert addButtonWithTitle:ok block:^()
		{
			[alert close];
		}];
		
		[alert showRelativeToRect:_clickedRect ofView:self.controlView preferredEdge:NSMaxYEdge];
	}
	else
	{
		[NSApp presentError:_badgeError];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) showAccessRightsPopover:(id)inSender
{
	NSString* libraryName = self.title;

	NSString* title = NSLocalizedStringWithDefaultValue(
		@"IMBNodeCell.grantAccessRightsTitle",
		nil,
		IMBBundle(),
		@"Access to Media Files Not Allowed",
		@"Alert title");

	NSString* format = NSLocalizedStringWithDefaultValue(
		@"IMBNodeCell.grantAccessRightsMessage",
		nil,
		IMBBundle(),
		@"The application does not have the necessary rights to access the media files in %@.\n\n Click the \"Grant Access\" button to allow the application to access these media files.",
		@"Alert message");
		
	NSString* ok = NSLocalizedStringWithDefaultValue(
		@"IMBNodeCell.grantAccessRightsButton",
		nil,
		IMBBundle(),
		@"Grant Access",
		@"Alert button");

	NSString* message = [NSString stringWithFormat:format,libraryName];
	IMBAlertPopover* alert = [IMBAlertPopover warningPopoverWithHeader:title body:message footer:nil];
	
	[alert addButtonWithTitle:ok block:^()
	{
		[[IMBAccessRightsViewController sharedViewController] grantAccessRightsForNode:self.node];
		[alert close];
	}];
	
	[alert showRelativeToRect:_clickedRect ofView:self.controlView preferredEdge:NSMaxYEdge];
}


//----------------------------------------------------------------------------------------------------------------------


@end

