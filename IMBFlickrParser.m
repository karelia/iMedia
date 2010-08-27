/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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


//----------------------------------------------------------------------------------------------------------------------

//	System
#import <Quartz/Quartz.h>

//	iMedia
#import "IMBConfig.h"
#import "IMBFlickrNode.h"
#import "IMBFlickrParser.h"
//#import "IMBFlickrQueryEditor.h"
#import "IMBFlickrHeaderViewController.h"
#import "IMBIconCache.h"
#import "IMBLibraryController.h"
#import "IMBLoadMoreObject.h"
#import "IMBObject.h"
#import "IMBObjectPromise.h"
#import "IMBParserController.h"
#import "NSWorkspace+iMedia.h"



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
	IMBRelease (_loadMoreButton);
	[super dealloc];
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
		
		[node startLoadMoreRequestWithContext:_flickrContext];
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
//	self.editor = [IMBFlickrQueryEditor flickrQueryEditorForParser:self];
//	rootNode.customObjectView = self.editor.view;

	IMBFlickrHeaderViewController* viewController = [IMBFlickrHeaderViewController headerViewControllerWithParser:self owningNode:rootNode];
	viewController.queryAction = @selector(addQuery:);
	viewController.buttonAction = @selector(addQuery:);
	viewController.buttonTitle = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.button.add",nil,IMBBundle(),@"Add",@"Button title in Flickr Options");

	rootNode.customHeaderViewController = viewController;
	rootNode.shouldDisplayObjectView = NO;
	
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
	if ([inOldFlickrNode hasRequest] || inOldFlickrNode.subNodes.count > 0 || inOldFlickrNode.objects.count > 0) {
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
		if ([inFlickrNode hasResponse]) {
			[inFlickrNode processResponse];
			[inFlickrNode clearResponse];
		} else {
			//	keep the 'populateNode:' loop quiet until we got our data...
			if (inFlickrNode.objects == nil) {
				inFlickrNode.subNodes = [NSArray array];
				inFlickrNode.objects = [NSArray array];
			}
			
			//	the network access needs to be started on the main thread...
			[inFlickrNode startLoadRequestWithContext:_flickrContext];
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
	
	if ([inObject isSelectable])
	{
		NSString* title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.openflickrpage",nil,IMBBundle(),@"Open Flickr Page",@"Flickr parser node context menu title.");
		NSMenuItem* showWebPageItem = [[NSMenuItem alloc] initWithTitle:title 
																 action:@selector(openFlickrPage:) 
														  keyEquivalent:@""];
		[showWebPageItem setTarget:self];
		[showWebPageItem setRepresentedObject:inObject];
		[inMenu addItem:showWebPageItem];
		[showWebPageItem release];
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
	}	

	//	lazy initialize the 'load more' button...
	if (_loadMoreButton == nil) {
		_loadMoreButton = [[IMBLoadMoreObject alloc] init];
		_loadMoreButton.clickAction = @selector (loadMoreImages:);
		_loadMoreButton.parser = self;
		_loadMoreButton.target = self;
	}
}


// For Flickr we need a remote promise that downloads the files off the internet
- (IMBObjectPromise*) objectPromiseWithObjects: (NSArray*) inObjects {
	return [[(IMBObjectPromise*)[IMBRemoteObjectPromise alloc] initWithObjects:inObjects] autorelease];
}

// Convert metadata into human readable string...

- (void) loadMetadataForObject:(IMBObject*)inObject
{
	return;
}

- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return nil;
}

#pragma mark 
#pragma mark Properties

@synthesize customQueries = _customQueries;
@synthesize delegate = _delegate;
@synthesize editor = _editor;
@synthesize flickrAPIKey = _flickrAPIKey;
@synthesize flickrSharedSecret = _flickrSharedSecret;


- (IMBLoadMoreObject*) loadMoreButton {
	return _loadMoreButton;
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


- (void) addCustomQuery:(NSDictionary*)inQueryParams {
	if (inQueryParams){
		[self.customQueries addObject:inQueryParams];
	}
}


- (void) removeCustomQuery:(NSDictionary*)inQueryParams {
	if (inQueryParams){
		[self.customQueries removeObject:inQueryParams];
	}
}


- (void) loadCustomQueries {
	NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
	
	//	try to read user defaults...
	NSArray* nodes = [prefs objectForKey:IMBFlickrParserPrefKey_CustomQueries];
	
	//	setup default user nodes...
	if (!nodes && _delegate && [_delegate respondsToSelector:@selector(flickrParserSetupDefaultQueries:)]) {
		nodes = [_delegate flickrParserSetupDefaultQueries:self];
		
	if (nodes == nil){
		nodes = [NSArray array];
	}
		
#if 0
		[prefs setObject:nodes forKey:IMBFlickrParserPrefKey_CustomQueries];
		[IMBConfig setPrefs:prefs forClass:[self class]];
#endif
	}
	
	self.customQueries = [[nodes mutableCopy] autorelease];
}


- (void) reloadCustomQueries {
	IMBLibraryController* libController = [IMBLibraryController sharedLibraryControllerWithMediaType:[self mediaType]];
	IMBFlickrNode* root = (IMBFlickrNode*) [libController nodeWithIdentifier:[self identifierForPath:@"/"]];
	[libController reloadNode:root];	
}


- (void) saveCustomQueries {
	NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
	[prefs setObject:self.customQueries forKey:IMBFlickrParserPrefKey_CustomQueries];
	[IMBConfig setPrefs:prefs forClass:[self class]];
}


@end
