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


// Author: Jörg Jacobsen, Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBiPhotoParser.h"
#import "IMBNode.h"
#import "IMBiPhotoEventNodeObject.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSString+iMedia.h"
#import "IMBIconCache.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiPhotoParser

@synthesize shouldDisplayLibraryName = _shouldDisplayLibraryName;
@synthesize dateFormatter = _dateFormatter;


//----------------------------------------------------------------------------------------------------------------------

// Returns name of library

+ (NSString *)libraryName
{
    return @"iPhoto";
}


- (id) init
{
	if ((self = [super init]))
	{
		_fakeAlbumID = 0;
		
		NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
		formatter.dateStyle = NSDateFormatterShortStyle;
		self.dateFormatter = formatter;
		[formatter release];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_dateFormatter);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	NSDictionary* plist = self.plist;
	NSDictionary* images = [plist objectForKey:@"Master Image List"];
	NSArray* albums = [plist objectForKey:@"List of Albums"];
	
	// Population of events, faces, photo stream and regular album node fundamentally different
	
	if ([self isEventsNode:inNode])
	{
		NSArray* events = [plist objectForKey:@"List of Rolls"];
		[self populateEventsNode:inNode withEvents:events images:images];
	} 
	else if ([self isFacesNode:inNode])
	{
		NSDictionary* faces = [plist objectForKey:@"List of Faces"];
		[self populateFacesNode:inNode withFaces:faces images:images];
	} 
	else if ([self isPhotoStreamNode:inNode])
	{
		[self populatePhotoStreamNode:inNode images:images];
	} 
	else
	{
		[self addSubNodesToNode:inNode albums:albums images:images]; 
		[self populateAlbumNode:inNode images:images]; 
	}

	// If we are populating the root nodes, then also populate the "Photos" node and mirror its objects array 
	// into the objects array of the root node. Please note that this is non-standard parser behavior, which is 
	// implemented here, to achieve the desired "feel" in the browser...
	
	// Will find Photos node at same index in subnodes as in album list
	// which offset was it found, in "List of Albums" Array

    BOOL result = YES;
	NSUInteger photosNodeIndex = [self indexOfAllPhotosAlbumInAlbumList:albums];
	if (inNode.isTopLevelNode && photosNodeIndex != NSNotFound)
	{
		NSArray* subnodes = inNode.subnodes;
		if (photosNodeIndex < [subnodes count])	// Karelia case 136310, make sure offset exists
		{
			IMBNode* photosNode = [subnodes objectAtIndex:photosNodeIndex];	// assumes subnodes exists same as albums!
			result = [self populateNode:photosNode error:outError];
			inNode.objects = photosNode.objects;
		}
	}
	
	return result;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helper Methods


//----------------------------------------------------------------------------------------------------------------------

- (Class) objectClass
{
	return [IMBObject class];
}


// Returns the events node that should be subnode of our root node.
// Returns nil if there is none.

- (IMBNode*) eventsNodeInNode:(IMBNode*)inNode
{	
	IMBNode* eventsNode = nil;
	
	if (inNode.isTopLevelNode && [inNode.subnodes count]>0)
	{
		// We should find the events node at index 0 but this logic is more bullet proof.
		
		for (IMBNode* node in inNode.subnodes)
		{			
			if ([self isEventsNode:node])
			{
				eventsNode = node;
				break;
			}
		}
	}
	
	return eventsNode;
}


//----------------------------------------------------------------------------------------------------------------------


// This media type is specific to iPhoto and is not to be confused with kIMBMediaTypeImage...

- (NSString*) iPhotoMediaType
{
	return @"Image";
}


//----------------------------------------------------------------------------------------------------------------------


// Returns the identifier of the root node.

- (NSString*) rootNodeIdentifier
{
    return [self identifierForPath:@"/"];
}


// Create an identifier from the AlbumID that is stored in the XML file. An example is "IMBiPhotoParser://AlbumId/17"...

- (NSString*) identifierForId:(NSNumber*)inId inSpace:(NSString*)inIdSpace
{
	NSString* albumPath = [NSString stringWithFormat:@"/%@/%@",inIdSpace,inId];
	return [self identifierForPath:albumPath];
}


//----------------------------------------------------------------------------------------------------------------------


// iPhoto supports Photo Stream through AlbumData.xml since version 9.2.1

- (BOOL) supportsPhotoStreamFeatureInVersion:(NSString*)inVersion
{
    if (inVersion && inVersion.length > 0)
    {
        NSComparisonResult compareResult = [inVersion imb_finderCompare:@"9.2.1"];
        return (compareResult >= 0);
    }
    return NO;
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


// Check if the supplied album contains media files of correct media type. If we find a single one, then the 
// album qualifies as a new node. If however we do not find any media files of the desired type, then the 
// album will not show up as a node...

- (BOOL) shouldUseAlbum:(NSDictionary*)inAlbumDict images:(NSDictionary*)inImages
{
	// Usage of Events or Faces or Photo Stream album is not determined here
	
	NSUInteger albumId = [[inAlbumDict objectForKey:@"AlbumId"] unsignedIntegerValue];
	if (albumId == EVENTS_NODE_ID || albumId == FACES_NODE_ID || albumId == PHOTO_STREAM_NODE_ID)
	{
		return YES;
	}
	
	// Usage of other albums is determined by media type of key list images
	
	NSArray* imageKeys = [inAlbumDict objectForKey:@"KeyList"];
	
	for (NSString* key in imageKeys)
	{
		NSDictionary* imageDict = [inImages objectForKey:key];
		
		if ([self shouldUseObject:imageDict])
		{
			return YES;
		}
	}
	
	return NO;
}


// Check if a media file qualifies for this parser...

- (BOOL) shouldUseObject:(NSDictionary*)inObjectDict
{
	NSString* iPhotoMediaType = [self iPhotoMediaType];
	
	if (inObjectDict)
	{
		NSString* mediaType = [inObjectDict objectForKey:@"MediaType"];
		if (mediaType == nil) mediaType = @"Image";
		
		if ([mediaType isEqualToString:iPhotoMediaType])
		{
			return YES;
		}
	}
	
	return NO;
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
		{@"Faces",					@"sl-icon-small_people.tiff",			@"folder",	nil,				nil},
		{@"Flagged",				@"sl-icon-small_flag.tiff",				@"folder",	nil,				nil},
		{@"Folder",					@"sl-icon-small_folder.tiff",			@"folder",	nil,				nil},
		{@"Photo Stream",			@"sl-icon-small_photostream.tiff",		@"folder",	nil,				nil},
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


- (BOOL) isAllPhotosAlbum:(NSDictionary*)inAlbumDict
{
	return [(NSNumber *)[inAlbumDict objectForKey:@"Master"] unsignedIntegerValue] == 1;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) isFlaggedAlbum:(NSDictionary*)inAlbumDict
{
    NSString *albumType = [inAlbumDict objectForKey:@"Album Type"];
    
	return ([albumType isEqualTo:@"Shelf"] ||        // iPhoto 8
            [albumType isEqualTo:@"Flagged"]);       // iPhoto 9
}


//----------------------------------------------------------------------------------------------------------------------


- (void) addSubNodesToNode:(IMBNode*)inParentNode albums:(NSArray*)inAlbums images:(NSDictionary*)inImages
{
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];
	
	// Now parse the iPhoto XML plist and look for albums whose parent matches our parent node. We are 
	// only going to add subnodes that are direct children of inParentNode...
	
	for (NSDictionary* albumDict in inAlbums)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		NSString* albumType = [albumDict objectForKey:@"Album Type"];
		NSString* albumName = [albumDict objectForKey:@"AlbumName"];
		NSNumber* parentId = [albumDict objectForKey:@"Parent"];
        
		NSString* albumIdSpace = [self idSpaceForAlbumType:albumType];
        
		// parent always from same id space for non top-level albums
		NSString* parentIdentifier = parentId ? [self identifierForId:parentId inSpace:albumIdSpace] : [self identifierForPath:@"/"];
		
		if ([self shouldUseAlbumType:albumType] && 
			[inParentNode.identifier isEqualToString:parentIdentifier] && 
			[self shouldUseAlbum:albumDict images:inImages])
		{
			// Create node for this album...
			
			IMBNode* albumNode = [[[IMBNode alloc] init] autorelease];
			
			albumNode.isLeafNode = [self isLeafAlbumType:albumType];
			albumNode.icon = [self iconForAlbumType:albumType];
			albumNode.name = albumName;
			albumNode.mediaSource = self.mediaSource;
			albumNode.parserIdentifier = self.identifier;
			
			// Set the node's identifier. This is needed later to link it to the correct parent node. Please note 
			// that older versions of iPhoto didn't have AlbumId, so we are generating fake AlbumIds in this case
			// for backwards compatibility...
			
			NSNumber* albumId = [albumDict objectForKey:@"AlbumId"];
			if (albumId == nil) albumId = [NSNumber numberWithInt:_fakeAlbumID++]; 
			albumNode.identifier = [self identifierForId:albumId inSpace:albumIdSpace];
			
			// Keep a ref to the album dictionary for later use when we populate this node
			// so we don't have to loop through the whole album list again to find it.
			
			albumNode.attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    albumDict, @"nodeSource",
                                    [self nodeTypeForNode:albumNode], @"nodeType", nil];
			
			// Add the new album node to its parent (inRootNode)...
			
			[subnodes addObject:albumNode];
		}
		
		[pool drain];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Returns the path to a thumbnail containing the wanted clipped face in the image provided.
//
// There are reports (see issue 252) that ./Data occasionally is not a symbolic link
// to ./Data.noindex and faces we are looking for are not found in ./Data but ./Data.noindex.
// To account for this we return the image path including ./Data.noindex if necessary.

- (NSString*) imagePathForFaceIndex:(NSNumber*)inFaceIndex inImageWithKey:(NSString*)inImageKey
{
	NSString* imagePath = [super imagePathForFaceIndex:inFaceIndex inImageWithKey:inImageKey];
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Image path should currently be pointing to image in subdirectory of ./Data (iPhoto 8) or ./Thumbnails (iPhoto 9).
	
	if (![fileManager fileExistsAtPath:imagePath]) {
		
		// Oops, could not locate face image here. Provide alternate path
		NSLog(@"Could not find face image at %@", imagePath);
		
		NSString* pathPrefix = [[[self mediaSource] path] stringByDeletingLastPathComponent];
		NSString* replacement = @"/Data.noindex/";
		NSScanner* aScanner =  [[NSScanner alloc] initWithString:imagePath];
		
		if (([aScanner scanString:pathPrefix intoString:nil] && [aScanner scanString:@"/Data/" intoString:nil]) ||
			[aScanner scanString:@"/Thumbnails/" intoString:nil])
		{
			NSString* suffixString = [imagePath substringFromIndex:[aScanner scanLocation]];
			imagePath = [NSString stringWithFormat:@"%@%@%@", pathPrefix, replacement, suffixString];
			NSLog(@"Trying %@...", imagePath);
		}
		[aScanner release];
	}
	return imagePath;
}


//---------------------------------------------------------------------------------------------------------------------


// Returns a dictionary that contains the "true" KeyList, KeyPhotoKey and PhotoCount values for the provided node.
// (The values provided by the according dictionary in .plist are mostly wrong because we separate node children by
// media types 'Image' and 'Movie' into different views.)

- (NSDictionary*) childrenInfoForNode:(IMBNode*)inNode images:(NSDictionary*)inImages
{
	// We saved a reference to the album dictionary when this node was created
	// (ivar 'attributes') and now happily reuse it here.
	NSDictionary* albumDict = [inNode.attributes objectForKey:@"nodeSource"];
	
	// Determine images relevant to this view.
	// Note that everything regarding 'ImageFaceMetadata' is only relevant
	// when providing a faces node. Otherwise it will be nil'ed.
	
	NSArray* imageKeys = [albumDict objectForKey:@"KeyList"];
	NSMutableArray* relevantImageKeys = [NSMutableArray array];
	NSArray* imageFaceMetadataList = [albumDict objectForKey:@"ImageFaceMetadataList"];
	NSMutableArray* relevantImageFaceMetadataList = imageFaceMetadataList ? [NSMutableArray array] : nil;
	
	// Loop setup
	NSString* key = nil;
	NSDictionary* imageFaceMetadata = nil;
	NSDictionary* imageDict = nil;
	
	for (NSUInteger i = 0; i < [imageKeys count]; i++)
	{
		key = [imageKeys objectAtIndex:i];
		imageFaceMetadata = [imageFaceMetadataList objectAtIndex:i];
		
		imageDict = [inImages objectForKey:key];
		
		if ([self shouldUseObject:imageDict])
		{
			[relevantImageKeys addObject:key];
			
			if (imageFaceMetadata) [relevantImageFaceMetadataList addObject:imageFaceMetadata];
		}		
	}
	
	// Ensure that key image for movies is movie related:
	
	NSString* keyPhotoKey = nil;
	NSNumber* keyImageFaceIndex = nil;
	
	if ([[self iPhotoMediaType] isEqualToString:@"Movie"] && [relevantImageKeys count] > 0)
	{
		keyPhotoKey = [relevantImageKeys objectAtIndex:0];
		keyImageFaceIndex = [[relevantImageFaceMetadataList objectAtIndex:0] objectForKey:@"face index"];
	} else {
		keyPhotoKey = [albumDict objectForKey:@"KeyPhotoKey"];
	}

    return [NSDictionary dictionaryWithObjectsAndKeys:
			relevantImageKeys, @"KeyList",
			[NSNumber numberWithUnsignedInteger:[relevantImageKeys count]], @"PhotoCount", 
			keyPhotoKey, @"KeyPhotoKey",
			relevantImageFaceMetadataList, @"ImageFaceMetadataList",   // May be nil
			keyImageFaceIndex, @"key image face index", nil];          // May be nil
}


//----------------------------------------------------------------------------------------------------------------------


// Create a subnode for each event and a corresponding visual object

- (void) populateEventsNode:(IMBNode*)inNode withEvents:(NSArray*)inEvents images:(NSDictionary*)inImages
{
	
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subnodes = [inNode mutableArrayForPopulatingSubnodes];
	
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];
	NSUInteger index = 0;
	
	// We saved a reference to the album dictionary when this node was created
	// (ivar 'attributes') and now happily reuse it to save an outer loop (over album list) here.
	
	NSString* subNodeType = @"Event";
	
	// Events node is populated with node objects that represent events
	
	NSString* eventKeyPhotoKey = nil;
	NSString* path = nil;
	IMBiPhotoEventNodeObject* object = nil;
	
	for (NSDictionary* subnodeDict in inEvents)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

		NSString* subnodeName = [subnodeDict objectForKey:@"RollName"];
		
		if ([self shouldUseAlbumType:subNodeType] && 
			[self shouldUseAlbum:subnodeDict images:inImages])
		{
			// Create subnode for this node...
			
			IMBNode* subnode = [[[IMBNode alloc] init] autorelease];
			
			subnode.isLeafNode = [self isLeafAlbumType:subNodeType];
			subnode.icon = [self iconForAlbumType:subNodeType];
			subnode.name = subnodeName;
			subnode.mediaSource = self.mediaSource;
			subnode.parserIdentifier = self.identifier;
			
			// Keep a ref to the subnode dictionary for potential later use
			
			subnode.attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                  subnodeDict, @"nodeSource",
                                  [self nodeTypeForNode:subnode], @"nodeType", nil];
			
			// Set the node's identifier. This is needed later to link it to the correct parent node. Please note 
			// that older versions of iPhoto didn't have AlbumId, so we are generating fake AlbumIds in this case
			// for backwards compatibility...
			
			NSNumber* subnodeId = [subnodeDict objectForKey:@"RollID"];
			if (subnodeId == nil) subnodeId = [NSNumber numberWithInt:_fakeAlbumID++]; 
			subnode.identifier = [self identifierForId:subnodeId inSpace:EVENTS_ID_SPACE];
			
			// Add the new subnode to its parent (inRootNode)...

			[subnodes addObject:subnode];
			
			// Now create the visual object and link it to subnode just created...

			object = [[IMBiPhotoEventNodeObject alloc] init];
			[objects addObject:object];
			[object release];
			
			// Adjust keys "KeyPhotoKey", "KeyList", and "PhotoCount" in metadata dictionary because movies and 
			// images are not jointly displayed in iMedia browser...
			
			NSMutableDictionary* preliminaryMetadata = [NSMutableDictionary dictionaryWithDictionary:subnodeDict];
			[preliminaryMetadata addEntriesFromDictionary:[self childrenInfoForNode:subnode images:inImages]];

			object.preliminaryMetadata = preliminaryMetadata;	// This metadata from the XML file is available immediately
			object.metadata = nil;								// Build lazily when needed (takes longer)
			object.metadataDescription = nil;					// Build lazily when needed (takes longer)
			
			// Obtain key photo dictionary (key photo is displayed while not skimming)
			
			eventKeyPhotoKey = [object.preliminaryMetadata objectForKey:@"KeyPhotoKey"];
			NSDictionary* keyPhotoDict = [inImages objectForKey:eventKeyPhotoKey];
			
			path = [keyPhotoDict objectForKey:@"ImagePath"];
			
			object.representedNodeIdentifier = subnode.identifier;
			object.location = (id)[NSURL fileURLWithPath:path isDirectory:NO];
			object.name = subnode.name;
			object.parserIdentifier = [self identifier];
			object.index = index++;
			
			object.imageLocation = (id)[NSURL fileURLWithPath:[self imageLocationForObject:keyPhotoDict] isDirectory:NO];
			object.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
			object.imageRepresentation = nil;
		}
		[pool drain];
	}	
	inNode.objects = objects;
	
}


