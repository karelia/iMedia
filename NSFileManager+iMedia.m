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


// Author: Unknown


#import "NSFileManager+iMedia.h"
#import "NSString+iMedia.h"


@implementation NSFileManager (iMedia)

+ (NSFileManager *)imb_threadSafeManager
{
	NSFileManager*	instance = nil;
	
	@synchronized([self class])
	{
		static NSMutableDictionary* sPerThreadInstances = nil;
		
		if (sPerThreadInstances == nil)
		{
			sPerThreadInstances = [[NSMutableDictionary alloc] init];
		}
		
		NSString *threadID = [NSString stringWithFormat:@"%p",[NSThread currentThread]];
		instance = [sPerThreadInstances objectForKey:threadID];
		
		if (instance == nil)
		{
			instance = [[[NSFileManager alloc] init] autorelease];
			[sPerThreadInstances setObject:instance forKey:threadID];
		}	 
	}

	return instance;	
}

- (BOOL)imb_createDirectoryPath:(NSString *)path attributes:(NSDictionary *)attributes
{
	if ([path isAbsolutePath])
	{
		NSString*		thePath = @"";
		NSEnumerator*	enumerator = [[path pathComponents] objectEnumerator];
		NSString*		component;
		
		while ((component = [enumerator nextObject]) != nil)
		{
			NSError* eatError = nil;
			thePath = [thePath stringByAppendingPathComponent:component];
			if (![self fileExistsAtPath:thePath] &&
				![self createDirectoryAtPath:thePath 
				 withIntermediateDirectories:YES
								  attributes:attributes
									   error:&eatError])
			{
				[NSException raise:@"iMediaException" format:@"createDirectory:attributes: failed at path: %@", path];
			}
		}
	}
	else
	{
		[NSException raise:@"iMediaException" format:@"imb_createDirectoryPath:attributes: path not absolute:%@", path];
	}
	
	return [self fileExistsAtPath:path];
}

- (BOOL)imb_isPathHidden:(NSString *)path
{
	LSItemInfoRecord	itemInfo;
	NSURL*				pathURL = [NSURL fileURLWithPath:path];
	
	return ((LSCopyItemInfoForURL((CFURLRef)pathURL, kLSRequestBasicFlagsOnly, &itemInfo) == noErr) &&
			(itemInfo.flags & kLSItemInfoIsInvisible));
}

// Will resolve an alias into a path.. this code was taken from
// see http://cocoa.karelia.com/Foundation_Categories/
// see http://developer.apple.com/documentation/Cocoa/Conceptual/LowLevelFileMgmt/Tasks/ResolvingAliases.html
- (NSString *)imb_pathResolved:(NSString *)path
{
	NSString *resolvedPath = NULL;
	
	CFURLRef url = CFURLCreateWithFileSystemPath(NULL /*allocator*/, (CFStringRef)path, kCFURLPOSIXPathStyle, NO /*isDirectory*/);
	if (url != NULL)
	{
		FSRef fsRef;
		if (CFURLGetFSRef(url, &fsRef))
		{
			Boolean targetIsFolder, wasAliased;
			if (FSResolveAliasFile (&fsRef, true /*resolveAliasChains*/, 
									&targetIsFolder, &wasAliased) == noErr && wasAliased)
			{
				CFURLRef resolvedUrl = CFURLCreateFromFSRef(NULL, &fsRef);
				if (resolvedUrl != NULL)
				{
					CFStringRef cfstr = CFURLCopyFileSystemPath(resolvedUrl,
																kCFURLPOSIXPathStyle);
					CFRelease(resolvedUrl);
					resolvedPath = [NSMakeCollectable(cfstr) autorelease];
				}
			}
		}
		CFRelease(url);
	}
	
	if ( resolvedPath == NULL )
		resolvedPath = [[path copy] autorelease];
	
	return resolvedPath;
}

// Return (creating if necessary) a path to the shared iMedia temporary directory.
// If you pass in a subfolder name, that will be created and appended.

- (NSString*)imb_sharedTemporaryFolder:(NSString*)dirName;
{
	NSString *directoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"iMedia"];
	if (dirName && ![dirName isEqualToString:@""])
	{
		directoryPath = [directoryPath stringByAppendingPathComponent:dirName];
	}
	[self createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:NULL];
    return directoryPath;
}

- (NSString*)imb_uniqueTemporaryFile:(NSString*)name
{
	NSString *processName = [[NSProcessInfo processInfo] processName];
	NSString *directoryName = [NSString stringWithFormat:@"%@_iMediaTemporary", processName];
	NSString *directoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:directoryName];
	
	[self createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:NULL];
	
    return [self imb_uniqueTemporaryFile:name withinDirectory:directoryPath];
}

