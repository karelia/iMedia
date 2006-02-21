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
 
 In the case of iMediaBrowse, in addition to the terms noted above, in any 
 application that uses iMediaBrowse, we ask that you give a small attribution to 
 the members of CocoaDev.com who had a part in developing the project. Including, 
 but not limited to, Jason Terhorst, Greg Hulands and Ben Dunton.
 
 Greg doesn't really want acknowledgement he just want bug fixes as he has rewritten
 practically everything but the xml parsing stuff. Please send fixes to 
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 This file was Authored by Greg Hulands
 
 */

#import "iMBPhotoView.h"

#pragma mark OMNI

@interface NSImage (Omni)
- (void)drawFlippedInRect:(NSRect)rect fromRect:(NSRect)sourceRect operation:(NSCompositingOperation)op fraction:(float)delta;
- (void)drawFlippedInRect:(NSRect)rect fromRect:(NSRect)sourceRect operation:(NSCompositingOperation)op;
- (void)drawFlippedInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(float)delta;
- (void)drawFlippedInRect:(NSRect)rect operation:(NSCompositingOperation)op;
@end

#pragma mark
@implementation NSImage (Omni)
- (void)drawFlippedInRect:(NSRect)rect fromRect:(NSRect)sourceRect operation:(NSCompositingOperation)op fraction:(float)delta;
{
    CGContextRef context;
	
    context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(context); {
        CGContextTranslateCTM(context, 0, NSMaxY(rect));
        CGContextScaleCTM(context, 1, -1);
        
        rect.origin.y = 0; // We've translated ourselves so it's zero
        [self drawInRect:rect fromRect:sourceRect operation:op fraction:delta];
    } CGContextRestoreGState(context);
}

- (void)drawFlippedInRect:(NSRect)rect fromRect:(NSRect)sourceRect operation:(NSCompositingOperation)op;
{
    [self drawFlippedInRect:rect fromRect:sourceRect operation:op fraction:1.0];
}

- (void)drawFlippedInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(float)delta;
{
    [self drawFlippedInRect:rect fromRect:NSZeroRect operation:op fraction:delta];
}

- (void)drawFlippedInRect:(NSRect)rect operation:(NSCompositingOperation)op;
{
    [self drawFlippedInRect:rect operation:op fraction:1.0];
}
@end

#pragma mark 
#pragma mark DATA STRUCTURES
// This is from Apple's Sketch Example
NSRect SKTRectFromPoints(NSPoint point1, NSPoint point2) {
    return NSMakeRect(((point1.x <= point2.x) ? point1.x : point2.x), ((point1.y <= point2.y) ? point1.y : point2.y), ((point1.x <= point2.x) ? point2.x - point1.x : point1.x - point2.x), ((point1.y <= point2.y) ? point2.y - point1.y : point1.y - point2.y));
}

NSRect centeredAspectRatioPreservedRect(NSRect rect, NSSize imgSize, NSSize maxCellSize)
{
	float ratioH = imgSize.width / NSWidth(rect);
	float ratioV = imgSize.height / NSHeight(rect);
	float destWidth = 0;
	float destHeight = 0;
	
	if (ratioV > ratioH) {
		destHeight = NSHeight(rect);
		if (destHeight > maxCellSize.height)
			destHeight = maxCellSize.height;
		destWidth = (destHeight / imgSize.height) * imgSize.width;
	} else {
		destWidth = NSWidth(rect);
		if (destWidth > maxCellSize.width) 
			destWidth = maxCellSize.width;
		destHeight = (destWidth / imgSize.width) * imgSize.height;
	}
	
	float x = NSMidX(rect);
	float y = NSMidY(rect);
	
	return NSMakeRect(x - (destWidth / 2), y - (destHeight / 2), destWidth, destHeight);
}

#pragma mark
@interface iMBPhotoView (PrivateAPI)
//Drag Image
+ (NSImage *)draggingIconWithTitle:(NSString *)title andImage:(NSImage *)image;

//Selection
- (NSMutableArray *)selectedCells;
- (void)selectCellsInRect:(NSRect)rect;
- (BOOL)isSelected:(NSString *)thumb;
- (void)removeSelectedCellForPath:(NSString*)thumb;
- (NSDictionary *)recordUnderPoint:(NSPoint)p;
- (NSDictionary *)recordForThumb:(NSString *)thumb;
- (NSArray *)cellsInRect:(NSRect)rect;
- (void)selectCellsInRect:(NSRect)rect;
- (NSMutableArray *)selectedCells;
- (NSSize)cellSize;
- (BOOL)isSelected:(NSString *)thumb;
@end

