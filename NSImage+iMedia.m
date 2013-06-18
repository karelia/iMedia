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


// Author: Unknown


#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "IMBNode.h"

@interface NSBundle (SDK_10_7)

- (NSImage *)imageForResource:(NSString *)name;

@end

@implementation NSImage (iMedia)

// Actually ignore the mime type, but maybe later we can use it as a hint
+ (NSImage *) imb_imageWithData:(NSData *)aData mimeType:(NSString *)aMimeType;
{
	return [[[NSImage alloc] initWithData:aData] autorelease];
}


// Try to load an image out of the bundle for another application and if not found fallback to one of our own.
+ (NSImage *)imb_imageForResource:(NSString *)name fromAppWithBundleIdentifier:(NSString *)bundleID fallbackName:(NSString *)imageInOurBundle
{
	NSString *pathToOtherApp = [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:bundleID];
	NSImage *image = nil;
	
	if (pathToOtherApp)
	{
		NSBundle *appBundle = [NSBundle bundleWithPath:pathToOtherApp];
        
        // SANDBOXING: To my shock, this continues to work when sandboxed (at least on 10.8). Why would Apple allow us to access other apps' resources? I tested and this seems to work regardless of what the app is named or where it is placed
        
        // Use imageForResource: if available to take advantage of possibly additionally available high res representations
        
        if ([appBundle respondsToSelector:@selector(imageForResource:)])
        {
            image = [appBundle imageForResource:name];
        } else {
            NSURL *imageURL = [appBundle URLForImageResource:name];
            image = [[[NSImage alloc] initWithContentsOfURL:imageURL] autorelease];
        }
	}
	
	if (image==nil && imageInOurBundle!=nil)
	{
		NSBundle *ourBundle = [NSBundle bundleForClass:[IMBNode class]];		// iMedia bundle
        if ([ourBundle respondsToSelector:@selector(imageForResource:)])
        {
            image = [ourBundle imageForResource:imageInOurBundle];
        }
        else
        {
            NSURL *imageURL = [ourBundle URLForImageResource:imageInOurBundle];
            image = [[[NSImage alloc] initWithContentsOfURL:imageURL] autorelease];
        }
	}
	return image;
}

// Return a dictionary with these properties: width (NSNumber), height (NSNumber), dateTimeLocalized (NSString)
+ (NSDictionary *)imb_metadataFromImageAtPath:(NSString *)aPath checkSpotlightComments:(BOOL)aCheckSpotlight;
{
	NSDictionary *result = nil;
	NSURL *url = [NSURL fileURLWithPath:aPath];
	
	if (url)
	{
		CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
		NSMutableDictionary *md = [NSMutableDictionary dictionary];
		
		if (source)
		{
			CGImageSourceStatus status = CGImageSourceGetStatus(source);

			if (status == kCGImageStatusComplete) {
				CFDictionaryRef propsCF = CGImageSourceCopyPropertiesAtIndex(source,  0,  NULL );
				if (propsCF)
				{
					NSDictionary *props = (NSDictionary *)propsCF;
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
					[md setObject:aPath forKey:@"path"];

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
					CFRelease(propsCF);
				}
			}
			CFRelease(source);
		}
		
		if (aCheckSpotlight)	// done from folder parsers, but not library-based items like iPhoto
		{
			MDItemRef item = MDItemCreate(NULL,(CFStringRef)aPath);
			
			if (item)
			{
				CFStringRef comment = MDItemCopyAttribute(item,kMDItemFinderComment);
				if (comment)
				{
					[md setObject:(NSString*)comment forKey:@"comment"]; 
					CFRelease(comment);
				}
				CFRelease(item);
			}
		}
			
		result = [NSDictionary dictionaryWithDictionary:md];
	}
	
	return result;
}


