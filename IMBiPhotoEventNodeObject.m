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

#import "IMBiPhotoEventNodeObject.h"


@implementation IMBiPhotoEventNodeObject


//----------------------------------------------------------------------------------------------------------------------


// Key image and skimmed images of events are processed by Core Graphics before display

- (CGImageRef) newProcessedImageFromImage:(CGImageRef)inImage
{
	size_t imgWidth = CGImageGetWidth(inImage);
	size_t imgHeight = CGImageGetHeight(inImage);
	size_t squareSize = MIN(imgWidth, imgHeight);
	
	CGContextRef bitmapContext = CGBitmapContextCreate(NULL, 
													   squareSize, 
													   squareSize,
													   8, 
													   4 * squareSize, 
													   CGImageGetColorSpace(inImage), 
													   kCGImageAlphaPremultipliedLast);
	// Fill everything with transparent pixels
	CGRect bounds = CGContextGetClipBoundingBox(bitmapContext);
	CGContextClearRect(bitmapContext, bounds);
	
	// Set clipping path
	CGFloat cornerRadius = squareSize / 10.0;
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapContext flipped:NO]];
	[[NSBezierPath bezierPathWithRoundedRect:NSRectFromCGRect(bounds) xRadius: cornerRadius yRadius:cornerRadius] addClip];
	
	// Move image in context to get desired image area to be in context bounds
	CGRect imageBounds = CGRectMake(((NSInteger)(squareSize - imgWidth)) / 2.0,   // Will be negative or zero
									((NSInteger)(squareSize - imgHeight)) / 2.0,  // Will be negative or zero
									imgWidth, imgHeight);
	
	CGContextDrawImage(bitmapContext, imageBounds, inImage);
	
	CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
	
	CGContextRelease(bitmapContext);
	
	return image;
}


// Set a processed image instead of the image provided

- (void) setImageRepresentation:(id)inObject
{
	NSString* type = self.imageRepresentationType;

	CGImageRef image = NULL;
	if (inObject && [type isEqualToString:IKImageBrowserCGImageRepresentationType])
	{
		image = [self newProcessedImageFromImage:(CGImageRef)inObject];
		if (image) inObject = (id) image;
	}
	
	[super setImageRepresentation:inObject];
	
	if (image) CGImageRelease(image);
}


// Set a processed image instead of the image provided

- (void) setQuickLookImage:(CGImageRef)inImage
{
	CGImageRef image = NULL;
	if (inImage)
	{
		image = [self newProcessedImageFromImage:inImage];
		if (image) inImage = image;
	}
	
	[super setQuickLookImage:inImage];
	
	if (image) CGImageRelease(image);
}


@end
