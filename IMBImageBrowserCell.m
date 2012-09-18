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


// Author: Peter Baumgartner, Dan Wood


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBImageBrowserCell.h"
#import "IMBObject.h"
#import "IMBNode.h"
#import "IMBCommon.h"
#import "IMBObjectViewController.h"
#import "NSImage+iMedia.h"

/* weak linking of types for layerForType to ensure 10.5 compatibility: */
extern NSString *const IKImageBrowserCellBackgroundLayer __attribute__((weak_import));
extern NSString *const IKImageBrowserCellForegroundLayer __attribute__((weak_import));
extern NSString *const IKImageBrowserCellSelectionLayer __attribute__((weak_import));
extern NSString *const IKImageBrowserCellPlaceHolderLayer __attribute__((weak_import));


//----------------------------------------------------------------------------------------------------------------------

@interface IKImageBrowserCell (NotPublicSoThisMightBeAProblemForTheMAS)

- (void) setDataSource:(id)inDataSource;
- (void) drawShadow;
- (void) drawImageOutline;
- (NSRect) usedRectInCellFrame:(NSRect)inFrame;
- (NSRect) imageContainerFrame;
- (IKImageBrowserView*) imageBrowserView;	// To shut up the compiler when using 10.5.sdk
- (void) drawTitle;							// To shut up the compiler when using 10.6.sdk
- (id) parent;

@end

@interface IMBImageBrowserCell()

- (CALayer *)imb_layerWithBadge:(CGImageRef)inBadge inRect:(NSRect)inRect;

@end
//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBImageBrowserCell

@synthesize imbShouldDrawOutline = _imbShouldDrawOutline;
@synthesize imbShouldDrawShadow = _imbShouldDrawShadow;
@synthesize imbShouldDisableTitle = _imbShouldDisableTitle;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		_imbShouldDrawOutline = YES;
		_imbShouldDrawShadow = YES;
		_imbShouldDisableTitle = NO;
	}
	
	return self;
}


//----------------------------------------------------------------------------------------------------------------------


// Disable outline and shadow drawing for certain objects...

- (void) setDataSource:(id)inDataSource
{
	[super setDataSource:inDataSource];
	
	if ([inDataSource isKindOfClass:[IMBObject class]])
	{
		IMBObject* object = (IMBObject*)inDataSource;
		_imbShouldDrawOutline = object.shouldDrawAdornments;
		_imbShouldDrawShadow = object.shouldDrawAdornments;
		_imbShouldDisableTitle = object.shouldDisableTitle;
	}
}

//----------------------------------------------------------------------------------------------------------------------


// Drawing outlines and shadows should be suppress in some cases (e.g. for IMBNodeObjects which are displayed 
// as non-rectangular folder icons)...

- (void) drawShadow
{
	if (_imbShouldDrawShadow)
	{
		[super drawShadow];	
	}
}


- (void) drawImageOutline
{
	if (_imbShouldDrawOutline)
	{
		[super drawImageOutline];	
	}	
}


// Draw the image itself. In the case of an IMBNodeObject (which is represented as a large folder icon)
// we should draw a small badge icon on top of the large folder icon. This si used to distinguish various 
// kinds of subnodes visually (e.g. iPhoto events, albums, etc)...

//- (void) drawImage:(id)inImage
//{
//	[super drawImage:inImage];
//	
//	id datasource = self.dataSource;
//	
//	if ([datasource isKindOfClass:[IMBNodeObject class]])
//	{
//		IMBNode* node = (IMBNode*) datasource;
//		NSImage* icon = node.icon;
//		NSRect frame = [self imageFrame];
//		CGFloat x0 = 20; //NSMidX(frame);
//		CGFloat y0 = 20; //NSMidY(frame);
//		CGFloat dx = 16.0;
//		CGFloat dy = 16.0;
//		frame = NSMakeRect(x0-0.5*dx,y0-0.5*dy,dx,dy);
//		[icon drawInRect:frame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
//	}
//}


//----------------------------------------------------------------------------------------------------------------------


- (CGFloat) imbPointSize
{
	CGFloat points = 0;
	CGFloat width = [((id)self) size].width;
	if (width < 60) points = 9;
	else if (width < 70) points = 10;
	else points = 11;

	return points;
}


// Is there any smarter way to do this?

