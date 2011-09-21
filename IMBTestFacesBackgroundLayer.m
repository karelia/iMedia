/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
 following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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

#import "IMBTestFacesBackgroundLayer.h"


// Simple utility function that creates an image from a name by looking into the main bundle

CGImageRef createImageWithName(NSString* imageName)
{
	CGImageRef returnValue = NULL;
	
	NSString* path = [[NSBundle mainBundle] pathForResource:[imageName stringByDeletingPathExtension] ofType:[imageName pathExtension]];
	if(path){
		CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:path], NULL);
		
		if(imageSource){
			returnValue = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
		}
	}
	
	return returnValue;
}


// Provides the background image (will be cached once loaded)

static CGImageRef backgroundImage()
{
	static CGImageRef image = NULL;
	
	if(image == NULL)
		image = createImageWithName(@"cork-background.jpg");
	
	return image;
}


@implementation IMBTestFacesBackgroundLayer

@synthesize owner;

// -------------------------------------------------------------------------
//	init
// -------------------------------------------------------------------------
- (id) init
{
	if((self = [super init])){
		//needs to redraw when bounds change
		[self setNeedsDisplayOnBoundsChange:YES];
	}
	
	return self;
}

// -------------------------------------------------------------------------
//	actionForKey:
//
// always return nil, to never animate
// -------------------------------------------------------------------------
- (id<CAAction>)actionForKey:(NSString *)event
{
	return nil;
}

// -------------------------------------------------------------------------
//	drawInContext:
//
// draw a metal background that scrolls when the image browser scroll
// -------------------------------------------------------------------------
- (void)drawInContext:(CGContextRef)context
{
	//retreive bounds and visible rect
	NSRect visibleRect = [owner visibleRect];
	NSRect bounds = [owner bounds];
	
	//retreive background image
	CGImageRef image = backgroundImage();
	float width = (float) CGImageGetWidth(image);
	float height = (float) CGImageGetHeight(image);
	
	//compute coordinates to fill the view
	float left, top, right, bottom;
	
	top = bounds.size.height - NSMaxY(visibleRect);
	top = fmod(top, height);
	top = height - top;
	
	right = NSMaxX(visibleRect);
	bottom = -height;
	
	// tile the image and take in account the offset to 'emulate' a scrolling background
	for (top = visibleRect.size.height-top; top>bottom; top -= height){
		for(left=0; left<right; left+=width){
			CGContextDrawImage(context, CGRectMake(left, top, width, height), image);
		}
	}
}

@end
