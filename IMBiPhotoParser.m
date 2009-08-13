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

#import "IMBiPhotoParser.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBiPhotoParser ()

- (BOOL) allowAlbumType:(NSString*)inAlbumType;
- (NSString*) identifierWithAlbumId:(NSNumber*)inAlbumId;
- (IMBNode*) subNodeWithIdentifier:(NSString*)inIdentfier withRoot:(IMBNode*)inRootNode;
- (void) addSubNodesToNode:(IMBNode*)inParentNode listOfAlbums:(NSArray*)inListOfAlbums listOfImages:(NSDictionary*)inListOfImages;
- (void) populateNode:(IMBNode*)inNode listOfAlbums:(NSArray*)inListOfAlbums listOfImages:(NSDictionary*)inListOfImages iPhotoMediaType:(NSString*)iPhotoMediaType;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiPhotoParser

@synthesize plist = _plist;


//----------------------------------------------------------------------------------------------------------------------


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBPhotosMediaType];
	[pool release];
}


// Find the path to the first iPhoto library...
		
+ (NSString*) iPhotoLibraryPath
{
	NSString* path = nil;
	CFArrayRef recentLibraries = CFPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",(CFStringRef)@"com.apple.iApps");
	NSArray* libraries = (NSArray*)recentLibraries;
		
	for (NSString* library in libraries)
	{
		NSURL* url = [NSURL URLWithString:library];
		path = [url path];
		break;
	}
	
	CFRelease(recentLibraries);
	
	return path;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		_plist = nil;
		_fakeAlbumID = 0;
		
		self.mediaSource = [[self class] iPhotoLibraryPath];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_plist);
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
	
	// Create an empty root node (without subnodes, but with empty objects array)...
	
	IMBNode* rootNode = [[[IMBNode alloc] init] autorelease];
	
	rootNode.parentNode = inOldNode.parentNode;
	rootNode.mediaSource = self.mediaSource;
	rootNode.identifier = [self identifierForPath:@"/"];
	rootNode.name = @"iPhoto";
//	rootNode.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:path];
	rootNode.parser = self;
	rootNode.leaf = NO;

	// Watch the root node via UKKQueue. Whenever something in iPhoto changes, we have to replace the
	// WHOLE node tree, as we have no way of finding WHAT has changed in iPhoto...
	
	if (rootNode.parentNode == nil)
	{
		rootNode.watcherType = kIMBWatcherTypeKQueue;
		rootNode.watchedPath = (NSString*)rootNode.mediaSource;
	}
	else
	{
		rootNode.watcherType = kIMBWatcherTypeNone;
	}
	
	// If the old node was populated, then also populate the new node...
	
	if (inOldNode.subNodes.count > 0 || inOldNode.objects.count > 0)
	{
		[self populateNode:rootNode options:inOptions error:&error];
	}
	
	if (outError) *outError = error;
	return rootNode;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation. Parse the 
// iPhoto XML file and create subnodes as needed...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	NSArray* listOfAlbums = [self.plist objectForKey:@"List of Albums"];
	NSDictionary* listOfImages = [self.plist objectForKey:@"Master Image List"];
	[self addSubNodesToNode:inNode listOfAlbums:listOfAlbums listOfImages:listOfImages]; 
	[self populateNode:inNode listOfAlbums:listOfAlbums listOfImages:listOfImages iPhotoMediaType:@"Image"]; 

	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Load the XML file into a plist lazily (on demand)...

- (NSDictionary*) plist
{
	if (_plist == nil)
	{
		self.plist = [NSDictionary dictionaryWithContentsOfFile:(NSString*)self.mediaSource];
	}
	
	return _plist;
}


//----------------------------------------------------------------------------------------------------------------------


// Exclude some album types...

