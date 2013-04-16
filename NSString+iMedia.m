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
 
 This file was authored by Dan Wood and Terrence Talbot. 
 
 NOTE: THESE METHODS ARE SIMILAR OR IDENTICAL TO METHODS IN SANDVOX.
 PLEASE BE SURE TO "SYNC" THEM UP IF ANY FIXES ARE MADE HERE.
 */


// Author: Unknown


#import "NSString+iMedia.h"
#import "NSFileManager+iMedia.h"
#include <sys/stat.h>


@implementation NSString ( UTI )

//  convert to UTI

+ (NSString *)imb_UTIForFileAtPath:(NSString *)anAbsolutePath
{
	NSString *result = nil;
	FSRef fileRef;
	Boolean isDirectory;
	
	if (anAbsolutePath == nil)
	{
		return nil;
	}
	
	if (FSPathMakeRef((const UInt8 *)[anAbsolutePath fileSystemRepresentation], &fileRef, &isDirectory) == noErr)
	{
		// get the content type (UTI) of this file
		CFStringRef uti = NULL;
		if (LSCopyItemAttribute(&fileRef, kLSRolesViewer, kLSItemContentType, (CFTypeRef*)&uti)==noErr)
		{
			//			result = [[((NSString *)uti) retain] autorelease];	// I want an autoreleased copy of this.
			
			if (uti)											// PB 06/18/08: fixes a memory leak
			{
				result = [NSString stringWithString:(NSString*)uti];
				CFRelease(uti);
			}
		}
	}
	
	// check extension if we can't find the actual file
	if (nil == result)
	{
		NSString *extension = [anAbsolutePath pathExtension];
		if ( (nil != extension) && ![extension isEqualToString:@""] )
		{
			result = [self imb_UTIForFilenameExtension:extension];
		}
	}
	
	// if no extension or no result, check file type
	if ( nil == result || [result isEqualToString:(NSString *)kUTTypeData])
	{
		NSString *fileType = NSHFSTypeOfFile(anAbsolutePath);
		if (6 == [fileType length])
		{
			fileType = [fileType substringWithRange:NSMakeRange(1,4)];
		}
		result = [self imb_UTIForFileType:fileType];
		if ([result hasPrefix:@"dyn."])
		{
			result = nil;		// reject a dynamic type if it tries that.
		}
	}
	
	if (nil == result)	// not found, figure out if it's a directory or not
	{
		NSFileManager *fm = [NSFileManager imb_threadSafeManager];
		BOOL isDirectory;
		if ( [fm fileExistsAtPath:anAbsolutePath isDirectory:&isDirectory] )
		{
			// TODO: Really should use -[NSWorkspace isFilePackageAtPath:] to possibly return either kUTTypePackage or kUTTypeFolder
			result = isDirectory ? (NSString *)kUTTypeDirectory : (NSString *)kUTTypeData;
		}
	}
	
	// Will return nil if file doesn't exist.
	
	return result;
}

+ (NSString *)imb_UTIForFilenameExtension:(NSString *)anExtension
{
	NSString *UTI = nil;
	
	if (anExtension == nil)
	{
		return nil;
	}
	
	if ([anExtension isEqualToString:@"m4v"])
	{
		// Hack, since we already have this UTI defined in the system, I don't think I can add it to the plist.
		UTI = (NSString *)kUTTypeMPEG4;
	}
	else
	{
		CFStringRef cfstr = UTTypeCreatePreferredIdentifierForTag(
																kUTTagClassFilenameExtension,
																(CFStringRef)anExtension,
																NULL
																);
		UTI = [NSMakeCollectable(cfstr) autorelease];
	}
	
	// If we don't find it, add an entry to the info.plist of the APP,
	// along the lines of what is documented here: 
	// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/understand_utis_conc/chapter_2_section_4.html
	// A good starting point for informal ones is:
	// http://www.huw.id.au/code/fileTypeIDs.html
	
	return UTI;
}

+ (NSString *)imb_descriptionForUTI:(NSString *)aUTI;
{
	CFStringRef result = UTTypeCopyDescription((CFStringRef)aUTI);
	return [NSMakeCollectable(result) autorelease];	
}