- (void) populateAlbumNode:(IMBNode*)inNode images:(NSDictionary*)inImages
{

	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];
	
	// Populate the node with IMBVisualObjects for each image in the album
	
	NSUInteger index = 0;
	Class objectClass = [self objectClass];
	
	// We saved a reference to the album dictionary when this node was created
	// (ivar 'attributes') and now happily reuse it to save an outer loop (over album list) here.
	
	NSDictionary* albumDict = [inNode.attributes objectForKey:@"nodeSource"];
	NSArray* imageKeys = [albumDict objectForKey:@"KeyList"];
	
	for (NSString* key in imageKeys)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		NSDictionary* imageDict = [inImages objectForKey:key];
		
		if ([self shouldUseObject:imageDict])
		{
			NSString* path = [imageDict objectForKey:@"ImagePath"];
			NSString* name = [imageDict objectForKey:@"Caption"];
			if ([name isEqualToString:@""])
			{
				name = [[path lastPathComponent] stringByDeletingPathExtension];	// fallback to filename
			}
			
			IMBObject* object = [[objectClass alloc] init];
			[objects addObject:object];
			[object release];
			
			object.location = (id)[NSURL fileURLWithPath:path isDirectory:NO];
			object.name = name;
			object.preliminaryMetadata = imageDict;	// This metadata from the XML file is available immediately
			object.metadata = nil;					// Build lazily when needed (takes longer)
			object.metadataDescription = nil;		// Build lazily when needed (takes longer)
			object.parserIdentifier = [self identifier];
			object.index = index++;
			
            
			object.imageLocation = (id)[NSURL fileURLWithPath:[self imageLocationForObject:imageDict] isDirectory:NO];
			object.imageRepresentationType = [self requestedImageRepresentationType];
			object.imageRepresentation = nil;
		}
		
		[pool drain];
	}
	
    inNode.objects = objects;

}


