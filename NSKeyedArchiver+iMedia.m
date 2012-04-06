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


//----------------------------------------------------------------------------------------------------------------------


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "NSKeyedArchiver+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation NSKeyedArchiver (iMedia)


// Convert the image to NSData and encode that as an object...

- (void) encodeCGImage:(CGImageRef)inImage forKey:(NSString*)inKey
{
	if (inImage != nil && inKey != nil)
	{
		NSMutableData* data = [NSMutableData data];
		CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)data,kUTTypeJPEG,1,NULL);
		
		if (dest)
		{
			NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithFloat:0.7],(id)kCGImageDestinationLossyCompressionQuality,
				nil];
				
			CGImageDestinationAddImage(dest,inImage,(CFDictionaryRef)options);
			CGImageDestinationFinalize(dest);
			CFRelease(dest);
		}
		
		[self encodeObject:data forKey:inKey];
	}
}


// If we do not have any representations, then add one before archiving the image...

- (void) encodeNSImage:(NSImage*)inImage forKey:(NSString*)inKey
{
	if ([[inImage representations] count] == 0)
	{
		NSData* tiff = [inImage TIFFRepresentation];
		NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:tiff];
		[inImage addRepresentation:bitmap];
	}
	
	[self encodeObject:inImage forKey:inKey];
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation NSKeyedUnarchiver (iMedia)


// Decode data blob and convert it to a CGImageRef...

- (CGImageRef) decodeCGImageForKey:(NSString*)inKey
{
	CGImageRef image = NULL;
	CGImageSourceRef source = NULL;
	NSData* data = [self decodeObjectForKey:inKey];
	
	if (data)
	{
		if ((source = CGImageSourceCreateWithData((CFDataRef)data,NULL)))
		{
			image = CGImageSourceCreateImageAtIndex(source,0,NULL);
			CFRelease(source);
		}
	}
	
	return image;
}


// Decode NSImage (as generic object) and typecast it...

- (NSImage*) decodeNSImageForKey:(NSString*)inKey
{
	return (NSImage*)[self decodeObjectForKey:inKey];
}

@end


//----------------------------------------------------------------------------------------------------------------------
