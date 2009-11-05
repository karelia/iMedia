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

#import "IMBSafariBookmarkParser.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSImage+iMedia.h"
#import "WebIconDatabase.h"
#import <WebKit/WebKit.h>
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


@interface IMBSafariBookmarkParser ()
- (NSDictionary*) plist;
- (NSString*) identifierForPlist:(NSDictionary*)inPlist;
- (BOOL) isLeafPlist:(NSDictionary*)inPlist;
- (void) populateNode:(IMBNode*)inNode plist:(NSDictionary*)inPlist;
- (IMBNode*) subnodeForPlist:(NSDictionary*)inPlist;
- (IMBObject*) objectForPlist:(NSDictionary*)inPlist;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBSafariBookmarkParser

@synthesize appPath = _appPath;
@synthesize plist = _plist;
@synthesize modificationDate = _modificationDate;
@synthesize safariFaviconCache = _safariFaviconCache;


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	// Register this parser, so that it gets automatically loaded...

	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeLink];

	// Force the WebIconDatabase to be created on main thread - some webkit versions seem to complain when 
	// it's not the case...
	
	[WebIconDatabase performSelectorOnMainThread:@selector(sharedIconDatabase) withObject:nil waitUntilDone:YES];

	[pool release];
}


//----------------------------------------------------------------------------------------------------------------------


// Check if Safari is installed...