+ (NSString*) imb_imageMetadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	NSMutableString* metaDesc = [NSMutableString string];
	NSNumber* width = [inMetadata objectForKey:@"width"];
	NSNumber* height = [inMetadata objectForKey:@"height"];
	NSNumber* depth = [inMetadata objectForKey:@"depth"];
	NSNumber* model = [inMetadata objectForKey:@"model"];
	NSString* type = [inMetadata objectForKey:@"ImageType"];
	NSString* filetype = [inMetadata objectForKey:@"filetype"];
	NSString* dateTime = [inMetadata objectForKey:@"dateTime"];
	NSString* path = [inMetadata objectForKey:@"path"];
	NSString* comment = [inMetadata objectForKey:@"comment"];
	NSArray* keywords = [inMetadata objectForKey:@"iMediaKeywords"];
	NSInteger rating = [[inMetadata objectForKey:@"Rating"] integerValue];

	if (comment == nil) comment = [inMetadata objectForKey:@"Comment"];	// uppercase from iPhoto
	if (comment) comment = [comment stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if ((width != nil && height != nil) || depth != nil || model != nil || type != nil)
	{		
		if (metaDesc.length > 0) [metaDesc imb_appendNewline];
		
		if (depth) [metaDesc appendFormat:@"%@-bit ",depth];		// TODO: LOCALIZE
		if (model) [metaDesc appendFormat:@"%@ ",model];
		
		if (type)
		{
			NSString *UTI = [NSString imb_UTIForFileType:type];
			NSString *descUTI = [NSString imb_descriptionForUTI:UTI];
			if (descUTI)
			{
				[metaDesc appendFormat:@"%@",descUTI];
			}
		}
		else if (path)
		{
			NSString *UTI = [NSString imb_UTIForFileAtPath:path];
			NSString *descUTI = [NSString imb_descriptionForUTI:UTI];
			if (descUTI)
			{
				[metaDesc appendFormat:@"%@",descUTI];
			}
		}
		else if (filetype)
		{
			NSString *UTI = [NSString imb_UTIForFilenameExtension:filetype];
			NSString *descUTI = [NSString imb_descriptionForUTI:UTI];
			if (descUTI)
			{
				[metaDesc appendFormat:@"%@",descUTI];
			}
		}
	}

	if (width != nil && height != nil)
	{
		if (metaDesc.length > 0) [metaDesc imb_appendNewline];
		[metaDesc appendFormat:@"%@×%@",width,height];
	}
	
	if (dateTime != nil)
	{
		NSString *dateTimeDesc = [dateTime imb_exifDateToLocalizedDisplayDate];
		if (dateTimeDesc)
		{
			if (metaDesc.length > 0) [metaDesc imb_appendNewline];
			[metaDesc appendString:dateTimeDesc];
		}
	}
	
	if (keywords != nil && [keywords count])
	{
		[metaDesc imb_appendNewline];
		for (NSString *keyword in keywords)
		{
			[metaDesc appendFormat:@"%@, ", keyword];
		}
		[metaDesc deleteCharactersInRange:NSMakeRange([metaDesc length] - 2, 2)];	// remove last comma+space
	}
	
	if (rating > 0)
	{
		[metaDesc imb_appendNewline];
		[metaDesc appendString:[NSString imb_stringFromStarRating:rating]];
	}

	if (comment != nil && ![comment isEqualToString:@""])
	{
		NSString* commentLabel = NSLocalizedStringWithDefaultValue(
																   @"Comment",
																   nil,IMBBundle(),
																   @"Comment",
																   @"Comment label in metadataDescription");
		
		if (metaDesc.length > 0) [metaDesc imb_appendNewline];
		[metaDesc appendFormat:@"%@: %@",commentLabel,comment];
	}
	
	return metaDesc;
}


+ (NSImage *) imb_sharedGenericFolderIcon
{
	static NSImage *sGenericFolderIcon = nil;
	
	if (sGenericFolderIcon == nil)
	{
		sGenericFolderIcon = [[[NSWorkspace imb_threadSafeWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kGenericFolderIcon)] retain];
		[sGenericFolderIcon setScalesWhenResized:YES];
		[sGenericFolderIcon setSize:NSMakeSize(16,16)];
	}
	
	if (sGenericFolderIcon == nil)
	{
		sGenericFolderIcon = [NSImage imageNamed:@"folder"];	// NSImageNameFolder in 10.6 and up... does it work in 10.5 ?
	}
	
	return sGenericFolderIcon;
}

+ (NSImage *) imb_sharedGenericFileIcon
{
	static NSImage *sGenericFileIcon = nil;
	
	if (sGenericFileIcon == nil)
	{
		sGenericFileIcon = [[[NSWorkspace imb_threadSafeWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kGenericDocumentIcon)] retain];
		[sGenericFileIcon setScalesWhenResized:YES];
		[sGenericFileIcon setSize:NSMakeSize(16,16)];
	}

	return sGenericFileIcon;
}


+ (NSImage *) imb_genericFolderIcon
{
	return [[[self imb_sharedGenericFolderIcon] copy] autorelease];
}


- (NSImage *) imb_imageCroppedToRect:(NSRect)inCropRect
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


// returns nil if no bitmap associated.

- (NSBitmapImageRep *) imb_firstBitmap	
{
	NSBitmapImageRep *result = nil;
	NSArray *reps = [self representations];
    
	for (NSImageRep *theRep in reps )
	{
		if ([theRep isKindOfClass:[NSBitmapImageRep class]])
		{
			result = (NSBitmapImageRep *)theRep;
			break;
		}
	}
	return result;
}


// returns bitmap, or creates one.

- (NSBitmapImageRep *) imb_bitmap	
{
	NSBitmapImageRep *result = [self imb_firstBitmap];
    
	if (nil == result)	
	{
		NSInteger width, height;
		NSSize sz = [self size];
		width = sz.width;
		height = sz.height;
		[self lockFocus];
		result = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, (CGFloat)width, (CGFloat)height)] autorelease];
		[self unlockFocus];
	}
	
	return result;
}


@end

