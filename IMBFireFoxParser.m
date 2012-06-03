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
*/


// Author: Dan Wood
// Documentation on firefox bookmarks:
// https://developer.mozilla.org/en/The_Places_database
// http://www.forensicswiki.org/index.php?title=Mozilla_Firefox_3_History_File_Format

#import "IMBFireFoxParser.h"
#import <WebKit/WebKit.h>
#import "IMBNode.h"
#import "IMBParserController.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "NSWorkspace+iMedia.h"
#import "IMBObject.h"
#import "NSImage+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "IMBNodeObject.h"

@interface IMBFireFoxParser ()
+ (NSString *)firefoxBookmarkPath;
- (BOOL)openDatabase;
@end

@implementation IMBFireFoxParser

@synthesize databasePathOriginal = _databasePathOriginal;
@synthesize databasePathCurrent = _databasePathCurrent;

@synthesize appPath = _appPath;
@synthesize database = _database;

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeLink];
	[pool drain];
}

+ (NSString*) firefoxPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"org.mozilla.firefox"];
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
	NSFileManager *fm = [NSFileManager imb_threadSafeManager];	// File manager, not flying meat!
	if ([self isInstalled] && bookmarkPath && [fm fileExistsAtPath:bookmarkPath] && [fm isReadableFileAtPath:bookmarkPath])
	{
		IMBFireFoxParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
		parser.databasePathOriginal = bookmarkPath;
		parser.databasePathCurrent = bookmarkPath;
		parser.appPath = [self firefoxPath];
		[parserInstances addObject:parser];
		[parser release];
	}
	return parserInstances;
}

+ (NSString *)firefoxBookmarkPath;
{
	NSString *result = nil;
	NSArray *libraryPaths1 = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask | NSLocalDomainMask, YES);
	NSArray *libraryPaths2 = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask | NSLocalDomainMask, YES);
	
	NSMutableArray *libraryPaths = [NSMutableArray arrayWithArray:libraryPaths1];
	[libraryPaths addObjectsFromArray:libraryPaths2];

	NSFileManager *fm = [NSFileManager imb_threadSafeManager];
	for (NSString *path in libraryPaths)
	{
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
						return result;
					}
				}
			}
		}
	}
	return result;
}



- (void) copyDatabase;		// try to copy the database and store in copy.
{
	NSFileManager *fm = [NSFileManager imb_threadSafeManager];
	NSString *newPath = nil;	// copy destination if we have to copy the file
	
	// null result set means we couldn't open it ... it's probably busy.
	// The stupid workaround is to make a copy of the sqlite file, and check there!
	// However just in case the source file has not changed, we'll check modification dates.
	//
	newPath = [[[NSFileManager imb_threadSafeManager] imb_sharedTemporaryFolder:@"firefox"] stringByAppendingPathComponent:@"places.sqlite"];
	if (![newPath isEqualToString:self.databasePathCurrent])	// if we are trying to open the copy, don't allow that.
	{
		BOOL needToCopyFile = YES;		// probably we will need to copy but let's check
		if ([fm fileExistsAtPath:newPath])
		{
			NSError *error = nil;
			NSDictionary *attr = [fm attributesOfItemAtPath:newPath error:&error];
			NSDate *modDateOfCopy = [attr fileModificationDate];
			attr = [fm attributesOfItemAtPath:self.databasePathOriginal error:&error];
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
			BOOL copied = (nil != self.databasePathOriginal)
				&& (nil != newPath)
				&& [fm copyItemAtPath:self.databasePathOriginal toPath:newPath error:&error];
			if (!copied)
			{
				NSLog(@"Unable to copy Firefox bookmarks.");
			}
		}
		[self.database close];		// explicitly close now
		self.database = [FMDatabase databaseWithPath:newPath];
		self.databasePathCurrent = newPath;
		if (![self openDatabase])
		{
			// Couldn't open, so empty out this database so it doesn't keep trying
			self.database = nil;
		}
	}
	else
	{
		self.database = nil;	// don't try to open; couldn't open copy
	}
}