+ (NSString *)imb_UTIForFileType:(NSString *)aFileType;

{
	CFStringRef result = UTTypeCreatePreferredIdentifierForTag(
															   kUTTagClassOSType,
															   (CFStringRef)aFileType,
															   NULL
															   );
	return [NSMakeCollectable(result) autorelease];	
}

// See list here:
// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/utilist/chapter_4_section_1.html

+ (BOOL) imb_doesUTI:(NSString *)aUTI conformsToUTI:(NSString *)aConformsToUTI
{
	return UTTypeConformsTo((CFStringRef)aUTI, (CFStringRef)aConformsToUTI);
}

+ (BOOL) imb_doesFileAtPath:(NSString*)inPath conformToUTI:(NSString*)inRequiredUTI;
{
	NSString* uti = [NSString imb_UTIForFileAtPath:inPath];
	return (BOOL) UTTypeConformsTo((CFStringRef)uti,(CFStringRef)inRequiredUTI);
}

@end

// This is from cocoadev.com -- public domain

@implementation NSString ( iMedia )

// Convert a file:// URL (as a string) to just its path
- (NSString *)imb_pathForURLString;
{
	NSString *result = self;
	if ([self hasPrefix:@"file://"])
	{
		NSURL* url = [NSURL URLWithString:self];
		result = [url path];
	}
	return result;
}

// For compatibility with NSURL as in [(NSURL*)stringOrURL path]
- (NSString *)imb_path
{
	return [self imb_pathForURLString];
}

+ (id)uuid
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);
	return (NSString *)[NSMakeCollectable(uuidStr) autorelease];
}

//- (NSString *)imb_exifDateToLocalizedDisplayDate
//{
//	static NSDateFormatter *parser = nil;
//	static NSDateFormatter *formatter = nil;
//	static NSString* sMutex = @"com.karelia.NSString+iMedia";
//	
//	@synchronized(sMutex)
//	{
//		if (parser == nil)
//		{
//			parser = [[NSDateFormatter alloc] init];
//			[parser setDateFormat:@"yyyy':'MM':'dd kk':'mm':'ss"];
//		}
//		
//		if (formatter == nil)
//		{
//			formatter = [[NSDateFormatter alloc] init];
//			[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
//			[formatter setDateStyle:NSDateFormatterMediumStyle];	// medium date
//			[formatter setTimeStyle:NSDateFormatterShortStyle];	// no seconds
//		}
//	}
//	
//	NSDate *date = [parser dateFromString:self];
//	NSString *result = [formatter stringFromDate:date];
//	
//	return result;
//}

// PB 23/07/2010: Commented out the above version of this method and replaced it with the un-optimized version
// below, to avoid multiple crashes in the Release and Test builds. Both use an NSOperationQueue with multiple
// cores, which caused the above method to fail badly, despite the fact that I tried to safeguard it with the 
// @synchronized directive...

// Note: This below may return nil, if it can't be parsed, e.g. "0000:00:00 00:00:00"

- (NSString *)imb_exifDateToLocalizedDisplayDate
{
	NSDateFormatter *parser = [[NSDateFormatter alloc] init];
	[parser setDateFormat:@"yyyy':'MM':'dd kk':'mm':'ss"];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateStyle:NSDateFormatterMediumStyle];	// medium date
	[formatter setTimeStyle:NSDateFormatterShortStyle];	// no seconds

	NSDate *date = [parser dateFromString:self];
	NSString *result = [formatter stringFromDate:date];

	[formatter release];
	[parser release];
	
	return result;
}


+ (NSString *)imb_stringFromStarRating:(NSUInteger)aRating;
{
	static unichar blackStars[] = { 0x2605, 0x2605, 0x2605, 0x2605, 0x2605 };
	aRating = MIN((NSUInteger)5,aRating);	// make sure not above 5
	return [NSString stringWithCharacters:blackStars length:aRating];
}