- (BOOL) allowAlbumType:(NSString*)inAlbumType
{
	if (inAlbumType == nil) return YES;
	if ([inAlbumType isEqualToString:@"Slideshow"]) return NO;
	if ([inAlbumType isEqualToString:@"Book"]) return NO;
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// Create an identifier from the AlbumID that is stored in the XML file. An example is "IMBiPhotoParser://AlbumId/17"...

- (NSString*) identifierWithAlbumId:(NSNumber*)inAlbumId
{
	NSString* albumPath = [NSString stringWithFormat:@"/AlbumId/%@",inAlbumId];
	return [self identifierForPath:albumPath];
}


//----------------------------------------------------------------------------------------------------------------------


// Look in our node tree for a node with the specified identifier...

- (IMBNode*) subNodeWithIdentifier:(NSString*)inIdentfier withRoot:(IMBNode*)inRootNode
{
	if ([inRootNode.identifier isEqualToString:inIdentfier])
	{
		return inRootNode;
	}
	
	for (IMBNode* subnode in inRootNode.subNodes)
	{
		IMBNode* found = [self subNodeWithIdentifier:inIdentfier withRoot:subnode];
		if (found) return found;
	}

	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) addSubNodesToNode:(IMBNode*)inParentNode
		 listOfAlbums:(NSArray*)inListOfAlbums
		 listOfImages:(NSDictionary*)inListOfImages
{
	// Create the subNodes array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* subNodes = (NSMutableArray*) inParentNode.subNodes;
	if (subNodes == nil) inParentNode.subNodes = subNodes = [NSMutableArray array];

	// Now parse the iPhoto XML plist and look for albums whose parent matches our parent node. We are only
	// going to add subnodes that are direct children of inParentNode...
	
	for (NSDictionary* albumDict in inListOfAlbums)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSString* albumType = [albumDict objectForKey:@"Album Type"];
		NSNumber* parentId = [albumDict objectForKey:@"Parent"];
		NSString* parentIdentifier = parentId ? [self identifierWithAlbumId:parentId] : [self identifierForPath:@"/"];
		
		if ([self allowAlbumType:albumType] && [inParentNode.identifier isEqualToString:parentIdentifier])
		{
			// Create node for this album...
			
			IMBNode* albumNode = [[[IMBNode alloc] init] autorelease];
			
			albumNode.mediaSource = self.mediaSource;
			albumNode.name = [albumDict objectForKey:@"AlbumName"];
//			albumNode.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:path];	// Depends on album type
			albumNode.parser = self;
			albumNode.leaf = ![albumType isEqualToString:@"Folder"];

			// Set the node's identifier. This is needed later to link it to the correct parent node. Please note 
			// that older versions of iPhoto didn't have AlbumId, so we are generating fake AlbumIds in this case
			// for backwards compatibility...
			
			NSNumber* albumId = [albumDict objectForKey:@"AlbumId"];
			if (albumId == nil) albumId = [NSNumber numberWithInt:_fakeAlbumID++]; 
			albumNode.identifier = [self identifierWithAlbumId:albumId];

			// Add the new album node to its parent (inRootNode)...
			
			[subNodes addObject:albumNode];
			albumNode.parentNode = inParentNode;
		}
		
		[pool release];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (void) populateNode:(IMBNode*)inNode
		 listOfAlbums:(NSArray*)inListOfAlbums
		 listOfImages:(NSDictionary*)inListOfImages
		 iPhotoMediaType:(NSString*)iPhotoMediaType	// this mediaType is special to iPhoto, not the same as IMB mediaType!
{
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = (NSMutableArray*) inNode.objects;
	if (objects == nil) inNode.objects = objects = [NSMutableArray array];

	// Look for the correct album in the iPhoto XML plist. Once we find it, populate the node with IMBVisualObjects
	// for each image in this album...
	
	for (NSDictionary* albumDict in inListOfAlbums)
	{
		NSAutoreleasePool* pool1 = [[NSAutoreleasePool alloc] init];
		NSNumber* albumId = [albumDict objectForKey:@"AlbumId"];
		NSString* albumIdentifier = albumId ? [self identifierWithAlbumId:albumId] : [self identifierForPath:@"/"];
		
		if ([inNode.identifier isEqualToString:albumIdentifier])
		{
			NSArray* imageKeys = [albumDict objectForKey:@"KeyList"];

			for (NSString* key in imageKeys)
			{
				NSAutoreleasePool* pool2 = [[NSAutoreleasePool alloc] init];
				NSDictionary* imageDict = [inListOfImages objectForKey:key];
				NSString* mediaType = [imageDict objectForKey:@"MediaType"];
			
				if (imageDict!=nil && ([mediaType isEqualToString:iPhotoMediaType] || mediaType==nil))
				{
					NSString* imagePath = [imageDict objectForKey:@"ImagePath"];
					NSString* thumbPath = [imageDict objectForKey:@"ThumbPath"];
					NSString* caption   = [imageDict objectForKey:@"Caption"];
	
					IMBVisualObject* object = [[IMBVisualObject alloc] init];
					[objects addObject:object];
					[object release];

					object.value = (id)imagePath;
					object.name = caption;
					object.imageRepresentationType = IKImageBrowserPathRepresentationType;
					object.imageRepresentation = (thumbPath!=nil) ? thumbPath : imagePath;
					object.metadata = imageDict;
				}
				
				[pool2 release];
			}
			
		}
		
		[pool1 release];
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end
