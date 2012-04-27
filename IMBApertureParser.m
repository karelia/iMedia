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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBApertureParser.h"

#import "IMBApertureHeaderViewController.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBIconCache.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBApertureParser ()

- (NSString*) identifierForId:(NSNumber*) inId inSpace:(NSString*) inIdSpace;
- (NSString*) rootNodeIdentifier;
- (BOOL) shouldUseAlbumType:(NSString*)inAlbumType;
- (BOOL) isLeafAlbumType:(NSString*)inType;
- (NSImage*) iconForAlbumType:(NSString*)inType;
- (NSArray*) keylistForAlbum:(NSDictionary*)inAlbumDict;
- (BOOL) shouldUseObject:(NSString*)inObjectType;
- (void) addSubNodesToNode:(IMBNode*)inParentNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages;
- (void) populateNode:(IMBNode*)inNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBApertureParser

@synthesize placeholderParser = _placeholderParser;
@synthesize shouldDisplayLibraryName = _shouldDisplayLibraryName;
@synthesize version = _version;


//----------------------------------------------------------------------------------------------------------------------


// Check if Aperture is installed...

+ (NSString*) aperturePath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.Aperture"];
}


+ (BOOL) isInstalled
{
	return [self aperturePath] != nil;
}


// Returns name of library

+ (NSString *)libraryName
{
    return @"Aperture";
}


//----------------------------------------------------------------------------------------------------------------------


// Look at the iApps preferences file and find all iPhoto libraries. Create a parser instance for each libary...

//+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
//{
//	NSMutableArray* parserInstances = [NSMutableArray array];
//
//	if ([self isInstalled])
//	{
//		CFArrayRef apertureLibraries = CFPreferencesCopyAppValue((CFStringRef)@"ApertureLibraries",(CFStringRef)@"com.apple.iApps");
//		NSArray* libraries = (NSArray*)apertureLibraries;
//
//		for (NSString* library in libraries)
//		{
//			NSURL* url = [NSURL URLWithString:library];
//			NSString* path = [url path];
//			BOOL changed;
//			(void) [[NSFileManager imb_threadSafeManager] imb_fileExistsAtPath:&path wasChanged:&changed];
//
//			IMBApertureParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
//			parser.mediaSource = path;
//			parser.shouldDisplayLibraryName = libraries.count > 1;
//			[parserInstances addObject:parser];
//			[parser release];
//		}
//		
//		if (apertureLibraries) CFRelease(apertureLibraries);
//		
//		if ([parserInstances count] == 0) {
//			NSArray *keys = [NSArray arrayWithObjects:@"RKXMLExportManagerMode", @"LibraryPath", nil];
//			NSDictionary *preferences = (NSDictionary*) CFPreferencesCopyMultiple((CFArrayRef)keys, 
//																				   (CFStringRef)@"com.apple.Aperture", 
//																				   kCFPreferencesCurrentUser, 
//																				   kCFPreferencesAnyHost);
//			preferences = [NSMakeCollectable(preferences) autorelease];	
//
//			NSString *exportManagerMode = [preferences objectForKey:[keys objectAtIndex:0]];
//			NSString *libraryPath = [preferences objectForKey:[keys objectAtIndex:1]];
//			
//			if ((libraryPath != nil) && ([@"RKXMLExportManagerExportNeverKey" isEqual:exportManagerMode])) {
//				IMBApertureParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];
//				parser.placeholderParser = YES;
//				parser.mediaSource = libraryPath;
//				parser.shouldDisplayLibraryName = NO;
//				[parserInstances addObject:parser];
//				[parser release];
//			}
//		}
//	}
//	
//	return parserInstances;
//}
//

//----------------------------------------------------------------------------------------------------------------------


- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_plist);
	IMBRelease(_modificationDate);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark -
#pragma mark IMBParserProtocol

//----------------------------------------------------------------------------------------------------------------------
//

- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	NSDictionary* plist = self.plist;
	NSDictionary* images = [plist objectForKey:@"Master Image List"];
	
	// Population of events and faces node fundamentally different from album node
	
	if ([self isFacesNode:inNode]) {
		NSDictionary* faces = [plist objectForKey:@"List of Faces"];
		[self populateFacesNode:inNode withFaces:faces images:images];
	} else {
		NSArray* albums = [plist objectForKey:@"List of Albums"];
		[self addSubNodesToNode:inNode albums:albums images:images]; 
		[self populateNode:inNode albums:albums images:images]; 
	}

	return YES;
}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark -

//----------------------------------------------------------------------------------------------------------------------
// Placeholder parsers provide their own custom header view...

- (NSViewController*) customHeaderViewControllerForNode:(IMBNode*)inNode
{
	if (self.placeholderParser)
	{
		return [IMBApertureHeaderViewController headerViewControllerWithNode:inNode];
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helper Methods


//----------------------------------------------------------------------------------------------------------------------


- (NSInteger) version
{
	if (_version == 0)
	{
		_version = [[self.plist objectForKey:@"Application Version"] integerValue];
	}
	
	return _version;
}


//----------------------------------------------------------------------------------------------------------------------

// Create a unique identifier from the library path and the AlbumID that is stored in the XML file. 
// An example is "IMBApertureParser://123/Sample/AlbumId/17"...

- (NSString*) identifierForId:(NSNumber*) inId inSpace:(NSString*) inIdSpace
{
	NSString* path = [(NSURL *) self.mediaSource path];
	NSString* libraryName = [[[path stringByDeletingLastPathComponent] lastPathComponent] stringByDeletingPathExtension];
	
	NSString* nodePath = nil;
	if (inIdSpace)
	{
		nodePath = [NSString stringWithFormat:@"/%i/%@/%@/%@",[path hash],libraryName,inIdSpace,inId];
	} else {
		nodePath = [NSString stringWithFormat:@"/%i/%@/%@",[path hash],libraryName,inId];
	}
	
	return [self identifierForPath:nodePath];
}


// In Aperture 2 the root node always has the hardcoded AlbumID 1. In Aperture 3 however we are choosing a
// different node as root as there always seems to be an (empty) extra node (Album Type 5) inserted between
// the root and the nodes that we like to see at the first level. So we'll look for this type 5 album and
// return its id as the root node...

- (NSString*) rootNodeIdentifier
{
	// Aperture 2...
	
	if (self.version < 3)
	{
		return [self identifierForId:[NSNumber numberWithInt:1] inSpace:nil];
	}
	
	// Aperture 3...
	
	NSArray* albums = [self.plist objectForKey:@"List of Albums"];
	
	for (NSDictionary* albumDict in albums)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		NSString* albumType = [albumDict objectForKey:@"Album Type"];
		NSNumber* albumId = [albumDict objectForKey:@"AlbumId"];
		NSString* rootNodeIdentifier = nil;
		
		if ([albumType isEqualToString:@"5"])
		{
			rootNodeIdentifier = [[self identifierForId:albumId inSpace:nil] retain];
		}

		[pool drain];
		
		if (rootNodeIdentifier != nil)
		{
			return [rootNodeIdentifier autorelease];
		}
	}

	// Fallback if nothing is found...
	
	return [self identifierForId:[NSNumber numberWithInt:1] inSpace:nil];
}


//----------------------------------------------------------------------------------------------------------------------


// Exclude some album types. Specifically exclude all root albums as the root node has already
// been created by the parser during its first invocation...

- (BOOL) shouldUseAlbumType:(NSString*)inAlbumType
{
	if ([inAlbumType isEqualToString:@"5"]) return (self.version < 3);
	if ([inAlbumType isEqualToString:@"97"]) return NO;
	if ([inAlbumType isEqualToString:@"98"]) return NO;
	if ([inAlbumType isEqualToString:@"99"]) return NO;
	return YES;
}


// This method may be used to filter specific albums from the list
// (e.g. ones that don't have the correct media type).
// Always returns YES for now.

- (BOOL) shouldUseAlbum:(NSDictionary*)inAlbumDict images:(NSDictionary*)inImages
{
	return YES;
}


// Return YES indicating that an album should be a leaf node, i.e. that it does not have a disclosure triangle
// in the IMBOutlineView...

- (BOOL) isLeafAlbumType:(NSString*)inType
{
	NSInteger type = [inType integerValue];
	
	switch (type)
	{
		case 1:	 return YES;	// Album
		case 2:	 return YES;	// Smart album
		case 3:	 return YES;	// Smart album
		case 4:	 return NO;		// Project
		case 5:	 return NO;		// All projects
		case 6:	 return NO;		// Folder
		case 7:	 return NO;		// Folder
		case 8:	 return YES;	// Book
		case 9:	 return YES;	// Web page
		case 10: return YES;	// Web journal
		case 11: return YES;	// Lighttable
		case 13: return YES;	// Web gallery
		case 19: return YES;	// Slideshow
		case 94: return YES;	// Photos
		case 95: return YES;	// Flagged
		case 96: return NO;		// Smart albums
		case 97: return NO;		// Library
		case 98: return NO;		// Library
		case 99: return NO;		// Library (holding all images)
	}
	
	return [super isLeafAlbumType:inType];
}


//----------------------------------------------------------------------------------------------------------------------

// Returns whether the album dictionary provided represents the "photos" album

- (BOOL) isAllPhotosAlbum:(NSDictionary*)inAlbumDict
{
	return [[inAlbumDict objectForKey:@"uuid"] isEqualToString:@"allPhotosAlbum"];
}


//----------------------------------------------------------------------------------------------------------------------

// Returns whether the album dictionary provided represents the "Flagged" album

- (BOOL) isFlaggedAlbum:(NSDictionary*)inAlbumDict
{
    return [[inAlbumDict objectForKey:@"uuid"] isEqualToString:@"flaggedAlbum"];
}


//----------------------------------------------------------------------------------------------------------------------


// Icons for older Aperture versions...

- (NSImage*) iconForAlbumType2:(NSString*)inType
{
	static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
		{@"v2-1",	@"Project_I_Album.tiff",			@"folder",	nil,	nil},	// album
		{@"v2-2",	@"Project_I_SAlbum.tiff",			@"folder",	nil,	nil},	// smart album
		{@"v2-3",	@"List_Icons_LibrarySAlbum.tiff",	@"folder",	nil,	nil},	// library **** ... 200X
		{@"v2-4",	@"Project_I_Project.tiff",			@"folder",	nil,	nil},	// project
		{@"v2-5",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (top level)
		{@"v2-6",	@"Project_I_Folder.tiff",			@"folder",	nil,	nil},	// folder
		{@"v2-7",	@"Project_I_ProjectFolder.tiff",	@"folder",	nil,	nil},	// sub-folder of project
		{@"v2-8",	@"Project_I_Book.tiff",				@"folder",	nil,	nil},	// book
		{@"v2-9",	@"Project_I_WebPage.tiff",			@"folder",	nil,	nil},	// web gallery
		{@"v2-9",	@"Project_I_WebGallery.tiff",		@"folder",	nil,	nil},	// web gallery (alternate image)
		{@"v2-10",	@"Project_I_WebJournal.tiff",		@"folder",	nil,	nil},	// web journal
		{@"v2-11",	@"Project_I_LightTable.tiff",		@"folder",	nil,	nil},	// light table
		{@"v2-13",	@"Project_I_SWebGallery.tiff",		@"folder",	nil,	nil},	// smart web gallery
		{@"v2-97",	@"Project_I_Projects.tiff",			@"folder",	nil,	nil},	// library
		{@"v2-98",	@"AppIcon.icns",					@"folder",	nil,	nil},	// library
		{@"v2-99",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (knot holding all images)
	};

	static const IMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"v2-1",	@"Project_I_Album.tiff",			@"folder",	nil,	nil}	// fallback image
	};

	// Since icons are different for different versions of Aperture, we are adding the prefix v2- or v3- 
	// to the album type so that we can store different icons (for each version) in the icon cache...

	NSString* type = [@"v2-" stringByAppendingString:inType];
	return [[IMBIconCache sharedIconCache] iconForType:type fromBundleID:@"com.apple.Aperture" withMappingTable:&kIconTypeMapping];
}


