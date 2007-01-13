//
//  EpegWrapper.m
//  Epeg
//
//  Created by Marc Liyanage on Fri Jan 16 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "EpegWrapper.h"
#include "Epeg.h"


@implementation EpegWrapper

+ (NSImage *)imageWithPath:(NSString *)path boundingBox:(NSSize)boundingBox 
{
	Epeg_Image *im = NULL;
	NSImage *image;
	int width_in, height_in;

	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory, exists;
	exists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory];
	if (!exists) {
		NSLog(@"invalid path '%@' passed, does not exist:", path);
		[self release];
		return nil;
	}
	if (isDirectory) {
		NSLog(@"invalid path '%@' passed; it's a directory:", path);
		[self release];
		return nil;
	}
	
	im = epeg_file_open([path UTF8String]);
	if (!im) {
		NSLog(@"unable to create epeg image for path '%@'", path);
		[self release];
		return nil;
	}

	epeg_size_get(im, &width_in, &height_in);

	float bbox_ratio = (float)(boundingBox.width / boundingBox.height);
	float orig_ratio = ((float)width_in / (float)height_in);

	float scalefactor;
	scalefactor =
		(orig_ratio > bbox_ratio)
		? (float)(boundingBox.width / width_in)
		: (float)(boundingBox.height / height_in);

	int width_out = (int)((float)width_in * scalefactor);
	int height_out = (int)((float)height_in * scalefactor);

	epeg_decode_size_set(im, width_out, height_out);
	int cs;
	epeg_colorspace_get(im, &cs);
	if (cs == EPEG_CMYK) return nil; // epeg doesn't handle cmyk properly... they turn out to be a negative version
	epeg_decode_colorspace_set(im, cs);

	unsigned char *outbuffer;
	int outsize = 0;
	epeg_memory_output_set(im, &outbuffer, &outsize);
	epeg_quality_set(im, 90);
	epeg_encode(im);
	epeg_close(im);

	if (!outsize) {
		NSLog(@"unable to create image");
		return nil;
	}
	
	NSData *data = [NSData dataWithBytesNoCopy:outbuffer length:outsize];
	image = [[[NSImage alloc] initWithData:data] autorelease];
	
	if (!image) {
		NSLog(@"unable to create image");
		return nil;
	}
	
	return image;
}

// This creates broken, cropped output. Still figuring out why.
// It would be faster because it uses the raw RGB pixel data instead
// of an intermediate in-memory JPEG image.
//
+ (NSImage *)imageWithPath2:(NSString *)path boundingBox:(NSSize)boundingBox {
	
	Epeg_Image *im;
	NSImage *image;
	
	void *pixels = NULL, *destbuffer = NULL;
	int width_in, height_in;
	
	im = NULL;
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory, exists;
	exists = [fileManager fileExistsAtPath:path isDirectory:&isDirectory];
	if (!exists || isDirectory) {
		NSLog(@"invalid path '%@' passed", path);
		[self release];
		return nil;
	}
	
	im = epeg_file_open([path UTF8String]);
	if (!im) {
		NSLog(@"unable to create epeg image for path '%@'", path);
		[self release];
		return nil;
	}
	
	epeg_size_get(im, &width_in, &height_in);
	//	NSLog(@"bbox x %f, bbox y %f", boundingBox.width, boundingBox.height);
	
	float bbox_ratio = (float)(boundingBox.width / boundingBox.height);
	float orig_ratio = (float)((float)width_in / (float)height_in);
	//	NSLog(@"bbox ratio: %f, orig_ratio: %f", bbox_ratio, orig_ratio);
	
	float scalefactor;
	scalefactor =
		(orig_ratio > bbox_ratio)
		? (float)(boundingBox.width / width_in)
		: (float)(boundingBox.height / height_in);
	//	NSLog(@"scale %f", scalefactor);
	
	int width_out = (int)((float)width_in * scalefactor);
	int height_out = (int)((float)height_in * scalefactor);
	
	//	NSLog(@"x in %d, y in %d / x out %d, y out %d", width_in, height_in, width_out, height_out);
	
	epeg_decode_size_set(im, width_out, height_out);
	epeg_decode_colorspace_set(im, EPEG_RGB8);
	
	pixels = (unsigned char *)epeg_pixels_get(im, 0, 0, width_out, height_out);
	NSBitmapImageRep *imageRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width_out pixelsHigh:height_out bitsPerSample:8 samplesPerPixel:3 hasAlpha:NO isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
	
	destbuffer = [imageRep bitmapData];
	memcpy(destbuffer, pixels, (width_out * height_out * 3));
	epeg_pixels_free(im, pixels);
	image = [[NSImage alloc] initWithSize:NSMakeSize(0.0, 0.0)];
	[image addRepresentation:imageRep];
	
	epeg_close(im);
	
	if (!image) {
		NSLog(@"unable to create image");
		return nil;
	}
	
	return image;
}

@end
