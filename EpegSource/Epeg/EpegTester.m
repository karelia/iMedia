//
//  EpegTester.m
//  Epeg
//
//  Created by Marc Liyanage on Fri Jan 16 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EpegWrapper.h"
#include <unistd.h>


extern char *optarg;
extern int optind;
extern int optopt;
extern int opterr;
extern int optreset;

void usage(const char *appName)
{
	printf("%s: [-v] [-t] [-r] [-z sizePixels] jpegfile [ jpegfile2 ... ]\n", appName);
	printf("v: verbose mode\n");
	printf("t: open temp files\n");
	printf("r: recurse into directories\n");
	printf("z: pixel size; default is 128 high or wide\n");
	
	// TODO: we could specify prefix and suffix, to allow files to be output with another name.  Or we could have an option for overwriting?
}

BOOL isJPEG(NSString *path)		// could be more sophisticated by checking for contents
{
	NSString *extension = [[path pathExtension] lowercaseString];
	return ([extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"]);
}

BOOL isVisible(NSString *path)
{
	NSString *fileName = [path lastPathComponent];
	return ![fileName hasPrefix:@"."];
}

void processFile(NSString *path, int size, BOOL recurse, BOOL verbose, BOOL temp)
{
	BOOL isDir;
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
	{
		if (isDir && recurse)
		{
			NSString *file;
			NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:path];
			
			while (file = [dirEnum nextObject])
			{
				if (isVisible(file))
				{
					NSString *subPath = [path stringByAppendingPathComponent:file];
					processFile(subPath, size, recurse, verbose, temp);
				}
			}
		}
		else if (isDir)
		{
			printf([[NSString stringWithFormat:@"**** Unable to read file from directory %@ - specify -r for recursive\n", path] UTF8String]);
		}
		else
		{
			if (isJPEG(path))
			{
				if (verbose)
				{
					printf([[NSString stringWithFormat:@"Reading %@\n", path] UTF8String]);
				}
				NSImage *image = [EpegWrapper imageWithPath:path boundingBox:NSMakeSize(size, size)];
				if (nil == image)
				{
					printf([[NSString stringWithFormat:@"**** Unable to create image from %@\n", path] UTF8String]);
				}
				if (temp)
				{
					NSData *data = [image TIFFRepresentation];
					NSString *outPath = [NSString stringWithFormat:@"/tmp/%@.tiff", [[path lastPathComponent] stringByDeletingPathExtension]];
					[data writeToFile:outPath atomically:YES];
				}
			}
			else
			{
				if (!recurse)	// when we recurse, don't warn of non-jpeg files
				{
					printf([[NSString stringWithFormat:@"**** File does not end in .jpg or .jpeg: %@\n", path] UTF8String]);
				}
			}
		}
	}
}

int main (int argc, const char * argv[])
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	const char *appName = argv[0];
	
	if (argc < 2)
	{
		usage(appName);
		exit(1);
	}
	
	BOOL verbose = NO;
	BOOL temp = NO;
	BOOL recurse = NO;
	int size = 128;
	char ch;
	
	// Default to UTF-8
	
	while ((ch = getopt(argc, argv, "z:rvt")) != -1) {
		switch (ch) {
			case 'v':
				verbose = YES;
				break;
			case 't':
				temp = YES;
				break;
			case 'r':
				recurse = YES;
				break;
			case 'z':
			{
				NSString *arg = [NSString stringWithUTF8String:optarg];
				size = [arg intValue];
				if (size < 16)
				{
					printf("%s: invalid size '%s', needs to be 16 or greater\n", argv[0], optarg);
					exit(1);
				}
				break;
			}
			case '?':
			default:
				usage(appName);
		}
	}
	
	// Skip past these arguments
	argc -= optind;
	argv += optind;
	
	int i;
	for ( i = 0 ; i < argc ; i++ )
	{
		NSString *path = [NSString stringWithUTF8String:argv[i]];
		processFile(path, size, recurse, verbose, temp);
	}
	[pool release];
    return 0;
}
