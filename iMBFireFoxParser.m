/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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


#import "iMBFireFoxParser.h"
#import <WebKit/WebKit.h>
#import "iMBLibraryNode.h"
#import "iMediaConfiguration.h"

// Some of this code is used from the Shiira Project - BSD Licensed

@implementation iMBFireFoxParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaConfiguration registerParser:[self class] forMediaType:@"links"];
	
	[pool release];
}

- (id)init
{
	// Get the paths of ~/Library/Application Support/Firefox/profiles.ini
    NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *bookmarksPath = nil;
    NSString *profilesPath = [[libraryPaths objectAtIndex:0] stringByAppendingPathComponent:@"/Firefox/profiles.ini"];
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    if ([fileMgr fileExistsAtPath:profilesPath]) 
	{
        // Parse profiles.ini
		NSString *profiles;
		profiles = [[NSString alloc] initWithData:[NSData dataWithContentsOfFile:profilesPath] encoding:NSUTF8StringEncoding];
		[profiles autorelease];
		
		NSScanner *scanner;
		NSString *profilePath = nil;
		scanner = [NSScanner scannerWithString:profiles];
		
		while (![scanner isAtEnd]) {
			NSString *token;
			if ([scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] 
										intoString:&token])
			{
				if ([token hasPrefix:@"Path="]) {
					// Remove 'Path='
					profilePath = [token substringFromIndex:5];
					break;
				}
			}
			
			[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:nil];
		}
		
		// Get bookmarks path
		bookmarksPath = [[profilesPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:profilePath];
		bookmarksPath = [bookmarksPath stringByAppendingPathComponent:@"bookmarks.html"];
    }
	
	if (self = [super initWithContentsOfFile:bookmarksPath])
	{
		
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

- (iMBLibraryNode *)parseDatabase
{
	NSString *bookmarksPath = [self databasePath];
	iMBLibraryNode *root = nil;
	
	if (bookmarksPath)
	{
		root = [[iMBLibraryNode alloc] init];
		[root setName:LocalizedStringInIMedia(@"Firefox", @"Firefox")];
		[root setIconName:@"org.mozilla.firefox"];
        [root setIdentifier:@"Firefox"];
        [root setParserClassName:NSStringFromClass([self class])];
		[root setWatchedPath:myDatabase];
		
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

