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

#import "IMBTableView.h"
#import "IMBObjectViewController.h"
#import "IMBButtonObject.h"
#import "IMBQLPreviewPanel.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

enum IMBMouseOperation
{
	kMouseOperationNone,
	kMouseOperationButtonClick
};


//----------------------------------------------------------------------------------------------------------------------


@interface NSTableView (ShutUpTheCompiler)
- (NSColor*) _highlightColorForCell:(NSCell*)inCell;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBTableView

@synthesize mouseOperation = _mouseOperation;
@synthesize clickedObjectIndex = _clickedObjectIndex;
@synthesize clickedObject = _clickedObject;

@synthesize customBackgroundColors = _customBackgroundColors;
@synthesize customHighlightColor = _customHighlightColor;
@synthesize customTextColor = _customTextColor;
@synthesize customHighlightedTextColor = _customHighlightedTextColor;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithFrame:(NSRect)inFrame
{
	if (self = [super initWithFrame:inFrame])
	{
		_mouseOperation = kMouseOperationNone;
		_clickedObjectIndex = -1;
		_clickedObject = nil;
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
	}
	
	return self;
}


- (void) dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	IMBRelease(_clickedObject);
	IMBRelease(_customBackgroundColors);
	IMBRelease(_customHighlightColor);
	IMBRelease(_customTextColor);
	IMBRelease(_customHighlightedTextColor);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Drawing


// This is a private internal method. If it no longer going to be called, there's no harm in proving an override...

- (NSColor*) _highlightColorForCell:(NSCell*)inCell
{
	NSColor* color = nil;
	
	if ([self respondsToSelector:@selector(_highlightColorForCell:)])
	{
		color = [super _highlightColorForCell:inCell];
	}

	if (_customHighlightColor != nil) 
	{
		color = self.customHighlightColor; 
	}
	
	return color;
}


// If we have custom background colors, then draw the alternating row background ourself, otherwise let the 
// superclass draw Apple's default white & light blue rows...

- (void) drawBackgroundInClipRect:(NSRect)inClipRect
{
	if (_customBackgroundColors != nil)
	{
		NSUInteger n = [_customBackgroundColors count];
		NSUInteger i = 0;

		CGFloat height = self.rowHeight + self.intercellSpacing.height;
		NSRect clipRect = [self bounds];
		NSRect drawRect = clipRect;
		drawRect.origin = NSZeroPoint;
		drawRect.size.height = height;
		
		[[self backgroundColor] set];
		NSRectFillUsingOperation(inClipRect,NSCompositeSourceOver);
		
		while ((NSMinY(drawRect) <= NSHeight(clipRect)))
		{
			if (NSIntersectsRect(drawRect,clipRect))
			{
				[[_customBackgroundColors objectAtIndex:i%n] set];
				NSRectFillUsingOperation(drawRect,NSCompositeSourceOver);
			}
			
			drawRect.origin.y += height;
			i++;
		}
	} 
	else
	{
		[super drawBackgroundInClipRect:inClipRect];
	}
}


// If we are using custom background and highlight colors, we may have to adjust the text colors accordingly,
// to make sure that text is always clearly readable...

- (NSCell*) preparedCellAtColumn:(NSInteger)inColumn row:(NSInteger)inRow
{
	NSCell* cell = [super preparedCellAtColumn:inColumn row:inRow];
	
	if ([cell isKindOfClass:[NSTextFieldCell class]])
	{
		if ([cell isHighlighted])
		{
			if (_customHighlightedTextColor != nil)
			{
				[(NSTextFieldCell*)cell setTextColor:_customHighlightedTextColor];
			}
		}
		else
		{
			if (_customTextColor != nil)
			{
				[(NSTextFieldCell*)cell setTextColor:_customTextColor];
			}
		}
	}
	
	return cell;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Event Handling


- (void) mouseDown:(NSEvent*)inEvent
{
	// Find the clicked object...
	
	NSPoint mouse = [self convertPoint:[inEvent locationInWindow] toView:nil];
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
	
	// In case of a normal object start selecting or dragging...
	
	else 
	{
		_mouseOperation = kMouseOperationNone;
		[super mouseDown:inEvent];
	}
}


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
		[super mouseDragged:inEvent];
	}
}


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


// Ask the IMBNodeViewController (which is our delegate) to return a context menu for the clicked node. If  
// the user clicked on the background node is nil...

- (NSMenu*) menuForEvent:(NSEvent*)inEvent
{
	NSPoint mouse = [self convertPoint:[inEvent locationInWindow] fromView:nil];
	NSInteger i = [self rowAtPoint:mouse];
	NSInteger n = [self numberOfRows];
	IMBObject* object = nil;
	
	IMBObjectViewController* objectViewController = (IMBObjectViewController*) self.delegate;

	if (i>=0 && i<n)
	{
		object = [[objectViewController.objectArrayController arrangedObjects] objectAtIndex:i];
		[objectViewController.objectArrayController setSelectionIndex:i];
	}

	return [objectViewController menuForObject:object];
}

			
//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Quicklook


- (void) keyDown:(NSEvent*)inEvent
{
    NSString* key = [inEvent charactersIgnoringModifiers];
	
    if([key isEqual:@" "])
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
}


- (void) endPreviewPanelControl:(QLPreviewPanel*)inPanel
{
    inPanel.delegate = nil;
    inPanel.dataSource = nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end
