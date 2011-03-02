/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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


// Author: Christoph Priebe

// SpeedLimit http://mschrag.github.com/ is a good way to debug this....
// farm1.static.flickr.com, farm2.static.flickr.com, farm3.static.flickr.com, farm4.static.flickr.com, farm5.static.flickr.com 


//----------------------------------------------------------------------------------------------------------------------

//	System
#import <Quartz/Quartz.h>

//	iMedia
#import "IMBConfig.h"
#import "IMBFlickrNode.h"
#import "IMBFlickrObject.h"
#import "IMBFlickrParser.h"
#import "IMBFlickrHeaderViewController.h"
#import "IMBIconCache.h"
#import "IMBLibraryController.h"
#import "IMBLoadMoreObject.h"
#import "IMBObjectsPromise.h"
#import "IMBParserController.h"
#import "NSWorkspace+iMedia.h"
#import "NSImage+iMedia.h"
#import "NSString+iMedia.h"
#import "IMBConfig.h"
#import "IMBNodeObject.h"
#import "IMBSmartFolderNodeObject.h"



//#define VERBOSE

//----------------------------------------------------------------------------------------------------------------------

@interface IMBFlickrParser ()
//	Flickr Request Handling:
- (void) cancelAllPendingFlickrRequests;
- (BOOL) hasFlickrRequestForNode: (IMBFlickrNode*) node;
- (void) startLoadRequestForFlickrNode: (IMBFlickrNode*) node;
- (void) startLoadMoreRequestForFlickrNode: (IMBFlickrNode*) node;
//	Query Persistence:
- (NSArray*) instantiateCustomQueriesWithRoot: (IMBFlickrNode*) root;
- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata;
@end

#pragma mark -

//----------------------------------------------------------------------------------------------------------------------

@implementation IMBFlickrParser

+ (void) load {
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeImage];
	[pool drain];
}


- (void) dealloc {
	_delegate = nil;
	
	[self cancelAllPendingFlickrRequests];
	
	IMBRelease (_customQueries);
	IMBRelease (_flickrAPIKey);
	IMBRelease (_flickrContext);
	IMBRelease (_flickrSharedSecret);
	IMBRelease (_flickrRequests);	
	IMBRelease (_loadMoreButton);
	[super dealloc];
}


- (BOOL) canBeUsed {
	BOOL result = (self.flickrAPIKey && ![self.flickrAPIKey isEqualToString:@""]
			&& self.flickrSharedSecret && ![self.flickrSharedSecret isEqualToString:@""]);
	// If these aren't available (provided by app delegate parserController:didLoadParser:forMediaType:)
	// then this parser can't be used, so it will be unloaded.
	return result;
}


#pragma mark
#pragma mark Actions

- (IBAction) editNode: (id) sender {
	NSLog (@"edit node...");
}


- (IBAction) loadMoreImages: (id) sender {	
	NSString* nodeIdentifier = nil;
	if ([sender isKindOfClass:[IMBLoadMoreObject class]]) {
		nodeIdentifier = [sender nodeIdentifier];
	}

	if (!nodeIdentifier && [sender isKindOfClass:[NSMenuItem class]]) {
		id obj = [sender representedObject];
		if ([obj isKindOfClass:[NSString class]]) {
			nodeIdentifier = obj;		
		}
	}
	
	if (nodeIdentifier) {
		IMBLibraryController* libController = [IMBLibraryController sharedLibraryControllerWithMediaType:self.mediaType];
		IMBFlickrNode* node = (IMBFlickrNode*) [libController nodeWithIdentifier:nodeIdentifier];
		[self startLoadMoreRequestForFlickrNode:node];
	} else {
		NSLog (@"Can't handle this kind of node.");
	}
}


- (IBAction) openFlickrPage: (id) sender {
	if (![sender isKindOfClass:[NSMenuItem class]]) return;
	
	id obj = [sender representedObject];
	if ([obj isKindOfClass:[IMBObject class]]) {
		IMBObject* imbObject = (IMBObject*) obj;
		NSURL* webPage = [[imbObject metadata] objectForKey:@"webPageURL"];
		[[NSWorkspace imb_threadSafeWorkspace] openURL:webPage];
	} else {
		NSLog (@"Can't handle this kind of object.");
	}
}


