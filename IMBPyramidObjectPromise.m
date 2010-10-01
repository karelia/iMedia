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


// Author: Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBPyramidObjectPromise.h"

#import "IMBLightroomParser.h"
#import "NSFileManager+iMedia.h"
#import "NSData+SKExtensions.h"


// TODO: should subclassed methods be public?
@interface IMBObjectsPromise ()
- (void) _countObjects:(NSArray*)inObjects;
- (void) loadObjects:(NSArray*)inObjects;
- (void) _loadObject:(IMBObject*)inObject;
- (void) _didFinish;

@end

// This subclass is used for pyramid files that need to be split. The split file is saved to the local file system,
// where it can then be accessed by the delegate... 

#pragma mark

@implementation IMBPyramidObjectPromise

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
		const char pattern[3] = { 0xFF, 0xD8, 0xFF };
		NSUInteger index = [data lastIndexOfBytes:pattern length:3];
		
		// Should we cache that index?
		if (index != NSNotFound) {
			BOOL success = NO;
			NSData* jpegData = [data subdataWithRange:NSMakeRange(index, [data length] - index)];
			NSString* fileName = [[(NSString*)lightroomObject.location lastPathComponent] stringByDeletingPathExtension];
			NSString* jpegPath = [[[NSFileManager imb_threadSafeManager] imb_uniqueTemporaryFile:fileName] stringByAppendingPathExtension:@"jpg"];
			
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
@end