#pragma mark
@implementation iMBPhotoView

static NSShadow *_shadow = nil;

+ (void)initialize
{
	_shadow = [[NSShadow alloc] init];
	[_shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.75]];
	[_shadow setShadowBlurRadius:3];
	[_shadow setShadowOffset:NSMakeSize(2,-2)];	
}

#define X_SPACE_BETWEEN_ICON_AND_TEXT_BOX 2
#define X_TEXT_BOX_BORDER 2
#define Y_TEXT_BOX_BORDER 2
static NSDictionary *titleFontAttributes;

+ (NSImage *)draggingIconWithTitle:(NSString *)title andImage:(NSImage *)image;
{
    NSImage *drawImage;
    NSSize imageSize, totalSize;
    NSSize titleSize, titleBoxSize;
    NSRect titleBox;
    NSPoint textPoint;
	
    NSParameterAssert(image != nil);
    imageSize = [image size];
	
    if (!titleFontAttributes)
        titleFontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont systemFontOfSize:12.0], NSFontAttributeName, [NSColor textColor], NSForegroundColorAttributeName, nil];
	
    if (!title || [title length] == 0)
        return image;
    
    titleSize = [title sizeWithAttributes:titleFontAttributes];
    titleBoxSize = NSMakeSize(titleSize.width + 2.0 * X_TEXT_BOX_BORDER, titleSize.height + Y_TEXT_BOX_BORDER);
	
    totalSize = NSMakeSize(imageSize.width + X_SPACE_BETWEEN_ICON_AND_TEXT_BOX + titleBoxSize.width, MAX(imageSize.height, titleBoxSize.height));
	
    drawImage = [[NSImage alloc] initWithSize:totalSize];
    [drawImage setFlipped:YES];
	
    [drawImage lockFocus];
	
    // Draw transparent background
    [[NSColor colorWithDeviceWhite:1.0 alpha:0.0] set];
    NSRectFill(NSMakeRect(0, 0, totalSize.width, totalSize.height));
	
    // Draw icon
    [image compositeToPoint:NSMakePoint(0.0, rint(totalSize.height / 2.0 + imageSize.height / 2.0)) operation:NSCompositeSourceOver];
    
    // Draw box around title
    titleBox = NSMakeRect(imageSize.width + X_SPACE_BETWEEN_ICON_AND_TEXT_BOX, floor((totalSize.height - titleBoxSize.height)/2.0), titleBoxSize.width, titleBoxSize.height);
    [[[NSColor selectedTextBackgroundColor] colorWithAlphaComponent:0.5] set];
    NSRectFill(titleBox);
	
    // Draw title
    textPoint = NSMakePoint(imageSize.width + X_SPACE_BETWEEN_ICON_AND_TEXT_BOX + X_TEXT_BOX_BORDER, Y_TEXT_BOX_BORDER - 1);
	
    [title drawAtPoint:textPoint withAttributes:titleFontAttributes];
	
    [drawImage unlockFocus];
	
    return [drawImage autorelease];
}

- (id)initWithFrame:(NSRect)frame
{
	if (self = [super initWithFrame:frame]) {
		myCache = [[NSMutableDictionary dictionary] retain];
		myRects = [[NSMutableArray array] retain];
		selectedCells = [[NSMutableArray array] retain];
		selectedRects = [[NSMutableArray array] retain];
	}
	return self;
}

- (void)dealloc
{
	[myCache release];
	[myRects release];
	[myImages release];
	[selectedCells release];
	[selectedRects release];
	[super dealloc];
}

- (void)removeSelectedCellForPath:(NSString*)thumb
{
	[selectedCells removeObject:[self recordForThumb:thumb]];
}

#define iPhotoColumns 3
#define CellPadding 5

