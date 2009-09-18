//
//  IMBDynamicTableView.m
//  iMedia
//
//  Created by Dan Wood on 9/17/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "IMBDynamicTableView.h"

@interface IMBDynamicTableView(ATPrivate)

- (void)_removeCachedViewForRow:(NSInteger)row;
- (void)_removeCachedViewsInIndexSet:(NSIndexSet *)rowIndexes;

@end


@implementation IMBDynamicTableView


@dynamic delegate;

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    return self;
}

- (void)dealloc {
    [_viewsInVisibleRows release];
    _viewsInVisibleRows = nil;
    [super dealloc];
}

- (void)_ensureVisibleRowsIsCreated {
    if (_viewsInVisibleRows == nil) {
        _viewsInVisibleRows = [NSMutableDictionary new];
    }
}

- (void)viewWillDraw {
    // We have to call super first in case the NSTableView does some layout in -viewWillDraw
    [super viewWillDraw];
    
    // Calculate the new visible rows and let the delegate do any extra work it wants to
    NSRange newVisibleRows = [self rowsInRect:self.visibleRect];
    BOOL visibleRowsNeedsUpdate = !NSEqualRanges(newVisibleRows, _visibleRows);
    NSRange oldVisibleRows = _visibleRows;
    if (visibleRowsNeedsUpdate) {
        _visibleRows = newVisibleRows;
        // Give the delegate a chance to do any pre-loading or special work that it wants to do
        if ([[self delegate] respondsToSelector:@selector(dynamicTableView:changedVisibleRowsFromRange:toRange:)]) {
            [[self delegate] dynamicTableView:self changedVisibleRowsFromRange:oldVisibleRows toRange:newVisibleRows];
        }
        // We always have to update our views if the visible area changed
        _viewsNeedUpdate = YES;
    }
    
    if (_viewsNeedUpdate) {
        _viewsNeedUpdate = NO;
        // Update any views that the delegate wants to give us
        if ([[self delegate] respondsToSelector:@selector(dynamicTableView:viewForRow:)]) {
			
            if (visibleRowsNeedsUpdate) {
                // First, remove any views that are no longer before our new visible rows
                NSMutableIndexSet *rowIndexesToRemove = [NSMutableIndexSet indexSetWithIndexesInRange:oldVisibleRows];
                // Remove any rows from the set that are STILL visible; we want a resulting index set that has the views which are no longer on screen.
                [rowIndexesToRemove removeIndexesInRange:newVisibleRows];
                // Remove those views which are no longer visible
                [self _removeCachedViewsInIndexSet:rowIndexesToRemove];
            }
            
            [self _ensureVisibleRowsIsCreated];
            
            // Finally, update and add in any new views given to us by the delegate. Use [NSNull null] for things that don't have a view at a particular row
            for (NSInteger row = _visibleRows.location; row < NSMaxRange(_visibleRows); row++) {
                NSNumber *key = [NSNumber numberWithInteger:row];
                id view = [_viewsInVisibleRows objectForKey:key];
                if (view == nil) {
                    // We don't already have a view at that row
                    view = [[self delegate] dynamicTableView:self viewForRow:row];
                    if (view != nil) {
                        [self addSubview:view];
                    } else {
                        // Use null as a place holder so we don't call the delegate again until the row is relaoded
                        view = [NSNull null]; 
                    }
                    [_viewsInVisibleRows setObject:view forKey:key];
                }
            }
        }
    }
}

- (void)_removeCachedViewForRow:(NSInteger)row {
    _viewsNeedUpdate = YES;
    if (_viewsInVisibleRows != nil) {
        NSNumber *key = [NSNumber numberWithInteger:row];
        id view = [_viewsInVisibleRows objectForKey:key];
        if (view != nil) {
            if (view != [NSNull null]) {
                [view removeFromSuperview];
            }
            [_viewsInVisibleRows removeObjectForKey:key];
        }
    }
}

- (void)_removeCachedViewsInIndexSet:(NSIndexSet *)rowIndexes {
    if (rowIndexes != nil) {
        for (NSInteger row = [rowIndexes firstIndex]; row != NSNotFound; row = [rowIndexes indexGreaterThanIndex:row]) {
            [self _removeCachedViewForRow:row];
        }
    }                 
}

- (void)_removeAllCachedViews {
    if (_viewsInVisibleRows != nil) {
        for (id view in [_viewsInVisibleRows allValues]) {
            [view removeFromSuperview];
        }
        [_viewsInVisibleRows release];
        _viewsInVisibleRows = nil;
    }
}             

// Reset our visible row cache when we reload things
- (void)reloadData {
    [self _removeAllCachedViews];
    _visibleRows = NSMakeRange(NSNotFound, 0);
    [super reloadData];
}

- (void)noteHeightOfRowsWithIndexesChanged:(NSIndexSet *)indexSet {
    // We replace all cached views, as their offsets may change
    [self _removeAllCachedViews];
    _visibleRows = NSMakeRange(NSNotFound, 0);
    [super noteHeightOfRowsWithIndexesChanged:indexSet];
}

/*
 Snow Leopard Only
 
 - (void)reloadDataForRowIndexes:(NSIndexSet *)rowIndexes columnIndexes:(NSIndexSet *)columnIndexes {
 [self _removeCachedViewsInIndexSet:rowIndexes];
 [super reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
 }
 */

- (void)setDelegate:(id <IMBDynamicTableViewDelegate>)delegate {
    [super setDelegate:delegate];
}

- (id <IMBDynamicTableViewDelegate>)delegate {
    return (id <IMBDynamicTableViewDelegate>)[super delegate];
}







@end
