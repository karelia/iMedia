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

#import "IMBTestFaceBrowserCell.h"

/* weak linking of types for layerForType to ensure 10.5 compatibility: */
extern NSString *const IKImageBrowserCellBackgroundLayer __attribute__((weak_import));
extern NSString *const IKImageBrowserCellForegroundLayer __attribute__((weak_import));
extern NSString *const IKImageBrowserCellSelectionLayer __attribute__((weak_import));
extern NSString *const IKImageBrowserCellPlaceHolderLayer __attribute__((weak_import));


@implementation IMBTestFaceBrowserCell

//----------------------------------------------------------------------------------------------------------------------
// Provides the layers for the given types

- (CALayer *) layerForType:(NSString*) type
{
	CGColorRef color;
	
	//retrieve some usefull rects
	NSRect frame = [self frame];
	NSRect imageFrame = [self imageFrame];
	NSRect relativeImageFrame = NSMakeRect(imageFrame.origin.x - frame.origin.x, imageFrame.origin.y - frame.origin.y, imageFrame.size.width, imageFrame.size.height);
	
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		/* place holder layer */
		if (type == IKImageBrowserCellPlaceHolderLayer)
		{
			//create a place holder layer
			CALayer *layer = [CALayer layer];
			layer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
			
			CALayer *placeHolderLayer = [CALayer layer];
			placeHolderLayer.frame = *(CGRect*) &relativeImageFrame;
			
			CGFloat fillComponents[4] = {1.0, 1.0, 1.0, 0.3};
			CGFloat strokeComponents[4] = {1.0, 1.0, 1.0, 0.9};
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			
			//set a background color
			color = CGColorCreate(colorSpace, fillComponents);
			[placeHolderLayer setBackgroundColor:color];
			CFRelease(color);
			
			//set a stroke color
			color = CGColorCreate(colorSpace, strokeComponents);
			[placeHolderLayer setBorderColor:color];
			CFRelease(color);
			
			[placeHolderLayer setBorderWidth:2.0];
			[placeHolderLayer setCornerRadius:10];
			CFRelease(colorSpace);
			
			[layer addSublayer:placeHolderLayer];
			
			return layer;
		}
		
		/* foreground layer */
		// Seems to me that background layer will be occasionaly drawn erronously
		// if we don't provide at least a dummy forground layer
		
		if (type == IKImageBrowserCellForegroundLayer){
			//no foreground layer on place holders
			if([self cellState] != IKImageStateReady)
				return nil;
			
			//create a foreground layer that will contain several childs layer
			CALayer *layer = [CALayer layer];
			layer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
			
			CALayer* superLayer = [super layerForType:type];
			if (superLayer)
			{
				[layer addSublayer:superLayer];
			}
			
			return layer;
		}
		
		/* background layer */
		if (type == IKImageBrowserCellBackgroundLayer){
			//no background layer on place holders
			if([self cellState] != IKImageStateReady)
				return nil;
			
			CALayer *layer = [CALayer layer];
			layer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
			
			NSRect backgroundRect = NSMakeRect(0, 0, frame.size.width, frame.size.height);		
			
			CALayer *photoBackgroundLayer = [CALayer layer];
			photoBackgroundLayer.frame = *(CGRect*) &backgroundRect;
			
			CGFloat fillComponents[4] = {0.95, 0.95, 0.95, 1.0};
			CGFloat strokeComponents[4] = {0.2, 0.2, 0.2, 0.5};
			
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			
			color = CGColorCreate(colorSpace, fillComponents);
			[photoBackgroundLayer setBackgroundColor:color];
			CFRelease(color);
			
			color = CGColorCreate(colorSpace, strokeComponents);
			[photoBackgroundLayer setBorderColor:color];
			CFRelease(color);
			
			[photoBackgroundLayer setBorderWidth:1.0];
			[photoBackgroundLayer setShadowOpacity:0.5];
			[photoBackgroundLayer setCornerRadius:3];
			
			CFRelease(colorSpace);
			
			[layer addSublayer:photoBackgroundLayer];
			
			return layer;
		}		
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------
// define where the image should be drawn

- (NSRect) imageFrame
{
	//get default imageFrame and aspect ratio
	NSRect imageFrame = [super imageFrame];
	
	if(imageFrame.size.height == 0 || imageFrame.size.width == 0) return NSZeroRect;
	
	float aspectRatio =  imageFrame.size.width / imageFrame.size.height;
	
	// compute the rectangle included in container with a margin of at least 10 pixel at the bottom, 5 pixel at the top and keep a correct  aspect ratio
	NSRect container = [self imageContainerFrame];
	container = NSInsetRect(container, 8, 8);
	
	if(container.size.height <= 0) return NSZeroRect;
	
	float containerAspectRatio = container.size.width / container.size.height;
	
	if(containerAspectRatio > aspectRatio){
		imageFrame.size.height = container.size.height;
		imageFrame.origin.y = container.origin.y;
		imageFrame.size.width = imageFrame.size.height * aspectRatio;
		imageFrame.origin.x = container.origin.x + (container.size.width - imageFrame.size.width)*0.5;
	}
	else{
		imageFrame.size.width = container.size.width;
		imageFrame.origin.x = container.origin.x;		
		imageFrame.size.height = imageFrame.size.width / aspectRatio;
		imageFrame.origin.y = container.origin.y + container.size.height - imageFrame.size.height;
	}
	
	//round it
	imageFrame.origin.x = floorf(imageFrame.origin.x);
	imageFrame.origin.y = floorf(imageFrame.origin.y);
	imageFrame.size.width = ceilf(imageFrame.size.width);
	imageFrame.size.height = ceilf(imageFrame.size.height);
	
	return imageFrame;
}


//----------------------------------------------------------------------------------------------------------------------
// override the default image container frame

- (NSRect) imageContainerFrame
{
	NSRect container = [super frame];
	
	//make the image container 15 pixels up
	container.origin.y += 15;
	container.size.height -= 15;
	
	return container;
}


//----------------------------------------------------------------------------------------------------------------------
// Set some title attributes to mimic iPhoto titles for faces

+ (NSDictionary*) titleAttributes
{
	NSFont* font = [NSFont fontWithName:@"Marker Felt" size:14.0];
	NSDictionary* titleAttributes = [NSMutableDictionary dictionaryWithObject:font forKey:NSFontAttributeName];

	return titleAttributes;
}


//----------------------------------------------------------------------------------------------------------------------
// override the default frame for the title

- (NSRect) titleFrame
{
	static CGFloat fontHeight = 0.0;
	
	if (fontHeight == 0.0) {
		fontHeight = [@"Jj" sizeWithAttributes:[[self class] titleAttributes]].height;
	}
	//get the default frame for the title
	NSRect titleFrame = [super titleFrame];
	
	//move the title inside the 'photo' background image
	NSRect container = [self frame];
	titleFrame.origin.y = container.origin.y + 3;
	titleFrame.size.height = fontHeight;
	
	//make sure the title has a 7px margin with the left/right borders
	float margin = titleFrame.origin.x - (container.origin.x + 7);
	if(margin < 0)
		titleFrame = NSInsetRect(titleFrame, -margin, 0);
	
	return titleFrame;
}

@end
