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

//  Created by Christoph Priebe on 2009-08-24.
//  Copyright 2009 Christoph Priebe. All rights reserved.

//----------------------------------------------------------------------------------------------------------------------

//	System
#import <Quartz/Quartz.h>

//	iMedia
#import "IMBFlickrParser.h"
#import "IMBIconCache.h"
#import "IMBLibraryController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBObjectPromise.h"
#import "IMBParserController.h"
#import "NSWorkspace+iMedia.h"



#define VERBOSE

//----------------------------------------------------------------------------------------------------------------------


@interface IMBNode (FlickrParserAdditions)

- (void) clearResponse;
- (OFFlickrAPIRequest*) flickrRequestWithContext: (OFFlickrAPIContext*) context;
- (NSDictionary*) flickrResponse;
- (BOOL) hasFlickrRequest;
- (BOOL) hasFlickrResponse;
- (void) setFlickrMethod: (NSString*) method arguments: (NSDictionary*) arguments;
- (void) setFlickrResponse: (NSDictionary*) response;
- (void) startFlickrRequestWithContext: (OFFlickrAPIContext*) context delegate: (id) delegate;

@end


//----------------------------------------------------------------------------------------------------------------------


//	Some additions to the iMB node useful for Flickr handling:
@implementation IMBNode (FlickrParserAdditions)

- (void) clearResponse {
	[(NSMutableDictionary*)self.attributes removeObjectForKey:@"flickrResponse"];
}


- (OFFlickrAPIRequest*) flickrRequestWithContext: (OFFlickrAPIContext*) context {
	OFFlickrAPIRequest* request = [self.attributes objectForKey:@"flickrRequest"];
	if (!request) {
		//	create a Flickr request for the given iMB node...
		request = [[OFFlickrAPIRequest alloc] initWithAPIContext:context];
		[(NSMutableDictionary*)self.attributes setObject:request forKey:@"flickrRequest"];
		[request release];
		
		//	we save the iMB node in the Flickr request for use in
		//	flickrAPIRequest:didCompleteWithResponse: ...
		request.sessionInfo = self.identifier;
	}
	return request;
}


- (NSDictionary*) flickrResponse {
	return [self.attributes objectForKey:@"flickrResponse"];
}


- (BOOL) hasFlickrRequest {
	return [self.attributes objectForKey:@"flickrRequest"] != nil;
}


- (BOOL) hasFlickrResponse {
	return [self.attributes objectForKey:@"flickrResponse"] != nil;
}


- (void) setFlickrMethod: (NSString*) method
			   arguments: (NSDictionary*) arguments {
	
	[(NSMutableDictionary*)self.attributes setObject:method forKey:@"flickrMethod"];
	[(NSMutableDictionary*)self.attributes setObject:arguments forKey:@"flickrArguments"];
}


- (void) setFlickrResponse: (NSDictionary*) response {
	[(NSMutableDictionary*)self.attributes setObject:response forKey:@"flickrResponse"];
}


- (void) startFlickrRequestWithContext: (OFFlickrAPIContext*) context
							  delegate: (id) delegate {
	
	OFFlickrAPIRequest* request = [self flickrRequestWithContext:context];
	if (![request isRunning]) {			
		[request setDelegate:delegate];	
		
		NSString* method = [self.attributes objectForKey:@"flickrMethod"];
		NSDictionary* arguments = [self.attributes objectForKey:@"flickrArguments"];
		[request callAPIMethodWithGET:method arguments:arguments];
		
		#ifdef VERBOSE
			NSLog (@"Start Flickr request for method %@", method);
		#endif
	}	
}

@end



//----------------------------------------------------------------------------------------------------------------------

@interface IMBFlickrParser ()
- (NSString*) identifierWithMethod: (NSString*) method argument: (NSString*) argument;
@end

#pragma mark -

//----------------------------------------------------------------------------------------------------------------------

@implementation IMBFlickrParser

+ (void) load {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeImage];
	[pool release];
}


- (void) dealloc {
	IMBRelease (_flickrAPIKey);
	IMBRelease (_flickrContext);
	IMBRelease (_flickrSharedSecret);
	[super dealloc];
}


#pragma mark
#pragma mark Actions

