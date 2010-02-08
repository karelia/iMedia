/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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
 
 This file was authored by Dan Wood and Terrence Talbot. 
 
 NOTE: THESE METHODS ARE SIMILAR OR IDENTICAL TO METHODS IN SANDVOX.
 PLEASE BE SURE TO "SYNC" THEM UP IF ANY FIXES ARE MADE HERE.
*/


#import "NSString+iMedia.h"
#include <openssl/bio.h>
#include <openssl/evp.h>

#ifndef NSMakeCollectable
#define NSMakeCollectable(x) (id)(x)
#endif

@implementation NSString ( UTI )

//  convert to UTI

+ (NSString *)UTIForFileAtPath:(NSString *)anAbsolutePath
{
	NSString *result = nil;
    FSRef fileRef;
    Boolean isDirectory;
	
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
			result = [self UTIForFilenameExtension:extension];
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
		result = [self UTIForFileType:fileType];
		if ([result hasPrefix:@"dyn."])
		{
			result = nil;		// reject a dynamic type if it tries that.
		}
	}
    
	if (nil == result)	// not found, figure out if it's a directory or not
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isDirectory;
        if ( [fm fileExistsAtPath:anAbsolutePath isDirectory:&isDirectory] )
		{
			result = isDirectory ? (NSString *)kUTTypeDirectory : (NSString *)kUTTypeData;
		}
	}
	
	// Will return nil if file doesn't exist.
	
	return result;
}

+ (NSString *)UTIForFilenameExtension:(NSString *)anExtension
{
	NSString *UTI = nil;
	
	if ([anExtension isEqualToString:@"m4v"])
	{
		// Hack, since we already have this UTI defined in the system, I don't think I can add it to the plist.
		UTI = (NSString *)kUTTypeMPEG4;
	}
	else
	{
		UTI = [NSMakeCollectable(UTTypeCreatePreferredIdentifierForTag(
																 kUTTagClassFilenameExtension,
																 (CFStringRef)anExtension,
																 NULL
																 )) autorelease];
	}
	
	// If we don't find it, add an entry to the info.plist of the APP,
	// along the lines of what is documented here: 
	// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/understand_utis_conc/chapter_2_section_4.html
	// A good starting point for informal ones is:
	// http://www.huw.id.au/code/fileTypeIDs.html
    
	return UTI;
}

+ (NSString *)UTIForFileType:(NSString *)aFileType;

{
	return [NSMakeCollectable(UTTypeCreatePreferredIdentifierForTag(
															 kUTTagClassOSType,
															 (CFStringRef)aFileType,
															 NULL
															 )) autorelease];	
}

// See list here:
// http://developer.apple.com/documentation/Carbon/Conceptual/understanding_utis/utilist/chapter_4_section_1.html

+ (BOOL) UTI:(NSString *)aUTI conformsToUTI:(NSString *)aConformsToUTI
{
	return UTTypeConformsTo((CFStringRef)aUTI, (CFStringRef)aConformsToUTI);
}


@end

// This is from cocoadev.com -- public domain

@implementation NSString ( iMedia )

// Convert a file:// URL (as a string) to just its path
- (NSString *)pathForURLString;
{
	NSString *result = self;
	if ([self hasPrefix:@"file://"])
	{
		NSURL* url = [NSURL URLWithString:self];
		result = [url path];
	}
	return result;
}


- (NSData *) decodeBase64;
{
    return [self decodeBase64WithNewlines: YES];
}

- (NSData *) decodeBase64WithNewlines: (BOOL) encodedWithNewlines;
{
    // Create a memory buffer containing Base64 encoded string data
	const char *UTF8String = [self UTF8String];
    BIO * mem = BIO_new_mem_buf((void *)UTF8String, strlen(UTF8String));
    
    // Push a Base64 filter so that reading from the buffer decodes it
    BIO * b64 = BIO_new(BIO_f_base64());
    if (!encodedWithNewlines)
        BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
    mem = BIO_push(b64, mem);
    
    // Decode into an NSMutableData
    NSMutableData * data = [NSMutableData data];
    char inbuf[512];
    int inlen;
    while ((inlen = BIO_read(mem, inbuf, sizeof(inbuf))) > 0)
        [data appendBytes: inbuf length: inlen];
    
    // Clean up and go home
    BIO_free_all(mem);
    return data;
}

+ (id)uuid
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);
	[NSMakeCollectable(uuidStr) autorelease];
	return (NSString *)uuidStr;
}

- (NSString *)exifDateToLocalizedDisplayDate
{
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateFormat:@"yyyy':'MM':'dd kk':'mm':'ss"];
	NSDate *date = [formatter dateFromString:self];
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateStyle:NSDateFormatterMediumStyle];	// medium date
	[formatter setTimeStyle:NSDateFormatterShortStyle];	// no seconds
	NSString *result = [formatter stringFromDate:date];
	return result;
}

+ (NSString *)stringFromStarRating:(unsigned int)aRating;
{
	static unichar blackStars[] = { 0x2605, 0x2605, 0x2605, 0x2605, 0x2605 };
	aRating = MIN((unsigned int)5,aRating);	// make sure not above 5
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

- (NSComparisonResult)finderCompare:(NSString *)aString
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




@end

