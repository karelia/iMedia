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

/*
 File: IMBComboTextCell.m
 
 */

#import "IMBComboTextCell.h"
#import "IMBComboTableView.h"

#define IMAGE_INSET 8.0
#define ASPECT_RATIO 1.6
#define TITLE_HEIGHT 17.0
#define INSET_FROM_IMAGE_TO_TEXT 4.0

@implementation IMBComboTextCell

- (id)copyWithZone:(NSZone *)zone
{
    IMBComboTextCell *result = [super copyWithZone:zone];
    if (result != nil)
	{
        // Retain or copy all our ivars
        result->_imageCell = [_imageCell copyWithZone:zone];
    }
    return result;
}

- (void)dealloc
{
    [_imageCell release];
    [super dealloc];
}

@dynamic image;

- (NSImage *)image
{
    return _imageCell.image;
}

- (void)setImage:(NSImage *)image
{
    if (_imageCell == nil)
	{
        _imageCell = [[NSImageCell alloc] init];
        [_imageCell setControlView:self.controlView];
        [_imageCell setBackgroundStyle:self.backgroundStyle];
    }
    _imageCell.image = image;
}

- (void)setControlView:(NSView *)controlView
{
    [super setControlView:controlView];
    [_imageCell setControlView:controlView];
}

- (void)setBackgroundStyle:(NSBackgroundStyle)style
{
    [super setBackgroundStyle:style];
    [_imageCell setBackgroundStyle:style];
}

- (NSRect)_imageFrameForInteriorFrame:(NSRect)frame
{
    NSRect result = frame;
    // Inset the top
    result.origin.y += IMAGE_INSET;
    result.size.height -= 2*IMAGE_INSET;
    // Inset the left
    result.origin.x += IMAGE_INSET;
    // Make the width match the aspect ratio based on the height
    result.size.width = ceil(result.size.height * ASPECT_RATIO);
    return result;
}

- (NSRect)imageRectForBounds:(NSRect)frame
{
    // We would apply any inset that here that drawWithFrame did before calling drawInteriorWithFrame:. It does none, so we don't do anything.
    return [self _imageFrameForInteriorFrame:frame];
}

- (NSRect)_titleFrameForInteriorFrame:(NSRect)frame
{
    NSRect imageFrame = [self _imageFrameForInteriorFrame:frame];
    NSRect result = frame;
    // Move our inset to the left of the image frame
    result.origin.x = NSMaxX(imageFrame) + INSET_FROM_IMAGE_TO_TEXT;
    // Go as wide as we can
    result.size.width = NSMaxX(frame) - NSMinX(result);
    // Move the title above the Y centerline of the image. 
    NSSize naturalSize = [super cellSize];
    result.origin.y = floor(NSMidY(imageFrame) - naturalSize.height - INSET_FROM_IMAGE_TO_TEXT);
    result.size.height = naturalSize.height;
    return result;
}

// NOT USED ....

- (NSRect)_subtitleFrameForInteriorFrame:(NSRect)frame
{		// THIS WILL HAVE TO BE COMPLETELY REDONE SINCE IT RELIED ON FILL COLOR
    NSRect result = frame;
    result.origin.x = NSMaxX(frame) + INSET_FROM_IMAGE_TO_TEXT;
    result.size.width = NSMaxX(frame) - NSMinX(result);    
    return result;    
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)controlView
{
    if (_imageCell)
	{
        NSRect imageFrame = [self _imageFrameForInteriorFrame:frame];
        [_imageCell drawWithFrame:imageFrame inView:controlView];
    }
    
    
    NSRect titleFrame = [self _titleFrameForInteriorFrame:frame];
    [super drawInteriorWithFrame:titleFrame inView:controlView];
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)frame ofView:(NSView *)controlView
{
    NSPoint point = [controlView convertPoint:[event locationInWindow] fromView:nil];
	
    // Delegate hit testing to other cells
    if (_imageCell)
	{
        NSRect imageFrame = [self _imageFrameForInteriorFrame:frame];
        if (NSPointInRect(point, imageFrame))
		{
            return [_imageCell hitTestForEvent:event inRect:imageFrame ofView:controlView];
        }
    }
	
    
    NSRect titleFrame = [self _titleFrameForInteriorFrame:frame];
    if (NSPointInRect(point, titleFrame))
	{
        return [super hitTestForEvent:event inRect:titleFrame ofView:controlView];
    }
    
    return NSCellHitNone;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
    aRect = [self _titleFrameForInteriorFrame:aRect];
    [super editWithFrame:aRect inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
    aRect = [self _titleFrameForInteriorFrame:aRect];
    [super selectWithFrame:aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

+ (BOOL)prefersTrackingUntilMouseUp
{
    // We want to have trackMouse:inRect:ofView:untilMouseUp: always track until the mouse is up
    return YES;
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)frame ofView:(NSView *)controlView untilMouseUp:(BOOL)flag
{
    BOOL result = NO;
	
    return result;
}

@end