- (IBAction) copyFlickrPageURL: (id) sender {
	if (![sender isKindOfClass:[NSMenuItem class]]) return;
	
	id obj = [sender representedObject];
	if ([obj isKindOfClass:[IMBObject class]]) {
		IMBObject* imbObject = (IMBObject*) obj;
		NSURL* webPage = [[imbObject metadata] objectForKey:@"webPageURL"];

		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		NSArray *types = [NSArray arrayWithObjects:NSStringPboardType, nil];
		[pb declareTypes:types owner:self];
		[pb setString:[webPage absoluteString] forType:NSStringPboardType];
	
	} else {
		NSLog (@"Can't handle this kind of object.");
	}
}


- (IBAction) copyAttribution: (id) sender {
	if (![sender isKindOfClass:[NSMenuItem class]]) return;
	
	id obj = [sender representedObject];
	if ([obj isKindOfClass:[IMBObject class]]) {
		IMBObject* imbObject = (IMBObject*) obj;
		
		NSURL *shortWebPageURL = [NSURL URLWithString:[@"http://flic.kr/p/" stringByAppendingString:
													   [IMBFlickrNode base58EncodedValue:[[[imbObject metadata] objectForKey:@"id"] longLongValue]]]];
		NSString *credit = [[obj metadata] objectForKey:@"ownername"];
		NSString *format = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.format.attribution",nil,IMBBundle(),@"Photo by %@ - %@",@"Format string for attribution credit; flickr user followed by short URL");
		NSString *attribution = [NSString stringWithFormat:format, credit, [shortWebPageURL absoluteString]];
		
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		NSArray *types = [NSArray arrayWithObjects:NSStringPboardType, nil];
		[pb declareTypes:types owner:self];
		[pb setString:attribution forType:NSStringPboardType];

	} else {
		NSLog (@"Can't handle this kind of object.");
	}
}


- (IBAction) removeNode: (id) sender {
	if (![sender isKindOfClass:[NSMenuItem class]]) return;
	
	id obj = [sender representedObject];
	if ([obj isKindOfClass:[NSString class]]) {				
		if (_customQueries.count > 0) {
			[_customQueries removeLastObject];
		}
		[self saveCustomQueries];
		[self reloadCustomQueries];
	} else {
		NSLog (@"Can't handle this kind of node.");
	}
}


#pragma mark 
#pragma mark Flickr Request Handling

- (void) cancelAllPendingFlickrRequests {
	for (OFFlickrAPIRequest* request in _flickrRequests.allValues) {
		[request cancel];
	}
}


- (void) flickrAPIRequest: (OFFlickrAPIRequest*) inRequest 
  didCompleteWithResponse: (NSDictionary*) inResponseDictionary {
	
	//	get the node we associated with the request in flickrRequestWithContext: ...
	NSString* nodeIdentifier = inRequest.sessionInfo;
	IMBLibraryController* libController = [IMBLibraryController sharedLibraryControllerWithMediaType:self.mediaType];
	IMBFlickrNode* node = (IMBFlickrNode*) [libController nodeWithIdentifier:nodeIdentifier];
	
	//	if the node does not exist any more, there is not much to do...
	if (!node) return;
		
	#ifdef VERBOSE
		NSLog (@"Flickr request completed for node '%@'.", nodeIdentifier);
	#endif
	
	//	save Flickr response in our iMB node for later population of the browser...
	[node setFlickrResponse:(inResponseDictionary) ? inResponseDictionary : [NSDictionary dictionary]];
	
	//	force reloading of the node holding the Flickr images...
	[libController reloadNode:node];	
}


- (void) flickrAPIRequest: (OFFlickrAPIRequest*) inRequest 
		 didFailWithError: (NSError*) inError {
	
	NSLog (@"flickrAPIRequest:didFailWithError: %@", inError);	
	//	TODO: Error Handling
}


