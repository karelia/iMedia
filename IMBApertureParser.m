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

#import "IMBApertureParser.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBIconCache.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBApertureParser ()

- (NSDictionary*) plist;
- (NSString*) identifierWithAlbumId:(NSNumber*)inAlbumId;
- (IMBNode*) subNodeWithIdentifier:(NSString*)inIdentfier withRoot:(IMBNode*)inRootNode;
- (BOOL) allowAlbumType:(NSString*)inAlbumType;
- (NSImage*) iconForAlbumType:(NSString*)inType;
- (BOOL) isLeafAlbumType:(NSString*)inType;
- (void) addSubNodesToNode:(IMBNode*)inParentNode listOfAlbums:(NSArray*)inListOfAlbums listOfImages:(NSDictionary*)inListOfImages;
- (void) populateNode:(IMBNode*)inNode listOfAlbums:(NSArray*)inListOfAlbums listOfImages:(NSDictionary*)inListOfImages;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBApertureParser

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


// Check if Aperture is installed...

+ (NSString*) aperturePath
{
	return [[NSWorkspace threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.Aperture"];
}


+ (BOOL) isInstalled
{
	return [self aperturePath] != nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Look at the iApps preferences file and find all iPhoto libraries. Create a parser instance for each libary...

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];

	if ([self isInstalled])
	{
		CFArrayRef apertureLibraries = CFPreferencesCopyAppValue((CFStringRef)@"ApertureLibraries",(CFStringRef)@"com.apple.iApps");
		NSArray* libraries = (NSArray*)apertureLibraries;

		for (NSString* library in libraries)
		{
			NSURL* url = [NSURL URLWithString:library];
			NSString* path = [url path];

			IMBApertureParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
			parser.mediaSource = path;
			parser.shouldDisplayLibraryName = libraries.count > 1;
			[parserInstances addObject:parser];
			[parser release];
		}
		
		if (apertureLibraries) CFRelease(apertureLibraries);
	}
	
	return parserInstances;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.appPath = [[self class] aperturePath];
		self.plist = nil;
		self.modificationDate = nil;
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
		node.parentNode = inOldNode.parentNode;
		node.mediaSource = self.mediaSource;
		node.identifier = [self identifierForPath:@"/AlbumId/1"];
		node.name = @"Aperture";
		node.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:self.appPath];
		node.groupType = kIMBGroupTypeLibrary;
		node.parser = self;
		node.leaf = NO;
	}
	
	// Or a subnode...
	
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
	
	// Watch the XML file. Whenever something in Aperture changes, we have to replace the
	// WHOLE node tree, as we have no way of finding WHAT has changed inside the library...
	
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
	
	NSArray* listOfAlbums = [self.plist objectForKey:@"List of Albums"];
	NSDictionary* listOfImages = [self.plist objectForKey:@"Master Image List"];
	[self addSubNodesToNode:inNode listOfAlbums:listOfAlbums listOfImages:listOfImages]; 
	[self populateNode:inNode listOfAlbums:listOfAlbums listOfImages:listOfImages]; 

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


// Create an identifier from the AlbumID that is stored in the XML file. An example is "IMBApertureParser://AlbumId/17"...

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


// Exclude some album types...

