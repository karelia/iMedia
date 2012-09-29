/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
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
 following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
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


// Author: Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------

#import "IMBTableViewAppearance+iMediaPrivate.h"
#import "IMBNode.h"
#import "IMBNodeCell.h"
#import "IMBTextFieldCell.h"
#import "NSCell+iMedia.h"

@implementation IMBTableViewAppearance

@synthesize view = _view;
@synthesize backgroundColors = _backgroundColors;
@synthesize keyWindowHighlightGradient = _keyWindowHighlightGradient;
@synthesize nonKeyWindowHighlightGradient = _nonKeyWindowHighlightGradient;
@synthesize rowTextAttributes = _rowTextAttributes;
@synthesize rowTextHighlightAttributes = _rowTextHighlightAttributes;
@synthesize sectionHeaderTextAttributes = _sectionHeaderTextAttributes;
@synthesize swapIconAndHighlightIcon = _swapIconAndHighlightIcon;


- (void)dealloc
{
    IMBRelease(_backgroundColors);
    IMBRelease(_keyWindowHighlightGradient);
    IMBRelease(_nonKeyWindowHighlightGradient);
    IMBRelease(_rowTextAttributes);
    IMBRelease(_rowTextHighlightAttributes);
    IMBRelease(_sectionHeaderTextAttributes);
    
    [super dealloc];
}


- (void) invalidateFormat
{
    if (self.view)
    {
        [self.view setNeedsDisplay:YES];
    }
}


- (NSColor *)backgroundColor
{
    if (self.view && [self.view respondsToSelector:@selector(setBackgroundColor:)])
    {
        NSTableView *tableView = (NSTableView *)self.view;
        return [tableView backgroundColor];
    }
return nil;
}


- (void) setBackgroundColor:(NSColor *)inColor
{
    if (self.view && [self.view respondsToSelector:@selector(setBackgroundColor:)])
    {
        NSTableView *tableView = (NSTableView *)self.view;
        [tableView setBackgroundColor:inColor];
        if (inColor) {
            tableView.usesAlternatingRowBackgroundColors = NO;
        }
    }
    [self invalidateFormat];
}


// Customizes appearance of cell according to this object's appearance properties

- (void) prepareCell:(NSCell *)inCell atColumn:(NSInteger)inColumn row:(NSInteger)inRow
{
	if ([inCell isKindOfClass:[NSTextFieldCell class]])
	{
        NSTextFieldCell *theCell = (NSTextFieldCell *) inCell;
        
        {
            theCell.textColor = [NSColor controlTextColor];
            if ([theCell isHighlighted])
            {
                if (self.rowTextHighlightAttributes) {
                    [theCell imb_setStringValueAttributes:self.rowTextHighlightAttributes];
                }
            } else {    // Non-highlighted cell
                if (self.rowTextAttributes) {
                    [theCell imb_setStringValueAttributes:self.rowTextAttributes];
                }
            }
        }
	}
	if ([inCell isKindOfClass:[IMBNodeCell class]])
	{
        IMBNodeCell *theCell = (IMBNodeCell *) inCell;
        theCell.icon = theCell.node.icon;
        
        if ([theCell isGroupCell])
        {
            if (self.sectionHeaderTextAttributes) {
                [theCell imb_setStringValueAttributes:self.sectionHeaderTextAttributes];
            }
        }
        if ([theCell isHighlighted])
        {
            if (theCell.node.highlightIcon) {
                theCell.icon = theCell.node.highlightIcon;
            }
            if (self.swapIconAndHighlightIcon) {
                theCell.icon = theCell.node.icon;
            }
        } else {    // Non-highlighted cell
            if (theCell.node.highlightIcon && self.swapIconAndHighlightIcon) {
                theCell.icon = theCell.node.highlightIcon;
            }
        }
    }
}


// Draws background colors for rows according to -backgroundColors (re-iterating colors).
// Returns NO if no background colors are set (thus not drawing anything). Returns YES otherwise.

- (BOOL) drawBackgroundInClipRect:(NSRect)inClipRect
{
	if (!self.backgroundColors) {
        return NO;
    }
    NSTableView *myTableView = (NSTableView *)self.view;
    
    NSUInteger n = [self.backgroundColors count];
    NSUInteger i = 0;
    
    CGFloat height = myTableView.rowHeight + myTableView.intercellSpacing.height;
    NSRect clipRect = [myTableView bounds];
    NSRect drawRect = clipRect;
    drawRect.origin = NSZeroPoint;
    drawRect.size.height = height;
    
    [[myTableView backgroundColor] set];
    NSRectFillUsingOperation(inClipRect,NSCompositeSourceOver);
    
    while ((NSMinY(drawRect) <= NSHeight(clipRect)))
    {
        if (NSIntersectsRect(drawRect,clipRect))
        {
            [(NSColor*)[self.backgroundColors objectAtIndex:i%n] set];
            NSRectFillUsingOperation(drawRect,NSCompositeSourceOver);
        }
        
        drawRect.origin.y += height;
        i++;
    }
    return YES;
}


// Draws selected rows with a highlight bar according to -keyWindowHighlightGradient and -nonKeyWindowHighlightGradient.
// Returns NO if no gradients are set (thus not drawing anything). Returns YES otherwise.

// 1. get the range of row indexes that are currently visible
// 2. get a list of selected rows
// 3. iterate over the visible rows and if their index is selected
// 4. draw our custom highlight in the rect of that row.

- (BOOL)highlightSelectionInClipRect:(NSRect)theClipRect
{
    if (!self.keyWindowHighlightGradient || !self.nonKeyWindowHighlightGradient) {
        return NO;
    }
    
    NSTableView *myTableView = (NSTableView *)self.view;
    
    NSRange         aVisibleRowIndexes = [myTableView rowsInRect:theClipRect];
    NSIndexSet *    aSelectedRowIndexes = [myTableView selectedRowIndexes];
    int             aRow = aVisibleRowIndexes.location;
    int             anEndRow = aRow + aVisibleRowIndexes.length;
    NSGradient *    gradient;
    NSColor *       pathColor;
    
    // if view is focused, use highlight color, otherwise use the out-of-focus highlight color
    
    if (myTableView == [[myTableView window] firstResponder] &&
        [[myTableView window] isMainWindow] &&
        [[myTableView window] isKeyWindow])
    {
        gradient = self.keyWindowHighlightGradient;
    }
    else {
        gradient = self.nonKeyWindowHighlightGradient;
    }
    pathColor = [gradient interpolatedColorAtLocation:1.0];
    
    // draw highlight for the visible, selected rows
    for (; aRow < anEndRow; aRow++)
    {
        if([aSelectedRowIndexes containsIndex:aRow])
        {
            NSRect aRowRect = NSInsetRect([myTableView rectOfRow:aRow], 0, 1); //first is horizontal, second is vertical
            NSBezierPath * path = [NSBezierPath bezierPathWithRoundedRect:aRowRect xRadius:0.0 yRadius:0.0]; //6.0
            [path setLineWidth: 2];
            [pathColor set];
            [path stroke];
            
            [gradient drawInBezierPath:path angle:90];
        }
    }
    return YES;
}


@end