- (BOOL)openDatabase;
{
	BOOL result = NO;
	if ([self.database openWithFlags:SQLITE_OPEN_READONLY])
	{
		[self.database setBusyRetryTimeout:10];
		result = YES;
	}
	return result;
}


- (void)dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_databasePathOriginal);
	IMBRelease(_databasePathCurrent);
	[super dealloc];
}

//----------------------------------------------------------------------------------------------------------------------

- (NSImage*) iconForFolderID:(int)aFolderID;
{
	NSImage *result = nil;
	NSString* filename = nil;
	
	switch(aFolderID)
	{
		case 1: filename = @"firefox_allBookmarks.png"; break;
		case 2: filename = @"firefox_bookmarksMenu.png"; break;
		case 3: filename = @"firefox_bookmarksToolbar.png"; break;
		case 4: filename = @"firefox_tag.png"; break;
		case 5: filename = @"firefox_unfiledBookmarks.png"; break;
		default: break;
	}
	
	if (filename)
	{
		NSBundle* bundle = [NSBundle bundleForClass:[self class]];
		NSString* path = [bundle pathForResource:filename ofType:nil];
		result = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	}
	else
	{
		result = [NSImage imb_sharedGenericFolderIcon];
	}
	return result;
}

// The following two methods must be overridden by subclasses...

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	
	if (nil == inOldNode)	// create the initial node
	{
		NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:self.appPath];;
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(16.0,16.0)];
		
		node.name = @"Firefox";
		node.icon = icon;
		node.groupType = kIMBGroupTypeLibrary;
		node.leaf = NO;
		node.isTopLevelNode = YES;
		node.parser = self;
		// ??? node.mediaSource = self.mediaSource;
		node.identifier = [self identifierForPath:@"/"];
		node.attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:@"id"];
		
		self.database = [FMDatabase databaseWithPath:self.databasePathCurrent];
		
		if ([self openDatabase])
		{
			[self populateNode:node options:inOptions error:outError];		// populate the WHOLE thing.
		}
		else
		{
			node.subNodes = [NSArray array];		// Empty subnodes/objects since we couldn't read it.
			node.objects = [NSArray array];
		}
	
		self.database = nil;	// close the database
	}
	else
	{
		node.mediaSource = self.mediaSource;
		node.identifier = inOldNode.identifier;
		node.name = inOldNode.name;
		node.icon = inOldNode.icon;
		node.parser = self;
		node.leaf = inOldNode.leaf;
		node.groupType = inOldNode.groupType;
		node.attributes = [[inOldNode.attributes copy] autorelease];
	}
	
	// Watch the root node. Whenever something in Lightroom changes, we have to replace the
	// WHOLE node tree, as we have no way of finding out WHAT has changed in Lightroom...
	
	if (node.isTopLevelNode)
	{
		node.watcherType = kIMBWatcherTypeFSEvent;
		node.watchedPath = self.databasePathOriginal;
	}
	
	return node;
}