- (BOOL) allowAlbumType:(NSString*)inAlbumType
{
	if ([inAlbumType isEqualToString:@"99"]) return NO;
//	if ([inAlbumType isEqualToString:@"98"]) return NO;
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) iconForAlbumType:(NSString*)inType
{
	// '12' ???
	// cp: I found icons for a 'smart journal' or a 'smart book' but no menu command to create on.
	
	static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
		{@"1",	@"Project_I_Album.tiff",			@"folder",	nil,	nil},	// album
		{@"2",	@"Project_I_SAlbum.tiff",			@"folder",	nil,	nil},	// smart album
		{@"3",	@"List_Icons_LibrarySAlbum.tiff",	@"folder",	nil,	nil},	// library **** ... 200X
		{@"4",	@"Project_I_Project.tiff",			@"folder",	nil,	nil},	// project
		{@"5",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (top level)
		{@"6",	@"Project_I_Folder.tiff",			@"folder",	nil,	nil},	// folder
		{@"7",	@"Project_I_ProjectFolder.tiff",	@"folder",	nil,	nil},	// sub-folder of project
		{@"8",	@"Project_I_Book.tiff",				@"folder",	nil,	nil},	// book
		{@"9",	@"Project_I_WebPage.tiff",			@"folder",	nil,	nil},	// web gallery
		{@"9",	@"Project_I_WebGallery.tiff",		@"folder",	nil,	nil},	// web gallery (alternate image)
		{@"10",	@"Project_I_WebJournal.tiff",		@"folder",	nil,	nil},	// web journal
		{@"11",	@"Project_I_LightTable.tiff",		@"folder",	nil,	nil},	// light table
		{@"13",	@"Project_I_SWebGallery.tiff",		@"folder",	nil,	nil},	// smart web gallery
		{@"97",	@"Project_I_Projects.tiff",			@"folder",	nil,	nil},	// library
		{@"98",	@"AppIcon.icns",					@"folder",	nil,	nil},	// library
		{@"99",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (knot holding all images)
	};

	static const IMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"1",	@"Project_I_Album.tiff",			@"folder",	nil,	nil}	// fallback image
	};

	return [[IMBIconCache sharedIconCache] iconForType:inType fromBundleID:@"com.apple.Aperture" withMappingTable:&kIconTypeMapping];
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) isLeafAlbumType:(NSString*)inType
{
	NSInteger type = [inType integerValue];
	
	switch (type)
	{
		case 1:	 return YES;
		case 2:	 return YES;
		case 3:	 return YES;
		case 4:	 return NO;
		case 5:	 return NO;
		case 6:	 return NO;
		case 7:	 return NO;
		case 8:	 return YES;
		case 9:	 return YES;
		case 10: return YES;
		case 11: return YES;
		case 13: return YES;
		case 97: return NO;
		case 98: return NO;
		case 99: return NO;
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) addSubNodesToNode:(IMBNode*)inParentNode
		 listOfAlbums:(NSArray*)inListOfAlbums
		 listOfImages:(NSDictionary*)inListOfImages
{
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subNodes = (NSMutableArray*) inParentNode.subNodes;
	if (subNodes == nil) inParentNode.subNodes = subNodes = [NSMutableArray array];

	// Now parse the Aperture XML plist and look for albums whose parent matches our parent node. We are 
	// only going to add subnodes that are direct children of inParentNode...
	
	for (NSDictionary* albumDict in inListOfAlbums)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSString* albumType = [albumDict objectForKey:@"Album Type"];
		NSString* albumName = [albumDict objectForKey:@"AlbumName"];
		NSNumber* parentId = [albumDict objectForKey:@"Parent"];
		NSString* parentIdentifier = parentId ? [self identifierWithAlbumId:parentId] : [self identifierForPath:@"/"];
		
		if ([self allowAlbumType:albumType] && [inParentNode.identifier isEqualToString:parentIdentifier])
		{
			// Create node for this album...
			
			IMBNode* albumNode = [[[IMBNode alloc] init] autorelease];
			
			albumNode.leaf = [self isLeafAlbumType:albumType];
			albumNode.icon = [self iconForAlbumType:albumType];
			albumNode.name = albumName;
			albumNode.mediaSource = self.mediaSource;
			albumNode.parser = self;

			// Set the node's identifier. This is needed later to link it to the correct parent node...
			
			NSNumber* albumId = [albumDict objectForKey:@"AlbumId"];
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
{
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = (NSMutableArray*) inNode.objects;
	if (objects == nil) inNode.objects = objects = [NSMutableArray array];

	// Look for the correct album in the Aperture XML plist. Once we find it, populate the node with IMBVisualObjects
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
			
				if (imageDict!=nil && ([mediaType isEqualToString:@"Image"] || mediaType==nil))
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
