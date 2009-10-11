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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBGarageBandParser.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBIconCache.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBGarageBandParser ()
- (IMBNode*) _unpopulatedRootNodes;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBGarageBandParser


//----------------------------------------------------------------------------------------------------------------------


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeAudio];
	[pool release];
}


//----------------------------------------------------------------------------------------------------------------------


// Check if GarageBand is installed...

+ (NSString*) garageBandPath
{
	return [[NSWorkspace threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.GarageBand"];
}


+ (BOOL) isInstalled
{
	return [self garageBandPath] != nil;
}


// Paths to important folders containing songs...

+ (NSString*) userSongsPath
{
	return [NSHomeDirectory() stringByAppendingPathComponent:@"Music/GarageBand"];
}


+ (NSString*) demoSongsPath
{
	return @"/Library/Application Support/GarageBand/GarageBand Demo Songs/GarageBand Demo Songs/";
}


//----------------------------------------------------------------------------------------------------------------------


// If GarageBand is installed, then create a parser instance...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	if ([IMBGarageBandParser isInstalled])
	{
		IMBGarageBandParser* parser = [[[IMBGarageBandParser alloc] initWithMediaType:inMediaType] autorelease];
		return [NSArray arrayWithObject:parser];
	}
	
	return nil;
}


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.fileUTI = @"com.apple.garageband.project"; 
	}
	
	return self;
}


- (void) dealloc
{
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods


- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	IMBNode* node = nil;
	NSError* error = nil;
	
	// Create a root node...
	
	if (inOldNode == nil)
	{
		node = [self _unpopulatedRootNodes];
	}
	
	// Or copy a subnode...
	
	else
	{
		node = [[[IMBNode alloc] init] autorelease];
		
		node.parentNode = inOldNode.parentNode;
		node.mediaSource = self.mediaSource;
		node.identifier = inOldNode.identifier;
		node.name = inOldNode.name;
		node.icon = inOldNode.icon;
		node.attributes = inOldNode.attributes;
		node.groupType = inOldNode.groupType;
		node.leaf = inOldNode.leaf;
		node.parser = self;
		node.watcherType = inOldNode.watcherType;
		node.watchedPath = inOldNode.watchedPath;
	}

	// If the old node was populated, then also populate the new node...
	
	if (inOldNode.isPopulated)
	{
		[self populateNode:node options:inOptions error:&error];
	}
	
	if (outError) *outError = error;
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation. Parse the 
// iPhoto XML file and create subnodes as needed...

//- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
//{
//	NSError* error = nil;
//	
//
//
//	if (outError) *outError = error;
//	return error == nil;
//}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helper Methods


- (IMBNode*) _unpopulatedRootNodes
{
	NSImage* icon = [[NSWorkspace threadSafeWorkspace] iconForFile:[IMBGarageBandParser garageBandPath]];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(16.0,16.0)];
	
	NSString* demoSongsName = NSLocalizedStringWithDefaultValue(
		@"IMBGarageBandParser.demosongs.name",
		nil,IMBBundle(),
		@"Demo Songs",
		@"Name of node in IMBGarageBandParser");
	
	NSString* userSongsName = NSLocalizedStringWithDefaultValue(
		@"IMBGarageBandParser.usersongs.name",
		nil,IMBBundle(),
		@"My Compositions",
		@"Name of node in IMBGarageBandParser");
	
	// Create Garageband root node...
	
	IMBNode* root = [[[IMBNode alloc] init] autorelease];
	root.parentNode = nil;
	root.mediaSource = nil;
	root.identifier = [self identifierForPath:@"/"];
	root.icon = icon;
	root.name = @"GarageBand";
	root.groupType = kIMBGroupTypeLibrary;
	root.leaf = NO;
	root.parser = self;
	root.watcherType = kIMBWatcherTypeNone;
	root.subNodes = [NSMutableArray array];
	root.objects = [NSMutableArray array];	// the root node doesn't have any objects so we can populate it already!
	
	// Add unpopulated subnode for demo songs...
	
	NSString* demoSongsPath = [IMBGarageBandParser demoSongsPath];

	if ([[NSFileManager defaultManager] fileExistsAtPath:demoSongsPath])
	{
		IMBNode* demo = [[[IMBNode alloc] init] autorelease];
		demo.parentNode = root;
		demo.mediaSource = demoSongsPath;
		demo.identifier = [self identifierForPath:demoSongsPath];
		demo.icon = [self iconForPath:demoSongsPath];
		demo.name = demoSongsName;
		demo.groupType = kIMBGroupTypeNone;
		demo.leaf = YES;
		demo.parser = self;
		demo.watcherType = kIMBWatcherTypeFSEvent;
		demo.watchedPath = demoSongsPath;

		[(NSMutableArray*)root.subNodes addObject:demo];
	}
	
	// Add unpopulated subnode for user songs...
	
	NSString* userSongsPath = [IMBGarageBandParser userSongsPath];

	if ([[NSFileManager defaultManager] fileExistsAtPath:userSongsPath])
	{
		IMBNode* user = [[[IMBNode alloc] init] autorelease];
		user.parentNode = root;
		user.mediaSource = userSongsPath;
		user.identifier = [self identifierForPath:userSongsPath];
		user.icon = [self iconForPath:userSongsPath];
		user.name = userSongsName;
		user.groupType = kIMBGroupTypeNone;
		user.leaf = YES;
		user.parser = self;
		user.watcherType = kIMBWatcherTypeFSEvent;
		user.watchedPath = userSongsPath;

		[(NSMutableArray*)root.subNodes addObject:user];
	}

	return root;
}


//----------------------------------------------------------------------------------------------------------------------


// Return metadata specific to audio files...

- (NSDictionary*) metadataForFileAtPath:(NSString*)inPath
{
	NSMutableDictionary* metadata = [NSMutableDictionary dictionary];
	MDItemRef item = MDItemCreate(NULL,(CFStringRef)inPath); 
	
	if (item)
	{
		CFNumberRef seconds = MDItemCopyAttribute(item,kMDItemDurationSeconds);
		CFArrayRef authors = MDItemCopyAttribute(item,kMDItemAuthors);
		CFStringRef album = MDItemCopyAttribute(item,kMDItemAlbum);

		if (seconds)
		{
			[metadata setObject:(NSNumber*)seconds forKey:@"duration"]; 
			CFRelease(seconds);
		}
		
		if (authors)
		{
			NSArray* artists = (NSArray*)authors;
			if (artists.count > 0)[metadata setObject:[artists objectAtIndex:0] forKey:@"artist"]; 
			CFRelease(authors);
		}
		
		if (album)
		{
			[metadata setObject:(NSString*)album forKey:@"album"]; 
			CFRelease(album);
		}
		
		CFRelease(item);
	}
	else
	{
//		NSLog(@"Nil from MDItemCreate for %@ exists?%d", inPath, [[NSFileManager threadSafeManager] fileExistsAtPath:inPath]);
	}
	
	return metadata;
}


//----------------------------------------------------------------------------------------------------------------------


@end