// Just load all the bookmarks in the tree -- this is not going to be that memory-intensive.

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{	
	NSMutableArray *subNodes = [NSMutableArray array];
	NSMutableArray *objects = [NSMutableArray array];

	NSNumber *parentIDNumber = [inNode.attributes objectForKey:@"id"];

	FMResultSet *rs = nil;
	
	// First get the folders (type 2)
	while (self.database && !rs)	// keep trying until we get result set (or database is invalid)
	{
		NSString *query = @"select id,title from moz_bookmarks where type=2 and parent=? order by position";
		
		rs = [self.database executeQuery:query, parentIDNumber];
		if (!rs)
		{
			[self copyDatabase];	// read-only copy if file busy
		}
	}
	
	NSUInteger index = 0;

	while ([rs next])
	{		
//		NSLog(@"%@>%@ '%@' %@", 
//			  parentIDNumber,
//			  [rs stringForColumn:@"id"],
//			  [rs stringForColumn:@"title"],
//			  @"type=2");

		int theID = [rs intForColumn:@"id"];
		NSString *theName = [rs stringForColumn:@"title"];
		if (theName && ![theName isEqualToString:@""])	// make sure we have a title; otherwise bogus
		{
			IMBNode* node = [[[IMBNode alloc] init] autorelease];
			//		NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:self.appPath];;
			//		[icon setScalesWhenResized:YES];
			//		[icon setSize:NSMakeSize(16.0,16.0)];
			NSImage* icon = [self iconForFolderID:theID];
			node.icon = icon;
			node.name = theName;
			node.attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:theID] forKey:@"id"];
			
			node.leaf = NO;
			node.parser = self;
			// ??? node.mediaSource = self.mediaSource;
			node.identifier = [self identifierForPath:[NSString stringWithFormat:@"/%d/%@",theID, theName]];
			[subNodes addObject:node];
			
			// Top level node?  Make sub-objects show up for these subnodes as well.
			// if ([parentIDNumber intValue] == 1)
			{
				IMBObject *object = [[[IMBNodeObject alloc] init] autorelease];
				object.name = theName;
				object.parser = self;
				((IMBNodeObject*)object).representedNodeIdentifier = node.identifier;
				
				object.index = index++;
				object.imageLocation = nil;
				object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
				object.imageRepresentation = icon;
				
				[objects addObject:object];
			}
		}
	}
	inNode.subNodes = subNodes;

	[rs close]; rs = nil;
		
	// Now get the bookmarks (type 1)
	while (self.database && !rs)	// keep trying until we get result set (or database is invalid)
	{
		NSString *query = @"select b.parent, b.id, b.title, b.type, p.url, f.mime_type, f.data from moz_bookmarks b, moz_places p left outer join moz_favicons f on p.favicon_id=f.id where p.id=b.fk and b.parent=? order by b.position;";
		rs = [self.database executeQuery:query, parentIDNumber];
		if (!rs)
		{
			[self copyDatabase];	// read-only copy if file busy
		}
	}
	
	while ([rs next])
	{		
		IMBObject *object = [[[IMBObject alloc] init] autorelease];
		
//		NSLog(@"%@>%@ '%@' %@", 
//			  [rs stringForColumn:@"parent"],
//			  [rs stringForColumn:@"id"],
//			  [rs stringForColumn:@"title"],
//			  [rs stringForColumn:@"type"]);

		
		object.name = [rs stringForColumn:@"title"];
		object.location = [NSURL URLWithString:[rs stringForColumn:@"url"]];
		
		NSData *imageData = [rs dataForColumn:@"data"];
		if (imageData)
		{
			NSImage *iconImage = [NSImage imb_imageWithData:imageData mimeType:[rs stringForColumn:@"mime_type"]];
//			[icon setScalesWhenResized:YES];
//			[icon setSize:NSMakeSize(16.0,16.0)];
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = iconImage;
		}
		else
		{
			static NSImage *sGenericIcon = nil;
			if (!sGenericIcon)
			{
				// Get generic icon, and shrink it down to favicon size for consistency.
				sGenericIcon = [[[NSWorkspace imb_threadSafeWorkspace] iconForFileType:(NSString *)kUTTypeURL] retain];
				[sGenericIcon setScalesWhenResized:YES];
				[sGenericIcon setSize:NSMakeSize(16.0,16.0)];
			}
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = sGenericIcon;
		}

		object.parser = self;
		
		[objects addObject:object];
		
	}
	inNode.objects = objects;
	[rs close]; rs = nil;
	
	
	// Now do the recursion, now that we are done with the queries.  (I don't want to try queries within queries!)
	for (IMBNode *subNode in inNode.subNodes)
	{
		[self populateNode:subNode options:inOptions error:outError];
	}
	

	
		
	return NO;
}

//----------------------------------------------------------------------------------------------------------------------


// Optional methods that do nothing in the base class and can be overridden in subclasses, e.g. to update  
// or get rid of cached data...


- (void) didStopUsingParser
{
	
}

- (void) watchedPathDidChange:(NSString*)inWatchedPath
{
	
}



@end