+ (NSString*) safariPath
{
	return [[NSWorkspace threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.Safari"];
}


+ (BOOL) isInstalled
{
	return [self safariPath] != nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Create a single parser instance for Safari bookmarks (if Safari is installed)...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];
	NSString* path = [@"~/Library/Safari/Bookmarks.plist" stringByStandardizingPath];

	if ([self isInstalled] && [[NSFileManager threadSafeManager] fileExistsAtPath:path])
	{
		IMBSafariBookmarkParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
		parser.mediaSource = path;
		[parserInstances addObject:parser];
		[parser release];
	}
	
	return parserInstances;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.appPath = [[self class] safariPath];
		self.plist = nil;
		self.modificationDate = nil;
		self.safariFaviconCache = [NSMutableDictionary dictionary];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_plist);
	IMBRelease(_modificationDate);
	IMBRelease(_safariFaviconCache);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	// Oops no path, can't create a root node. This is bad...
	
	if (self.mediaSource == nil)
	{
		return nil;
	}
	
	// Create an (unpopulated) root node...
	
	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	
	if (inOldNode == nil)
	{
		node.parentNode = nil;
		node.mediaSource = self.mediaSource;
		node.identifier = [self identifierForPath:@"/"];
		node.name = @"Safari";
		node.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:self.appPath];
		node.groupType = kIMBGroupTypeLibrary;
		node.leaf = NO;
		node.parser = self;
		node.objects = [NSMutableArray array];
		
		[node.icon setScalesWhenResized:YES];
		[node.icon setSize:NSMakeSize(16.0,16.0)];
	}
	
	// Or an subnode...
	
	else
	{
		node.parentNode = inOldNode.parentNode;
		node.mediaSource = self.mediaSource;
		node.identifier = inOldNode.identifier;
		node.name = inOldNode.name;
		node.icon = inOldNode.icon;
		node.groupType = inOldNode.groupType;
		node.leaf = inOldNode.leaf;
		node.parser = self;
	}
	
	// Watch the XML file. Whenever something in Safari changes, we have to replace the WHOLE tree   
	// from the root node down, as we have no way of finding WHAT has changed in Safari...
	
	if (node.isRootNode)
	{
		node.watcherType = kIMBWatcherTypeFSEvent;
		node.watchedPath = [(NSString*)node.mediaSource stringByDeletingLastPathComponent];
	}
	else
	{
		node.watcherType = kIMBWatcherTypeNone;
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


// Once the root node is selected or expanded, parse the whole tree at once, as we are only dealing with a 
// relatively small data set. In this case strict lazy loading on a node by node basis doesn't make sense,
// as it would require loading the plist form disk multiple times, which would probably outweight the benefits
// of lazy loading...
 
- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	if (inNode.isRootNode)
	{
		NSDictionary* plist = [self plist];
		[self populateNode:inNode plist:plist];
		[self didStopUsingParser];
	}

	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


// When the parser is deselected, then get rid of the cached plist data. It will be loaded into memory lazily 
// once it is needed again...

- (void) didStopUsingParser
{
	@synchronized(self)
	{
		self.plist = nil;
	}	
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helper Methods


// Load the XML file into a plist lazily (on demand). If we notice that an existing cached plist is  
// out-of-date we get rid of it and load it anew...

- (NSDictionary*) plist
{
	NSDictionary* plist = nil;
	NSError* error = nil;
	NSString* path = (NSString*)self.mediaSource;
	NSDictionary* metadata = [[NSFileManager threadSafeManager] attributesOfItemAtPath:path error:&error];
	NSDate* modificationDate = [metadata objectForKey:NSFileModificationDate];
	
	@synchronized(self)
	{
		if ([self.modificationDate compare:modificationDate] == NSOrderedAscending)
		{
			self.plist = nil;
		}
		
		if (_plist == nil)
		{
			self.plist = [NSDictionary dictionaryWithContentsOfFile:(NSString*)self.mediaSource];
			self.modificationDate = modificationDate;
		}
		
		plist = [[_plist retain] autorelease];
	}
	
	return plist;
}


//----------------------------------------------------------------------------------------------------------------------


// Create a unique identifier for a node specified by the plist dictionary...

- (NSString*) identifierForPlist:(NSDictionary*)inPlist
{
	NSString* uuid = [inPlist objectForKey:@"WebBookmarkUUID"];
	return [self identifierForPath:[NSString stringWithFormat:@"/%@",uuid]];
}


// A node is a leaf if it doesn't contain any subnodes...

- (BOOL) isLeafPlist:(NSDictionary*)inPlist
{
	BOOL isLeaf = YES;
	NSString* type = [inPlist objectForKey:@"WebBookmarkType"];
	
	if ([type isEqualToString:@"WebBookmarkTypeList"])
	{
		NSArray* childrenPlist = [inPlist objectForKey:@"Children"];
		for (NSDictionary* childPlist in childrenPlist)
		{
			type = [childPlist objectForKey:@"WebBookmarkType"];
			if ([type isEqualToString:@"WebBookmarkTypeList"])
			{
				isLeaf = NO;
			}
		}
	}
	
	return isLeaf;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) populateNode:(IMBNode*)inNode plist:(NSDictionary*)inPlist
{
	if (inNode.subNodes == nil)
	{
		inNode.subNodes = [NSMutableArray array];
	}
	
	if (inNode.objects == nil)
	{
		inNode.objects = [NSMutableArray array];
	}
	
	NSArray* childrenPlist = [inPlist objectForKey:@"Children"];
	NSUInteger index = 0;
	
	for (NSDictionary* childPlist in childrenPlist)
	{
		IMBNode* subnode = [self subnodeForPlist:childPlist];
		
		if (subnode)
		{
			subnode.parentNode = inNode;
			[self populateNode:subnode plist:childPlist];
			[(NSMutableArray*)inNode.subNodes addObject:subnode];
		}	
		
		IMBObject* object = [self objectForPlist:childPlist];
		
		if (object)
		{
			object.index = index++;
			[(NSMutableArray*)inNode.objects addObject:object];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (IMBNode*) subnodeForPlist:(NSDictionary*)inPlist 
{
	IMBNode* subnode = nil;
	
	NSString* type = [inPlist objectForKey:@"WebBookmarkType"];
	if ([type isEqualToString:@"WebBookmarkTypeList"])
	{
		NSString* title = [inPlist objectForKey:@"Title"];
		NSImage* icon = [NSImage genericFolderIcon];
		[icon setScalesWhenResized:YES];
		[icon setSize:NSMakeSize(16.0,16.0)];

		subnode = [[[IMBNode alloc] init] autorelease];
		subnode.mediaSource = self.mediaSource;
		subnode.parser = self;
		subnode.leaf = [self isLeafPlist:inPlist];
		subnode.identifier = [self identifierForPlist:inPlist];
		subnode.icon = icon;
		subnode.name = title;
	}
	
	return subnode;
}


//----------------------------------------------------------------------------------------------------------------------


- (IMBObject*) objectForPlist:(NSDictionary*)inPlist 
{
	IMBObject* object = nil;
	
	NSString* type = [inPlist objectForKey:@"WebBookmarkType"];
	if ([type isEqualToString:@"WebBookmarkTypeLeaf"])
	{
		NSDictionary* uri = [inPlist objectForKey:@"URIDictionary"];
		NSString* title = [uri objectForKey:@"title"];
		NSString* urlString = [inPlist objectForKey:@"URLString"];
		NSURL* url = [NSURL URLWithString:urlString];
		
		object = [[[IMBObject alloc] init] autorelease];
		object.location = (id)url;
		object.name = title;
		object.parser = self;

		NSImage* icon = [[WebIconDatabase sharedIconDatabase] 
			iconForURL:urlString
			withSize:NSMakeSize(16,16)
			cache:YES];
					
		object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
		object.imageRepresentation = icon;
	}
	
	return object;
}


//----------------------------------------------------------------------------------------------------------------------


@end
