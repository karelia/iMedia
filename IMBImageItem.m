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


// Author: Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#import "IMBImageItem.h"
#import <Quartz/Quartz.h>


@implementation NSImage (IMBImageItem)

+ (NSImage *)imageWithIMBImageItem:(id <IMBImageItem>)item;
{
    NSImage *result = nil;
    
    NSString *type = [item imageRepresentationType];
    
    // Already in the right format (CGImage)
	
	if ([type isEqualToString:IKImageBrowserNSImageRepresentationType])
    {
        result = [item imageRepresentation];
    }
    
    // From URL, path or data
	
	else if ([type isEqualToString:IKImageBrowserNSURLRepresentationType])
    {
        NSURL *url = [item imageRepresentation];
        result = [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
    }
    else if ([type isEqualToString:IKImageBrowserPathRepresentationType])
    {
        NSString *path = [item imageRepresentation];
        result = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    }
    else if ([type isEqualToString:IKImageBrowserNSDataRepresentationType])
    {
        NSData *data = [item imageRepresentation];
        result = [[[NSImage alloc] initWithData:data] autorelease];
    }
    
    return result;
}

@end


#pragma mark -


@implementation CIImage (IMBImageItem)

+ (CIImage *)imageWithIMBImageItem:(id <IMBImageItem>)item;
{
    CIImage *result = nil;
    
    NSString *type = [item imageRepresentationType];
    
    // From URL, path or data
	
	if ([type isEqualToString:IKImageBrowserNSURLRepresentationType])
    {
        NSURL *url = [item imageRepresentation];
        result = [[[CIImage alloc] initWithContentsOfURL:url] autorelease];
    }
    else if ([type isEqualToString:IKImageBrowserPathRepresentationType])
    {
        NSString *path = [item imageRepresentation];
        result = [[CIImage alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
        [result autorelease];
    }
    else if ([type isEqualToString:IKImageBrowserNSDataRepresentationType])
    {
        NSData *data = [item imageRepresentation];
        result = [[[CIImage alloc] initWithData:data] autorelease];
    }
    
    return result;
}

@end


#pragma mark -


CGImageRef IMB_CGImageCreateWithImageItem(id <IMBImageItem> item)
{
    CGImageRef result = NULL;
    
    NSString *type = [item imageRepresentationType];
    
    // Already in the right format (CGImage)
	
	if ([type isEqualToString:IKImageBrowserCGImageRepresentationType])
    {
        result = (CGImageRef)[item imageRepresentation];
        CGImageRetain(result);
    }
        
    else if ([type isEqualToString:IKImageBrowserQTMovieRepresentationType])
	{
		// A URL or path

		NSLog(@"Really don't want to try to make a thumbnail from a QTMovie since that may take a while.");
	}
	
    // Draw the thumbnail image (CGImageSource-compatible)...
	
	else
	{
		CGImageSourceRef source = IMB_CGImageSourceCreateWithImageItem(item, NULL);
		
		if (source)
		{
			result = CGImageSourceCreateImageAtIndex(source,0,NULL);
			CFRelease(source);
		}
	}
    
	return result;
}

CGImageSourceRef IMB_CGImageSourceCreateWithImageItem(id <IMBImageItem> item, CFDictionaryRef options)
{
    CGImageSourceRef result = NULL;
    
    NSString *type = [item imageRepresentationType];
    if ([type isEqualToString:IKImageBrowserNSURLRepresentationType])
    {
        NSURL *url = [item imageRepresentation];
		NSCAssert((id)url, @"Nil image source URL");
        result = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
    }
    else if ([type isEqualToString:IKImageBrowserPathRepresentationType])
    {
        NSString *path = [item imageRepresentation];
		NSCAssert((id)path, @"Nil image source URL");
        result = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:path], NULL);
    }
    else if ([type isEqualToString:IKImageBrowserNSDataRepresentationType])
    {
        NSData *data = [item imageRepresentation];
        result = CGImageSourceCreateWithData((CFDataRef)data,NULL);
    }	
    
    // Unsupported imageRepresentation...
    
    else
    {
        NSLog(@"%s: %@ is not supported by this cell class...",__FUNCTION__,type);
    }
    
    return result;
}

CGSize IMBImageItemGetSize(id <IMBImageItem> item)
{
    CGSize result = CGSizeZero;
    
	CIImage *image = [CIImage imageWithIMBImageItem:item];
    if (image)
    {
        result = [image extent].size;
    }
    else
    {
        NSImage *image = [NSImage imageWithIMBImageItem:item];
        if (image)
        {
            result = NSSizeToCGSize([image size]);
        }
	}
    
    return result;
}
