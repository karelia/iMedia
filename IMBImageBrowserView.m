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


// Author: Peter Baumgartner, Dan Wood, Daniel Jalkut


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBImageBrowserView.h"
#import "IMBImageBrowserCell.h"
#import "IMBObject.h"
#import "IMBButtonObject.h"
#import "IMBObjectViewController.h"
#import "IMBObjectFifoCache.h"
#import "IMBParser.h"
#import "IMBQLPreviewPanel.h"
#import <Carbon/Carbon.h>
#import "IMBPanelController.h"
#import "IMBConfig.h"

//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

enum IMBMouseOperation
{
	kMouseOperationNone,
	kMouseOperationButtonClick,
	kMouseOperationDragSelection
};


//----------------------------------------------------------------------------------------------------------------------


// Declare internal methods of superclass to shut up the compiler...

@interface IKImageBrowserView ()
- (NSImage*) draggedImage;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBImageBrowserView

@synthesize mouseOperation = _mouseOperation;
@synthesize clickedObjectIndex = _clickedObjectIndex;
@synthesize clickedObject = _clickedObject;


//----------------------------------------------------------------------------------------------------------------------

- (void) _init	// support method shared by both
{
	_mouseOperation = kMouseOperationNone;
	_clickedObjectIndex = NSNotFound;
	_clickedObject = nil;
	
	[[NSNotificationCenter defaultCenter]				// Unload parsers before we quit, so that custom have 
	 addObserver:self								// a chance to clean up (e.g. remove callbacks, etc...)
	 selector:@selector(showTitlesStateChanged:) 
	 name:kIMBImageBrowserShowTitlesNotification 
	 object:nil];

	// Set up initial value
	NSString* filenames = [IMBConfig prefsValueForKey:@"prefersFilenamesInPhotoBasedBrowsers"];
	BOOL showTitle = (nil == filenames) ? YES : [filenames boolValue];
	int mask = showTitle ? IKCellsStyleTitled : IKCellsStyleNone;
	[self setCellsStyleMask: mask];
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
	if (self = [super initWithCoder:aDecoder])
	{
		[self _init];
	}
	return self;
}


- (id) initWithFrame:(NSRect) frame;
{
	if (self = [super initWithFrame:frame])
	{
		[self _init];
	}
	return self;
}


- (void) dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	IMBRelease(_clickedObject);
	[super dealloc];
}

//----------------------------------------------------------------------------------------------------------------------

- (void) showTitlesStateChanged:(NSNotification *)aNotification
{
	id obj = [aNotification object];
	BOOL showTitle = [obj boolValue];
	int mask = showTitle ? IKCellsStyleTitled : IKCellsStyleNone;
	[self setCellsStyleMask: mask];
}

//----------------------------------------------------------------------------------------------------------------------


// If the IKImageBrowserView asked for a custom cell class, then pass on the request to the library's delegate. 
// That way the application is given a chance to customize the look of the browser...

- (Class) _cellClass
{
	Class cellClass = nil;
	id delegate = self.delegate;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(imageBrowserCellClassForController:)])
		{
			cellClass =  [delegate imageBrowserCellClassForController:nil];
		}
	}
	
	// Please note that we check for the existence of the base class before creating the subclass, 
	// as the baseclass is an undocumented internal class on 10.5. In 10.6 it is always there...
	
	if (cellClass == nil)
	{
		if (NSClassFromString(@"IKImageBrowserCell") != nil)
		{
			cellClass = [IMBImageBrowserCell class];
		}
	}
	
	return cellClass;
}


//----------------------------------------------------------------------------------------------------------------------


// Make the browser use our own custom cell class...

- (void) awakeFromNib
{
	_cellClass = [self _cellClass];
	
	if ([self respondsToSelector:@selector(setCellClass:)])
	{
		[self performSelector:@selector(setCellClass:) withObject:_cellClass];
	}

	[self setConstrainsToOriginalSize:NO];
//	[self setValue:attributes forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];	
//	[self setCellSize:NSMakeSize(44.0,22.0)];
//	[self setIntercellSpacing:NSMakeSize(8.0,12.0)];
//	[self setAnimates:NO];
//	[self setWantsLayer:NO];

//	NSColor* selectionColor = [NSColor selectedTextBackgroundColor];
//	[self setValue:selectionColor forKey:IKImageBrowserSelectionColorKey];
}


// This method is for 10.6 only. Create and return a cell. Please note that we must not autorelease here!

- (IKImageBrowserCell*) newCellForRepresentedItem:(id)inCell
{
	return [[_cellClass alloc] init];
}


//----------------------------------------------------------------------------------------------------------------------


// This makes sure that dragging to external applications works...

- (NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)inLocal
{
	return NSDragOperationCopy;
}


// When creating the drag image first give the delegate of our controller a chance to create a custom drag image.
// If it declines, then simply return the default drag image created by Apple. Please note that we supply nil 
// arguments to the delegate method here. These will be filled in by the controller...
			
