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

#import "IMBImageBrowserView.h"
#import "IMBImageBrowserCell.h"
#import "IMBObjectViewController.h"
#import "IMBObjectFifoCache.h"


//----------------------------------------------------------------------------------------------------------------------


// Declare internal methods of superclass to shut up the compiler...

@interface IKImageBrowserView ()
- (NSImage*) draggedImage;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBImageBrowserView


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
	
	return [IMBImageBrowserCell class];
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


#ifndef IMB_SUPPORTFILEPROMISES
#define IMB_SUPPORTFILEPROMISES 0
#endif

#if IMB_SUPPORTFILEPROMISES

//----------------------------------------------------------------------------------------------------------------------

#pragma mark Handling drags to allow for promises
// This code is based on code contributed by Fraser Speirs.

- (void)mouseDown:(NSEvent *)theEvent {
	// If the mouse first goes down on the background, this is a drag-select and
	// we don't want to handle any mouseDragged events until the mouse comes up again.
	NSPoint clickPosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSInteger indexOfItemUnderClick = [self indexOfItemAtPoint: clickPosition];
	_dragSelectInProgress = (indexOfItemUnderClick == NSNotFound);
	[super mouseDown: theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent {
	_dragSelectInProgress = NO;
	[super mouseUp: theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent;
{
	// If there's a drag-select in progress, we don't want to know.
	if(_dragSelectInProgress) {
		[super mouseDragged: theEvent];
		return;
	}
	
	// Otherwise, the mouse went down on an image and we should drag it
	NSPoint dragPosition = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSInteger indexOfItemUnderClick = [self indexOfItemAtPoint: dragPosition];
	
	if(indexOfItemUnderClick == NSNotFound) {
		[super mouseDragged: theEvent];
		return;
	}
		
	dragPosition.x -= 16;
	dragPosition.y -= 16;
	
	NSRect imageLocation;
	imageLocation.origin = dragPosition;
	imageLocation.size = NSMakeSize(64, 64);	// should this vary?
	
	[self dragPromisedFilesOfTypes:[NSArray arrayWithObject:@"jpg"]		// should probably get REAL value?
						  fromRect:imageLocation
							source:self.delegate		// handle drag messages
						 slideBack:YES
							 event:theEvent];
}
#endif

@end
