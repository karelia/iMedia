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


#import "IMBFireFoxParser.h"
#import <WebKit/WebKit.h>
#import "IMBNode.h"
#import "IMBParserController.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "NSWorkspace+iMedia.h"

@interface IMBFireFoxParser ()
+ (NSString *)firefoxBookmarkPath;
@end

@implementation IMBFireFoxParser

@synthesize databasePath = _databasePath;
@synthesize appPath = _appPath;
@synthesize initialized = _initialized;


+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeLink];
	
	[pool release];
}

+ (NSString*) firefoxPath
{
	return [[NSWorkspace threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"org.mozilla.firefox"];
}

+ (BOOL) isInstalled
{
	return [self firefoxPath] != nil;
}


//----------------------------------------------------------------------------------------------------------------------
		
// Create a single parser instance for Firefox bookmarks (if found)

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];
	
	NSString *bookmarkPath = [self firefoxBookmarkPath];
	NSFileManager *fm = [NSFileManager defaultManager];	// File manager, not flying meat!
	if ([self isInstalled] && bookmarkPath && [fm fileExistsAtPath:bookmarkPath] && [fm isReadableFileAtPath:bookmarkPath])
	{
		IMBFireFoxParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
		parser.databasePath = bookmarkPath;
		parser.appPath = [self firefoxPath];
		[parserInstances addObject:parser];
		[parser release];
	}
	return parserInstances;
}


+ (NSString *)firefoxBookmarkPath;
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


- (void)dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_databasePath);
	[super dealloc];
}

//----------------------------------------------------------------------------------------------------------------------

#pragma mark 

// The following two methods must be overridden by subclasses...

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	if (nil == inOldNode)	// create the initial node
	{
		NSImage* icon = [[NSWorkspace threadSafeWorkspace] iconForFile:self.appPath];;
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(16.0,16.0)];
		
		node.parentNode = nil;
		node.name = @"Firefox";
		node.icon = icon;
		node.groupType = kIMBGroupTypeLibrary;
		node.leaf = NO;
		node.parser = self;
		node.mediaSource = self.mediaSource;
		node.identifier = [self identifierForPath:@"/"];
		node.parser = self;
		node.objects = [NSMutableArray array];
		// node.subnodes = ;
	}
	
	
	
	// Watch the root node. Whenever something in Lightroom changes, we have to replace the
	// WHOLE node tree, as we have no way of finding out WHAT has changed in Lightroom...
	
	if (node.isRootNode)
	{
		node.watcherType = kIMBWatcherTypeFSEvent;
		node.watchedPath = self.databasePath;
	}
	
	return node;
}

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	return NO;
}

//----------------------------------------------------------------------------------------------------------------------


// Optional methods that do nothing in the base class and can be overridden in subclasses, e.g. to update  
// or get rid of cached data...

- (void) willUseParser
{
	NSFileManager *fm = [NSFileManager defaultManager];

	// Just load all the bookmarks in the tree -- this is not going to be that memory-intensive.
	NSString *query = @"select id,title from moz_bookmarks where type=2";
	NSString *newPath = nil;	// copy destination if we have to copy the file

	FMDatabase *database = [FMDatabase databaseWithPath:self.databasePath];

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
				attr = [fm attributesOfItemAtPath:self.databasePath error:&error];
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
				BOOL copied = [fm copyItemAtPath:self.databasePath toPath:newPath error:&error];
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

- (void) didStopUsingParser
{
	
}

- (void) watchedPathDidChange:(NSString*)inWatchedPath
{
	
}



@end