- (void) imbSetTitleColors
{
	CGFloat points = [self imbPointSize];	// we need to get the whole font thing since we have to set the whole attributes
	
	NSMutableDictionary *attributes1 = [NSMutableDictionary dictionaryWithObject:[NSFont systemFontOfSize:points] forKey:NSFontAttributeName];
	NSMutableDictionary *attributes2 = [NSMutableDictionary dictionaryWithDictionary:attributes1];
	
	// Now set the title color.  Try to match what we see in table views. 
	// Enabled: Black, white if Selected; Disabled: grayed out.
	
	if (_imbShouldDisableTitle)
	{
		[attributes1 setObject:[NSColor colorWithCalibratedWhite:0.0 alpha:0.4] forKey:NSForegroundColorAttributeName];
		[attributes2 setObject:[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] forKey:NSForegroundColorAttributeName];
	}
	else
	{
		[attributes1 setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
		[attributes2 setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	}

	if (IMBRunningOnSnowLeopardOrNewer())
	{
		[[self imageBrowserView] setValue:attributes1  forKey:IKImageBrowserCellsTitleAttributesKey];
		[[self imageBrowserView] setValue:attributes2 forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];
	}
	else
	{
		[[self parent] setValue:attributes1  forKey:IKImageBrowserCellsTitleAttributesKey];
		[[self parent] setValue:attributes2 forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];
	}	
}


- (void) drawTitle
{
	[self imbSetTitleColors];
	[super drawTitle];
}


//---------------------------------------------------------------------------------
// layerForType:
//
// provides the layers for the given types
//---------------------------------------------------------------------------------
- (CALayer *) layerForType:(NSString*) type
{
	CGColorRef color;
	
	//retrieve some usefull rects
	NSRect frame = [self frame];
	NSRect imageFrame = [self imageFrame];
	NSRect relativeImageFrame = NSMakeRect(imageFrame.origin.x - frame.origin.x, imageFrame.origin.y - frame.origin.y, imageFrame.size.width, imageFrame.size.height);
	
	/* place holder layer */
	if(type == IKImageBrowserCellPlaceHolderLayer){
		//create a place holder layer
		CALayer *layer = [CALayer layer];
		layer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
		
		CALayer *placeHolderLayer = [CALayer layer];
		placeHolderLayer.frame = *(CGRect*) &relativeImageFrame;
		
		CGFloat fillComponents[4] = {0.9, 0.9, 0.9, 0.3};   // Light gray
		CGFloat strokeComponents[4] = {0.6, 0.6, 0.6, 0.9}; // medium gray
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
	if(type == IKImageBrowserCellForegroundLayer){
		// No foreground layer on place holders
		if([self cellState] != IKImageStateReady)
			return nil;
		
		// Create a foreground layer that may contain a badge layer
		// (i.e. add a badge icon if the host app does provide one)
		
		CALayer *layer = [CALayer layer];
		layer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
		
		IMBObject* item = (IMBObject*) [self representedItem];

        // Display warning or error sign badge if resource that thumbnail is representing is not accessible
        
        CGImageRef imageRef = NULL;
        switch (item.accessibility)
        {
            case kIMBResourceDoesNotExist:
                imageRef = [NSImage imb_CGImageNamed:@"IMBStopIcon.icns"];
                [layer addSublayer: [self imb_layerWithBadge:imageRef inRect:relativeImageFrame]];
                break;
				
            case kIMBResourceNoPermission:
                imageRef = [NSImage imb_CGImageNamed:@"warning.tiff"];
                [layer addSublayer: [self imb_layerWithBadge:imageRef inRect:relativeImageFrame]];
                break;
                
           case kIMBResourceIsAccessible:
				{
					// Display any kind of badge if host app wants us to (should not exceed 16x16 points)
					
					IMBObjectViewController* objectViewController = (IMBObjectViewController*) [[self imageBrowserView] delegate];
					id <IMBObjectViewControllerDelegate> delegate = [objectViewController delegate];
					
					if ([delegate respondsToSelector:@selector(objectViewController:badgeForObject:)])
					{			
						[layer addSublayer:
						 [self imb_layerWithBadge:[delegate objectViewController:objectViewController badgeForObject:item]
										   inRect:relativeImageFrame]];
					}
				}
				break;
				
            default:
                break;
        }
        
		return layer;
	}
	
	/* selection layer */
	if(type == IKImageBrowserCellSelectionLayer){
		
		return nil;
		
		//create a selection layer
		CALayer *selectionLayer = [CALayer layer];
		selectionLayer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
		
		CGFloat fillComponents[4] = {1.0, 0, 0.5, 0.3};
		CGFloat strokeComponents[4] = {1.0, 0.0, 0.5, 1.0};
		
		//set a background color
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		color = CGColorCreate(colorSpace, fillComponents);
		[selectionLayer setBackgroundColor:color];
		CFRelease(color);
		
		//set a border color
		color = CGColorCreate(colorSpace, strokeComponents);
		[selectionLayer setBorderColor:color];
		CFRelease(color);
		
		[selectionLayer setBorderWidth:2.0];
		[selectionLayer setCornerRadius:5];
		
		return selectionLayer;
	}
	
	/* background layer */
	if(type == IKImageBrowserCellBackgroundLayer)
	{
		//return nil;
		
		//no background layer on place holders
		if([self cellState] != IKImageStateReady)
			return nil;
		
		CALayer *layer = [CALayer layer];
		layer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
		
//		NSRect backgroundRect = NSMakeRect(0, 0, frame.size.width, frame.size.height);		
//		
//		CALayer *photoBackgroundLayer = [CALayer layer];
//		photoBackgroundLayer.frame = *(CGRect*) &backgroundRect;
//		
//		CGFloat fillComponents[4] = {0.95, 0.95, 0.95, 1.0};
//		CGFloat strokeComponents[4] = {0.2, 0.2, 0.2, 0.5};
//		
//		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//		
//		color = CGColorCreate(colorSpace, fillComponents);
//		[photoBackgroundLayer setBackgroundColor:color];
//		CFRelease(color);
//		
//		color = CGColorCreate(colorSpace, strokeComponents);
//		[photoBackgroundLayer setBorderColor:color];
//		CFRelease(color);
//		
//		[photoBackgroundLayer setBorderWidth:5.0];
//		[photoBackgroundLayer setShadowOpacity:0.5];
//		[photoBackgroundLayer setCornerRadius:3];
//		
//		CFRelease(colorSpace);
//		
//		[layer addSublayer:photoBackgroundLayer];
		
		return layer;
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Helpers

// Returns a layer that displays inBadge in the lower right corner relative to inRect

- (CALayer *)imb_layerWithBadge:(CGImageRef)inBadge inRect:(NSRect)inRect
{
    CALayer *badgeLayer = nil;
    if (inBadge)
    {
        badgeLayer = [CALayer layer];
        [badgeLayer setContents:(id)inBadge];
        
        NSUInteger squareSize = 18;
        badgeLayer.frame = CGRectMake(inRect.origin.x + inRect.size.width - squareSize - 3,
                                      inRect.origin.y + 3,
                                      squareSize,
                                      squareSize);
    }
    return badgeLayer;
}

//----------------------------------------------------------------------------------------------------------------------


@end

