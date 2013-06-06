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

#import "IMBTableView.h"
#import "IMBObjectViewController.h"
#import "IMBButtonObject.h"
#import "IMBQLPreviewPanel.h"
#import "IMBTableViewAppearance+iMediaPrivate.h"
#import "NSPasteboard+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

enum IMBMouseOperation
{
	kMouseOperationNone,
	kMouseOperationButtonClick
};


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBTableView

@synthesize mouseOperation = _mouseOperation;
@synthesize clickedObjectIndex = _clickedObjectIndex;
@synthesize clickedObject = _clickedObject;

@synthesize imb_Appearance = _appearance;


- (void)setImb_Appearance:(IMBTableViewAppearance *)inAppearance
{
    if (_appearance == inAppearance) {
        return;
    }
    if (_appearance) {
        [_appearance unsetView];
    }
    [_appearance release];
    _appearance = inAppearance;
    [_appearance retain];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithFrame:(NSRect)inFrame
{
	if (self = [super initWithFrame:inFrame])
	{
		_mouseOperation = kMouseOperationNone;
		_clickedObjectIndex = -1;
		_clickedObject = nil;
        self.imb_Appearance = [self defaultAppearance];
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		_mouseOperation = kMouseOperationNone;
		_clickedObjectIndex = -1;
		_clickedObject = nil;
        self.imb_Appearance = [self defaultAppearance];
	}
	
	return self;
}


- (void) dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	IMBRelease(_clickedObject);

    if (_appearance)
    {
        [_appearance unsetView];
        IMBRelease(_appearance);
    }
    
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Appearance

// This method is asking us to draw the backgrounds for all rows that are visible inside theClipRect.
// If possible delegate task to appearance object

- (void) drawBackgroundInClipRect:(NSRect)inClipRect
{
    if (!self.imb_Appearance || ![self.imb_Appearance drawBackgroundInClipRect:inClipRect])
    {
		[super drawBackgroundInClipRect:inClipRect];
    }
}


// This method is asking us to draw the hightlights for all of the selected rows that are visible inside theClipRect.
// If possible delegate task to appearance object

- (void)highlightSelectionInClipRect:(NSRect)inClipRect
{
    if (!self.imb_Appearance || ![self.imb_Appearance highlightSelectionInClipRect:inClipRect])
    {
        [super highlightSelectionInClipRect:inClipRect];
    }
}


// If we are using custom background and highlight colors, we may have to adjust the text colors accordingly,
// to make sure that text is always clearly readable...

- (NSCell*) preparedCellAtColumn:(NSInteger)inColumn row:(NSInteger)inRow
{
	NSCell* cell = [super preparedCellAtColumn:inColumn row:inRow];
	
    if (self.imb_Appearance) {
        [self.imb_Appearance prepareCell:cell atColumn:inColumn row:inRow];
    }
	
	return cell;
}


- (IMBTableViewAppearance*) defaultAppearance
{
    return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Event Handling


- (void) mouseDown:(NSEvent*)inEvent
{
	// Find the clicked object...
	
	NSPoint mouse = [self convertPoint:[inEvent locationInWindow] fromView:nil];
    _clickedObjectIndex = [self rowAtPoint:mouse];

	if (_clickedObjectIndex != -1)
	{
		NSArrayController* arrayController = nil;
		if ([self.delegate respondsToSelector:@selector(objectArrayController)])
		{
			arrayController = [self.delegate performSelector:@selector(objectArrayController)];
		}
		if (arrayController)
		{
			self.clickedObject = [arrayController.arrangedObjects objectAtIndex:_clickedObjectIndex];
		}
	}
	
	// If it was a button, then handle the click...
	
	if ([_clickedObject isKindOfClass:[IMBButtonObject class]])
	{
		_mouseOperation = kMouseOperationButtonClick;
		[(IMBButtonObject*)_clickedObject setImageRepresentationForState:YES];
		[self setNeedsDisplayInRect:[self rectOfRow:_clickedObjectIndex]];
	}
	
	// In case of a normal object start selecting or dragging. Indicate what object was clicked upon so  
	// thatdragging can happen to the clicked object, which is not necessarily the same row as one of 
	// the selection row(s)...
	
	else 
	{
		IMBObjectViewController* objectViewController = (IMBObjectViewController*) self.delegate;
		[objectViewController setClickedObject:self.clickedObject];
		_mouseOperation = kMouseOperationNone;
		[super mouseDown:inEvent];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Careful -- this only works in special cases; see
// http://www.cocoabuilder.com/archive/cocoa/234849-mousedragged-with-nstableview.html

- (void) mouseDragged:(NSEvent*)inEvent;
{
	// If a button was clicked then track that button and highlight it when inside...
	
	if (_mouseOperation == kMouseOperationButtonClick)
	{
		NSPoint mouse = [self convertPoint:[inEvent locationInWindow] fromView:nil];
		BOOL highlighted = [self rowAtPoint: mouse] == _clickedObjectIndex;
		[(IMBButtonObject*)_clickedObject setImageRepresentationForState:highlighted];
		[self setNeedsDisplayInRect:[self rectOfRow:_clickedObjectIndex]];
	}
	
	// Let the superclass handle other events...
	
	else
	{
		if (nil != [_clickedObject URL])
		{
			[super mouseDragged:inEvent];
		}
		// Ignore drag if we don't have a draggable object
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) mouseUp:(NSEvent*)inEvent
{
	// If a button was clicked the perform the click action and remove the highlight...
	
	if (_mouseOperation == kMouseOperationButtonClick)
	{
		NSPoint mouse = [self convertPoint:[inEvent locationInWindow] fromView:nil];
		NSInteger objectIndex = [self rowAtPoint:mouse];

		if (objectIndex == _clickedObjectIndex)
		{
			[(IMBButtonObject*)_clickedObject sendClickAction];
		}
			
		[(IMBButtonObject*)_clickedObject setImageRepresentationForState:NO];
		[self setNeedsDisplayInRect:[self rectOfRow:_clickedObjectIndex]];
	}
	
	// Let the superclass handle other events...
	
	else
	{
		[super mouseUp:inEvent];
	}

	// Cleanup...
	
	_mouseOperation = kMouseOperationNone;
	self.clickedObject = nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Ask the IMBNodeViewController (which is our delegate) to return a context menu for the clicked node.   
// If the user clicked on the background node is nil...

- (NSMenu*) menuForEvent:(NSEvent*)inEvent
{
	NSPoint mouse = [self convertPoint:[inEvent locationInWindow] fromView:nil];
	NSInteger i = [self rowAtPoint:mouse];
	NSInteger n = [self numberOfRows];
	IMBObject* object = nil;
	
	IMBObjectViewController* objectViewController = (IMBObjectViewController*) self.delegate;

	// Change the selection to the clicked row so that contextual menu matches properly.
	if (i>=0 && i<n && [objectViewController respondsToSelector:@selector(objectArrayController)])
	{
		object = [[objectViewController.objectArrayController arrangedObjects] objectAtIndex:i];
		[objectViewController.objectArrayController setSelectionIndex:i];
	}

	return [objectViewController menuForObject:object];
}

			
//----------------------------------------------------------------------------------------------------------------------


// Once a drag has finished, release the global array of IMBObjects, so that we don't leak anything...

- (void) draggingSession:(NSDraggingSession*)inSession endedAtPoint:(NSPoint)inScreenPoint operation:(NSDragOperation)inOperation
{
	[NSPasteboard imb_setIMBObjects:nil];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Quicklook


- (void) keyDown:(NSEvent*)inEvent
{
    NSString* key = [inEvent charactersIgnoringModifiers];
	NSUInteger modifiers = [inEvent modifierFlags];
	
    if([key isEqual:@"y"] && (modifiers&NSCommandKeyMask)!=0)
	{
		IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;
        [controller quicklook:self];
    } 
	else
	{
        [super keyDown:inEvent];
    }
}


- (BOOL) acceptsPreviewPanelControl:(QLPreviewPanel*)inPanel
{
	return YES;
}


- (void) beginPreviewPanelControl:(QLPreviewPanel*)inPanel
{
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;
    inPanel.delegate = controller;
    inPanel.dataSource = controller;
	
	if ([controller respondsToSelector:@selector(beginPreviewPanelControl:)])
	{
		[controller performSelector:@selector(beginPreviewPanelControl:) withObject:inPanel];
	}
}


- (void) endPreviewPanelControl:(QLPreviewPanel*)inPanel
{
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;
	
	if ([controller respondsToSelector:@selector(endPreviewPanelControl:)])
	{
		[controller performSelector:@selector(endPreviewPanelControl:) withObject:inPanel];
	}
	
    inPanel.delegate = nil;
    inPanel.dataSource = nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end
