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


#import "iMBDNDArrayController.h"

@interface iMBDNDArrayController (PrivateAPI)
//Drag and drop
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op;

//Utility
- (void)moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet *)indexSet 
									   toIndex:(unsigned)aIndex;

- (NSIndexSet *)indexSetFromRows:(NSArray *)rows;
- (int)rowsAboveRow:(unsigned int)row inIndexSet:(NSIndexSet *)indexSet;
@end

@implementation iMBDNDArrayController

- (void)dealloc
{
	[searchableProperties release];
	[self setSearchString:nil];
	[super dealloc];
}

- (void)awakeFromNib
{
    [tableView setAllowsMultipleSelection:YES];
	[super awakeFromNib];
	[self setSearchableProperties:[NSArray arrayWithObjects:@"Name",@"Artist",@"Album",@"Genre",nil]]; 
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
	
    NSArray			*objects = [self arrangedObjects];
	unsigned int	theIndex = [indexSet lastIndex];
	
    int				aboveInsertIndexCount = 0;
    id				object;
    int				removeIndex;
	
    while (NSNotFound != theIndex)
	{
		if (theIndex >= insertIndex) {
			removeIndex = theIndex + aboveInsertIndexCount;
			aboveInsertIndexCount += 1;
		}
		else
		{
			removeIndex = theIndex;
			insertIndex -= 1;
		}
		object = [objects objectAtIndex:removeIndex];
		[self removeObjectAtArrangedObjectIndex:removeIndex];
		[self insertObject:object atArrangedObjectIndex:insertIndex];
		
		theIndex = [indexSet indexLessThanIndex:theIndex];
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

- (int)rowsAboveRow:(unsigned int)row inIndexSet:(NSIndexSet *)indexSet
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

- (void)setSearchableProperties:(NSArray *)properties 
{
	[searchableProperties autorelease];
	searchableProperties = [properties retain];
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
			// Search all properties in the array. Please note that we need to check for the existance 
			// of a property (value!=nil) BEFORE checking rangeOfString: or a nil value will provide 
			// us with a positive match. This would yield way to many false results...
			
			NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
			unsigned int i,n = [searchableProperties count];
			NSString *key,*value;
			
			for (i=0; i<n; i++)
			{
				key = [searchableProperties objectAtIndex:i];
				value = [[item valueForKeyPath:key] lowercaseString];
				
				if (value!=nil && [value rangeOfString:lowerSearch].location!=NSNotFound)
				{
					[matchedObjects addObject:item];
					break;
				}
			}
			
			[pool release];
		}
    }
	
    return [super arrangeObjects:matchedObjects];
}

@end