- (IBAction) openFlickrPage: (id) sender {
	if (![sender isKindOfClass:[NSMenuItem class]]) return;
	
	id obj = [sender representedObject];
	if ([obj isKindOfClass:[IMBObject class]]) {
		IMBObject* imbObject = (IMBObject*) obj;
		NSURL* webPage = [[imbObject metadata] objectForKey:@"webPageURL"];
		[[NSWorkspace threadSafeWorkspace] openURL:webPage];
	} else if ([obj isKindOfClass:[IMBNode class]]) {
		
	} else {
		NSLog (@"Can't handle this kind of object.");
	}
}


#pragma mark 
#pragma mark Flickr Handling

- (NSArray*) extractPhotosFromFlickrResponse: (NSDictionary*) response {
	NSArray* photos = [response valueForKeyPath:@"photos.photo"];
	NSMutableArray* objects = [NSMutableArray arrayWithCapacity:photos.count];
	for (NSDictionary* photoDict in photos) {
		NSURL* thumbnailURL = [_flickrContext photoSourceURLFromDictionary:photoDict size:OFFlickrThumbnailSize];
		NSURL* imageURL = [_flickrContext photoSourceURLFromDictionary:photoDict size:OFFlickrLargeSize];
		NSURL* webPageURL = [_flickrContext photoWebPageURLFromDictionary:photoDict];
		
		// We will need to get the URL of the original photo (or the largest possible)
		// Or, perhaps, we may want to have a callback to the application for what size of photo it would like
		// to receive.  (There's no point in getting larger size than the application will need.)
		
		IMBVisualObject* obj = [[IMBVisualObject alloc] init];
		obj.name = [photoDict objectForKey:@"title"];
		obj.imageRepresentation = thumbnailURL;
		obj.imageRepresentationType = IKImageBrowserNSURLRepresentationType;
		obj.metadata = [NSDictionary dictionaryWithObject:webPageURL forKey:@"webPageURL"];
		obj.value = imageURL;
		[objects addObject:obj];
		[obj release];
	}
	return objects;
}


- (void) flickrAPIRequest: (OFFlickrAPIRequest*) inRequest 
  didCompleteWithResponse: (NSDictionary*) inResponseDictionary {
	
	//	get the node we associated with the request in flickrRequestWithContext: ...
	NSString* nodeIdentifier = inRequest.sessionInfo;
	IMBLibraryController* libController = [IMBLibraryController sharedLibraryControllerWithMediaType:[self mediaType]];
	IMBNode* node = [libController nodeWithIdentifier:nodeIdentifier];
	
	#ifdef VERBOSE
		NSLog (@"Flickr request completed for node: %@", nodeIdentifier);
	#endif
	
	//	save Flickr response in our iMB node for later population of the browser...
	NSDictionary* response = [inResponseDictionary copy];
	[node setFlickrResponse:response];
	[response release];
	
	//	force reloading of the node holding the Flickr images...
	[libController reloadNode:node];	
}


- (void) flickrAPIRequest: (OFFlickrAPIRequest*) inRequest 
		 didFailWithError: (NSError*) inError {
	
	NSLog (@"flickrAPIRequest:didFailWithError: %@", inError);	
	//	TODO: Error Handling
}


- (void) startFlickrRequestForNode: (IMBNode*) node {
	[node startFlickrRequestWithContext:_flickrContext delegate:self];
}


#pragma mark 
#pragma mark Parser Methods

/// JUST TEMP TO PLEASE THE EYE ...
- (NSImage*) iconForAlbumType: (NSString*) inAlbumType {
	static const IMBIconTypeMappingEntry kIconTypeMappingEntries[] = {
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
	
	static const IMBIconTypeMapping kIconTypeMapping = {
		sizeof(kIconTypeMappingEntries) / sizeof(kIconTypeMappingEntries[0]),
		kIconTypeMappingEntries,
		{@"Regular",				@"sl-icon-small_album.tiff",			@"folder",	nil,				nil}	// fallback image
	};
	
	NSString* type = inAlbumType;
	if (type == nil) type = @"Photos";
	return [[IMBIconCache sharedIconCache] iconForType:type fromBundleID:@"com.apple.iPhoto" withMappingTable:&kIconTypeMapping];
}
/// ... JUST TEMP TO PLEASE THE EYE


- (NSImage*) smartFolderIcon {
	NSBundle* coreTypes = [NSBundle	bundleWithPath:@"/System/Library/CoreServices/CoreTypes.bundle"];
	NSString* path = [coreTypes pathForResource:@"SmartFolderIcon.icns" ofType:nil];
	NSImage* icon = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(16.0,16.0)];
	return icon;
}

	
- (IMBNode*) createGenericFlickrNodeForRoot: (IMBNode*) root {
	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	node.parentNode = root;
	node.parser = self;
	node.leaf = YES;
	node.attributes = [NSMutableDictionary dictionary];
	
	//	Leaving subNodes and objects nil, will trigger a populateNode:options:error: 
	//	as soon as the root node is opened.
	node.subNodes = nil;
	node.objects = nil;
	
	node.badgeTypeNormal = kIMBBadgeTypeReload;
	node.badgeTarget = self;
	node.badgeSelector = @selector (reloadNode:);
		
	return node;
}


