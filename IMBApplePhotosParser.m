/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2015 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2015 by Karelia Software et al.
 
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


// Author: Jörg Jacobsen, Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBApplePhotosParser.h"

#import "IMBAppleMediaLibraryPropertySynchronizer.h"

#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "IMBNode.h"
#import "IMBNodeObject.h"


#define MEDIA_SOURCE_IDENTIFIER MLMediaSourcePhotosIdentifier

/**
 Reverse-engineered keys of the Photos app media source's attributes.

 Apple doesn't seem to yet publicly define these constants anywhere.
 */
NSString * const kIMBApplePhotosParserMediaSourceAttributeIdentifier = @"mediaSourceIdentifier";

/**
 Only supported by Photos media source (as of OS X 10.10.3)
 */
NSString * const kIMBApplePhotosParserMediaSourceAttributeLibraryURL = @"libraryURL";


@interface IMBApplePhotosParser ()

@end


@implementation IMBApplePhotosParser

@synthesize appPath = _appPath;
@synthesize appleMediaLibrary = _appleMediaLibrary;
@synthesize appleMediaSource = _appleMediaSource;

- (id) initWithMediaType:(NSString*)inMediaType
{
	if ((self = [super initWithMediaType:inMediaType]) != nil)
	{
		self.appPath = [[self class] photosAppPath];
	}

	return self;
}

- (void) dealloc
{
	IMBRelease(_appPath);
	IMBRelease(_appleMediaLibrary);
	IMBRelease(_appleMediaSource);
	[super dealloc];
}

//----------------------------------------------------------------------------------------------------------------------

// Check if Photos.app is installed...

+ (NSString*) photosAppPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.Photos"];
}


+ (BOOL) isInstalled
{
	if (IMBRunningOnYosemiteOrNewer()) {
		return [self photosAppPath] != nil;
	}

	return NO;
}

//----------------------------------------------------------------------------------------------------------------------

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	NSMutableArray* parserInstances = [NSMutableArray array];

	if ([self isInstalled])
	{
		IMBApplePhotosParser* parser = [[[self class] alloc] initWithMediaType:inMediaType];

		[parserInstances addObject:parser];
		[parser release];
	}

	return parserInstances;
}

/**
 Internal media type is specific to Apple Media Library based parsers and is not to be confused with kIMBMediaTypeImage and its siblings.
 */
+ (MLMediaType)internalMediaType
{
	[[self class] _throwAbstractBaseClassExceptionForSelector:_cmd];

	return nil;
}

//----------------------------------------------------------------------------------------------------------------------

- (instancetype)initializeMediaLibrary
{
	// Note: Host application needs to be code-signed for this to work
	// Otherwise the media library framework will report errors lije the following:
	// __38-[MLMediaLibraryImpl connectToService]_block_invoke connection interrupted
	// MLMediaLibrary error obtaining remote object proxy: Error Domain=NSCocoaErrorDomain Code=4097 "Couldn’t communicate with a helper application." (connection to service named com.apple.MediaLibraryService) {NSDebugDescription=connection to service named com.apple.MediaLibraryService}


	NSDictionary *libraryOptions = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:MEDIA_SOURCE_IDENTIFIER]
															   forKey:MLMediaLoadIncludeSourcesKey];

	self.appleMediaLibrary = [[MLMediaLibrary alloc] initWithOptions:libraryOptions];

	NSDictionary *mediaSources = [IMBAppleMediaLibraryPropertySynchronizer mediaSourcesForMediaLibrary:self.appleMediaLibrary];

	self.appleMediaSource = [mediaSources objectForKey:MEDIA_SOURCE_IDENTIFIER];

	// Note that the following line is only proven to work for Photos app. Would have to use other means e.g. for iPhoto to provide path to media library (look in attributes dictionary for root group).
	self.mediaSource = [[self.appleMediaSource.attributes objectForKey:kIMBApplePhotosParserMediaSourceAttributeLibraryURL] path];

	return self;
}

#pragma mark - Media Group

/**
 */
- (MLMediaGroup *)mediaGroupForNode:(IMBNode *)node
{
	NSString *mediaLibraryIdentifier = [node.identifier stringByReplacingOccurrencesOfString:[self identifierPrefix] withString:@""];
	return [self.appleMediaSource mediaGroupForIdentifier:mediaLibraryIdentifier];
}

/**
 Returns YES if media group contains at least one media object of media type associated with the receiver. NO otherwise.
 */
- (BOOL)shouldUseMediaGroup:(MLMediaGroup *)mediaGroup
{
	__block BOOL should = NO;

	// We should use this media group if it has at least one media object qualifying

	NSArray *mediaObjects = [IMBAppleMediaLibraryPropertySynchronizer mediaObjectsForMediaGroup:mediaGroup];

	[mediaObjects enumerateObjectsUsingBlock:^(MLMediaObject *mediaObject, NSUInteger idx, BOOL *stop) {
		if ([self shouldUseMediaObject:mediaObject]) {
			should = YES;
			*stop = YES;
		}
	}];

	return should;
}

#pragma mark - Media Object

/**
 */
- (BOOL)shouldUseMediaObject:(MLMediaObject *)mediaObject
{
	return ([[self class] internalMediaType] == mediaObject.mediaType);
}

/**
 */
- (NSString *)nameForMediaObject:(MLMediaObject *)mediaObject
{
	if (mediaObject.name) {
		return mediaObject.name;
	} else {
		return [[mediaObject.URL lastPathComponent] stringByDeletingPathExtension];
	}
}