- (NSImage*) draggedImage
{
	NSImage* image = nil;
	id delegate = self.delegate;
	
	if (delegate)
	{
		if ([delegate respondsToSelector:@selector(draggedImageForController:draggedObjects:)])
		{
			image =  [delegate draggedImageForController:nil draggedObjects:nil];
		}
	}

	if (image == nil)
	{
		image = [super draggedImage];
	}
	
	return image;
}

		
//----------------------------------------------------------------------------------------------------------------------


// Disable background loading. This is an undocumented internal method. It was suggested to override this method 
// by a developer on StackOverflow.com. otool -oV reveals that this method is available on 10.5 and 10.6, but
// we do not yet know whether the behavior is the same...

- (BOOL) _shouldProcessLongTasks
{
	// If there still is plenty of space left in the cache we can allow some background loading, but do not
	// fill it up all the way. Try to leave some space for when it is needed...
	
	return [IMBObjectFifoCache count] < [IMBObjectFifoCache size]-64;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) mouseDown:(NSEvent*)inEvent
{
	// Find the clicked object...
	
	NSPoint mouse = [self convertPoint:[inEvent locationInWindow] fromView:nil];
	_clickedObjectIndex = [self indexOfItemAtPoint:mouse];	
	
	if (_clickedObjectIndex != NSNotFound && [self.dataSource respondsToSelector:@selector(imageBrowser:itemAtIndex:)])
	{
		self.clickedObject = [self.dataSource imageBrowser:self itemAtIndex:_clickedObjectIndex];
	}
	
	// If it was a button, then handle the click...
	
	if ([_clickedObject isKindOfClass:[IMBButtonObject class]])
	{
		_mouseOperation = kMouseOperationButtonClick;
		[(IMBButtonObject*)_clickedObject setImageRepresentationForState:YES];
		[self setNeedsDisplayInRect:[self itemFrameAtIndex:_clickedObjectIndex]];
	}
	
	// In case of a normal object start dragging or selection...
	
	else if (_clickedObject != nil && _clickedObject.isSelectable)
	{	
		_mouseOperation = kMouseOperationDragSelection;
	}
	else
	{
		_mouseOperation = kMouseOperationNone;
	}

	// For parity with TableView; not really needed since selection is changed anyhow
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;
	[controller setClickedObject:self.clickedObject];
	[controller setClickedObjectIndex:self.clickedObjectIndex];

	[super mouseDown:inEvent];
}


- (void) mouseDragged:(NSEvent*)inEvent;
{
	// If a button was clicked then track that button and highlight it when inside...
	
	if (_mouseOperation == kMouseOperationButtonClick)
	{
		NSPoint mouse = [self convertPoint:[inEvent locationInWindow] fromView:nil];
		BOOL highlighted = [self indexOfItemAtPoint: mouse] == _clickedObjectIndex;
		[(IMBButtonObject*)_clickedObject setImageRepresentationForState:highlighted];
		[self setNeedsDisplayInRect:[self itemFrameAtIndex:_clickedObjectIndex]];
	}
	
	// If the user clicked on an object, then this will start a drag. Ignore the drag if the object is 
	// not supposed to be draggable...
	
	else if (_clickedObject)
	{
		[self.delegate setDropDestinationURL:nil];		// initialize to nil so we know drag has just started
		
		if ([_clickedObject isDraggable])
		{
			[super mouseDragged:inEvent];
			return;
		}
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
		NSInteger objectIndex = [self indexOfItemAtPoint: mouse];

		if (objectIndex == _clickedObjectIndex)
		{
			[(IMBButtonObject*)_clickedObject sendClickAction];
		}
			
		[(IMBButtonObject*)_clickedObject setImageRepresentationForState:NO];
		[self setNeedsDisplayInRect:[self itemFrameAtIndex:_clickedObjectIndex]];
	}
	
	// Let the superclass handle other events...
	
	else
	{
		[super mouseUp:inEvent];
	}

	// Cleanup...
	
	_mouseOperation = kMouseOperationNone;
	_dragSelectInProgress = NO;
	self.clickedObject = nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Dragging Promise Support


- (NSArray*) namesOfPromisedFilesDroppedAtDestination:(NSURL*)inDropDestination
{
	return [self.delegate namesOfPromisedFilesDroppedAtDestination:inDropDestination];
}


- (void) draggedImage:(NSImage*)inImage endedAt:(NSPoint)inScreenPoint operation:(NSDragOperation)inOperation
{
	[self.delegate draggedImage:inImage endedAt:inScreenPoint operation:inOperation];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Quicklook 


- (void) keyDown:(NSEvent*)inEvent
{
	IMBObjectViewController* controller = (IMBObjectViewController*) self.delegate;
    NSString* key = [inEvent charactersIgnoringModifiers];
	
    if([key isEqual:@" "])
	{
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