- (IMBNode*) createInterestingPhotosNodeForRoot: (IMBNode*) root {
	IMBNode* node = [self createGenericFlickrNodeForRoot:root];
	node.icon = [self smartFolderIcon];
	node.identifier = [self identifierWithMethod:@"interestingness" argument:@"30"];
	node.mediaSource = node.identifier;
	node.name = NSLocalizedString (@"Most Interesting", @"Flickr parser standard node name.");
	
	[node setFlickrMethod:@"flickr.interestingness.getList"
				arguments:[NSDictionary dictionaryWithObjectsAndKeys:@"30", @"per_page", nil]];
	
	return node;
}


- (IMBNode*) createRecentPhotosNodeForRoot: (IMBNode*) root {
	IMBNode* node = [self createGenericFlickrNodeForRoot:root];
	node.icon = [self smartFolderIcon];
	node.identifier = [self identifierWithMethod:@"recent" argument:@"30"];
	node.mediaSource = node.identifier;
	node.name = NSLocalizedString (@"Recent", @"Flickr parser standard node name.");
	
	[node setFlickrMethod:@"flickr.photos.getRecent"
				arguments:[NSDictionary dictionaryWithObjectsAndKeys:@"30", @"per_page", nil]];
	
	return node;
}


- (IMBNode*) createNodeForSearch: (NSString*) text
						   title: (NSString*) title
							root: (IMBNode*) root {
	
	IMBNode* node = [self createGenericFlickrNodeForRoot:root];
	node.icon = [self smartFolderIcon];
	node.identifier = [self identifierWithMethod:@"search" argument:text];
	node.mediaSource = node.identifier;
	node.name = title;
	
	[node setFlickrMethod:@"flickr.photos.search"
				arguments:[NSDictionary dictionaryWithObjectsAndKeys:
						   text, @"text", 
						   @"20", @"per_page", nil]];
	
	return node;
}


- (IMBNode*) createNodeForTags: (NSString*) tags
						 title: (NSString*) title
						  root: (IMBNode*) root {
	
	IMBNode* node = [self createGenericFlickrNodeForRoot:root];
	node.identifier = [self identifierWithMethod:@"tag" argument:tags];
	node.mediaSource = node.identifier;
	node.name = title;
	node.icon = [self smartFolderIcon];
	
	[node setFlickrMethod:@"flickr.photos.search"
				arguments:[NSDictionary dictionaryWithObjectsAndKeys:
						   tags, @"tags", 
						   @"all", @"tag_mode", 
						   @"20", @"per_page", nil]];
	
	return node;
}


///	Create an empty "Flickr" root node.
- (IMBNode*) createRootNode {
	IMBNode* rootNode = [[[IMBNode alloc] init] autorelease];
	rootNode.parentNode = nil;
	rootNode.mediaSource = nil;
	rootNode.identifier = [self identifierForPath:@"/"];
	rootNode.name = @"Flickr";
	rootNode.icon = [self iconForAlbumType:@"Published"];
	rootNode.parser = self;
	rootNode.leaf = NO;
	rootNode.groupType = kIMBGroupTypeInternet;
	
	//	Leaving subNodes and objects nil, will trigger a populateNode:options:error: 
	//	as soon as the root node is opened.
	rootNode.subNodes = nil;
	rootNode.objects = nil;

	//	TODO: ???
	rootNode.watcherType = kIMBWatcherTypeFirstCustom;
	rootNode.watchedPath = (NSString*) rootNode.mediaSource;
	
	// The root node has a custom view that we are loading from a nib file
	
	NSView* customObjectView = nil;
	NSArray* topLevelObjects = nil;
	NSNib* nib = [[NSNib alloc] initWithNibNamed:@"IMBFlickrParser" bundle:[NSBundle bundleForClass:[self class]]];
	[nib instantiateNibWithOwner:self topLevelObjects:&topLevelObjects];
	
	for (id topLevelObject in topLevelObjects)
	{
		if ([topLevelObject isKindOfClass:[NSView class]])
		{
			customObjectView = topLevelObject;
			break;
		}
	}

	rootNode.customObjectView = customObjectView;
	
	return rootNode;
}