#pragma mark -
#pragma mark VIEW
- (void)drawRect:(NSRect)rect 
{
    [[NSColor whiteColor] set];
	NSRectFill(rect);
	
	//If ruuberbanding, save rects to maintain "selection" of images not visible in scrollview
	if(!isRubberbanding)
	{
		[myRects removeAllObjects];		
	}

	[self removeAllToolTips];
	
	NSSize cellSize = [self cellSize];
	div_t rows = div([myImages count], iPhotoColumns);
	float matrixHeight = rows.quot * cellSize.height;
	if (rows.rem > 0) {
		rows.quot++;
		matrixHeight += cellSize.height;
	}
	if (rows.quot == 0) {
		matrixHeight = NSHeight([[self enclosingScrollView] documentVisibleRect]);
	}
	
	NSRect frame = [self frame];
	frame.size.height = matrixHeight;
	[self setFrame:frame];
	
	//we only want to actually draw the cells that are visible
	NSRect cell = NSZeroRect;
	cell.size = cellSize;
	int i, j;
	NSRect scrollerViewableRect = [[self enclosingScrollView] documentVisibleRect];
	unsigned idx;
	
	for (i = 0; i < rows.quot; i++) {
		cell.origin.y = i * cellSize.height;
		//we can determine if we need to draw this cell at this early stage
		
		if (!NSIntersectsRect(cell,scrollerViewableRect) && ![selectedRects containsObject:[NSValue valueWithRect:cell]])
		{
			continue;
		}
		
		for (j = 0; j < iPhotoColumns; j++) {
			cell.origin.x = j * cellSize.width;
			idx = (i * iPhotoColumns) + j;
			if (idx >= [myImages count]) continue;
			NSDictionary *record = [myImages objectAtIndex: idx];
			NSString *thumbPath = [record objectForKey:@"ThumbPath"];
			NSImage *img = [myCache objectForKey:thumbPath];
			
			if (!img) { //only load the image if we have to
				img = [[[NSImage alloc] initWithContentsOfFile:thumbPath] autorelease];
				[myCache setObject:img forKey:thumbPath];
			}
			BOOL isSelected = [self isSelected:thumbPath];
			NSRect drawable = centeredAspectRatioPreservedRect(NSInsetRect(cell, CellPadding, CellPadding), [img size], NSMakeSize(240,240));
			drawable = NSIntegralRect(drawable);
			
			[[NSGraphicsContext currentContext] saveGraphicsState];
			[_shadow set];
			if ([self isFlipped])
				[img drawFlippedInRect:drawable fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
			else
				[img drawInRect:drawable fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
			[[NSGraphicsContext currentContext] restoreGraphicsState];
			
			if (isSelected) {
				NSRect selectable = NSInsetRect(drawable, 3, 3);
				NSBezierPath *outer = [NSBezierPath bezierPathWithRect:drawable];
				NSBezierPath *inner = [NSBezierPath bezierPathWithRect:selectable];
				NSBezierPath *combined = [NSBezierPath bezierPath];
				[combined appendBezierPath:outer];
				[combined appendBezierPath:inner];
				[combined setWindingRule:NSEvenOddWindingRule];
				[[NSGraphicsContext currentContext] saveGraphicsState];
				//[[NSColor colorWithCalibratedRed:0.17 green:0.5 blue:1.0 alpha:0.8] set];	// blue 
				[[[NSColor selectedControlColor] colorWithAlphaComponent:0.80] set];
				[combined fill];
				[[NSGraphicsContext currentContext] restoreGraphicsState];
			}
			
			
			NSDictionary *rectRec = [NSDictionary dictionaryWithObjectsAndKeys:thumbPath, @"thumbPath", NSStringFromRect(drawable), @"rect", [record objectForKey:@"ImagePath"], @"file", img, @"thumb", nil];
			[myRects addObject:rectRec];
			//add a tooltip with the caption
			[self addToolTipRect:drawable owner:self userData:[record objectForKey:@"Caption"]];
		}
	}
	
	if (isRubberbanding) {
		NSColor *selColor = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.17 alpha:1.0];	// yellow
		[[selColor colorWithAlphaComponent:0.2] set];
		NSRectFillUsingOperation(rubberbandRect,NSCompositeSourceOver);
		[selColor set];
		NSFrameRect(rubberbandRect);
	}
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
	return [NSString stringWithString:userData];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	return YES;
}

- (BOOL)resignFirstResponder
{
	return YES;
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	if ([theEvent modifierFlags] & NSShiftKeyMask) {
		canAddToSelection = YES;
	} else {
		canAddToSelection = NO;
	}
}

static NSImage *_badge = nil;

- (void)mouseDown:(NSEvent *)theEvent
{
	NSPoint p = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSDictionary *rec = [self recordUnderPoint:p];
	
	if (rec) {
		if (!canAddToSelection && ![self isSelected:[rec objectForKey:@"thumbPath"]])
		{
			[selectedCells removeAllObjects];
			[selectedRects removeAllObjects];
		}
		
		//add to selection
		NSRect selectRect = NSZeroRect;
		selectRect.origin = p;
		selectRect.size = NSMakeSize(1,1);
		
		//see if we are dragging
		NSPoint curPoint;
		while (1) {
			theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
			curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
			
			if ([theEvent type] == NSLeftMouseUp) {
				if ([self isSelected:[rec objectForKey:@"thumbPath"]]) {
					[selectedCells removeObject:[rec objectForKey:@"thumbPath"]];
					[selectedRects removeObject:[NSValue valueWithRect:NSRectFromString([rec objectForKey:@"rect"])]];						
				} else {
					[selectedCells addObject:[rec objectForKey:@"thumbPath"]];
					[selectedRects addObject:[NSValue valueWithRect:NSRectFromString([rec objectForKey:@"rect"])]];
				}
				[self setNeedsDisplay:YES];
				return;
			}
			if (!NSEqualPoints(curPoint, p)) {
				NSImage *dragImage;
				NSPoint dragPosition;
				
				[self selectCellsInRect:selectRect];
				
				if (!_badge) {
					NSBundle *b = [NSBundle bundleForClass:[self class]];
					NSString *p = [b pathForResource:@"badge" ofType:@"png"];
					_badge = [[NSImage alloc] initWithContentsOfFile:p];
				}
				
				NSRect thumbRect = NSRectFromString([rec objectForKey:@"rect"]);
				NSSize size = thumbRect.size;
				NSSize badgeSize = [_badge size];
				size.width += badgeSize.width / 2;
				size.height += badgeSize.height / 2;
				
				/*dragImage = [iMBPhotoView draggingIconWithTitle:[rec objectForKey:@"Caption"]
													   andImage:[rec objectForKey:@"thumb"]];
				[dragImage lockFocus];
				[dragImage drawInRect:NSMakeRect(0,0,NSWidth(thumbRect),NSHeight(thumbRect))
							 fromRect:NSZeroRect
							operation:NSCompositeSourceOver
							 fraction:1.0];
				*/
				
				dragImage = [[NSImage alloc] initWithSize:size];
				[dragImage lockFocus];
				[[rec objectForKey:@"thumb"] drawInRect:NSMakeRect(0,0,NSWidth(thumbRect),NSHeight(thumbRect))
											   fromRect:NSZeroRect
											  operation:NSCompositeSourceOver
											   fraction:1.0];
				
				if ([selectedCells count] > 1) {
					NSRect badgeRect = NSMakeRect(size.width - badgeSize.width, size.height - badgeSize.height, badgeSize.width, badgeSize.height);
					[_badge drawInRect:badgeRect
							  fromRect:NSZeroRect
							 operation:NSCompositeSourceOver
							  fraction:1.0];
					NSString *count = [NSString stringWithFormat:@"%d", [selectedCells count]];
					static NSDictionary *badgeAttribs = nil;
					if (!badgeAttribs) {
						badgeAttribs = [[NSDictionary dictionaryWithObjectsAndKeys:[NSColor whiteColor], NSForegroundColorAttributeName, nil] retain];
					}
					NSSize countSize = [count sizeWithAttributes:badgeAttribs];
					[count drawInRect:NSMakeRect(NSMidX(badgeRect) - (countSize.width/2), NSMidY(badgeRect) - (countSize.height/2), countSize.width, countSize.height)
					   withAttributes:badgeAttribs];
				}
				[dragImage unlockFocus];
				[dragImage autorelease];
				// Write data to the pasteboard
				NSMutableArray *fileList = [NSMutableArray array];
				NSMutableDictionary *iphotoData = [NSMutableDictionary dictionary];
				NSEnumerator *e = [selectedCells objectEnumerator];
				NSString *cur;
				
				while (cur = [e nextObject]) {
					NSDictionary *rec = [self recordForThumb:cur];
					[fileList addObject:[rec objectForKey:@"ImagePath"]];
					[iphotoData setObject:rec forKey:cur]; //the key should be irrelavant
				}
				
				NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
				[pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, @"ImageDataListPboardType", nil]
							   owner:nil];
				[pboard setPropertyList:fileList forType:NSFilenamesPboardType];
				[pboard setPropertyList:iphotoData forType:@"ImageDataListPboardType"];
				
				// Start the drag operation
				dragPosition = p;
				
				dragPosition.x -= p.x - NSMinX(thumbRect);
				dragPosition.y += NSMaxY(thumbRect) - p.y;
				
				[self dragImage:dragImage 
							 at:dragPosition
						 offset:NSZeroSize
						  event:theEvent
					 pasteboard:pboard
						 source:self
					  slideBack:YES];
				return;
			} 
		}
		
	} else {
		// we must be rubberbanding the selection
		if (!canAddToSelection)
		{
			[selectedCells removeAllObjects];
			[selectedRects removeAllObjects];
		}
		
		
		isRubberbanding = YES;
		NSPoint curPoint = p;
		NSPoint lastPoint = p;
		while (1) {
			theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
			curPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
			
			if (!NSEqualPoints(p, curPoint)) {
				NSRect newRubberbandRect = SKTRectFromPoints(p, curPoint); // this is from the Sketch Sample
				if (!NSEqualRects(rubberbandRect, newRubberbandRect)) {
					rubberbandRect = newRubberbandRect;
					[selectedCells removeAllObjects];
					[selectedRects removeAllObjects];
					
					[self selectCellsInRect:rubberbandRect];
					[self setNeedsDisplay:YES];
				}
				//auto scroll down
				if (NSMaxY([[self enclosingScrollView] documentVisibleRect]) - curPoint.y < 10) {
					[[[self enclosingScrollView] contentView] scrollToPoint:NSMakePoint(0, NSMinY([[self enclosingScrollView] documentVisibleRect]) + (curPoint.y - lastPoint.y))];
				}
				
				//auto scroll up
				if (curPoint.y - NSMinY([[self enclosingScrollView] documentVisibleRect]) < 10) {
					NSPoint newPoint = NSMakePoint(0, NSMinY([[self enclosingScrollView] documentVisibleRect]) - (lastPoint.y - curPoint.y));
					if (newPoint.y < 0) newPoint.y = 0;
					[[[self enclosingScrollView] contentView] scrollToPoint:newPoint];
				}
				
				[[self enclosingScrollView] reflectScrolledClipView:[[self enclosingScrollView] contentView]];
			}
			
			if ([theEvent type] == NSLeftMouseUp) {
				isRubberbanding = NO;
				[self setNeedsDisplay:YES];
				break;
			}
			lastPoint = curPoint;
		}
	}
}