+ (NSString*) flickrMethodForMethodCode: (NSInteger) code {
	if (code == IMBFlickrNodeMethod_TagSearch || code == IMBFlickrNodeMethod_TextSearch) {
		return @"flickr.photos.search";
	} else if (code == IMBFlickrNodeMethod_Recent) {
		return @"flickr.photos.getRecent";
	} else if (code == IMBFlickrNodeMethod_MostInteresting) {
		return @"flickr.interestingness.getList";
	} else if (code == IMBFlickrNodeMethod_GetInfo) {
		return @"flickr.photos.getInfo";
	}
	NSLog (@"Can't find Flickr method for method code.");
	return nil;
}


- (OFFlickrAPIRequest*) flickrRequestWithNode: (IMBFlickrNode*) node {
	
	//	create our dictionary of flickr request lazily... 
	if (_flickrRequests == nil) {
		_flickrRequests = [[NSMutableDictionary alloc] init]; 
	}
	
	OFFlickrAPIRequest* request = [_flickrRequests objectForKey:node.identifier];
	if (!request) {
		//	create a Flickr request for the given iMB node...
		request = [[OFFlickrAPIRequest alloc] initWithAPIContext:_flickrContext];
		[_flickrRequests setObject:request forKey:node.identifier];
		request.requestTimeoutInterval = 60.0f;
		//		[request setShouldWaitUntilDone:YES];
		[request release];
		
		//	we save the iMB node in the Flickr request for use in
		//	flickrAPIRequest:didCompleteWithResponse: ...
		request.sessionInfo = node.identifier;
	}
	return request;
}


- (BOOL) hasFlickrRequestForNode: (IMBFlickrNode*) node {
	if (!node) return NO;
	OFFlickrAPIRequest* request = [_flickrRequests objectForKey:node.identifier];
	return request != nil;
}


- (void) startLoadRequestForFlickrNode: (IMBFlickrNode*) node {
	[self performSelectorOnMainThread:@selector(startLoadRequestForFlickrNode_onMainThread:) withObject:node waitUntilDone:NO];	
}


- (void) startLoadMoreRequestForFlickrNode: (IMBFlickrNode*) node {
	node.page = node.page + 1;
	[self performSelectorOnMainThread:@selector(startLoadRequestForFlickrNode_onMainThread:) withObject:node waitUntilDone:NO];	
}


- (void) startLoadRequestForFlickrNode_onMainThread: (IMBFlickrNode*) node {
	if (!node) return;
	
	OFFlickrAPIRequest* request = [self flickrRequestWithNode:node];
	if (![request isRunning]) {			
		[request setDelegate:self];	
		
		//	Keep the 'populateNode:' loop quiet until we got our data. Also this will
		//	ensure that the parser is not called again and again to populate the node.
		if (node.objects == nil) {
			node.subNodes = [NSArray array];
			node.objects = [NSArray array];
		}
		
		//	compose and start Flickr request...
		NSString* method = [self.class flickrMethodForMethodCode:node.method];
		NSDictionary* arguments = [node argumentsForFlickrCall];
		[request callAPIMethodWithGET:method arguments:arguments];
		
#ifdef VERBOSE
		NSLog (@"Start Flickr request for node '%@' method: '%@' and query: '%@'.", node.identifier, method, node.query);
#endif
	}	
}


#pragma mark 
#pragma mark Parser Methods

///	Create an empty "Flickr" root node.
- (IMBFlickrNode*) createRootNode {
	//	load Flickr icon...
	NSBundle* ourBundle = [NSBundle bundleForClass:[IMBNode class]];
	NSString* pathToImage = [ourBundle pathForResource:@"Flickr" ofType:@"png"];
	NSImage* icon = [[[NSImage alloc] initWithContentsOfFile:pathToImage] autorelease];

	//	create root node...
	IMBFlickrNode* rootNode = [[[IMBFlickrNode alloc] init] autorelease];
	rootNode.mediaSource = nil;
	rootNode.identifier = [self identifierForPath:@"/"];
	rootNode.name = @"Flickr";
	rootNode.icon = icon;
	rootNode.parser = self;
	rootNode.leaf = NO;
	rootNode.isTopLevelNode = YES;
	rootNode.groupType = kIMBGroupTypeInternet;
	
	//	Leaving subNodes and objects nil, will trigger a populateNode:options:error: 
	//	as soon as the root node is opened.
	rootNode.subNodes = nil;
	rootNode.objects = nil;

	rootNode.watcherType = kIMBWatcherTypeFirstCustom;
	rootNode.watchedPath = (NSString*) rootNode.mediaSource;
		
	return rootNode;
}