// New icons for Aperture 3...

- (NSImage*) iconForAlbumType3:(NSString*)inType
{
	static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] =
	{
		{@"v3-Photo Stream",@"SL-stream.tiff",          @"folder",	nil,	nil},   // photo stream
		{@"v3-Faces",@"sl-icon-small_people.tiff",		@"folder",	nil,	nil},   // faces
		{@"v3-1",	@"SL-album.tiff",					@"folder",	nil,	nil},	// album
		{@"v3-2",	@"SL-smartAlbum.tiff",				@"folder",	nil,	nil},	// smart album
		{@"v3-3",	@"SL-smartAlbum.tiff",				@"folder",	nil,	nil},	// library **** ... 200X
		{@"v3-4",	@"SL-project.tiff",					@"folder",	nil,	nil},	// project
		{@"v3-5",	@"SL-allProjects.tiff",				@"folder",	nil,	nil},	// library (top level)
		{@"v3-6",	@"SL-folder.tiff",					@"folder",	nil,	nil},	// folder
		{@"v3-7",	@"SL-folder.tiff",					@"folder",	nil,	nil},	// sub-folder of project
		{@"v3-8",	@"SL-book.tiff",					@"folder",	nil,	nil},	// book
		{@"v3-9",	@"SL-webpage.tiff",					@"folder",	nil,	nil},	// web gallery
		{@"v3-9",	@"Project_I_WebGallery.tiff",		@"folder",	nil,	nil},	// web gallery (alternate image)
		{@"v3-10",	@"SL-webJournal.tiff",				@"folder",	nil,	nil},	// web journal
		{@"v3-11",	@"SL-lightTable.tiff",				@"folder",	nil,	nil},	// light table
		{@"v3-13",	@"sl-icon-small_webGallery.tiff",	@"folder",	nil,	nil},	// smart web gallery
		{@"v3-19",	@"SL-slideshow.tiff",				@"folder",	nil,	nil},	// slideshow
		{@"v3-94",	@"SL-photos.tiff",					@"folder",	nil,	nil},	// photos
		{@"v3-95",	@"SL-flag.tif",						@"folder",	nil,	nil},	// flagged
		{@"v3-96",	@"SL-smartLibrary.tiff",			@"folder",	nil,	nil},	// library albums
		{@"v3-97",	@"SL-allProjects.tiff",				@"folder",	nil,	nil},	// library
		{@"v3-98",	@"AppIcon.icns",					@"folder",	nil,	nil},	// library
		{@"v3-99",	@"List_Icons_Library.tiff",			@"folder",	nil,	nil},	// library (knot holding all images)
	};

	static const IMBIconTypeMapping kIconTypeMapping =
	{
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"1",	@"SL-album.tiff",					@"folder",	nil,	nil}	// fallback image
	};

	// Since icons are different for different versions of Aperture, we are adding the prefix v2- or v3- 
	// to the album type so that we can store different icons (for each version) in the icon cache...

	NSString* type = [@"v3-" stringByAppendingString:inType];
	return [[IMBIconCache sharedIconCache] iconForType:type fromBundleID:@"com.apple.Aperture" withMappingTable:&kIconTypeMapping];
}