//--------------------------------------------------------------------------------------------------
// Returns array of all image dictionaries that belong to the Photo Stream (sorted by date).
// It will also exclude duplicate objects in terms of the image's "PhotoStreamAssetId".

- (NSArray *) photoStreamObjectsFromImages:(NSDictionary*)inImages
{
    NSMutableArray *photoStreamObjectDictionaries = [NSMutableArray array];
    NSDictionary *imageDict = nil;
    NSMutableSet *assetIds = [NSMutableSet set];
	
	for (NSString *imageKey in inImages)
	{
        imageDict = [inImages objectForKey:imageKey];
		
        // Being a member of Photo Stream is determined by having a non-empty Photo Stream asset id.
        // Add objects with the same asset id only once.
        
        NSString *photoStreamAssetId = [imageDict objectForKey:@"PhotoStreamAssetId"];
		if (photoStreamAssetId && photoStreamAssetId.length > 0 &&
            ![assetIds member:photoStreamAssetId] &&
            [self shouldUseObject:imageDict])
		{
            [assetIds addObject:photoStreamAssetId];
            [photoStreamObjectDictionaries addObject:imageDict];
        }
    }
    // After collecting all Photo Stream object dictionaries sort them by date
    
	NSSortDescriptor* dateDescriptor = [[NSSortDescriptor alloc] initWithKey:@"DateAsTimerInterval" ascending:YES];
	NSArray* sortDescriptors = [NSArray arrayWithObject:dateDescriptor];
	[dateDescriptor release];
	
    NSArray *sortedObjectDictionaries = [photoStreamObjectDictionaries sortedArrayUsingDescriptors:sortDescriptors];
    
    return sortedObjectDictionaries;
}