- (void) didClickObject: (IMBObject*) inObject objectView: (NSView*) inView {
	if ([inObject isKindOfClass:[IMBLoadMoreObject class]]) {
		[self loadMoreImages:inObject];		
	}
}


- (IMBNode*) nodeWithOldNode: (const IMBNode*) inOldNode 
					 options: (IMBOptions) inOptions 
					   error: (NSError**) outError {
	
	if (!inOldNode) return [self createRootNode];

	NSError* error = nil;
	
	IMBFlickrNode* updatedNode = [[inOldNode copy] autorelease];
	
	// If the old node was populated, then also populate the new node...
	
	IMBFlickrNode* inOldFlickrNode = (IMBFlickrNode*) inOldNode;
//	if ([inOldFlickrNode hasRequest] || inOldFlickrNode.subNodes.count > 0 || inOldFlickrNode.objects.count > 0) {
//		[self populateNode:updatedNode options:inOptions error:&error];
//	}
	
	if ([self hasFlickrRequestForNode:inOldFlickrNode] || inOldNode.isPopulated)
	{
		[self populateNewNode:updatedNode likeOldNode:inOldNode options:inOptions];
	}

	if (outError) *outError = error;
	
	return updatedNode;
}


// The supplied node is a private copy which may be modified here in the background operation. Parse the 
// iPhoto XML file and create subnodes as needed...
- (BOOL) populateNode: (IMBNode*) inNode options: (IMBOptions) inOptions error: (NSError**) outError {
	NSError* error = nil;
	IMBFlickrNode* inFlickrNode = (IMBFlickrNode*) inNode;
	
	#ifdef VERBOSE
		NSLog (@"Populate node '%@', query '%@'", inFlickrNode.identifier, inFlickrNode.query);
	#endif
	
	if (!inFlickrNode.mediaSource) {
		//	populate root node...
		NSArray* standardNodes = [NSArray arrayWithObjects:
								  [IMBFlickrNode flickrNodeForRecentPhotosForRoot:inFlickrNode parser:self],
								  [IMBFlickrNode flickrNodeForInterestingPhotosForRoot:inFlickrNode parser:self], nil];
		inFlickrNode.subNodes = [standardNodes arrayByAddingObjectsFromArray:[self instantiateCustomQueriesWithRoot:inFlickrNode]];
		
		// Put the queries into the objects, so that selecting top-level node will show queries as smart folders
		NSUInteger index = 0;
		NSMutableArray* objects = [NSMutableArray array];
		for (IMBFlickrNode* node in inFlickrNode.subNodes) {
			IMBSmartFolderNodeObject* object = [[IMBSmartFolderNodeObject alloc] init];
			object.location = (id)node;
			object.name = node.name;
			object.metadata = nil;
			object.parser = self;
			object.index = index++;
			object.imageLocation = nil;
			object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
			
			object.imageRepresentation = [IMBSmartFolderNodeObject icon];

			[objects addObject:object];
			[object release];
		}
		
		inFlickrNode.objects = objects;
	} else {
		//	populate nodes with Flickr contents...
		if ([inFlickrNode hasFlickrResponse]) {
			[inFlickrNode processResponseForContext:_flickrContext];
			[inFlickrNode clearFlickrResponse];
		} else {			
			//	the network access needs to be started on the main thread...
			[self startLoadRequestForFlickrNode:inFlickrNode];
		}
	}
		
	if (outError) *outError = error;
	return error == nil;
}


