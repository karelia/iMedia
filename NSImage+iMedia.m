//
//  NSImage+iMedia.m
//  iMediaBrowse
//
//  Created by Greg Hulands on 4/05/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"

@implementation NSImage (iMedia)

// Try to load an image out of the bundle for another application and if not found fallback to one of our own.
+ (NSImage *)imageResourceNamed:(NSString *)name fromApplication:(NSString *)bundleID fallbackTo:(NSString *)imageInOurBundle
{
	NSString *pathToOtherApp = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:bundleID];
	if (pathToOtherApp)
	{
		NSBundle *otherApp = [NSBundle bundleWithPath:pathToOtherApp];
		NSString *pathToImage = [otherApp pathForResource:[name stringByDeletingPathExtension] ofType:[name pathExtension]];
		NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathToImage];
		return [image autorelease];
	}
	else
	{
		NSBundle *ourBundle = [NSBundle bundleForClass:[self class]];
		NSString *pathToImage = [ourBundle pathForResource:[imageInOurBundle stringByDeletingPathExtension] ofType:[imageInOurBundle pathExtension]];
		NSImage *image = [[NSImage alloc] initWithContentsOfFile:pathToImage];
		return [image autorelease];
	}
}

+ (NSImage *)imageFromFirefoxEmbeddedIcon:(NSString *)base64WithMime
{
	//need to strip the mime bit - data:image/x-icon;base64,
	NSRange r = [base64WithMime rangeOfString:@"data:image/x-icon;base64,"];
	NSString *base64 = [base64WithMime substringFromIndex:NSMaxRange(r)];
	NSData *decoded = [base64 decodeBase64];
	NSImage *img = [[NSImage alloc] initWithData:decoded];
	return [img autorelease];
}

@end

