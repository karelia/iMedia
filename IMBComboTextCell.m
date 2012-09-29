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


// Author: Dan Wood, Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBComboTextCell.h"
#import "IMBComboTableView.h"
#import "IMBCommon.h"
#import <Quartz/Quartz.h>
#import <QTKit/QTKit.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

#define IMAGE_INSET 8.0
#define ASPECT_RATIO 1.5
#define TITLE_HEIGHT 17.0
#define INSET_FROM_IMAGE_TO_TEXT 8.0


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBComboTextCell

@synthesize imageRepresentation = _imageRepresentation;
@synthesize imageRepresentationType = _imageRepresentationType;
@synthesize subtitle = _subtitle;
@synthesize badge = _badge;
@synthesize subtitleTextAttributes = _subtitleTextAttributes;
@synthesize isDisabledFromDragging = _isDisabledFromDragging;


//----------------------------------------------------------------------------------------------------------------------


//----------------------------------------------------------------------------------------------------------------------


- (void) dealloc
{
	IMBRelease(_imageRepresentation);
	IMBRelease(_imageRepresentationType);
	IMBRelease(_subtitle);
	IMBRelease(_subtitleTextAttributes);
	IMBRelease(_badge);
	
    [super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
    IMBComboTextCell* result = [super copyWithZone:inZone];
	
	// Because copyWithZone may use NSCopyObject, we need to implicitly ZERO out our retained subclass fields 
	// in order to prevent them being over-released by the accessor methods that get implicitly called below. 
	// Notice the use of the C-struct style -> avoids using an accessor and blots out the value completely. 
	// This is appropriate because NSCopyObject, if called, has blithely copied the bits over without retaining...
	
	result->_imageRepresentation = nil;
	result->_imageRepresentationType = nil;
	result->_subtitle = nil;
	result->_subtitleTextAttributes = nil;
	
	result.imageRepresentation = self.imageRepresentation;
 	result.imageRepresentationType = self.imageRepresentationType;
	result.attributedStringValue = self.attributedStringValue;
	result.subtitle = self.subtitle;
	result.subtitleTextAttributes = self.subtitleTextAttributes;
	
	result.isDisabledFromDragging = self.isDisabledFromDragging;
	
    return result;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Layout


- (NSRect) titleRectForBounds:(NSRect)inBounds
{
    NSRect imageRect = [self imageRectForBounds:inBounds];
	
    NSRect rect = NSInsetRect(inBounds,IMAGE_INSET,IMAGE_INSET);
    rect.origin.x = NSMaxX(imageRect) + INSET_FROM_IMAGE_TO_TEXT;
    rect.origin.y -= 2.0;
    rect.size.width = NSMaxX(inBounds) - INSET_FROM_IMAGE_TO_TEXT - NSWidth(imageRect) - IMAGE_INSET;
    rect.size.height = TITLE_HEIGHT;
    return rect;
}


- (NSRect) subtitleRectForBounds:(NSRect)inBounds
{
	NSRect rect = [self titleRectForBounds:inBounds];
	rect.origin.y = NSMaxY(rect);
	rect.size.height = NSHeight(inBounds) - IMAGE_INSET - TITLE_HEIGHT - IMAGE_INSET;
    return rect;
}


- (NSRect) imageRectForBounds:(NSRect)inBounds
{
    NSRect rect = NSInsetRect(inBounds,IMAGE_INSET,IMAGE_INSET);
    rect.size.width = round(rect.size.height * ASPECT_RATIO);
    return rect;
}


- (NSRect) imageRectForFrame:(NSRect)inImageFrame imageWidth:(CGFloat)inWidth imageHeight:(CGFloat)inHeight
{
	CGFloat f = 1.0;
	if (inWidth > inImageFrame.size.width || inHeight > inImageFrame.size.height)
	{
		CGFloat fx		 = inImageFrame.size.width / inWidth;
		CGFloat fy		 = inImageFrame.size.height / inHeight;
		f		 = MIN(fx,fy);
	}
	
	CGFloat x0		 = NSMidX(inImageFrame);
	CGFloat y0		 = NSMidY(inImageFrame);
	CGFloat width	 = f * inWidth;
	CGFloat height	 = f * inHeight;
	
	NSRect rect;
	rect.origin.x	 = round(x0 - 0.5*width);
	rect.origin.y	 = round(y0 - 0.5*height);
	rect.size.width  = round(width);
	rect.size.height = round(height);
	
	return rect;
}


- (NSRect) badgeRectForImageRect:(NSRect)inImageRect
{
	NSRect badgeRect;
	NSSize badgeSize = NSMakeSize(18.0,18.0);
	badgeRect.origin.x = inImageRect.origin.x + inImageRect.size.width - badgeSize.width - 3;
	badgeRect.origin.y = inImageRect.origin.y + 3;
	badgeRect.size.width  = badgeSize.width;
	badgeRect.size.height = badgeSize.height;
	
	return badgeRect;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Drawing


// Please note that we have to temporarily modify the CTM because the tableview
// is flipped... You should restore the gstate afterwards

- (void) willDrawImageInRect:(NSRect)rect context:(CGContextRef)context;
{
	CGContextSaveGState(context);
	CGContextScaleCTM(context,1.0,-1.0);
	CGContextTranslateCTM(context,0.0,-2.0*rect.origin.y-NSHeight(rect));
}


// Draw a CGImageRef into the specified rect, keeping the aspect ratio of the image intact. The image will have 
// to be scaled to fit into the rect. 

- (void) _drawImage:(CGImageRef)inImage withFrame:(NSRect)inImageRect
{
	CGFloat width = CGImageGetWidth(inImage);
	CGFloat height = CGImageGetHeight(inImage);
	NSRect rect = [self imageRectForFrame:inImageRect imageWidth:width imageHeight:height];
	
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    [self willDrawImageInRect:rect context:context];
	CGContextSetInterpolationQuality(context, kCGInterpolationHigh);	// artwork is pretty bad if you don't set this.
	CGContextDrawImage(context,NSRectToCGRect(rect),inImage);
	
	if (_badge) 
	{
		NSRect badgeRect = [self badgeRectForImageRect:rect];
		[_badge drawInRect:badgeRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
	CGContextRestoreGState(context);
}


//----------------------------------------------------------------------------------------------------------------------


- (void) drawInteriorWithFrame:(NSRect)inCellFrame inView:(NSView*)inView
{
	// Get cell layout...
	
	NSRect imageRect = [self imageRectForBounds:inCellFrame];
	NSRect titleRect = [self titleRectForBounds:inCellFrame];
	NSRect subtitleRect = [self subtitleRectForBounds:inCellFrame];
	
	// If the image hasn't been loaded yet, then draw a placeholder frame...
	
	if (self.imageRepresentation == nil)
	{
		NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:imageRect xRadius:8.0 yRadius:8.0];
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.05] set];
		[path fill];
		
		CGFloat dashes[2] = {8.0,4.0};
		[[NSColor colorWithCalibratedWhite:0.0 alpha:0.15] set];
		[path setLineWidth:2.0];
		[path setLineDash:dashes count:2 phase:0.0];
		[path stroke];
	}
	
	else
    {
        // Draw the thumbnail image (NSImage)...
        
        if ([_imageRepresentationType isEqualToString:IKImageBrowserNSImageRepresentationType])
        {
            NSImage* image = (NSImage*) _imageRepresentation;
            
            CGFloat width = image.size.width;
            CGFloat height = image.size.height;
            NSRect rect = [self imageRectForFrame:imageRect imageWidth:width imageHeight:height];
            
            CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
            [self willDrawImageInRect:rect context:context];
            [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
            CGContextRestoreGState(context);
        }
        
        // Draw the thumbnail image (CGImage)...
        
        else if ([_imageRepresentationType isEqualToString:IKImageBrowserCGImageRepresentationType])
        {
			CGImageRef image = (CGImageRef) _imageRepresentation;
            [self _drawImage:image withFrame:imageRect];
        }
		else if ([_imageRepresentationType isEqualToString:IKImageBrowserQTMovieRepresentationType])	// QTMovie, we got quicklook...
        {
			NSLog(@"WHAT TO DO? IKImageBrowserQTMovieRepresentationType, _imageRepresentation = %@", _imageRepresentation);
		}
		else if ([_imageRepresentationType isEqualToString:IKImageBrowserQTMoviePathRepresentationType])
        {
			//NSImage *nsImage = [[NSImage alloc] initWithContentsOfFile:_imageRepresentation];
			//NSBitmapImageRep *imageRep = [[nsImage representations] objectAtIndex:0];
			//CGImageRef image =  [imageRep CGImage];
			//[nsImage release];
			CGImageRef image = (CGImageRef) _imageRepresentation;
			
            [self _drawImage:image withFrame:imageRect];
		}
		
        // Draw the thumbnail image (other representations)...
        
        else
        {
            CGImageRef image = IMB_CGImageCreateWithImageItem(self);
            [self _drawImage:image withFrame:imageRect];
            CFRelease(image);
        }
    }
	
	// Draw the title and subtitle...
	
	if (self.attributedStringValue)
	{
		[self.attributedStringValue drawInRect:titleRect];
	}
	
	if (_subtitle)
	{
		[_subtitle drawInRect:subtitleRect withAttributes:_subtitleTextAttributes];
	}	
}


//----------------------------------------------------------------------------------------------------------------------


@end
