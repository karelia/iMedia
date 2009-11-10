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
#import "IMBConfig.h"
#import "IMBFlickrNode.h"
#import "IMBFlickrParser.h"
#import "IMBFlickrQueryEditor.h"
#import "IMBIconCache.h"
#import "IMBLibraryController.h"
#import "IMBObject.h"
#import "IMBObjectPromise.h"
#import "IMBParserController.h"
#import "NSWorkspace+iMedia.h"



#define VERBOSE

//----------------------------------------------------------------------------------------------------------------------

@interface IMBFlickrParser ()
@property (retain) IMBFlickrQueryEditor* editor;
//	Query Persistence:
- (NSArray*) instantiateCustomQueriesWithRoot: (IMBFlickrNode*) root;
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
	_delegate = nil;
	IMBRelease (_customQueries);
	IMBRelease (_editor);
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
		
		IMBObject* obj = [[IMBObject alloc] init];
		
		obj.location = imageURL;
		obj.name = [photoDict objectForKey:@"title"];
		obj.metadata = [NSDictionary dictionaryWithObject:webPageURL forKey:@"webPageURL"];
		obj.parser = self;
		
		obj.imageLocation = thumbnailURL;
		obj.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
		obj.imageRepresentation = nil;	// Build lazily when needed
		
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
	IMBFlickrNode* node = (IMBFlickrNode*) [libController nodeWithIdentifier:nodeIdentifier];
	
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


- (void) startFlickrRequestForNode: (IMBFlickrNode*) node {
	[node startFlickrRequestWithContext:_flickrContext delegate:self];
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
	rootNode.parentNode = nil;
	rootNode.mediaSource = nil;
	rootNode.identifier = [self identifierForPath:@"/"];
	rootNode.name = @"Flickr";
	rootNode.icon = icon;
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
	
	// The root node has a custom view that we are loading from a nib file...
	self.editor = [IMBFlickrQueryEditor flickrQueryEditorForParser:self];
	rootNode.customObjectView = self.editor.view;
	
	return rootNode;
}


- (IMBNode*) nodeWithOldNode: (const IMBNode*) inOldNode 
					 options: (IMBOptions) inOptions 
					   error: (NSError**) outError {
	
	if (!inOldNode) return [self createRootNode];

	NSError* error = nil;
	
	IMBFlickrNode* updatedNode = [[inOldNode copy] autorelease];
	
	// If the old node was populated, then also populate the new node...
	IMBFlickrNode* inOldFlickrNode = (IMBFlickrNode*) inOldNode;
	if ([inOldFlickrNode hasFlickrRequest] || inOldFlickrNode.subNodes.count > 0 || inOldFlickrNode.objects.count > 0) {
		[self populateNode:updatedNode options:inOptions error:&error];
	}
	
	if (outError) *outError = error;
	
	return updatedNode;
}


// The supplied node is a private copy which may be modified here in the background operation. Parse the 
// iPhoto XML file and create subnodes as needed...
- (BOOL) populateNode: (IMBNode*) inNode options: (IMBOptions) inOptions error: (NSError**) outError {
	NSError* error = nil;
	IMBFlickrNode* inFlickrNode = (IMBFlickrNode*) inNode;
	
	if (!inFlickrNode.mediaSource) {
		//	populate root node...
		NSArray* standardNodes = [NSArray arrayWithObjects:
								  [IMBFlickrNode flickrNodeForRecentPhotosForRoot:inFlickrNode parser:self],
								  [IMBFlickrNode flickrNodeForInterestingPhotosForRoot:inFlickrNode parser:self], nil];
		inFlickrNode.subNodes = [standardNodes arrayByAddingObjectsFromArray:[self instantiateCustomQueriesWithRoot:inFlickrNode]];
		inFlickrNode.objects = [NSArray array];
	} else {
		//	populate nodes with Flickr contents...
		if ([inFlickrNode hasFlickrResponse]) {
			inFlickrNode.objects = [self extractPhotosFromFlickrResponse:[inFlickrNode flickrResponse]];
			[inFlickrNode clearResponse];
		} else {
			//	keep the 'populateNode:' loop quiet until we got our data...
			if (inFlickrNode.objects == nil) {
				inFlickrNode.subNodes = [NSArray array];
				inFlickrNode.objects = [NSArray array];
			}
			
			//	the network access needs to be started on the main thread...
			[self performSelectorOnMainThread:@selector(startFlickrRequestForNode:) withObject:inFlickrNode waitUntilDone:NO];
		}
	}
		
	if (outError) *outError = error;
	return error == nil;
}


- (void) willShowContextMenu: (NSMenu*) inMenu forNode: (IMBNode*) inNode {
	if (![inNode isKindOfClass:[IMBFlickrNode class]]) return;
	
	IMBFlickrNode* flickrNode = (IMBFlickrNode*) inNode;
	if (!flickrNode.isCustomNode) return;
	
	//	'Remove'...
	NSMenuItem* removeNode = [[NSMenuItem alloc] initWithTitle:NSLocalizedString (@"Remove Custom Query", @"Flickr parser node context menu title.") 
															 action:@selector(removeNode:) 
													  keyEquivalent:@""];
	[removeNode setTarget:self];
	[removeNode setRepresentedObject:flickrNode.identifier];
	[inMenu addItem:removeNode];
	[removeNode release];
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
		
		[self loadCustomQueries];
	}	
}


// For Flickr we need a remote promise that downloads the files off the internet
- (IMBObjectPromise*) objectPromiseWithObjects: (NSArray*) inObjects {
	return [[(IMBObjectPromise*)[IMBRemoteObjectPromise alloc] initWithObjects:inObjects] autorelease];
}


#pragma mark 
#pragma mark Properties

@synthesize customQueries = _customQueries;
@synthesize delegate = _delegate;
@synthesize editor = _editor;
@synthesize flickrAPIKey = _flickrAPIKey;
@synthesize flickrSharedSecret = _flickrSharedSecret;


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
		NSLog (@"No usefull user bodes available. Fallback to defaults.");
		nodes = nil;
		goto setupDefaults;
	}
#endif
	
	return customNodes;	
}


- (void) loadCustomQueries {
	NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
	
	//	try to read user defaults...
	NSArray* nodes = [prefs objectForKey:IMBFlickrParserPrefKey_CustomQueries];
	
	//	setup default user nodes...
	if (!nodes && _delegate && [_delegate respondsToSelector:@selector(flickrParserSetupDefaultQueries:)]) {
		nodes = [_delegate flickrParserSetupDefaultQueries:self];
#if 0
		[prefs setObject:nodes forKey:IMBFlickrParserPrefKey_CustomQueries];
		[IMBConfig setPrefs:prefs forClass:[self class]];
#endif
	}
	
	self.customQueries = [[nodes mutableCopy] autorelease];
}


- (void) reloadCustomQueries {
	IMBLibraryController* libController = [IMBLibraryController sharedLibraryControllerWithMediaType:[self mediaType]];
	IMBFlickrNode* root =  (IMBFlickrNode*) [libController nodeWithIdentifier:[self identifierForPath:@"/"]];
	[libController reloadNode:root];	
}


- (void) saveCustomQueries {
	NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
	[prefs setObject:self.customQueries forKey:IMBFlickrParserPrefKey_CustomQueries];
	[IMBConfig setPrefs:prefs forClass:[self class]];
}

@end