/**
 Returns whether this object is hidden in Photos app (users can hide media objects in Photos app).
 @discussion
 Do not utilize this media object's property since media objects will already be treated by MediaLibrary framework according to their hidden status in Photos app. And hidden objects are not visible in Years/Collections/Moments but visible in albums by default.
 */
- (BOOL)hiddenMediaObject:(MLMediaObject *)mediaObject
{
	return [((NSNumber *)mediaObject.attributes[@"Hidden"]) boolValue];
}

#pragma mark - Utility

- (NSString *)libraryName
{
	return [[NSBundle bundleWithPath:self.appPath] localizedInfoDictionary][@"CFBundleDisplayName"];
}

- (NSString *)identifierPrefix
{
	return self.mediaSource;
}

- (NSString *)globalIdentifierForLocalIdentifier:(NSString *)identifier
{
	return [[self identifierPrefix] stringByAppendingString:identifier];
}

- (NSData*)previewDataForObject:(IMBObject*)inObject maximumSize:(NSNumber*)maximumSize
{

	return nil;
}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark
#pragma mark Parser Methods

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	IMBNode* node = [[[IMBNode alloc] init] autorelease];

	// Create an empty root node (without subnodes, but with empty objects array)...

	if (inOldNode == nil)
	{
		// (Re-)instantiate media library and media source (in Apple speak), because content might have changed on disk. Note though that this yet doesn't seem to have an effect when media library changes (Apple doesn't seem to update its object cache).
		[self initializeMediaLibrary];

		MLMediaGroup *rootMediaGroup = [IMBAppleMediaLibraryPropertySynchronizer rootMediaGroupForMediaSource:self.appleMediaSource];

		NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:self.appPath];

		[icon setSize:NSMakeSize(16.0,16.0)];

		node.mediaSource = self.mediaSource;
		node.identifier = [self globalIdentifierForLocalIdentifier:[rootMediaGroup identifier]];
		node.name = [self libraryName];
		node.icon = icon;
		node.parser = self;
		node.leaf = NO;
		node.isTopLevelNode = YES;
		node.groupType = kIMBGroupTypeLibrary;
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

	// If the old node was populated, then also populate the new node...

	if (inOldNode.isPopulated)
	{
		[self populateNewNode:node likeOldNode:inOldNode options:inOptions];
	}

	if (outError) *outError = error;
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation...

- (BOOL) populateNode:(IMBNode*)inParentNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because without creating an array we would cause an endless loop...

	NSMutableArray* subNodes = [NSMutableArray arrayWithArray:inParentNode.subNodes];
	NSMutableArray* objects = [NSMutableArray arrayWithArray:inParentNode.objects];

	inParentNode.displayedObjectCount = 0;

	NSError *error = nil;
	MLMediaGroup *parentGroup = [self mediaGroupForNode:inParentNode];
	NSInteger index = 0;

	for (MLMediaGroup *mediaGroup in [parentGroup childGroups]) {
		// Create node for this album...

		if ([self shouldUseMediaGroup:mediaGroup]) {
			IMBNode* albumNode = [[[IMBNode alloc] init] autorelease];

			albumNode.name = [mediaGroup name];
			albumNode.icon = [IMBAppleMediaLibraryPropertySynchronizer iconImageForMediaGroup:mediaGroup];
			albumNode.parser = self;
			albumNode.mediaSource = self.mediaSource;
			albumNode.identifier = [self globalIdentifierForLocalIdentifier:[mediaGroup identifier]];

			// Add the new album node to its parent (inRootNode)...

			[subNodes addObject:albumNode];

			/*
			IMBNodeObject* object = [[[IMBNodeObject alloc] init] autorelease];

			object.representedNodeIdentifier = albumNode.identifier;
			object.name = albumNode.name;
			object.metadata = nil;
			object.parser = self;
			object.index = index++;
			object.imageLocation = (id)self.mediaSource;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			object.imageRepresentation = albumNode.icon;

			[objects addObject:object];
			*/
		}
	}

	NSArray *mediaObjects = [IMBAppleMediaLibraryPropertySynchronizer mediaObjectsForMediaGroup:parentGroup];

	for (MLMediaObject *mediaObject in mediaObjects)
	{
		if ([self shouldUseMediaObject:mediaObject])
		{
			IMBObject* object = [[[IMBObject alloc] init] autorelease];

			object.location = [mediaObject.URL path];
			object.name = [self nameForMediaObject:mediaObject];
			object.parser = self;
			object.index = index++;
			object.imageLocation = [mediaObject.URL path];
			object.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
			object.imageRepresentation = nil;
			object.preliminaryMetadata = mediaObject.attributes;

			[objects addObject:object];
			inParentNode.displayedObjectCount++;
		}
	}

	inParentNode.subNodes = subNodes;
	inParentNode.objects = objects;

	if (*outError) *outError = error;
	return YES;
}

//----------------------------------------------------------------------------------------------------------------------


// When the parser is deselected, then get rid of cached data. In our case we can close the database...

- (void) didStopUsingParser
{
	@synchronized (self)
	{
		self.appleMediaLibrary = nil;
		self.appleMediaSource = nil;
	}
}


//----------------------------------------------------------------------------------------------------------------------

+ (void) _throwAbstractBaseClassExceptionForSelector:(SEL)inSelector
{
	NSString* reason = [NSString stringWithFormat:@"Abstract base class: Please override method %@ in subclass",NSStringFromSelector(inSelector)];
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:reason userInfo:nil] raise];
}

@end
