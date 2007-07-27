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


#import "iMBLibraryOutlineView.h"

@interface NSObject (iMediaHack)
- (id)observedObject;
- (void)outlineView:(NSOutlineView *)olv deleteItems:(NSArray *)items;
@end

@implementation iMBLibraryOutlineView

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
			[items addObject:[[self itemAtRow:[row intValue]] observedObject]];
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

@end