#pragma mark -
#pragma mark PRIVATE API
- (NSDictionary *)recordUnderPoint:(NSPoint)p
{
	NSEnumerator *e = [myRects objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject]) {
		NSRect r = NSRectFromString([cur objectForKey:@"rect"]);
		if (NSPointInRect(p,r))
			return cur;
	}
	return nil;
}

- (NSDictionary *)recordForThumb:(NSString *)thumb
{
	NSEnumerator *e = [myImages objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject]) {
		if ([[cur objectForKey:@"ThumbPath"] isEqualToString:thumb])
			return cur;
	}
	return nil;
}

- (NSArray *)cellsInRect:(NSRect)rect
{
	NSMutableArray *cells = [NSMutableArray array];
	NSEnumerator *e = [myRects objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject]) {
		NSRect r = NSRectFromString([cur objectForKey:@"rect"]);
		if (NSIntersectsRect(rect,r)) {
			NSString *path = [cur objectForKey:@"thumbPath"];
			if (![selectedCells containsObject:path])
			{
				[cells addObject:path];
				
				NSDictionary *recDict = [self recordForThumb:[cur objectForKey:@"thumbPath"]];
				if(recDict != nil)
				{
					[selectedRects addObject:[NSValue valueWithRect:NSRectFromString([recDict objectForKey:@"rect"])]];
				}
			}
		}
	}
	return cells;
}

