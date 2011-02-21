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


// Author: Dan Wood


#import "NSURL+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import <QuickLook/QuickLook.h>

@implementation NSURL (imedia)

// Quicklook methods to create images from non-image files...
// (Should be called on a background thread.)

- (CGImageRef) imb_quicklookCGImageIfAvailable
{
	if ([NSThread isMainThread])
	{
		NSLog(@"%s is being called on main thread. We probably want to re-do this for background thread", __FUNCTION__);
	}
	
	CGSize size = CGSizeMake(kIMBMaxThumbnailSize,kIMBMaxThumbnailSize);
	CGImageRef image = QLThumbnailImageCreate(kCFAllocatorDefault,(CFURLRef)self,size,NULL);
	return (CGImageRef) [NSMakeCollectable(image) autorelease];
}

- (CGImageRef) imb_quicklookCGImage
{
	CGImageRef result = [self imb_quicklookCGImageIfAvailable];
	if (!result)
	{
		// In 10.5, we often get a nil
		NSString *path = [self path];
		NSImage *icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:path];	// Don't worry about size
		// Now get this into a CGImageRef.  Not the most efficient implementation, though.
		NSData * imageData = [icon TIFFRepresentation];
		CGImageRef imageRef = nil;
		if(imageData)
		{
			CGImageSourceRef imageSource = 
			CGImageSourceCreateWithData((CFDataRef)imageData,  NULL);
			if (imageSource)
			{
				imageRef = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
				imageRef = (CGImageRef) [NSMakeCollectable(imageRef) autorelease];

				CFRelease(imageSource);
			}
		}
		return imageRef;
	}
	return result;
}


- (NSImage*) imb_quicklookNSImage
{
	NSImage* nsimage = nil;
	CGImageRef cgimage = [self imb_quicklookCGImageIfAvailable];
	
	if (cgimage)
	{
		NSSize size = NSZeroSize;
		size.width = CGImageGetWidth(cgimage);
		size.height = CGImageGetWidth(cgimage);
		
		nsimage = [[[NSImage alloc] initWithSize:size] autorelease];
		
		NSBitmapImageRep* rep = [[NSBitmapImageRep alloc] initWithCGImage:cgimage];
		[nsimage addRepresentation:rep];		
		[rep release];
	}
	else
	{
		// In 10.5, we often get a nil
		NSString *path = [self path];
		nsimage = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:path];	// Don't worry about size
	}
	return nsimage;
}

+ (NSDictionary *)imb_metadataFromVideoAtURL:(NSURL*)inURL
{
	if (![inURL isFileURL]) {
		return nil;
	}
	
	NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
	
	[metadata setObject:[inURL path] forKey:@"path"];

	MDItemRef item = MDItemCreateWithURL(NULL,(CFURLRef)inURL); 
	
//	NSLog(@"%@", [NSMakeCollectable(MDItemCopyAttributeNames(item)) autorelease]);
	
	if (item)
	{
		CFNumberRef seconds = MDItemCopyAttribute(item,kMDItemDurationSeconds);
		CFNumberRef width = MDItemCopyAttribute(item,kMDItemPixelWidth);
		CFNumberRef height = MDItemCopyAttribute(item,kMDItemPixelHeight);
		
		if (seconds)
		{
			[metadata setObject:(NSNumber*)seconds forKey:@"duration"]; 
			CFRelease(seconds);
		}
		
		if (width)
		{
			[metadata setObject:(NSNumber*)width forKey:@"width"]; 
			CFRelease(width);
		}
		
		if (height)
		{
			[metadata setObject:(NSNumber*)height forKey:@"height"]; 
			CFRelease(height);
		}
		
		CFRelease(item);
	}
	else
	{
		//		NSLog(@"Nil from MDItemCreate for %@ exists?%d", inPath, [[NSFileManager imb_threadSafeManager] fileExistsAtPath:inPath]);
	}
	
	return metadata;
}

+ (NSDictionary *)imb_metadataFromAudioAtURL:(NSURL*)inURL
{
	if (![inURL isFileURL]) {
		return nil;
	}
	
	NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
	
	[metadata setObject:[inURL path] forKey:@"path"];
	
	MDItemRef item = MDItemCreateWithURL(NULL,(CFURLRef)inURL); 
	
//	NSLog(@"%@", [NSMakeCollectable(MDItemCopyAttributeNames(item)) autorelease]);

	if (item)
	{
		CFNumberRef seconds = MDItemCopyAttribute(item,kMDItemDurationSeconds);
		CFArrayRef authors = MDItemCopyAttribute(item,kMDItemAuthors);
		CFStringRef album = MDItemCopyAttribute(item,kMDItemAlbum);
		CFStringRef comment = MDItemCopyAttribute(item,kMDItemFinderComment);
		
		if (seconds)
		{
			[metadata setObject:(NSNumber*)seconds forKey:@"duration"]; 
			CFRelease(seconds);
		}
		else
		{
			NSSound* sound = [[NSSound alloc] initWithContentsOfURL:inURL byReference:YES];
			[metadata setObject:[NSNumber numberWithDouble:sound.duration] forKey:@"duration"]; 
			[sound release];
		}
		
		if (authors)
		{
			NSArray* artists = (NSArray*)authors;
			if (artists.count > 0) [metadata setObject:[artists objectAtIndex:0] forKey:@"artist"]; 
			CFRelease(authors);
		}
		
		if (album)
		{
			[metadata setObject:(NSString*)album forKey:@"album"]; 
			CFRelease(album);
		}
		
		if (comment)
		{
			[metadata setObject:(NSString*)comment forKey:@"comment"]; 
			CFRelease(comment);
		}
		
		CFRelease(item);
	}
	else
	{
		//		NSLog(@"Nil from MDItemCreate for %@ exists?%d", inPath, [[NSFileManager imb_threadSafeManager] fileExistsAtPath:inPath]);
	}
	
	return metadata;
}

@end
