/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
 following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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

#import "NSFileManager+iMedia.h"

#ifndef NSMakeCollectable
#define NSMakeCollectable(x) (id)(x)
#endif

@implementation NSFileManager (iMedia)

+ (NSFileManager *)threadSafeManager
{
	NSFileManager*	instance = nil;
		
	static NSString* sMutex = @"threadSafeFileManagerMutex";
	
	@synchronized(sMutex)
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

- (BOOL)createDirectoryPath:(NSString *)path attributes:(NSDictionary *)attributes
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
			if (![[NSFileManager defaultManager] fileExistsAtPath:thePath] &&
				![[NSFileManager defaultManager] createDirectoryAtPath:thePath 
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
		[NSException raise:@"iMediaException" format:@"createDirectoryPath:attributes: path not absolute:%@", path];
	}
	
	return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (BOOL)isPathHidden:(NSString *)path
{
	LSItemInfoRecord	itemInfo;
	NSURL*				pathURL = [NSURL fileURLWithPath:path];
	
	return ((LSCopyItemInfoForURL((CFURLRef)pathURL, kLSRequestBasicFlagsOnly, &itemInfo) == noErr) &&
			(itemInfo.flags & kLSItemInfoIsInvisible));
}

// Will resolve an alias into a path.. this code was taken from
// see http://cocoa.karelia.com/Foundation_Categories/
// see http://developer.apple.com/documentation/Cocoa/Conceptual/LowLevelFileMgmt/Tasks/ResolvingAliases.html
- (NSString *)pathResolved:(NSString *)path
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
					resolvedPath = NSMakeCollectable(
													 CFURLCopyFileSystemPath(resolvedUrl,
																			 kCFURLPOSIXPathStyle));
					CFRelease(resolvedUrl);
					resolvedPath = [resolvedPath autorelease];
				}
			}
		}
		CFRelease(url);
	}
	
	if ( resolvedPath == NULL )
		resolvedPath = [[path copy] autorelease];
	
	return resolvedPath;
}

- (NSString*)temporaryFile:(NSString*)name
{
	NSString *processName = [[NSProcessInfo processInfo] processName];
	NSString *directoryName = [NSString stringWithFormat:@"%@_iMediaTemporary", processName];
	NSString *directoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:directoryName];
	
	[self createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:NULL];
	
    return [self temporaryFile:name withinDirectory:directoryPath];
}

- (NSString*)temporaryFile:(NSString*)name withinDirectory:(NSString*)directoryPath
{
	NSString *temporaryPath = [self temporaryPathWithinDirectory:directoryPath];
	
	if ([name length] > 0) {
		[self createDirectoryAtPath:temporaryPath withIntermediateDirectories:YES attributes:nil error:NULL];
		
		return [temporaryPath stringByAppendingPathComponent:name];
	}
	
	return temporaryPath;
}

- (NSString*)temporaryPathWithinDirectory:(NSString*)directoryPath
{
    char template[13];
    
	strlcpy(template, "XXXXXXXXXXXX", 13 );
    
	char *tmpName = mktemp(template);
    
	return [directoryPath stringByAppendingPathComponent:[NSString stringWithUTF8String:tmpName]];
}

@end