- (void) willShowContextMenu: (NSMenu*) inMenu forNode: (IMBNode*) inNode {
	if (![inNode isKindOfClass:[IMBFlickrNode class]]) return;
	
	IMBFlickrNode* flickrNode = (IMBFlickrNode*) inNode;
	
	//	'Load More'...
	NSString* title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.loadmore",nil,IMBBundle(),@"Load More",@"Flickr parser node context menu title.");
	title = [NSString stringWithFormat:title, flickrNode.name];
	NSMenuItem* loadMoreItem = [[NSMenuItem alloc] initWithTitle:title
														  action:@selector(loadMoreImages:) 
												   keyEquivalent:@""];
	[loadMoreItem setTarget:self];
	[loadMoreItem setRepresentedObject:flickrNode.identifier];
	[inMenu addItem:loadMoreItem];
	[loadMoreItem release];

	
	//	you can edit the custom nodes only...
	if (!flickrNode.isCustomNode) return;	
	
	[inMenu addItem:[NSMenuItem separatorItem]];

	//	'Edit'...
	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.edit",nil,IMBBundle(),@"Edit",@"Flickr parser node context menu title.");
	title = [NSString stringWithFormat:title, flickrNode.name];
	NSMenuItem* editNodeItem = [[NSMenuItem alloc] initWithTitle:title
														action:@selector(editNode:) 
												 keyEquivalent:@""];
	[editNodeItem setTarget:self];
	[editNodeItem setRepresentedObject:flickrNode.identifier];
	[inMenu addItem:editNodeItem];
	[editNodeItem release];
	
	//	'Remove'...
	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.remove",nil,IMBBundle(),@"Remove '%@'",@"Flickr parser node context menu title.");
	title = [NSString stringWithFormat:title, flickrNode.name];
	NSMenuItem* removeNode = [[NSMenuItem alloc] initWithTitle:title
														action:@selector(removeNode:) 
												 keyEquivalent:@""];
	[removeNode setTarget:self];
	[removeNode setRepresentedObject:flickrNode.identifier];
	[inMenu addItem:removeNode];
	[removeNode release];
}


