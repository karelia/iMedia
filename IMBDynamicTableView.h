//
//  IMBDynamicTableView.h
//  iMedia
//
//  Created by Dan Wood on 9/17/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IMBTableView.h"

// Forward declaration:
@protocol IMBDynamicTableViewDelegate;


@interface IMBDynamicTableView : IMBTableView
{
	
@private
	// The _visibleRows is a cache of the rows that are currently displaying. We inform the delegate when they change
	NSRange _visibleRows;
	// _viewsInVisibleRows is a record of the views that we are currently displaying. The key is an NSNumber with the row index. We only ever keep track of views that are in our _visibleRows, and remove others that aren't seen.
	NSMutableDictionary *_viewsInVisibleRows;
	BOOL _viewsNeedUpdate;
	
}

@property(assign) id <IMBDynamicTableViewDelegate> delegate;

@end





#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@protocol NSTableViewDelegate <NSObject> @end
#endif

// We declare some extra protocol messages to let the delegate know when the visible rows are changing.
// It is important to create a delegate signature that will not conflict with standard Cocoa delegate signatures. In short, that means don't use the prefix "tableView:".
@protocol IMBDynamicTableViewDelegate <NSTableViewDelegate>
@optional

// We want to give the delegate a change to pre-load things given a new visible row set. In addition, it could stop loading previous things that have scrolled off screen and weren't fully loaded yet.
- (void)dynamicTableView:(IMBDynamicTableView *)tableView changedVisibleRowsFromRange:(NSRange)oldVisibleRows toRange:(NSRange)newVisibleRows;

// Allows the delegate to give a custom view back for a particular row. The view's frame should be properly set based on the rectOfRow:. This could easily be extended to a row/column matrix.
- (NSView *)dynamicTableView:(IMBDynamicTableView *)tableView viewForRow:(NSInteger)row;

// Allows advanced cell editing to easily be supported by the delegate. propertyName is the name of the property that was edited by the advanced cell editor.
- (void)dynamicTableView:(IMBDynamicTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row property:(NSString *)propertyName;



@end


