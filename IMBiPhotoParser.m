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
#import "IMBIconCache.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBiPhotoParser ()

- (NSString*) identifierWithAlbumId:(NSNumber*)inAlbumId;
- (BOOL) shouldUseAlbumType:(NSString*)inAlbumType;
- (NSImage*) iconForAlbumType:(NSString*)inAlbumType;
- (BOOL) isLeafAlbumType:(NSString*)inAlbumType;
- (void) addSubNodesToNode:(IMBNode*)inParentNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages;
- (void) populateNode:(IMBNode*)inNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages iPhotoMediaType:(NSString*)iPhotoMediaType;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiPhotoParser

@synthesize appPath = _appPath;
@synthesize plist = _plist;
@synthesize modificationDate = _modificationDate;
@synthesize shouldDisplayLibraryName = _shouldDisplayLibraryName;


//----------------------------------------------------------------------------------------------------------------------


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeImage];
	[pool release];
}


//----------------------------------------------------------------------------------------------------------------------


// Check if iPhoto is installed...

+ (NSString*) iPhotoPath
{
	return [[NSWorkspace threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.iPhoto"];
}


+ (BOOL) isInstalled
{
	return [self iPhotoPath] != nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Look at the iApps preferences file and find all iPhoto libraries. Create a parser instance for each libary...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];

	if ([self isInstalled])
	{
		CFArrayRef recentLibraries = CFPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",(CFStringRef)@"com.apple.iApps");
		NSArray* libraries = (NSArray*)recentLibraries;
			
		for (NSString* library in libraries)
		{
			NSURL* url = [NSURL URLWithString:library];
			NSString* path = [url path];

			IMBiPhotoParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
			parser.mediaSource = path;
			parser.shouldDisplayLibraryName = libraries.count > 1;
			[parserInstances addObject:parser];
			[parser release];
		}
		
		if (recentLibraries) CFRelease(recentLibraries);
	}
	
	return parserInstances;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.appPath = [[self class] iPhotoPath];
		self.plist = nil;
		self.modificationDate = nil;
		_fakeAlbumID = 0;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_plist);
	IMBRelease(_modificationDate);
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
	
	// Create a root node...
	
	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	
	if (inOldNode == nil)
	{
		node.parentNode = nil;
		node.mediaSource = self.mediaSource;
		node.identifier = [self identifierForPath:@"/"];
		node.name = @"iPhoto";
		node.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:self.appPath];
		node.groupType = kIMBGroupTypeLibrary;
		node.leaf = NO;
		node.parser = self;
		
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
	
	// If we have more than one library then append the library name to the root node...
	
	if (node.isRootNode && self.shouldDisplayLibraryName)
	{
		NSString* path = (NSString*)node.mediaSource;
		NSString* name = [[[path stringByDeletingLastPathComponent] lastPathComponent] stringByDeletingPathExtension];
		node.name = [NSString stringWithFormat:@"%@ (%@)",node.name,name];
	}

	// Watch the XML file. Whenever something in iPhoto changes, we have to replace the WHOLE tree from  
	// the root node down, as we have no way of finding WHAT has changed in iPhoto...
	
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


// The supplied node is a private copy which may be modified here in the background operation. Parse the 
// iPhoto XML file and create subnodes as needed...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	NSArray* albums = [self.plist objectForKey:@"List of Albums"];
	NSDictionary* images = [self.plist objectForKey:@"Master Image List"];
	[self addSubNodesToNode:inNode albums:albums images:images]; 
	[self populateNode:inNode albums:albums images:images iPhotoMediaType:@"Image"]; 

	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


// When the parser is deselected, then get rid of the cached plist data. It will be loaded into memory lazily 
// once it is needed again...

- (void) didDeselectParser
{
	self.plist = nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helper Methods


// Load the XML file into a plist lazily (on demand). If we notice that an existing cached plist is out-of-date 
// we get rid of it and load it anew...

- (NSDictionary*) plist
{
	NSError* error = nil;
	NSString* path = (NSString*)self.mediaSource;
	NSDictionary* metadata = [[NSFileManager threadSafeManager] attributesOfItemAtPath:path error:&error];
	NSDate* modificationDate = [metadata objectForKey:NSFileModificationDate];
	
	if ([self.modificationDate compare:modificationDate] == NSOrderedAscending)
	{
		self.plist = nil;
	}
	
	if (_plist == nil)
	{
		self.plist = [NSDictionary dictionaryWithContentsOfFile:(NSString*)self.mediaSource];
		self.modificationDate = modificationDate;
	}
	
	return _plist;
}


//----------------------------------------------------------------------------------------------------------------------


// Create an identifier from the AlbumID that is stored in the XML file. An example is "IMBiPhotoParser://AlbumId/17"...

- (NSString*) identifierWithAlbumId:(NSNumber*)inAlbumId
{
	NSString* albumPath = [NSString stringWithFormat:@"/AlbumId/%@",inAlbumId];
	return [self identifierForPath:albumPath];
}


//----------------------------------------------------------------------------------------------------------------------


// Exclude some album types...

- (BOOL) shouldUseAlbumType:(NSString*)inAlbumType
{
	if (inAlbumType == nil) return YES;
	if ([inAlbumType isEqualToString:@"Slideshow"]) return NO;
	if ([inAlbumType isEqualToString:@"Book"]) return NO;
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) iconForAlbumType:(NSString*)inAlbumType
{
	static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
		// iPhoto 7
		{@"Book",					@"sl-icon-small_book.tiff",				@"folder",	nil,				nil},
		{@"Calendar",				@"sl-icon-small_calendar.tiff",			@"folder",	nil,				nil},
		{@"Card",					@"sl-icon-small_card.tiff",				@"folder",	nil,				nil},
		{@"Event",					@"sl-icon-small_event.tiff",			@"folder",	nil,				nil},
		{@"Events",					@"sl-icon-small_events.tiff",			@"folder",	nil,				nil},
		{@"Folder",					@"sl-icon-small_folder.tiff",			@"folder",	nil,				nil},
		{@"Photocasts",				@"sl-icon-small_subscriptions.tiff",	@"folder",	nil,				nil},
		{@"Photos",					@"sl-icon-small_library.tiff",			@"folder",	nil,				nil},
		{@"Published",				@"sl-icon-small_publishedAlbum.tiff",	nil,		@"dotMacLogo.icns",	@"/System/Library/CoreServices/CoreTypes.bundle"},
		{@"Regular",				@"sl-icon-small_album.tiff",			@"folder",	nil,				nil},
		{@"Roll",					@"sl-icon-small_roll.tiff",				@"folder",	nil,				nil},
		{@"Selected Event Album",	@"sl-icon-small_event.tiff",			@"folder",	nil,				nil},
		{@"Shelf",					@"sl-icon_flag.tiff",					@"folder",	nil,				nil},
		{@"Slideshow",				@"sl-icon-small_slideshow.tiff",		@"folder",	nil,				nil},
		{@"Smart",					@"sl-icon-small_smartAlbum.tiff",		@"folder",	nil,				nil},
		{@"Special Month",			@"sl-icon-small_cal.tiff",				@"folder",	nil,				nil},
		{@"Special Roll",			@"sl-icon_lastImport.tiff",				@"folder",	nil,				nil},
		{@"Subscribed",				@"sl-icon-small_subscribedAlbum.tiff",	@"folder",	nil,				nil},
	};

	static const IMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"Regular",				@"sl-icon-small_album.tiff",			@"folder",	nil,				nil}	// fallback image
	};

	NSString* type = inAlbumType;
	if (type == nil) type = @"Photos";
	return [[IMBIconCache sharedIconCache] iconForType:type fromBundleID:@"com.apple.iPhoto" withMappingTable:&kIconTypeMapping];
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) isLeafAlbumType:(NSString*)inType
{
	return ![inType isEqualToString:@"Folder"];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) addSubNodesToNode:(IMBNode*)inParentNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages
{
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subNodes = (NSMutableArray*) inParentNode.subNodes;
	if (subNodes == nil) inParentNode.subNodes = subNodes = [NSMutableArray array];

	// Now parse the iPhoto XML plist and look for albums whose parent matches our parent node. We are 
	// only going to add subnodes that are direct children of inParentNode...
	
	for (NSDictionary* albumDict in inAlbums)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSString* albumType = [albumDict objectForKey:@"Album Type"];
		NSString* albumName = [albumDict objectForKey:@"AlbumName"];
		NSNumber* parentId = [albumDict objectForKey:@"Parent"];
		NSString* parentIdentifier = parentId ? [self identifierWithAlbumId:parentId] : [self identifierForPath:@"/"];
		
		if ([self shouldUseAlbumType:albumType] && [inParentNode.identifier isEqualToString:parentIdentifier])
		{
			// Create node for this album...
			
			IMBNode* albumNode = [[[IMBNode alloc] init] autorelease];
			
			albumNode.leaf = [self isLeafAlbumType:albumType];
			albumNode.icon = [self iconForAlbumType:albumType];
			albumNode.name = albumName;
			albumNode.mediaSource = self.mediaSource;
			albumNode.parser = self;

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
		 albums:(NSArray*)inAlbums 
		 images:(NSDictionary*)inImages
		 iPhotoMediaType:(NSString*)iPhotoMediaType	// this mediaType is special to iPhoto, not the same as IMB mediaType!
{
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = (NSMutableArray*) inNode.objects;
	if (objects == nil) inNode.objects = objects = [NSMutableArray array];

	// Look for the correct album in the iPhoto XML plist. Once we find it, populate the node with IMBVisualObjects
	// for each image in this album...
	
	for (NSDictionary* albumDict in inAlbums)
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
				NSDictionary* imageDict = [inImages objectForKey:key];
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
			
//			// If this is the "Photos" node, then assign the same object array to the parent node (iPhoto),
//			// so that selecting the parent node also displays all images...
//			
//			NSNumber* master = [albumDict objectForKey:@"Master"];
//			if ([master boolValue]) inNode.parentNode.objects = inNode.objects;
		}
		
		[pool1 release];
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end