//  FinderCompare.m
//  Created by Pablo Gomez Basanta on 23/7/05.
//
//
//	http://neop.gbtopia.com/?p=27
//
//  Based on:
//  http://developer.apple.com/qa/qa2004/qa1159.html
//

- (NSComparisonResult)imb_finderCompare:(NSString *)aString
{
	SInt32 compareResult;
	
	CFIndex lhsLen = [self length];;
	CFIndex rhsLen = [aString length];
	
	UniChar *lhsBuf = malloc(lhsLen * sizeof(UniChar));
	UniChar *rhsBuf = malloc(rhsLen * sizeof(UniChar));
	
	[self getCharacters:lhsBuf];
	[aString getCharacters:rhsBuf];
	
	(void) UCCompareTextDefault(kUCCollateComposeInsensitiveMask | kUCCollateWidthInsensitiveMask | kUCCollateCaseInsensitiveMask | kUCCollateDigitsOverrideMask | kUCCollateDigitsAsNumberMask| kUCCollatePunctuationSignificantMask,lhsBuf,lhsLen,rhsBuf,rhsLen,NULL,&compareResult);
	
	free(lhsBuf);
	free(rhsBuf);
	
	return (CFComparisonResult) compareResult;
}

- (NSString *)imb_resolvedPath
{
	NSString* path = self;
	OSStatus err = noErr;
	FSRef ref;
	UInt8 buffer[PATH_MAX+1];	
	
	if (err == noErr)
	{
		err = FSPathMakeRef((const UInt8 *)[path UTF8String],&ref,NULL);
	}
	
	if (err == noErr)
	{
		Boolean isFolder,wasAliased;
		err = FSResolveAliasFile(&ref,true,&isFolder,&wasAliased);
	}
	
	if (err == noErr)
	{
		err = FSRefMakePath(&ref,buffer,PATH_MAX);
	}
	
	if (err == noErr)
	{
		path = [NSString stringWithUTF8String:(const char*)buffer];
	}
	
	return path;	
}

@end

@implementation NSMutableString (iMedia)

- (void)imb_appendNewline;
{
	[self appendString:@"\n"];
}

@end

@implementation NSString (SymlinksAndAliases)

//  Created by Matt Gallagher on 2010/02/22.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.

//
// stringByResolvingSymlinksAndAliases
//
// Tries to make a standardized, absolute path from the current string,
// resolving any aliases or symlinks in the path.
//
// returns the fully resolved path (if possible) or nil (if resolution fails)
//
- (NSString *)stringByResolvingSymlinksAndAliases
{
	//
	// Convert to a standardized absolute path.
	//
	NSString *path = [self stringByStandardizingPath];
	if (![path hasPrefix:@"/"])
	{
		return nil;
	}
	
	//
	// Break into components. First component ("/") needs no resolution, so
	// we only need to handle subsequent components.
	//
	NSArray *pathComponents = [path pathComponents];
	NSString *resolvedPath = [pathComponents objectAtIndex:0];
	pathComponents = [pathComponents
                      subarrayWithRange:NSMakeRange(1, [pathComponents count] - 1)];
    
	//
	// Process all remaining components.
	//
	for (NSString *component in pathComponents)
	{
		resolvedPath = [resolvedPath stringByAppendingPathComponent:component];
		resolvedPath = [resolvedPath stringByIterativelyResolvingSymlinkOrAlias];
		if (!resolvedPath)
		{
			return nil;
		}
	}
    
	return resolvedPath;
}

