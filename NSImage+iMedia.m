/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>  

*/

#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"

@implementation NSImage (iMedia)

// Try to load an image out of the bundle for another application and if not found fallback to one of our own.
+ (NSImage *)imageResourceNamed:(NSString *)name fromApplication:(NSString *)bundleID fallbackTo:(NSString *)imageInOurBundle
{
	NSString *pathToOtherApp = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:bundleID];
	NSImage *image = nil;
	
	if (pathToOtherApp)
	{
		NSBundle *otherApp = [NSBundle bundleWithPath:pathToOtherApp];
		NSString *pathToImage = [otherApp pathForResource:[name stringByDeletingPathExtension] ofType:[name pathExtension]];
		image = [[NSImage alloc] initWithContentsOfFile:pathToImage];
	}
	
	if (!image)
	{
		NSBundle *ourBundle = [NSBundle bundleForClass:[self class]];
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
	source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
	if (source)
	{
		CFDictionaryRef propsCF = CGImageSourceCopyPropertiesAtIndex(source,  0,  NULL );
		NSDictionary *props = (NSDictionary *)propsCF;
		if (props)
		{
			NSMutableDictionary *md = [NSMutableDictionary dictionary];
			NSNumber *width = [NSNumber numberWithFloat:[[props objectForKey:(NSString *)kCGImagePropertyPixelWidth] floatValue]];
			NSNumber *height= [NSNumber numberWithFloat:[[props objectForKey:(NSString *)kCGImagePropertyPixelHeight] floatValue]];
			if (width) [md setObject:width forKey:@"width"];
			if (height) [md setObject:height forKey:@"height"];
			NSDictionary *exif = [props objectForKey:(NSString *)kCGImagePropertyExifDictionary];
			if ( nil != exif )
			{
				NSString *dateTime = [exif objectForKey:(NSString *)kCGImagePropertyExifDateTimeOriginal];
				// format from EXIF -- we could convert to a date and make more localized....
				if (nil != dateTime)
				{
					NSString *displayDate = [dateTime exifDateToLocalizedDisplayDate];
					if (displayDate)
					{
						[md setObject: forKey:@"dateTimeLocalized"];
					}
				}
			}
			CFRelease(props);
			result = [NSDictionary dictionaryWithDictionary:md];
		}
		CFRelease(source);
	}
	return [NSDictionary dictionaryWithDictionary:result];
}

@end

