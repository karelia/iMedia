/*
 iMedia Browser <http://kareia.com/imedia>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window,Acknowledgments window, or similar, either a) the original
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


@implementation NSFileManager (iMedia)

- (BOOL)createDirectoryPath:(NSString *)path attributes:(NSDictionary *)attributes
{
	if ( ![path isAbsolutePath] )
	{
		[NSException raise:@"iMediaException" format:@"createDirectoryPath:attributes: path not absolute:%@", path];
		return NO;
	}
	
	NSString *thePath = @"";
	BOOL result = YES;
	
    NSEnumerator *enumerator = [[path pathComponents] objectEnumerator];
    NSString *component;
    while ( component = [enumerator nextObject] )
    {
        thePath = [thePath stringByAppendingPathComponent:component];
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:thePath] )
		{
			result = result && [[NSFileManager defaultManager] createDirectoryAtPath:thePath 
																		  attributes:attributes];
			if ( NO == result )
			{
				[NSException raise:@"iMediaException" format:@"createDirectory:attributes: failed at path: %@", path];
				return NO;
			}
		}
    }
	
    return ( (YES == result) && [[NSFileManager defaultManager] fileExistsAtPath:path] );
}

- (BOOL)isPathHidden:(NSString *)path
{
	// exit early
	if ([[path lastPathComponent] hasPrefix:@"."]) return YES;
	
	BOOL isHidden = NO;
//	OSStatus ret;
//	NSURL *url = [NSURL fileURLWithPath:path];
//	LSItemInfoRecord rec;
//	
//	ret = LSCopyItemInfoForURL((CFURLRef)url, kLSRequestAllInfo, &rec);
//	if (ret == noErr)
//	{
//		if (rec.flags & kLSItemInfoIsInvisible)
//		{
//			isHidden = YES;
//		}
//	}
	return isHidden;
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
                    resolvedPath = (NSString*)
                    CFURLCopyFileSystemPath(resolvedUrl,
                                            kCFURLPOSIXPathStyle);
                    CFRelease(resolvedUrl);
                }
            }
        }
        CFRelease(url);
    }
    
    if ( resolvedPath == NULL )
        resolvedPath = [[path copy] autorelease];
    
    return resolvedPath;
}

@end
