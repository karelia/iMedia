/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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

#import "iMediaConfiguration.h"
#import "iMBLibraryOutlineView.h"
#import "iMBVerticallyAlignedTextCell.h"
#import "iMediaBrowserProtocol.h"

@interface NSObject (iMediaHack)
- (id)observedObject;
- (void)outlineView:(NSOutlineView *)olv deleteItems:(NSArray *)items;
@end

@interface iMBLibraryOutlineView ( Private )
- (iMBVerticallyAlignedTextCell *)placeholderTextCell;
@end

@implementation iMBLibraryOutlineView

#pragma mark -
#pragma mark Init and Dealloc

- (void)awakeFromNib
{
	if ([self respondsToSelector:@selector(setSelectionHighlightStyle:)])
	{
		// Here's how we'd do it on Leopard:
		// [self setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
		// but then we'd get compile problems on Tiger so we do it like this instead:
		[self setValue:[NSNumber numberWithInt:1] forKey:@"selectionHighlightStyle"];
	}

	// See: http://developer.apple.com/documentation/Cocoa/Conceptual/DragandDrop/Tasks/faq.html
	[self setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];

	// Monitor the clip view containing us
	[[self superview] setPostsBoundsChangedNotifications:YES];

//	[[NSNotificationCenter defaultCenter] addObserver:self
//											 selector:@selector(clipViewBoundsChanged:)
//												 name:NSViewBoundsDidChangeNotification
//											   object:[self superview]];
	
	[self setPlaceholderString:LocalizedStringInIMedia(@"Drag additional source folders here", @"Instructions for media browser source list")];
}

- (void)dealloc
{
	// De-register from clip view notifications
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSViewBoundsDidChangeNotification
												  object:[self superview]];
	// Release ivars
	[myPlaceholder release];
	[myPlaceholderCell release];
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSString *)placeholderString { return myPlaceholder; }

- (void)setPlaceholderString:(NSString *)placeholder
{
	placeholder = [placeholder copy];
	[myPlaceholder release];
	myPlaceholder = placeholder;
	
	[self setNeedsDisplay:YES];
}

- (NSColor *)placeholderStringColor { return [[self placeholderTextCell] textColor]; }

- (void)setPlaceholderStringColor:(NSColor *)color { [[self placeholderTextCell] setTextColor:color]; }

#pragma mark -
#pragma mark Drawing

- (void)drawRect:(NSRect)aRect	// draw the drag and drop zone.  Fade in depending on how much empty area.
{
	[super drawRect:aRect];
	
	int meHeight = [self bounds].size.height;
//	int scrollHeight = [[[self superview] superview] bounds].size.height;
	int dataHeight = [self rowHeight] * [self numberOfRows];	
	const int MARGIN_BELOW = 15;
	const int FADE_AREA = 35;
	
	// If there are no rows in the table, draw the placeholder
	if ([self placeholderString]
			&& [[self dataSource] respondsToSelector:@selector(hasCustomFolderParser)]
			&& nil != [((iMediaBrowser *)[self dataSource]) hasCustomFolderParser]
			&& dataHeight + MARGIN_BELOW <= meHeight)		// show if we have some room below
	{
		int fadeHeight = MIN(meHeight - dataHeight, MARGIN_BELOW+FADE_AREA) - MARGIN_BELOW;
		float alpha = (float)fadeHeight / FADE_AREA;
		[self setPlaceholderStringColor:[NSColor colorWithCalibratedWhite:0.66667 alpha:alpha]];

		NSTextFieldCell *cell = [self placeholderTextCell];
		[cell setStringValue:[self placeholderString]];
		
		NSRect textRect = NSInsetRect([self bounds], 12.0, 12.0);
		[cell drawWithFrame:textRect inView:self];
	}
}

- (iMBVerticallyAlignedTextCell *)placeholderTextCell
{
	if (!myPlaceholderCell)
	{
		// Create the new cell with appropriate attributes
		myPlaceholderCell = [[iMBVerticallyAlignedTextCell alloc] initTextCell:@""];
		
		[myPlaceholderCell setAlignment:NSCenterTextAlignment];
		[myPlaceholderCell setVerticalAlignment:iMBBottomTextAlignment];
		
		float fontSize = [NSFont systemFontSizeForControlSize:NSSmallControlSize];
		NSFont *font = [NSFont boldSystemFontOfSize:fontSize];
		[myPlaceholderCell setFont:font];
		[myPlaceholderCell setTextColor:[NSColor grayColor]];
	}
	
	return myPlaceholderCell;
}

#pragma mark -
#pragma mark Data

- (void)reloadData
{
	if (!myIsReloading)
	{
		myIsReloading = YES;
		[super reloadData];
		myIsReloading = NO;
	}
	else
	{
		[self performSelector:@selector(reloadData) withObject:nil afterDelay:0];
	}
}

/*
	When editing is enabled in the view, and the user finishes editing using Enter/Return, we don't
	want it to start editing the next row. 
*/
- (void)textDidEndEditing:(NSNotification *)notification;
{
    if ([[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] == NSReturnTextMovement)
	{
        NSMutableDictionary *newUserInfo = [[notification userInfo] mutableCopy];
        [newUserInfo setObject:[NSNumber numberWithInt:NSIllegalTextMovement] forKey:@"NSTextMovement"];
        [super textDidEndEditing:[NSNotification notificationWithName:[notification name] object:[notification object] userInfo:newUserInfo]];
		[newUserInfo release];
        [[self window] makeFirstResponder:self];
	}
	else
        [super textDidEndEditing:notification];
}

- (void)doDelete
{
	if ([[self dataSource] respondsToSelector:@selector(outlineView:deleteItems:)])
	{
		NSMutableArray *items = [NSMutableArray array];
		NSEnumerator *e = [self selectedRowEnumerator];
		NSNumber *row;
		
		while ((row = [e nextObject]))
		{
			id rowObject = [self itemAtRow:[row intValue]];
			id representedObject = [rowObject respondsToSelector:@selector(representedObject)] ? [rowObject representedObject] : [rowObject observedObject];
			[items addObject:representedObject];
		}
		[[self dataSource] outlineView:self deleteItems:items];
	}
}


- (void)scrollToEndOfDocument:(id)sender
{
	unsigned rows = [self numberOfRows];
	if (rows)
		[self scrollRowToVisible:rows - 1];
}

- (void)scrollToBeginningOfDocument:(id)sender
{
	if ([self numberOfRows])
		[self scrollRowToVisible:0];
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSString* chars = [theEvent characters];
	if ([chars length] == 1)
		{
		unichar c = [chars characterAtIndex:0];
		switch (c)
		{
			case 127:
			case NSDeleteFunctionKey:
			{
				[self doDelete];
				return;
			}
			case NSHomeFunctionKey:
			{
				[self scrollToBeginningOfDocument:theEvent];
				return;
			}
			case NSEndFunctionKey:
			{
				[self scrollToEndOfDocument:theEvent];
				return;
			}
		}
	}
	[super keyDown:theEvent];
}

#pragma mark -
#pragma mark Mouse handling

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    id delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(outlineView:menuForEvent:)])
        return [delegate outlineView:self menuForEvent:theEvent];
    else
        return [super menuForEvent:theEvent];
}

@end