- (void)selectCellsInRect:(NSRect)rect
{
	NSEnumerator *e = [[self cellsInRect:rect] objectEnumerator];
	NSDictionary *cur;
	
	while (cur = [e nextObject])
	{
		if ([selectedCells indexOfObject:cur] == NSNotFound)
		{
			[selectedCells addObject:cur];
		}
	}
}

- (NSMutableArray *)selectedCells {
    if (!selectedCells) {
        selectedCells = [[NSMutableArray alloc] init];
    }
    return [[selectedCells retain] autorelease];
}

- (NSSize)cellSize
{
	float w = NSWidth([self frame]) / 3;
	return NSMakeSize(w,w);
}

- (BOOL)isSelected:(NSString *)thumb
{
	NSEnumerator *e = [selectedCells objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		if ([cur isEqualToString:thumb])
			return YES;
	}
	return NO;
}

#pragma mark -
#pragma mark ACCESSORS & MUTATORS
- (NSArray*)images
{
	return [[myImages retain] autorelease];
}

- (void)setImages:(NSArray *)images
{
	[myImages autorelease];
	myImages = [images copy];
	[selectedCells removeAllObjects];
	[selectedRects removeAllObjects];
	
	//need to reset the scroll view
	[[[self enclosingScrollView] contentView] scrollToPoint:NSMakePoint(0,0)];
	[[self enclosingScrollView] reflectScrolledClipView:[[self enclosingScrollView] contentView]];
	[self setNeedsDisplay:YES];
}

@end