//
// stringByIterativelyResolvingSymlinkOrAlias
//
// Resolves the path where the final component could be a symlink and any
// component could be an alias.
//
// returns the resolved path
//
- (NSString *)stringByIterativelyResolvingSymlinkOrAlias
{
	NSString *path = self;
	NSString *aliasTarget = nil;
	struct stat fileInfo;
	
	//
	// Use lstat to determine if the file is a symlink
	//
	if (lstat([[NSFileManager defaultManager]
               fileSystemRepresentationWithPath:path], &fileInfo) < 0)
	{
		return nil;
	}
	
	//
	// While the file is a symlink or we can resolve aliases in the path,
	// keep resolving.
	//
	while (S_ISLNK(fileInfo.st_mode) ||
           (!S_ISDIR(fileInfo.st_mode) &&
			(aliasTarget = [path stringByConditionallyResolvingAlias]) != nil))
	{
		if (S_ISLNK(fileInfo.st_mode))
		{
			//
			// Resolve the symlink final component in the path
			//
			NSString *symlinkPath = [path stringByConditionallyResolvingSymlink];
			if (!symlinkPath)
			{
				return nil;
			}
			if ([path isEqualToString:symlinkPath])
			{
				//
				// Prevent looping
				//
				return path;
			}

			path = symlinkPath;
		}
		else
		{
			path = aliasTarget;
		}
        
		//
		// Use lstat to determine if the file is a symlink
		//
		if (lstat([[NSFileManager defaultManager]
                   fileSystemRepresentationWithPath:path], &fileInfo) < 0)
		{
			path = nil;
			continue;
		}
	}
	
	return path;
}

//
// stringByResolvingAlias
//
// Attempts to resolve the single alias at the end of the path.
//
// returns the resolved alias or self if path wasn't an alias or couldn't be
//	resolved.
//
- (NSString *)stringByResolvingAlias
{
	NSString *aliasTarget = [self stringByConditionallyResolvingAlias];
	if (aliasTarget)
	{
		return aliasTarget;
	}
	return self;
}

//
// stringByResolvingSymlink
//
// Attempts to resolve the single symlink at the end of the path.
//
// returns the resolved path or self if path wasn't a symlink or couldn't be
//	resolved.
//
- (NSString *)stringByResolvingSymlink
{
	NSString *symlinkTarget = [self stringByConditionallyResolvingSymlink];
	if (symlinkTarget)
	{
		return symlinkTarget;
	}
	return self;
}

//
// stringByConditionallyResolvingSymlink
//
// Attempt to resolve the symlink pointed to by the path.
//
// returns the resolved path (if it was a symlink and resolution is possible)
//	otherwise nil
//
- (NSString *)stringByConditionallyResolvingSymlink
{
	//
	// Resolve the symlink final component in the path
	//
	NSString *symlinkPath =
    [[NSFileManager defaultManager]
     destinationOfSymbolicLinkAtPath:self
     error:NULL];
	if (!symlinkPath)
	{
		return nil;
	}
	if (![symlinkPath hasPrefix:@"/"])
	{
		//
		// For relative path symlinks (common case), remove the
		// relative links
		//
		symlinkPath =
        [[self stringByDeletingLastPathComponent]
         stringByAppendingPathComponent:symlinkPath];
		symlinkPath = [symlinkPath stringByStandardizingPath];
	}
	return symlinkPath;
}

//
// stringByConditionallyResolvingAlias
//
// Attempt to resolve the alias pointed to by the path.
//
// returns the resolved path (if it was an alias and resolution is possible)
//	otherwise nil
//
- (NSString *)stringByConditionallyResolvingAlias
{
	NSString *resolvedPath = nil;
    
	CFURLRef url = CFURLCreateWithFileSystemPath
    (kCFAllocatorDefault, (CFStringRef)self, kCFURLPOSIXPathStyle, NO);
	if (url != NULL)
	{
		FSRef fsRef;
		if (CFURLGetFSRef(url, &fsRef))
		{
			Boolean targetIsFolder, wasAliased;
			OSErr err = FSResolveAliasFileWithMountFlags(
                                                         &fsRef, false, &targetIsFolder, &wasAliased, kResolveAliasFileNoUI);
			if ((err == noErr) && wasAliased)
			{
				CFURLRef resolvedUrl = CFURLCreateFromFSRef(kCFAllocatorDefault, &fsRef);
				if (resolvedUrl != NULL)
				{
					resolvedPath =
                    [(id)CFURLCopyFileSystemPath(resolvedUrl, kCFURLPOSIXPathStyle)
                     autorelease];
					CFRelease(resolvedUrl);
				}
			}
		}
		CFRelease(url);
	}
    
	return resolvedPath;
}

@end

