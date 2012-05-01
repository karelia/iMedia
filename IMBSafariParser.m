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


//----------------------------------------------------------------------------------------------------------------------


// Author: Peter Baumgartner, Dan Wood


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBSafariParser.h"
#import "IMBNode.h"
#import "IMBLinkObject.h"
#import "IMBFolderObject.h"
#import "NSImage+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


@interface IMBSafariParser ()
- (NSDictionary*) plist;
- (NSString*) identifierForPlist:(NSDictionary*)inPlist;
- (BOOL) isLeafPlist:(NSDictionary*)inPlist;
- (void) populateNode:(IMBNode*)inNode plist:(NSDictionary*)inPlist;
- (IMBNode*) subnodeForPlist:(NSDictionary*)inPlist;
- (IMBObject*) objectForPlist:(NSDictionary*)inPlist;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBSafariParser

@synthesize appPath = _appPath;
@synthesize plist = _plist;
@synthesize modificationDate = _modificationDate;
@synthesize safariFaviconCache = _safariFaviconCache;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		self.appPath = nil;
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


- (IMBNode*) unpopulatedTopLevelNode:(NSError**)outError
{
	NSURL* url = (NSURL*)self.mediaSource;
	NSString* path = [url path];

	NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:self.appPath];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(16.0,16.0)];
	
	// Create an empty (unpopulated) root node...
	
	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	node.icon = icon;
	node.name = @"Safari";
	node.identifier = [self identifierForPath:@"/"];
	node.mediaType = self.mediaType;
	node.mediaSource = self.mediaSource;
	node.groupType = kIMBGroupTypeLibrary;
	node.parserIdentifier = self.identifier;
	node.isTopLevelNode = YES;
	node.isLeafNode = NO;

	// Watch the XML file. Whenever something in iTunes changes, we have to replace the WHOLE tree from  
	// the root node down, as we have no way of finding WHAT has changed in iPhoto...
	
	node.watcherType = kIMBWatcherTypeFSEvent;
	node.watchedPath = [path stringByDeletingLastPathComponent];
	
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	if (inNode.isTopLevelNode)
	{
		NSDictionary* plist = [self plist];
		[self populateNode:inNode plist:plist];
	}

	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// Since we know that we have local files we can use the helper method supplied by the base class...

- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helper Methods


// Load the XML file into a plist lazily (on demand). If we notice that an existing cached plist is  
// out-of-date we get rid of it and load it anew...

- (NSDictionary*) plist
{
	NSDictionary* plist = nil;
	NSURL* url = (NSURL*)self.mediaSource;
	
    NSDate* modificationDate;
    if (![url getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:NULL]) modificationDate = nil;
	
	@synchronized(self)
	{
		if ([self.modificationDate compare:modificationDate] == NSOrderedAscending)
		{
			self.plist = nil;
		}
		
		if (_plist == nil)
		{
			self.plist = [NSDictionary dictionaryWithContentsOfURL:url];
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
	NSMutableArray* subnodes = [inNode mutableArrayForPopulatingSubnodes];
	NSMutableArray* objects = [NSMutableArray array];
	
	NSArray* childrenPlist = [inPlist objectForKey:@"Children"];
	NSUInteger index = 0;
	
	for (NSDictionary* childPlist in childrenPlist)
	{
		IMBNode* subnode = [self subnodeForPlist:childPlist];
		
		if (subnode)
		{
			if ([inNode isTopLevelNode])
			{
				NSImage* newImage = nil;
				
				if ([subnode.name isEqualToString:@"BookmarksMenu"])
				{
					subnode.name = NSLocalizedStringWithDefaultValue(
						@"IMBSafariBookmarkParser.bookmarksMenu",
						nil,IMBBundle(),
						@"Bookmarks Menu",
						@"top-level bookmark name");
							  
					newImage = [NSImage 
						imb_imageResourceNamed:@"tiny_menu.tiff"
						fromApplication:@"com.apple.Safari"
						fallbackTo:nil];
					
				}
				else if ([subnode.name isEqualToString:@"BookmarksBar"])
				{
					subnode.name = NSLocalizedStringWithDefaultValue(
						@"IMBSafariBookmarkParser.bookmarksBar",
						nil,IMBBundle(),
						@"Bookmarks Bar",
						@"top-level bookmark name");
					
					newImage = [NSImage 
						imb_imageResourceNamed:@"FavoritesBar.tif"
						fromApplication:@"com.apple.Safari"
						fallbackTo:nil];
				}
				
				if (newImage)
				{
					subnode.icon = newImage;
				}
			}
			
			[self populateNode:subnode plist:childPlist];
			[subnodes addObject:subnode];
		}	
		
		IMBObject* object = [self objectForPlist:childPlist];
		
		if (object)
		{
			object.index = index++;
			[objects addObject:object];
		}
	}
	
	inNode.objects = objects;
}


//----------------------------------------------------------------------------------------------------------------------


- (IMBNode*) subnodeForPlist:(NSDictionary*)inPlist 
{
	IMBNode* subnode = nil;
	NSString* type = [inPlist objectForKey:@"WebBookmarkType"];
	
	if ([type isEqualToString:@"WebBookmarkTypeList"])
	{
		NSString* title = [inPlist objectForKey:@"Title"];
		NSImage* icon = [NSImage imb_sharedGenericFolderIcon];

		subnode = [[[IMBNode alloc] init] autorelease];
		subnode.mediaSource = self.mediaSource;
		subnode.mediaType = self.mediaType;
		subnode.parserIdentifier = self.identifier;
		subnode.isLeafNode = [self isLeafPlist:inPlist];
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
				
		object = [[[IMBLinkObject alloc] init] autorelease];
		
		if (url)
		{
			object.location = url;
			object.imageRepresentationType = IKImageBrowserNSURLRepresentationType;
		}
		else
		{
			object.location = [NSURL fileURLWithPath:urlString];	// url may not have been formed from string
			object.imageRepresentationType = IKImageBrowserPathRepresentationType;
		}
		
		object.name = title;
		object.parserIdentifier = self.identifier;
	}
	else if ([type isEqualToString:@"WebBookmarkTypeList"])
	{
		IMBNode* subnode = [self subnodeForPlist:inPlist];
		subnode.isIncludedInPopup = NO;

		NSString* title = [inPlist objectForKey:@"Title"];		// Capitalized for list, lowercase for leaves?

		object = [[[IMBFolderObject alloc] init] autorelease];
		object.name = title;
		object.parserIdentifier = self.identifier;
		((IMBFolderObject*)object).representedNodeIdentifier = subnode.identifier;
	}
	
	return object;
}


//----------------------------------------------------------------------------------------------------------------------


@end
