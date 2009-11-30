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


// Author: Dan Wood


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