- (void) willShowContextMenu: (NSMenu*) inMenu forObject: (IMBObject*) inObject {
	//	'Open Flickr Page'...
	NSString *title = nil;
	NSMenuItem *item = nil;
	
	if ([inObject isSelectable])
	{
		if (![[[inObject metadata] objectForKey:@"can_download"] boolValue])
		{
			// This will replace the Download / Open With Browser that is usually shown
			title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.downloadingNotPermitted",nil,IMBBundle(),@"Downloading Not Permitted",@"Context menu item title to warn of not being downloadable");
			item = [[[NSMenuItem alloc] initWithTitle:title 
											   action:nil 
										keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[item setRepresentedObject:inObject];
			[inMenu insertItem:item atIndex:0];
			[inMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
			
		}
		
		
		title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.openflickrpage",nil,IMBBundle(),@"Open Flickr Page",@"Flickr parser node context menu title.");
		item = [[[NSMenuItem alloc] initWithTitle:title 
										   action:@selector(openFlickrPage:) 
									keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[item setRepresentedObject:inObject];
		[inMenu addItem:item];

		
		title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.copyFlickrURL",nil,IMBBundle(),@"Copy Flickr Page URL",@"Flickr parser node context menu title.");
		item = [[[NSMenuItem alloc] initWithTitle:title 
										   action:@selector(copyFlickrPageURL:) 
									keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[item setRepresentedObject:inObject];
		[inMenu addItem:item];


		title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.copyAttribution",nil,IMBBundle(),@"Copy Attribution",@"Flickr parser node context menu title.");
		item = [[[NSMenuItem alloc] initWithTitle:title 
										   action:@selector(copyAttribution:) 
									keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[item setRepresentedObject:inObject];
		[inMenu addItem:item];
	}
}


- (void) willUseParser {
	[super willUseParser];

	//	lazy initialize the flickr context...
	if (_flickrContext == nil) {
		NSAssert (self.flickrAPIKey, @"Flickr API key property not set!");
		NSAssert (self.flickrSharedSecret, @"Flickr shared secret property not set!");
		_flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:self.flickrAPIKey sharedSecret:self.flickrSharedSecret];
		
		[self loadCustomQueries];
		
		// setup desired size to get, from delegate
		self.desiredSize = [IMBConfig flickrDownloadSize];
	}	

	//	lazy initialize the 'load more' button...
	if (_loadMoreButton == nil) {
		_loadMoreButton = [[IMBLoadMoreObject alloc] init];
		_loadMoreButton.clickAction = @selector (loadMoreImages:);
		_loadMoreButton.parser = self;
		_loadMoreButton.target = self;
	}
}


/// For Flickr we need a remote promise that downloads the files off the internet
- (IMBObjectsPromise*) objectPromiseWithObjects: (NSArray*) inObjects {
	return [[[IMBRemoteObjectsPromise alloc] initWithIMBObjects:inObjects] autorelease];
}


/// Convert metadata into human readable string.
- (void) loadMetadataForObject:(IMBObject*)inObject
{
	NSDictionary* metadata = inObject.preliminaryMetadata;
	NSString* description = metadata ? [self metadataDescriptionForMetadata:metadata] : @"";

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


- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	BOOL canDownload = [[inMetadata objectForKey:@"can_download"] boolValue];
	NSString* ownername = [inMetadata objectForKey:@"ownername"];
	NSString* tags = [inMetadata objectForKey:@"tags"];

	NSString* info = [NSImage imb_imageMetadataDescriptionForMetadata:inMetadata];
	
	NSMutableString* description = [NSMutableString string];
	
	if (!canDownload)
	{
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@",
			NSLocalizedStringWithDefaultValue(
			@"IMBFlickrParser.menu.downloadingNotPermitted",
			nil,IMBBundle(),
			@"Downloading Not Permitted",
			@"Context menu item title to warn of not being downloadable")];
	}
	
	if (ownername && ![ownername isEqualToString:@""])
	{
		NSString* artist = NSLocalizedStringWithDefaultValue(
			@"Owner",
			nil,IMBBundle(),
			@"Owner",
			@"Owner (for flickr photographs) label in metadataDescription");

		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",artist,ownername];
	}
	
	if (info)
	{
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@",info];
	}
		
	if (tags && ![tags isEqualToString:@""])
	{
		NSString* tagsLabel = NSLocalizedStringWithDefaultValue(
																	@"Tags",
																	nil,IMBBundle(),
																	@"Tags",
																	@"Tags (Flickr term for keywords) label in metadataDescription");
		
		if (description.length > 0) [description imb_appendNewline];
		[description appendFormat:@"%@: %@",tagsLabel,tags];
	}
	
	return description;
}


//----------------------------------------------------------------------------------------------------------------------


- (NSViewController*) customHeaderViewControllerForNode:(IMBNode*)inNode
{
	IMBFlickrHeaderViewController* controller = nil;
	
	// The root node has a custom view that we are loading from a nib file...

	if ([inNode.identifier isEqualToString:[self identifierForPath:@"/"]])
	{
		controller = [IMBFlickrHeaderViewController headerViewControllerWithParser:self forNode:(IMBFlickrNode*)inNode];
		controller.queryAction = @selector(addQuery:);
		controller.buttonAction = @selector(addQuery:);
		controller.buttonTitle = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.button.add",nil,IMBBundle(),@"Add",@"Button title in Flickr Options");
	}
	else
	{
		controller = [IMBFlickrHeaderViewController headerViewControllerWithParser:self forNode:(IMBFlickrNode*)inNode];
		controller.queryAction = @selector(editQuery:);
		controller.buttonAction = @selector(removeQuery:);
		controller.buttonTitle = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.button.remove",nil,IMBBundle(),@"Remove",@"Button title in Flickr Options");
	}

	return controller;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Properties

@synthesize customQueries = _customQueries;
@synthesize delegate = _delegate;
@synthesize flickrAPIKey = _flickrAPIKey;
@synthesize flickrSharedSecret = _flickrSharedSecret;
@synthesize desiredSize = _desiredSize;


- (IMBLoadMoreObject*) loadMoreButton {
	return _loadMoreButton;
}


- (IMBFlickrNode*) flickrRootNode {
	IMBLibraryController* libController = [IMBLibraryController sharedLibraryControllerWithMediaType:[self mediaType]];
	IMBFlickrNode* root = (IMBFlickrNode*) [libController nodeWithIdentifier:[self identifierForPath:@"/"]];
	return root;
}


#pragma mark 
#pragma mark Query Persistence

NSString* const IMBFlickrParserPrefKey_CustomQueries = @"customQueries";


- (NSArray*) instantiateCustomQueriesWithRoot: (IMBFlickrNode*) root {
	NSMutableArray* customNodes = [NSMutableArray array];
	
	//	create nodes from settings...
	for (NSDictionary* dict in self.customQueries) {
		IMBFlickrNode* node = [IMBFlickrNode flickrNodeFromDict:dict rootNode:root parser:self];
		if (node) {
			[customNodes addObject:node];
		}
	}
#if 0		
	//	fallback to defaults, if no user nodes available...
	if (customNodes.count == 0) {
		NSLog (@"No useful user nodes available. Fallback to defaults.");
		nodes = nil;
		goto setupDefaults;
	}
#endif
	
	return customNodes;	
}


- (void) addCustomQuery: (NSDictionary*) inQueryParams {
	if (!inQueryParams) return;
	[self.customQueries addObject:inQueryParams];
}


- (void) removeCustomQuery: (NSDictionary*) inQueryParams {
	if (!inQueryParams) return;

	NSString* queryIdentifier = [inQueryParams objectForKey:IMBFlickrNodeProperty_UUID];
	
	NSDictionary* dictToBeRemoved = nil;
	for (NSDictionary* dict in _customQueries) {
		NSString* dictIdentifier = [dict objectForKey:IMBFlickrNodeProperty_UUID];
		if (dictIdentifier && [queryIdentifier hasSuffix:dictIdentifier]) {
			dictToBeRemoved = dict;
		}
	}
	
	if (dictToBeRemoved) {
		[_customQueries removeObject:dictToBeRemoved];			
	}
}


- (void) loadCustomQueries {
	NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
	
	//	try to read user defaults...
	NSArray* nodes = [prefs objectForKey:IMBFlickrParserPrefKey_CustomQueries];
	
	//	setup default user nodes...
	if (!nodes && _delegate && [_delegate respondsToSelector:@selector(flickrParserSetupDefaultQueries:)])
	{
		nodes = [_delegate flickrParserSetupDefaultQueries:self];
	}
	if (nodes == nil) nodes = [NSArray array];
	
	self.customQueries = [[nodes mutableCopy] autorelease];
}


- (void) reloadCustomQueries {
	IMBLibraryController* libController = [IMBLibraryController sharedLibraryControllerWithMediaType:[self mediaType]];
	[libController reloadNode:self.flickrRootNode];
}


- (void) saveCustomQueries {
	NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
	[prefs setObject:self.customQueries forKey:IMBFlickrParserPrefKey_CustomQueries];
	[IMBConfig setPrefs:prefs forClass:[self class]];
}


- (void) updateCustomQuery: (NSDictionary*) inQueryParams {
	if (!inQueryParams) return;

	NSString* queryIdentifier = [inQueryParams objectForKey:IMBFlickrNodeProperty_UUID];
	NSUInteger count = _customQueries.count;
	for (NSUInteger index = 0; index < count; index++) {
		NSDictionary* dict = [_customQueries objectAtIndex:index];
		NSString* dictIdentifier = [dict objectForKey:IMBFlickrNodeProperty_UUID];
		if (dictIdentifier && [queryIdentifier hasSuffix:dictIdentifier]) {
			[_customQueries replaceObjectAtIndex:index withObject:inQueryParams];
			break;
		}
	}
}

@end
