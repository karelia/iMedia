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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>

*/

#import "iMBDNDArrayController.h"

@interface iMBDNDArrayController (PrivateAPI)
//Drag and drop
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op;

//Utility
- (void)moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet *)indexSet 
									   toIndex:(unsigned)index;

- (NSIndexSet *)indexSetFromRows:(NSArray *)rows;
- (int)rowsAboveRow:(int)row inIndexSet:(NSIndexSet *)indexSet;
@end

@implementation iMBDNDArrayController

- (void)dealloc
{
	[self setSearchString:nil];
	[super dealloc];
}

- (void)awakeFromNib
{
    [tableView setAllowsMultipleSelection:YES];
	[super awakeFromNib];
}

- (BOOL)tableView:(NSTableView *)tv
		writeRows:(NSArray*)rows
	 toPasteboard:(NSPasteboard*)pboard
{
	if ([myDelegate respondsToSelector:@selector(tableView:writeRows:toPasteboard:)])
	{
		return [myDelegate tableView:tv writeRows:rows toPasteboard:pboard];
	}
	return NO;
}

- (void) moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)indexSet
										toIndex:(unsigned int)insertIndex
{
	
    NSArray		*objects = [self arrangedObjects];
	int			index = [indexSet lastIndex];
	
    int			aboveInsertIndexCount = 0;
    id			object;
    int			removeIndex;
	
    while (NSNotFound != index)
	{
		if (index >= insertIndex) {
			removeIndex = index + aboveInsertIndexCount;
			aboveInsertIndexCount += 1;
		}
		else
		{
			removeIndex = index;
			insertIndex -= 1;
		}
		object = [objects objectAtIndex:removeIndex];
		[self removeObjectAtArrangedObjectIndex:removeIndex];
		[self insertObject:object atArrangedObjectIndex:insertIndex];
		
		index = [indexSet indexLessThanIndex:index];
    }
}

- (NSIndexSet *)indexSetFromRows:(NSArray *)rows
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    NSEnumerator *rowEnumerator = [rows objectEnumerator];
    NSNumber *idx;
    while (idx = [rowEnumerator nextObject])
    {
		[indexSet addIndex:[idx intValue]];
    }
    return indexSet;
}

- (int)rowsAboveRow:(int)row inIndexSet:(NSIndexSet *)indexSet
{
    unsigned currentIndex = [indexSet firstIndex];
    int i = 0;
    while (currentIndex != NSNotFound)
    {
		if (currentIndex < row) { i++; }
		currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
    }
    return i;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[self arrangedObjects] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSString *colIdent = [aTableColumn identifier];
	return [[[self arrangedObjects] objectAtIndex:rowIndex] valueForKey:colIdent];
}

- (void)search:(id)sender
{
    [self setSearchString:[sender stringValue]];
}

#pragma mark ACCESSORS

- (NSString *)searchString {
    return [[searchString retain] autorelease];
}

- (void)setSearchString:(NSString *)value {
    if (searchString != value) {
        [searchString release];
        searchString = [value copy];
		[self rearrangeObjects];
    }
}

- (void)setDelegate:(id)delegate
{
	myDelegate = delegate;
}

- (id)delegate
{
	return myDelegate;
}

// Set default values, and keep reference to new object -- see arrangeObjects:
- (id)newObject
{
    newObject = [super newObject];
    [newObject setValue:@"Name" forKey:@"Name"];
    [newObject setValue:@"Artist" forKey:@"Artist"];
    return newObject;
}

- (NSArray *)arrangeObjects:(NSArray *)objects
{
	
    if ((searchString == nil) ||
		([searchString isEqualToString:@""]))
	{
		newObject = nil;
		return [super arrangeObjects:objects];   
	}
	
	/*
	 Create array of objects that match search string.
	 Also add any newly-created object unconditionally:
	 (a) You'll get an error if a newly-added object isn't added to arrangedObjects.
	 (b) The user will see newly-added objects even if they don't match the search term.
	 */
	
    NSMutableArray *matchedObjects = [NSMutableArray arrayWithCapacity:[objects count]];
    // case-insensitive search
    NSString *lowerSearch = [searchString lowercaseString];
    
	NSEnumerator *oEnum = [objects objectEnumerator];
    id item;	
    while (item = [oEnum nextObject])
	{
		// if the item has just been created, add it unconditionally
		if (item == newObject)
		{
            [matchedObjects addObject:item];
			newObject = nil;
		}
		else
		{
			//  Use of local autorelease pool here is probably overkill, but may be useful in a larger-scale application.
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			NSString *name = [[item valueForKeyPath:@"Name"] lowercaseString];
			if ([name rangeOfString:lowerSearch].location != NSNotFound)
			{
				[matchedObjects addObject:item];
			}
			else
			{
				name = [[item valueForKeyPath:@"Artist"] lowercaseString];
				if ([name rangeOfString:lowerSearch].location != NSNotFound)
				{
					[matchedObjects addObject:item];
				}
			}
			[pool release];
		}
    }
    return [super arrangeObjects:matchedObjects];
}

@end