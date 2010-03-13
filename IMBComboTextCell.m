/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
 following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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


// Author: Dan Wood, Peter Baumgartner


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
@synthesize title = _title;
@synthesize titleTextAttributes = _titleTextAttributes;
@synthesize subtitle = _subtitle;
@synthesize subtitleTextAttributes = _subtitleTextAttributes;


//----------------------------------------------------------------------------------------------------------------------


// Set default text style for title and subtitle...

- (void) initTextAttributes
{
	NSMutableParagraphStyle* paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];

	self.titleTextAttributes = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
		[NSColor blackColor],NSForegroundColorAttributeName,
		[NSFont systemFontOfSize:13.0],NSFontAttributeName,
		paragraphStyle,NSParagraphStyleAttributeName,
		nil] autorelease];
	
	self.subtitleTextAttributes = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
		[NSColor grayColor],NSForegroundColorAttributeName,
		[NSFont systemFontOfSize:11.0],NSFontAttributeName,
		paragraphStyle,NSParagraphStyleAttributeName,
		nil] autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initTextCell:(NSString*)inString
{
	if (self = [super initTextCell:inString])
	{
		[self initTextAttributes];
	}
	
	return self;
}


- (id) initImageCell:(NSImage*)inImage
{
	if (self = [super initImageCell:inImage])
	{
		[self initTextAttributes];
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		[self initTextAttributes];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_imageRepresentation);
	IMBRelease(_imageRepresentationType);
	IMBRelease(_title);
	IMBRelease(_titleTextAttributes);
	IMBRelease(_subtitle);
	IMBRelease(_subtitleTextAttributes);
	
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
	result->_title = nil;
	result->_subtitle = nil;
	result->_titleTextAttributes = nil;
	result->_subtitleTextAttributes = nil;
	
	result.imageRepresentation = self.imageRepresentation;
 	result.imageRepresentationType = self.imageRepresentationType;
	result.title = self.title;
	result.subtitle = self.subtitle;
	result.titleTextAttributes = self.titleTextAttributes;
	result.subtitleTextAttributes = self.subtitleTextAttributes;

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
    rect.size.width = NSMaxX(inBounds) - INSET_FROM_IMAGE_TO_TEXT;
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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Drawing


// Draw a CGImageRef into the specified rect, keeping the aspect ratio of the image intact. The image will have 
// to scaled to fit into the rect. Please note that we have to temporarily modify the CTM because the tableview
// is flipped...

- (void) _drawImage:(CGImageRef)inImage withFrame:(NSRect)inImageRect
{
	CGFloat width = CGImageGetWidth(inImage);
	CGFloat height = CGImageGetHeight(inImage);
	NSRect rect = [self imageRectForFrame:inImageRect imageWidth:width imageHeight:height];
	
	CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState(context);
	CGContextScaleCTM(context,1.0,-1.0);
	CGContextTranslateCTM(context,0.0,-2.0*rect.origin.y-NSHeight(rect));
	CGContextDrawImage(context,NSRectToCGRect(rect),inImage);
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
	
	// Draw the thumbnail image (NSImage)...
	
	else if ([_imageRepresentationType isEqualToString:IKImageBrowserNSImageRepresentationType])
	{
		NSImage* image = (NSImage*) _imageRepresentation;
		[image setFlipped:YES];

		CGFloat width = image.size.width;
		CGFloat height = image.size.height;
		NSRect rect = [self imageRectForFrame:imageRect imageWidth:width imageHeight:height];

		[image drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
	// Draw the thumbnail image (CGImage)...
	
	else if ([_imageRepresentationType isEqualToString:IKImageBrowserCGImageRepresentationType])
	{
		CGImageRef image = (CGImageRef) _imageRepresentation;
		[self _drawImage:image withFrame:imageRect];
	}
	
	// Draw the thumbnail image (NSData)...
	
	else if ([_imageRepresentationType isEqualToString:IKImageBrowserNSDataRepresentationType])
	{
		NSData* data = (NSData*) _imageRepresentation;
		CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data,NULL);
		
		if (source)
		{
			CGImageRef image = CGImageSourceCreateImageAtIndex(source,0,NULL);
			[self _drawImage:image withFrame:imageRect];
			CGImageRelease(image);
			CFRelease(source);
		}	
	}
	
	// Draw the thumbnail image (QTMovie)...
	
	else if ([_imageRepresentationType isEqualToString:IKImageBrowserQTMovieRepresentationType])
	{
		QTMovie* movie = (QTMovie*) _imageRepresentation;
		
		NSError* error = nil;
		QTTime duration = movie.duration;
		double tv = duration.timeValue;
		double ts = duration.timeScale;
		QTTime time = QTMakeTimeWithTimeInterval(0.5 * tv/ts);
		NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:QTMovieFrameImageTypeCGImageRef,QTMovieFrameImageType,nil];
			
		CGImageRef image = (CGImageRef) [movie frameImageAtTime:time withAttributes:attributes error:&error];
		[self _drawImage:image withFrame:imageRect];
	}
	
	// Unsupported imageRepresentation...
	
	else
	{
		NSLog(@"%s: %@ is not supported by this cell class...",__FUNCTION__,_imageRepresentationType);
	}

	// Draw the title and subtitle...
	
	if (_title)
	{
		[_title drawInRect:titleRect withAttributes:_titleTextAttributes];
	}
	
	if (_subtitle)
	{
		[_subtitle drawInRect:subtitleRect withAttributes:_subtitleTextAttributes];
	}	
}


//----------------------------------------------------------------------------------------------------------------------


@end