//--------------------------------------------------------------------------------------------------
// Populates the Photo Stream node.

- (void) populatePhotoStreamNode:(IMBNode*)inNode images:(NSDictionary*)inImages
{

    // Pull all Photo Stream objects from the inImages dictionary (should be master image list) sorted by date
    
    NSArray *sortedPhotoStreamObjectDictionaries = [self photoStreamObjectsFromImages:inImages];
    
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method, 
	// because without creating an array we would cause an endless loop...
	
	[inNode mutableArrayForPopulatingSubnodes];
	
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [[NSMutableArray alloc] initWithArray:inNode.objects];
	
	// Populate the node with IMBVisualObjects for each image in the album
	
	NSUInteger index = 0;
	Class objectClass = [self objectClass];
	
	for (NSDictionary *imageDict in sortedPhotoStreamObjectDictionaries)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
        NSString* path = [imageDict objectForKey:@"ImagePath"];
        NSString* name = [imageDict objectForKey:@"Caption"];
        if ([name isEqualToString:@""])
        {
            name = [[path lastPathComponent] stringByDeletingPathExtension];	// fallback to filename
        }
        
        IMBObject* object = [[objectClass alloc] init];
        [objects addObject:object];
        [object release];
        
        object.location = (id)[NSURL fileURLWithPath:path isDirectory:NO];
        object.name = name;
        object.preliminaryMetadata = imageDict;	// This metadata from the XML file is available immediately
        object.metadata = nil;					// Build lazily when needed (takes longer)
        object.metadataDescription = nil;		// Build lazily when needed (takes longer)
        object.parserIdentifier = [self identifier];
        object.index = index++;
        
        object.imageLocation = (id)[NSURL fileURLWithPath:[self imageLocationForObject:imageDict] isDirectory:NO];
        object.imageRepresentationType = [self requestedImageRepresentationType];
        object.imageRepresentation = nil;
		
		[pool drain];
	}
	
    inNode.objects = objects;
    [objects release];

}


//----------------------------------------------------------------------------------------------------------------------


@end