- (NSString*) identifierWithMethod: (NSString*) method argument: (NSString*) argument {
	NSString* albumPath = [NSString stringWithFormat:@"/%@/%@", method, argument];
	return [self identifierForPath:albumPath];
}


- (IMBNode*) nodeWithOldNode: (const IMBNode*) inOldNode 
					 options: (IMBOptions) inOptions 
					   error: (NSError**) outError {
	
	if (!inOldNode) return [self createRootNode];

	NSError* error = nil;
	
	IMBNode* updatedNode = [[inOldNode copy] autorelease];
	
	// If the old node was populated, then also populate the new node...
	if ([inOldNode hasFlickrRequest] || inOldNode.subNodes.count > 0 || inOldNode.objects.count > 0) {
		[self populateNode:updatedNode options:inOptions error:&error];
	}
	
	if (outError) *outError = error;
	
	return updatedNode;
}


// The supplied node is a private copy which may be modified here in the background operation. Parse the 
// iPhoto XML file and create subnodes as needed...
- (BOOL) populateNode: (IMBNode*) inNode options: (IMBOptions) inOptions error: (NSError**) outError {
	NSError* error = nil;
	
	if (!inNode.mediaSource) {
		//	populate root node...
		inNode.subNodes = [NSArray arrayWithObjects:
						   [self createRecentPhotosNodeForRoot:inNode],
						   [self createInterestingPhotosNodeForRoot:inNode],
						   [self createNodeForTags:@"macintosh, apple"
											 title:@"Tagged 'Macintosh' & 'Apple'"
											  root:inNode], 
						   [self createNodeForTags:@"iphone, screenshot"
											 title:@"Tagged 'iPhone' & 'Screenshot'"
											  root:inNode], 
						   [self createNodeForSearch:@"tree"
											 title:@"Search for 'Tree'"
											  root:inNode], 
						   nil];
		inNode.objects = [NSArray array];
	} else {
		//	populate nodes with Flickr contents...
		if ([inNode hasFlickrResponse]) {
			inNode.objects = [self extractPhotosFromFlickrResponse:[inNode flickrResponse]];
			[inNode clearResponse];
		} else {
			//	keep the 'populateNode:' loop quiet until we got our data...
			if (inNode.objects == nil) {
				inNode.subNodes = [NSArray array];
				inNode.objects = [NSArray array];
			}
			
			//	the network access needs to be started on the main thread...
			[self performSelectorOnMainThread:@selector(startFlickrRequestForNode:) withObject:inNode waitUntilDone:NO];
		}
	}
		
	if (outError) *outError = error;
	return error == nil;
}


- (void) willShowContextMenu: (NSMenu*) inMenu forObject: (IMBObject*) inObject {
	//	'Open Flickr Page'...
	NSMenuItem* showWebPageItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString (@"Open Flickr Page", @"Flickr parser context menu title.") 
															 action:@selector(openFlickrPage:) 
													  keyEquivalent:@""];
	[showWebPageItem setTarget:self];
	[showWebPageItem setRepresentedObject:inObject];
	[inMenu addItem:showWebPageItem];
	[showWebPageItem release];
}


- (void) willUseParser {
	[super willUseParser];

	//	lazy initialize the flickr context...
	if (_flickrContext == nil) {
		NSAssert (self.flickrAPIKey, @"Flickr API key property not set!");
		NSAssert (self.flickrSharedSecret, @"Flickr shared secret property not set!");
		_flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:self.flickrAPIKey sharedSecret:self.flickrSharedSecret];
	}	
}


// For Flickr we need a remote promise that downloads the files off the internet
- (IMBObjectPromise*) objectPromiseWithObjects:(NSArray*)inObjects
{
	return [[(IMBObjectPromise*)[IMBRemoteObjectPromise alloc] initWithObjects:inObjects] autorelease];
}


#pragma mark 
#pragma mark Actions

- (IBAction) newSearch:(id)inSender
{
	NSBeep();
}


- (IBAction) deleteSearch:(id)inSender
{
	NSBeep();
}

#pragma mark 
#pragma mark Properties

@synthesize flickrAPIKey = _flickrAPIKey;
@synthesize flickrSharedSecret = _flickrSharedSecret;

@end
