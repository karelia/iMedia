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

#import "IMBDynamicTableView.h"
#import "IMBCommon.h"

@interface NSTableView()
// Define this so we can call through to super, for when we are running Snow Leopard
- (void)reloadDataForRowIndexes:(NSIndexSet *)rowIndexes columnIndexes:(NSIndexSet *)columnIndexes;
@end

@interface IMBDynamicTableView()

- (void)_removeCachedViewForRow:(NSInteger)row;
- (void)_removeCachedViewsInIndexSet:(NSIndexSet *)rowIndexes;

@end

@implementation IMBDynamicTableView

@dynamic delegate;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    return self;
}

- (void)dealloc
{
    [_viewsInVisibleRows release];
    _viewsInVisibleRows = nil;
    [super dealloc];
}

- (void)_ensureVisibleRowsIsCreated
{
    if (_viewsInVisibleRows == nil)
	{
        _viewsInVisibleRows = [NSMutableDictionary new];
    }
}

- (void)viewWillDraw
{
    // We have to call super first in case the NSTableView does some layout in -viewWillDraw
    [super viewWillDraw];
    
    // Calculate the new visible rows and let the delegate do any extra work it wants to
    NSRange newVisibleRows = [self rowsInRect:self.visibleRect];
    BOOL visibleRowsNeedsUpdate = !NSEqualRanges(newVisibleRows, _visibleRows);
    NSRange oldVisibleRows = _visibleRows;
    if (visibleRowsNeedsUpdate)
	{
        _visibleRows = newVisibleRows;
        // Give the delegate a chance to do any pre-loading or special work that it wants to do
        if ([[self delegate] respondsToSelector:@selector(dynamicTableView:changedVisibleRowsFromRange:toRange:)])
		{
            [[self delegate] dynamicTableView:self changedVisibleRowsFromRange:oldVisibleRows toRange:newVisibleRows];
        }
        // We always have to update our views if the visible area changed
        _viewsNeedUpdate = YES;
    }
    
    if (_viewsNeedUpdate)
	{
        _viewsNeedUpdate = NO;
        // Update any views that the delegate wants to give us
        if ([[self delegate] respondsToSelector:@selector(dynamicTableView:viewForRow:)])
		{
			
            if (visibleRowsNeedsUpdate)
			{
                // First, remove any views that are no longer before our new visible rows
                NSMutableIndexSet *rowIndexesToRemove = [NSMutableIndexSet indexSetWithIndexesInRange:oldVisibleRows];
                // Remove any rows from the set that are STILL visible; we want a resulting index set that has the views which are no longer on screen.
                [rowIndexesToRemove removeIndexesInRange:newVisibleRows];
                // Remove those views which are no longer visible
                [self _removeCachedViewsInIndexSet:rowIndexesToRemove];
            }
            
            [self _ensureVisibleRowsIsCreated];
            
            // Finally, update and add in any new views given to us by the delegate. Use [NSNull null] for things that don't have a view at a particular row
            for (NSInteger row = _visibleRows.location; row < NSMaxRange(_visibleRows); row++)
			{
                NSNumber *key = [NSNumber numberWithInteger:row];
                id view = [_viewsInVisibleRows objectForKey:key];
                if (view == nil)
				{
                    // We don't already have a view at that row
                    view = [[self delegate] dynamicTableView:self viewForRow:row];
                    if (view != nil)
					{
                        [self addSubview:view];
                    } else
					{
                        // Use null as a place holder so we don't call the delegate again until the row is relaoded
                        view = [NSNull null]; 
                    }
                    [_viewsInVisibleRows setObject:view forKey:key];
                }
            }
        }
    }
}

- (void)_removeCachedViewForRow:(NSInteger)row
{
    _viewsNeedUpdate = YES;
    if (_viewsInVisibleRows != nil)
	{
        NSNumber *key = [NSNumber numberWithInteger:row];
        id view = [_viewsInVisibleRows objectForKey:key];
        if (view != nil)
		{
            if (view != [NSNull null])
			{
                [view removeFromSuperview];
            }
            [_viewsInVisibleRows removeObjectForKey:key];
        }
    }
}

- (void)_removeCachedViewsInIndexSet:(NSIndexSet *)rowIndexes
{
    if (rowIndexes != nil)
	{
        for (NSInteger row = [rowIndexes firstIndex]; row != NSNotFound; row = [rowIndexes indexGreaterThanIndex:row])
		{
            [self _removeCachedViewForRow:row];
        }
    }                 
}

- (void)_removeAllCachedViews
{
    if (_viewsInVisibleRows != nil)
	{
        for (id view in [_viewsInVisibleRows allValues])
		{
            [view removeFromSuperview];
        }
        [_viewsInVisibleRows release];
        _viewsInVisibleRows = nil;
    }
}             

// Reset our visible row cache when we reload things
- (void)reloadData
{
    [self _removeAllCachedViews];
    _visibleRows = NSMakeRange(NSNotFound, 0);
    [super reloadData];
}

- (void)noteHeightOfRowsWithIndexesChanged:(NSIndexSet *)indexSet
{
    // We replace all cached views, as their offsets may change
    [self _removeAllCachedViews];
    _visibleRows = NSMakeRange(NSNotFound, 0);
    [super noteHeightOfRowsWithIndexesChanged:indexSet];
}

// Snow Leopard Only, so we implement our own if we're not running snow leopard.

- (void)reloadDataForRowIndexes:(NSIndexSet *)rowIndexes columnIndexes:(NSIndexSet *)columnIndexes
{
	[self _removeCachedViewsInIndexSet:rowIndexes];
	
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		[super reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
	}
	else
	{
		// LEOPARD implementation.  Ignore the columns; mark the whole row dirty.
		NSRect dirtyRect = NSZeroRect;
		NSUInteger currentIndex = [rowIndexes firstIndex];
		while (currentIndex != NSNotFound)
		{
			NSRect rowDirtyRect = [self rectOfRow:currentIndex];
			dirtyRect = NSUnionRect(dirtyRect, rowDirtyRect);
			currentIndex = [rowIndexes indexGreaterThanIndex:currentIndex];
		}
		[self setNeedsDisplayInRect:dirtyRect];
	}
}

- (void)setDelegate:(id <IMBDynamicTableViewDelegate>)delegate
{
    [super setDelegate:delegate];
}

- (id <IMBDynamicTableViewDelegate>)delegate
{
    return (id <IMBDynamicTableViewDelegate>)[super delegate];
}

// Method called after KVO detects a change, to reload the table row.
- (void)_reloadRow:(NSNumber *)aRowNumber
{
	// NSLog(@"%s",__FUNCTION__);
	
	NSInteger row = [aRowNumber intValue];
	if (row != NSNotFound)
	{
		[self reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
	}
	
}

@end
