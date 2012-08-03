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


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBPyramidObjectPromise.h"
#import "IMBLightroom1Parser.h"
#import "IMBLightroom2Parser.h"
#import "IMBLightroom3Parser.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSData+SKExtensions.h"


// TODO: should subclassed methods be public?
@interface IMBObjectsPromise ()
- (void) _countObjects:(NSArray*)inObjects;
- (void) loadObjects:(NSArray*)inObjects;
- (void) _loadObject:(IMBObject*)inObject;
- (void) _didFinish;

@end


@interface IMBPyramidObjectPromise ()

+ (NSURL*) placeholderImageUrl;

@end


// This subclass is used for pyramid files that need to be split. The split file is saved to the local file system,
// where it can then be accessed by the delegate... 

#pragma mark

@implementation IMBPyramidObjectPromise


- (void) dealloc
{
	[super dealloc];
}


- (void) loadObjects:(NSArray*)inObjects
{
	[super loadObjects:inObjects];
	[self _didFinish];
}


- (void) _loadObject:(IMBObject*)inObject
{
	NSURL* imageURL = nil;
	
	if ([inObject isKindOfClass:[IMBLightroomObject class]]) {
		IMBLightroomObject* lightroomObject = (IMBLightroomObject*)inObject;
		
		imageURL = [IMBPyramidObjectPromise urlForObject:lightroomObject];

	}
	
	if (imageURL != nil) {
		[self setFileURL:imageURL error:nil forObject:inObject];
		_objectCountLoaded++;
	}
	else {
		[super _loadObject:inObject];
	}
}	

+ (NSURL*)urlForObject:(IMBLightroomObject*)lightroomObject
{
	NSString* imagePath = nil;
	NSString* absolutePyramidPath = [lightroomObject absolutePyramidPath];;
	
	if (absolutePyramidPath != nil) {
		NSString* orientation = [[lightroomObject preliminaryMetadata] objectForKey:@"orientation"];;
		NSData* data = [NSData dataWithContentsOfMappedFile:absolutePyramidPath];
		
		if (data == nil) {
			// We have a path, but there was no file at that path
			return [self placeholderImageUrl];
		}
		
		const char pattern[3] = { 0xFF, 0xD8, 0xFF };
		NSUInteger index = [data lastIndexOfBytes:pattern length:3];
		
		// Should we cache that index?
		if (index != NSNotFound) {
			BOOL success = NO;
			NSData* jpegData = [data subdataWithRange:NSMakeRange(index, [data length] - index)];
			NSString* fileName = [[lightroomObject.location lastPathComponent] stringByDeletingPathExtension];
            NSFileManager *fileManager = [[NSFileManager alloc] init];
			NSString* jpegPath = [[[fileManager imb_threadSafeManager] imb_uniqueTemporaryFile:fileName] stringByAppendingPathExtension:@"jpg"];
            [fileManager release];
			
			if ((orientation == nil) || [orientation isEqual:@"AB"]) {
				success = [jpegData writeToFile:jpegPath atomically:YES];
			}
			else {
				CGImageSourceRef jpegSource = CGImageSourceCreateWithData((CFDataRef)jpegData, NULL);
				
				if (jpegSource != NULL) {
					CGImageRef jpegImage = CGImageSourceCreateImageAtIndex(jpegSource, 0, NULL);
					
					if (jpegImage != NULL) {
						NSURL* fileURL = [NSURL fileURLWithPath:jpegPath];
						CGImageDestinationRef destination = CGImageDestinationCreateWithURL((CFURLRef)fileURL, (CFStringRef)@"public.jpeg", 1, nil);
						
						if (destination != NULL) {
							NSInteger orientationProperty = 2;
							
							if ([orientation isEqual:@"BC"]) {
								orientationProperty = 6;
							}
							else if ([orientation isEqual:@"CD"]) {
								orientationProperty = 4;
							}
							else if ([orientation isEqual:@"DA"]) {
								orientationProperty = 8;
							}
							else if ([orientation isEqual:@"CB"]) {
								orientationProperty = 5;
							}
							else if ([orientation isEqual:@"DC"]) {
								orientationProperty = 3;
							}
							else if ([orientation isEqual:@"AD"]) {
								orientationProperty = 7;
							}
							
							NSDictionary* metadata = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:orientationProperty]
																				 forKey:((NSString*)kCGImagePropertyOrientation)];
							CGImageDestinationAddImage(destination, jpegImage, (CFDictionaryRef)metadata);
							
							success = CGImageDestinationFinalize(destination);
							
							CFRelease(destination);
						}
						
						CGImageRelease(jpegImage);
					}
					
					CFRelease(jpegSource);
				}
			}
			
			if (success) {
				imagePath = jpegPath;
			}
		}
	}
	
	if (imagePath != nil) {
		return [NSURL fileURLWithPath:imagePath];
	}
	
	return nil;
}

