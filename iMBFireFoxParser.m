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


// Author: Dan Wood


#import "iMBFireFoxParser.h"
#import <WebKit/WebKit.h>
#import "IMBNode.h"
#import "IMBParserController.h"
#import "FMDatabase.h"
#import "FMResultSet.h"

// Some of this code is used from the Shiira Project - BSD Licensed

@implementation iMBFireFoxParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeLink];
	
	[pool release];
}

- (NSString *)__firefoxBookmarkPath;
{
	NSString *result = nil;
	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *path = [libraryPaths objectAtIndex:0];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	
	NSString *firefoxPath = [path stringByAppendingPathComponent:@"Firefox"];
	NSString *profilesPath = [firefoxPath stringByAppendingPathComponent:@"Profiles"];
	BOOL isDir;
	if ([fm fileExistsAtPath:profilesPath isDirectory:&isDir] && isDir)
	{
		NSDirectoryEnumerator *e = [fm enumeratorAtPath:profilesPath];
		[e skipDescendents];
		NSString *filename = nil;
		while ( filename = [e nextObject] )
		{
			if ( ![filename hasPrefix:@"."] )
			{
				NSString *profilePath = [profilesPath stringByAppendingPathComponent:filename];
				NSString *bookmarkPath = [profilePath stringByAppendingPathComponent:@"places.sqlite"];
				if ([fm fileExistsAtPath:bookmarkPath isDirectory:&isDir] && !isDir)
				{
					result = bookmarkPath;	// just stop on the first profile we find.  Should be good enough!
					break;
				}
			}
		}
	}
	return result;
}

- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		NSString *bookmarkPath = [self __firefoxBookmarkPath];
		NSFileManager *fm = [NSFileManager defaultManager];	// File manager, not flying meat!
		if (bookmarkPath && [fm fileExistsAtPath:bookmarkPath] && [fm isReadableFileAtPath:bookmarkPath])
		{
			NSString *query = @"select id,title from moz_bookmarks where type=2";
			NSString *newPath = nil;	// copy destination if we have to copy the file
			
			FMDatabase *database = [FMDatabase databaseWithPath:bookmarkPath];
			
			if ([database openWithFlags: SQLITE_OPEN_READONLY])
			{
				[database setBusyRetryTimeout:10];
				
				FMResultSet *rs = [database executeQuery:query];
				if (!rs)
				{
					// null result set means we couldn't open it ... it's probably busy.
					// The stupid workaround is to make a copy of the sqlite file, and check there!
					// However just in case the source file has not changed, we'll check modification dates.
					//
					newPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"places.sqlite"];
					BOOL needToCopyFile = YES;		// probably we will need to copy but let's check
					if ([fm fileExistsAtPath:newPath])
					{
						NSError *error = nil;
						NSDictionary *attr = [fm attributesOfItemAtPath:newPath error:&error];
						NSDate *modDateOfCopy = [attr fileModificationDate];
						attr = [fm attributesOfItemAtPath:bookmarkPath error:&error];
						NSDate *modDateOfOrig = [attr fileModificationDate];
						if (NSOrderedSame == [modDateOfOrig compare:modDateOfCopy])
						{
							needToCopyFile = NO;
						}
					}
					if (needToCopyFile)
					{
						NSError *error = nil;
						(void) [fm removeItemAtPath:newPath error:nil];
						BOOL copied = [fm copyItemAtPath:bookmarkPath toPath:newPath error:&error];
						if (!copied)
						{
							NSLog(@"Unable to copy Firefox bookmarks.");
						}
					}
					// Now to try again!
					[database close];	// close the old one
					database = [FMDatabase databaseWithPath:newPath];
					if ([database openWithFlags: SQLITE_OPEN_READONLY])
					{
						[database setBusyRetryTimeout:10];
						rs = [database executeQuery:query];
					}
				}
				
				while ([rs next])
				{
					NSString *theID = [rs stringForColumn:@"id"];
					NSString *theTitle = [rs stringForColumn:@"title"];
					NSLog(@"%@ %@", theID, theTitle);
				}
				// DON'T DELETE -- SO NEXT TIME THROUGH WE CAN OPEN COPY IF IT'S STILL AROUND.
				//			if (newPath)
				//			{
				//				(void) [fm removeFileAtPath:newPath handler:nil];
				//			}
				[rs close];
				[database close];
			}
		}
	}
return self;
}

- (NSString*)_removeTags:(NSArray*)tags fromHtml:(NSString*)html
{
    NSMutableString*    buffer;
    buffer = [NSMutableString string];
    
    NSScanner*  scanner;
    scanner = [NSScanner scannerWithString:html];
    [scanner setCharactersToBeSkipped:nil];
    while (![scanner isAtEnd]) {
        // Scan '<'
        NSString*   token;
        if ([scanner scanUpToString:@"<" intoString:&token]) {
            [buffer appendString:token];
        }
        
        // Scan '>'
        NSString*   tag;
        if ([scanner scanUpToString:@">" intoString:&tag]) {
            // Append tag if it is not contained in tags
            tag = [tag stringByAppendingString:@">"];
            if (![tags containsObject:tag]) {
                [buffer appendString:tag];
            }
            [scanner scanString:@">" intoString:nil];
        }
    }
    
    return buffer;
}

- (IMBNode *)parseDatabase
{
	NSString *bookmarksPath = [self databasePath];
	IMBNode *root = nil;
	
	if (bookmarksPath)
	{
		root = [[IMBNode alloc] init];
		[root setName:NSLocalizedStringWithDefaultValue(
														@"FireFox",
														nil,IMBBundle(),
														@"FireFox",
														@"FireFox application name")];
		[root setIconName:@"org.mozilla.firefox"];
        [root setIdentifier:@"Firefox"];
///        [root setParserClassName:NSStringFromClass([self class])];
///		[root setWatchedPath:_database];
		
		// Remove unneccessary tags
		static NSArray* _tags = nil;
		if (!_tags) {
			_tags = [[NSArray arrayWithObjects:@"<p>", @"<P>", @"<dd>", @"<DD>", @"<hr>", @"<HR>", nil] retain];
		}
		
		NSString *html = [[[NSString alloc] initWithData:[NSData dataWithContentsOfFile:bookmarksPath] encoding:NSUTF8StringEncoding] autorelease];
		html = [self _removeTags:_tags fromHtml:html];
//unused		NSError *err;
//unused		NSXMLDocument *xml = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:bookmarksPath]
//																  options:NSXMLDocumentTidyHTML
//																	error:&err];
//		NSLog(@"%@: %@", NSStringFromSelector(_cmd), [xml XMLStringWithOptions:NSXMLNodePrettyPrint]);
	}
    
	return [root autorelease];
}

@end

