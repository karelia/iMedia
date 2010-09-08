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


// Author: Unknown


#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "IMBNode.h"

@implementation NSImage (iMedia)

// Actually ignore the mime type, but maybe later we can use it as a hint
+ (NSImage *) imageWithData:(NSData *)aData mimeType:(NSString *)aMimeType;
{
	return [[[NSImage alloc] initWithData:aData] autorelease];
}


// Try to load an image out of the bundle for another application and if not found fallback to one of our own.
+ (NSImage *)imageResourceNamed:(NSString *)name fromApplication:(NSString *)bundleID fallbackTo:(NSString *)imageInOurBundle
{
	NSString *pathToOtherApp = [[NSWorkspace threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:bundleID];
	NSImage *image = nil;
	
	if (pathToOtherApp)
	{
		NSBundle *otherApp = [NSBundle bundleWithPath:pathToOtherApp];
		NSString *pathToImage = [otherApp pathForResource:[name stringByDeletingPathExtension] ofType:[name pathExtension]];
		image = [[NSImage alloc] initWithContentsOfFile:pathToImage];
	}
	
	if (image==nil && imageInOurBundle!=nil)
	{
		NSBundle *ourBundle = [NSBundle bundleForClass:[IMBNode class]];		// iMedia bundle
		NSString *pathToImage = [ourBundle pathForResource:[imageInOurBundle stringByDeletingPathExtension] ofType:[imageInOurBundle pathExtension]];
		image = [[NSImage alloc] initWithContentsOfFile:pathToImage];
	}
	return [image autorelease];
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

// Return a dictionary with these properties: width (NSNumber), height (NSNumber), dateTimeLocalized (NSString)
+ (NSDictionary *)metadataFromImageAtPath:(NSString *)aPath;
{
	NSDictionary *result = nil;
	CGImageSourceRef source = nil;
	NSURL *url = [NSURL fileURLWithPath:aPath];
	NSAssert(url, @"Nil image source URL");
	source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
	if (source)
	{
		CFDictionaryRef propsCF = CGImageSourceCopyPropertiesAtIndex(source,  0,  NULL );
		if (propsCF)
		{
			NSDictionary *props = (NSDictionary *)propsCF;
			NSMutableDictionary *md = [NSMutableDictionary dictionary];
			NSNumber *width = (NSNumber*) [props objectForKey:(NSString *)kCGImagePropertyPixelWidth];
			NSNumber *height= (NSNumber*) [props objectForKey:(NSString *)kCGImagePropertyPixelHeight];
			NSNumber *depth = (NSNumber*) [props objectForKey:(NSString *)kCGImagePropertyDepth];
			NSString *model = [props objectForKey:(NSString *)kCGImagePropertyColorModel];
			NSString *filetype = [[aPath pathExtension] uppercaseString];
			if (width) [md setObject:width forKey:@"width"];
			if (height) [md setObject:height forKey:@"height"];
			if (depth) [md setObject:depth forKey:@"depth"];
			if (model) [md setObject:model forKey:@"model"];
			if (filetype) [md setObject:filetype forKey:@"filetype"];
			NSDictionary *exif = [props objectForKey:(NSString *)kCGImagePropertyExifDictionary];
			if ( nil != exif )
			{
				NSString *dateTime = [exif objectForKey:(NSString *)kCGImagePropertyExifDateTimeOriginal];
				// format from EXIF -- we could convert to a date and make more localized....
				if (nil != dateTime)
				{
					[md setObject:dateTime forKey:@"dateTime"];
				}
			}
			result = [NSDictionary dictionaryWithDictionary:md];
			CFRelease(propsCF);
		}
		CFRelease(source);
	}
	return result;
}


+ (NSString*) imageMetadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	NSString* description = @"";
	NSNumber* width = [inMetadata objectForKey:@"width"];
	NSNumber* height = [inMetadata objectForKey:@"height"];
	NSNumber* depth = [inMetadata objectForKey:@"depth"];
	NSNumber* model = [inMetadata objectForKey:@"model"];
	NSString* type = [inMetadata objectForKey:@"ImageType"];
	NSString* filetype = [inMetadata objectForKey:@"filetype"];
	NSString* dateTime = [inMetadata objectForKey:@"dateTime"];
	
	if (width != nil && height != nil)
	{
		NSString* size = NSLocalizedStringWithDefaultValue(
				@"Size",
				nil,IMBBundle(),
				@"Size",
				@"Size label in metadataDescription");
		
		description = [description stringByAppendingFormat:@"%@: %@x%@\n",size,width,height];
	}
	
	if (depth != nil || model != nil || type != nil)
	{
		NSString* typeLabel = NSLocalizedStringWithDefaultValue(
				@"Type",
				nil,IMBBundle(),
				@"Type",
				@"Type label in metadataDescription");
		
		description = [description stringByAppendingFormat:@"%@: ",typeLabel];
		if (depth) description = [description stringByAppendingFormat:@"%@bit ",depth];
		if (model) description = [description stringByAppendingFormat:@"%@ ",model];
		if (type) description = [description stringByAppendingFormat:@"%@",type];
		else if (filetype) description = [description stringByAppendingFormat:@"%@",filetype];
		description = [description stringByAppendingFormat:@"\n"];
	}
	
	if (dateTime != nil)
	{
		NSString* dateLabel = NSLocalizedStringWithDefaultValue(
				@"Date",
				nil,IMBBundle(),
				@"Date",
				@"Date label in metadataDescription");
		
		description = [description stringByAppendingFormat:@"%@: %@\n",dateLabel,[dateTime exifDateToLocalizedDisplayDate]];
	}
	
	return description;
}


+ (NSImage *) sharedGenericFolderIcon
{
	static NSImage *sGenericFolderIcon = nil;
	
	if (sGenericFolderIcon == nil)
	{
		sGenericFolderIcon = [[[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kGenericFolderIcon)] retain];
		[sGenericFolderIcon setScalesWhenResized:YES];
		[sGenericFolderIcon setSize:NSMakeSize(16,16)];
	}
	
	if (sGenericFolderIcon == nil)
	{
		sGenericFolderIcon = [NSImage imageNamed:@"folder"];	// NSImageNameFolder in 10.6 and up... does it work in 10.5 ?
	}
	
	return sGenericFolderIcon;
}


+ (NSImage *) genericFolderIcon
{
	return [[[self sharedGenericFolderIcon] copy] autorelease];
}


- (NSImage *) imageCroppedToRect:(NSRect)inCropRect
{
	NSRect dstRect = NSZeroRect;
	dstRect.size = self.size;
	dstRect.origin.x = -inCropRect.origin.x;
	dstRect.origin.y = -inCropRect.origin.y;
	
	NSImage *croppedImage = [[[NSImage alloc] initWithSize:inCropRect.size] autorelease];
	[croppedImage lockFocus];
	[self drawAtPoint:dstRect.origin fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	[croppedImage unlockFocus];
	
	return croppedImage;
}


@end