+ (NSURL*) placeholderImageUrl
{
	static NSURL *placeholderImageUrl = nil;
	
	if (placeholderImageUrl != nil) {
		NSString *placeholderImagePath = [placeholderImageUrl path];
		NSFileManager *fm = [[[NSFileManager alloc] init] autorelease];

		if ([fm isReadableFileAtPath:placeholderImagePath]) {
			return placeholderImageUrl;
		}
	}
	
	NSString *message1 = NSLocalizedStringWithDefaultValue(
		@"IMB.IMBPyramidObjectPromise.PlaceholderMessage1",
		nil,
		IMBBundle(),
		@"Processed image not found.\n",
		@"Message to export when Pyramid file is missing");
														  
	NSString *message2 = NSLocalizedStringWithDefaultValue(
		@"IMB.IMBPyramidObjectPromise.PlaceholderMessage2",
		nil,
		IMBBundle(),
		@"Please launch Lightroom and select the menu command Library > Previews > Render 1:1 Previews.",
		@"Message to export when Pyramid file is missing");

	NSMutableParagraphStyle* style = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[style setAlignment:NSCenterTextAlignment];

	NSDictionary *attributes1 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:24.0],NSFontAttributeName, 
		[NSColor whiteColor],NSForegroundColorAttributeName,
		style,NSParagraphStyleAttributeName,
		nil];
								
	NSDictionary *attributes2 = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSFont boldSystemFontOfSize:16.0],NSFontAttributeName, 
		[NSColor grayColor],NSForegroundColorAttributeName,
		style,NSParagraphStyleAttributeName,
		nil];

	NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] 
		initWithString:message1 
		attributes:attributes1] 
		autorelease];

	[string appendAttributedString:[[[NSMutableAttributedString alloc] 
		initWithString:message2 
		attributes:attributes2] 
		autorelease]];
		
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSString *jpegPath = [[fm imb_uniqueTemporaryFile:@"LightroomPlaceholder"] stringByAppendingPathExtension:@"jpg"];
    [fm release];
    
	NSSize imageSize = NSMakeSize(640.0,480.0);
	NSRect imageBounds =  NSMakeRect(0.0,0.0,imageSize.width,imageSize.height);
	
	NSBitmapImageRep *bitmapImage = [[[NSBitmapImageRep alloc] 
		initWithBitmapDataPlanes:NULL 
		pixelsWide:imageSize.width 
		pixelsHigh:imageSize.height 
		bitsPerSample:8 
		samplesPerPixel:4 
		hasAlpha:YES 
		isPlanar:NO
		colorSpaceName:NSCalibratedRGBColorSpace 
		bytesPerRow:0 
		bitsPerPixel:0] autorelease];
	
	[NSGraphicsContext saveGraphicsState];
	NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapImage];
	[NSGraphicsContext setCurrentContext:nsContext];

	[[NSColor colorWithDeviceRed:0.1 green:0.1 blue:0.1 alpha:1.0] set];
	NSRectFill(imageBounds);
	
	NSString* lightroomPath = [IMBLightroom3Parser lightroomPath];
	if (lightroomPath == nil) lightroomPath = [IMBLightroom2Parser lightroomPath];
	if (lightroomPath == nil) lightroomPath = [IMBLightroom1Parser lightroomPath];
	if (lightroomPath)
	{
		NSImage* lightroomIcon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:lightroomPath];
		if (lightroomIcon)
		{
			NSRect lightroomRect = NSMakeRect(256.0,230.0,128.0,128.0);
			[lightroomIcon drawInRect:lightroomRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		}	
	}
	
	NSString* cautionPath = @"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns";
	NSImage* cautionIcon = [[[NSImage alloc] initWithContentsOfFile:cautionPath] autorelease];
	if (cautionIcon)
	{
		NSRect cautionRect = NSMakeRect(347.0,228.0,64.0,64.0);
		[cautionIcon drawInRect:cautionRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	
	NSRect stringRect = NSMakeRect(64.0,64.0,512.0,156.0);
	[string drawInRect:stringRect];
	
	[NSGraphicsContext restoreGraphicsState];

	NSData *data = [bitmapImage representationUsingType:NSJPEGFileType properties:nil];
	NSURL *url = [NSURL fileURLWithPath:jpegPath];
	BOOL status = [data writeToURL:url atomically:YES];
	
	
  	if (status == NO) {
		NSLog(@"%s Failed to write %@", __FUNCTION__, jpegPath);
		
		return nil;
	}
	
	[placeholderImageUrl release];
	placeholderImageUrl = [url retain];
	
	return url;
}

@end