- (NSImage*) iconForAlbumType:(NSString*)inType
{
	if (self.version < 3)
	{
		return [self iconForAlbumType2:inType];
	}
	else
	{
		return [self iconForAlbumType3:inType];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// The xml file has a list of albums. Each album contains a KeyList entry (array of images). However this list
// does not always seem to corresponds with what one sees in the Aperture UI itself. Instead there are albums
// in the xml that we do not want to display as a node, which do contain the images we need for another node.
// For this reason we need a mapping mechanism that lets us assign the KeyList of one album to another node.
// The following two methods provide this mecahism...

- (NSArray*) _keylistForAlbumType:(NSString*)inAlbumType
{
	NSArray* albums = [self.plist objectForKey:@"List of Albums"];

	for (NSDictionary* albumDict in albums)
	{
		NSString* albumType = [albumDict objectForKey:@"Album Type"];
		
		if ([albumType isEqualToString:inAlbumType])
		{
			return [albumDict objectForKey:@"KeyList"];
		}
	}
	
	return nil;
}


- (NSArray*) keylistForAlbum:(NSDictionary*)inAlbumDict
{
	NSString* albumType = [inAlbumDict objectForKey:@"Album Type"];
	
	// In Aperture 3 map keyList of album 99 to root node and Photos node...
	
//	if (self.version == 3)
//	{
		if ([albumType isEqualToString:@"98"])			// root node
		{
			return [self _keylistForAlbumType:@"99"];
		}
		else if ([albumType isEqualToString:@"5"])		// root node
		{
			return [self _keylistForAlbumType:@"99"];
		}
		else if ([albumType isEqualToString:@"94"])		// Photos node
		{
			return [self _keylistForAlbumType:@"99"];
		}
//	}
	
	// All other album just use their own key list...
	
	return [inAlbumDict objectForKey:@"KeyList"];
}


//----------------------------------------------------------------------------------------------------------------------


// Exclude everything but images...

- (BOOL) shouldUseObject:(NSString*)inObjectType
{
	return inObjectType==nil || [inObjectType isEqualToString:@"Image"];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) addSubNodesToNode:(IMBNode*)inParentNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages
{
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subNodes = [inParentNode mutableArrayForPopulatingSubnodes];

	// Now parse the Aperture XML plist and look for albums whose parent matches our parent node. We are 
	// only going to add subnodes that are direct children of inParentNode...
	
	for (NSDictionary* albumDict in inAlbums)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSString* albumType = [albumDict objectForKey:@"Album Type"];
		NSString* albumName = [albumDict objectForKey:@"AlbumName"];
		NSNumber* parentId = [albumDict objectForKey:@"Parent"];
		
		// Root node does not have an id space
		NSString* parentIdSpace = [inParentNode isTopLevelNode] ? nil : [self idSpaceForAlbumType:albumType];
		
		// parent always from same id space for non top-level albums
		NSString* parentIdentifier = parentId ? [self identifierForId:parentId inSpace:parentIdSpace] : [self identifierForPath:@"/"];
		
		if ([self shouldUseAlbumType:albumType] && [inParentNode.identifier isEqualToString:parentIdentifier])
		{
			// Create node for this album...
			
			IMBNode* albumNode = [[[IMBNode alloc] init] autorelease];
			
			albumNode.isLeafNode = [self isLeafAlbumType:albumType];
			albumNode.icon = [self iconForAlbumType:albumType];
			albumNode.name = albumName;
			albumNode.mediaSource = self.mediaSource;
			albumNode.parserIdentifier = self.identifier;

			// Set the node's identifier. This is needed later to link it to the correct parent node...
			
			NSNumber* albumId = [albumDict objectForKey:@"AlbumId"];
			albumNode.identifier = [self identifierForId:albumId inSpace:[self idSpaceForAlbumType:albumType]];
            
			// Keep a ref to the album dictionary for later use when we populate this node
			// so we don't have to loop through the whole album list again to find it.
			
			albumNode.attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    albumDict, @"nodeSource",
                                    [self nodeTypeForNode:albumNode], @"nodeType", nil];
			
			
			// Add the new album node to its parent (inRootNode)...
			
			[subNodes addObject:albumNode];
		}
		
		[pool drain];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (Class) objectClass
{
	return [IMBObject class];
}


// Returns an empty dictionary for now.
// TODO: Verify whether we need to return some "true" values for "KeyList", "KeyPhotoKey" and "PhotoCount"

- (NSDictionary*) childrenInfoForNode:(IMBNode*)inNode images:(NSDictionary*)inImages
{
    return [NSDictionary dictionaryWithObjectsAndKeys:nil];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) populateNode:(IMBNode*)inNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages
{
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];

	// Look for the correct album in the Aperture XML plist. Once we find it, populate the node with IMBVisualObjects
	// for each image in this album...
	
	Class objectClass = [self objectClass];
    NSUInteger index = 0;

	// We saved a reference to the album dictionary when this node was created
	// (ivar 'attributes') and now happily reuse it to save an outer loop (over album list) here.
	
	NSDictionary* albumDict = [inNode.attributes objectForKey:@"nodeSource"];

		NSAutoreleasePool* pool1 = [[NSAutoreleasePool alloc] init];
//			NSArray* imageKeys = [albumDict objectForKey:@"KeyList"];
			NSArray* imageKeys = [self keylistForAlbum:albumDict];

			for (NSString* key in imageKeys)
			{
				NSAutoreleasePool* pool2 = [[NSAutoreleasePool alloc] init];
				NSDictionary* objectDict = [inImages objectForKey:key];
				NSString* mediaType = [objectDict objectForKey:@"MediaType"];
			
				if (objectDict!=nil && [self shouldUseObject:mediaType])
				{
					NSString* path = [objectDict objectForKey:@"ImagePath"];
					NSString* thumbPath = [objectDict objectForKey:@"ThumbPath"];
					NSString* caption   = [objectDict objectForKey:@"Caption"];
                    NSMutableDictionary* preliminaryMetadata = [NSMutableDictionary dictionaryWithDictionary:objectDict];
                    
                    [preliminaryMetadata setObject:key forKey:@"VersionUUID"];
                    
					IMBObject* object = [[objectClass alloc] init];
					[objects addObject:object];
					[object release];

					object.location = (id)[NSURL fileURLWithPath:path isDirectory:NO];
					object.name = caption;
					object.preliminaryMetadata = preliminaryMetadata;	// This metadata from the XML file is available immediately
					object.metadata = nil;                              // Build lazily when needed (takes longer)
					object.metadataDescription = nil;                   // Build lazily when needed (takes longer)
					object.parserIdentifier = self.identifier;
					object.index = index++;

					object.imageLocation = thumbPath ? [NSURL fileURLWithPath:thumbPath isDirectory:NO] : object.location;
					object.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
					object.imageRepresentation = nil;
				}
				
				[pool2 drain];
			}
		
		[pool1 drain];
    
    inNode.objects = objects;
}


//----------------------------------------------------------------------------------------------------------------------


// Loaded lazily when actually needed for display. Here we combine the metadata we got from the Aperture XML file
// (which was available immediately, but not enough information) with more information that we obtain via ImageIO.
// This takes a little longer, but since it only done laziy for those object that are actually visible it's fine.
// Please note that this method may be called on a background thread...

- (void) loadMetadataForObject:(IMBObject*)inObject
{
	NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithDictionary:inObject.preliminaryMetadata];
	
	// Do not load (key) image specific metadata for node objects
	// because it doesn't represent the nature of the object well enough.
	
	if (![inObject isKindOfClass:[IMBNodeObject class]])
	{
		[metadata addEntriesFromDictionary:[NSImage imb_metadataFromImageAtPath:inObject.path checkSpotlightComments:NO]];
	}
    
	NSString* description = [self metadataDescriptionForMetadata:metadata];

	if ([NSThread isMainThread])
	{
		inObject.metadata = metadata;
		inObject.metadataDescription = description;
	}
	else
	{
		NSArray* modes = [NSArray arrayWithObject:NSRunLoopCommonModes];
		[inObject performSelectorOnMainThread:@selector(setMetadata:) withObject:metadata waitUntilDone:NO modes:modes];
		[inObject performSelectorOnMainThread:@selector(setMetadataDescription:) withObject:description waitUntilDone:NO modes:modes];
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end