- (NSString*)imb_uniqueTemporaryFile:(NSString*)name withinDirectory:(NSString*)directoryPath
{
	NSString *temporaryPath = [self imb_uniqueTemporaryPathWithinDirectory:directoryPath];
	
	if ([name length] > 0) {
		[self createDirectoryAtPath:temporaryPath withIntermediateDirectories:YES attributes:nil error:NULL];
		
		return [temporaryPath stringByAppendingPathComponent:name];
	}
	
	return temporaryPath;
}

// Creates a new, unique path (for a directory or a file), so don't use this if you want to match up
// with an existing downloaded file!

- (NSString*)imb_uniqueTemporaryPathWithinDirectory:(NSString*)directoryPath
{
	NSString *tempFileTemplate = [directoryPath stringByAppendingPathComponent:@"XXXXXXXXXXXX"];
	const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
	NSString* tempFilePath = nil;
	
	char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
	if (tempFileNameCString != NULL)
	{
		strcpy(tempFileNameCString, tempFileTemplateCString);

		char *tmpName = mktemp(tempFileNameCString);
		
		tempFilePath = [NSString stringWithUTF8String:tmpName];	
		
		free(tempFileNameCString);
	}
	
	return tempFilePath;
}


- (NSString*) imb_volumeNameAtPath:(NSString*)inPath
{
	NSString* path = [inPath stringByStandardizingPath];
	NSArray* components = [path pathComponents];

	if (![path hasPrefix:@"/Volumes/"])
	{
		return [self displayNameAtPath:@"/"];
	}
	else if ([components count] > 2)
	{
		NSString* volumeName = [components objectAtIndex:2];
		NSMutableArray* parts = [NSMutableArray arrayWithArray:[volumeName componentsSeparatedByString:@" "]];
		NSString* number = [parts lastObject];
		
		if ([number intValue] > 0)
		{
			[parts removeLastObject];
			volumeName = [parts componentsJoinedByString:@" "];
		}

		return volumeName;
	}

	return nil;
}


- (NSString*) imb_relativePathToVolumeAtPath:(NSString*)inPath
{
	NSString* path = [inPath stringByStandardizingPath];

	if ([path hasPrefix:@"/Volumes/"])
	{
		NSArray* components = [path pathComponents];
		
		NSMutableArray* relComponents = [NSMutableArray arrayWithArray:components];
		[relComponents removeObjectAtIndex:0];
		[relComponents removeObjectAtIndex:0];
		[relComponents removeObjectAtIndex:0];
		
		path = [NSString pathWithComponents:relComponents];
	}
	else if ([path hasPrefix:@"/"])
	{
		path = [path substringFromIndex:1];
	}

	return path;
}


- (BOOL) imb_fileExistsAtPath:(NSString**)ioPath wasChanged:(BOOL*)outWasChanged
{
	BOOL exists = NO;
	BOOL wasChanged = NO;
	
	if (ioPath)
	{
		NSString* path = [*ioPath stringByStandardizingPath];
		
		if ([self fileExistsAtPath:path])
		{
			exists = YES;
		}
		else
		{
			if ([path hasPrefix:@"/Volumes/"])
			{
				NSString* volName = [self imb_volumeNameAtPath:path];
				NSString* relPath = [self imb_relativePathToVolumeAtPath:path];
				NSString* newPath;
				
				if (!exists)
				{
					newPath = [[NSString stringWithFormat:@"/Volumes/%@",volName] stringByAppendingPathComponent:relPath];
					exists = [self fileExistsAtPath:newPath];
				}
				
				for (NSInteger i=1; i<=10; i++)
				{
					if (!exists)
					{
						newPath = [[NSString stringWithFormat:@"/Volumes/%@ %i",volName,i] stringByAppendingPathComponent:relPath];
						exists = [self fileExistsAtPath:newPath];
						if (exists) break;
					}
				}
				
				if (exists && ![newPath isEqualToString:path])
				{
					*ioPath = newPath;
					wasChanged = YES;
				}
			}
		}
	}
	
	if (outWasChanged) *outWasChanged = wasChanged;
	return exists;
}

// Based on Sample code DragNDropOutlineView:AppController.m
- (NSString *) imb_generateUniqueFileNameAtPath:(NSString *)path base:(NSString *)basename extension:(NSString *)extension;
{
	NSString *filename = [NSString stringWithFormat:@"%@.%@", basename, extension];
    NSString *result = [path stringByAppendingPathComponent:filename];
    NSInteger i = 1;
    while ([self fileExistsAtPath:result]) {
        filename = [NSString stringWithFormat:@"%@ %ld.%@", basename, (long)i, extension];
        result = [path stringByAppendingPathComponent:filename];
        i++;
    }    
    return result;
}



@end
