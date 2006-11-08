/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/
#import "iMBLibraryOutlineView.h"


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
