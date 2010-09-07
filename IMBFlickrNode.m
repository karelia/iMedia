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

//	iMedia
#import "IMBFlickrNode.h"
#import "IMBFlickrObject.h"
#import "IMBFlickrParser.h"
#import "IMBLibraryController.h"
#import "IMBLoadMoreObject.h"
#import "NSString+iMedia.h"
#import "IMBNodeViewController.h"
#import "IMBFlickrHeaderViewController.h"


//----------------------------------------------------------------------------------------------------------------------

//	We need this category to make the Flickr request block on the current thread
//	and don't use the current thread's run loop. As discussed with Lukhnos D. Liu.
@interface OFFlickrAPIRequest (private)
- (void) setShouldWaitUntilDone: (BOOL) wait;
@end

@implementation OFFlickrAPIRequest (private)

- (void) setShouldWaitUntilDone: (BOOL) wait {
	[HTTPRequest setShouldWaitUntilDone:wait];
}

@end

#pragma mark -

//----------------------------------------------------------------------------------------------------------------------

@interface IMBFlickrNode ()
//	Flickr Handling:
- (OFFlickrAPIRequest*) flickrRequestWithContext: (OFFlickrAPIContext*) context;
- (void) setFlickrMethod: (NSString*) method arguments: (NSDictionary*) arguments;
//	Properties:
- (NSDictionary*) flickrResponse;
- (void) setFlickrResponse: (NSDictionary*) response;
//	Utilities:
- (NSDictionary*) argumentsForFlickrCall;
+ (NSString*) flickrMethodForMethodCode: (NSInteger) code;
+ (NSString*) identifierWithMethod: (NSInteger) method query: (NSString*) query;
+ (NSString*) identifierWithQueryParams: (NSDictionary*) inQueryParams;
@end

#pragma mark -

//----------------------------------------------------------------------------------------------------------------------

//	Some additions to the iMB node useful for Flickr handling:
@implementation IMBFlickrNode

NSString* const IMBFlickrNodeProperty_License = @"license";
NSString* const IMBFlickrNodeProperty_Method = @"method";
NSString* const IMBFlickrNodeProperty_Query = @"query";
NSString* const IMBFlickrNodeProperty_SortOrder = @"sortOrder";
NSString* const IMBFlickrNodeProperty_UUID = @"uuid";
//NSString* const IMBFlickrNodeProperty_Title = @"title";


#pragma mark
#pragma mark Construction

- (id) init {
	if (self = [super init]) {
		self.license = IMBFlickrNodeLicense_Undefined;
		self.method = IMBFlickrNodeMethod_TextSearch;
		self.sortOrder = IMBFlickrNodeSortOrder_InterestingnessDesc;		
	}
	return self;
}


- (id) copyWithZone: (NSZone*) inZone {
	IMBFlickrNode* copy = [super copyWithZone:inZone];
	copy.customNode = self.customNode;
	copy.license = self.license;
	copy.method = self.method;
	copy.query = self.query;
	copy.page = self.page;
	copy.sortOrder = self.sortOrder;
	return copy;
}
	

+ (IMBFlickrNode*) genericFlickrNodeForRoot: (IMBFlickrNode*) root
									 parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [[[IMBFlickrNode alloc] init] autorelease];
	node.attributes = [NSMutableDictionary dictionary];
	node.leaf = YES;
	node.parentNode = root;
	node.parser = parser;
	
	
	//	Leaving subNodes and objects nil, will trigger a populateNode:options:error: 
	//	as soon as the root node is opened.
	node.subNodes = nil;
	node.objects = nil;
	
	node.badgeTypeNormal = kIMBBadgeTypeReload;
	node.badgeTarget = self;
	node.badgeSelector = @selector (reloadNode:);
	
	return node;
}


+ (IMBFlickrNode*) flickrNodeForInterestingPhotosForRoot: (IMBFlickrNode*) root
												  parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [self genericFlickrNodeForRoot:root parser:parser];
	node.icon = [NSImage imageNamed:NSImageNameFolderSmart];
	[node.icon setScalesWhenResized:YES];
	[node.icon setSize:NSMakeSize(16.0, 16.0)];
	node.identifier = [self identifierWithMethod:IMBFlickrNodeMethod_MostInteresting query:@"30"];
	node.mediaSource = node.identifier;
	node.method = IMBFlickrNodeMethod_MostInteresting;
	node.name = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.node.mostinteresting",nil,IMBBundle(),@"Most Interesting",@"Flickr parser standard node name.");	
	node.sortOrder = IMBFlickrNodeSortOrder_DatePostedDesc;
	return node;
}


+ (IMBFlickrNode*) flickrNodeForRecentPhotosForRoot: (IMBFlickrNode*) root
											 parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [self genericFlickrNodeForRoot:root parser:parser];
	node.icon = [NSImage imageNamed:NSImageNameFolderSmart];
	[node.icon setScalesWhenResized:YES];
	[node.icon setSize:NSMakeSize(16.0, 16.0)];
	node.identifier = [self identifierWithMethod:IMBFlickrNodeMethod_Recent query:@"30"];
	node.mediaSource = node.identifier;
	node.method = IMBFlickrNodeMethod_Recent;	
	node.name = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.node.recent",nil,IMBBundle(),@"Recent",@"Flickr parser standard node name.");
	node.sortOrder = IMBFlickrNodeSortOrder_DatePostedDesc;
	return node;
}


+ (IMBFlickrNode*) flickrNodeForRoot: (IMBFlickrNode*) root
							  parser: (IMBParser*) parser {

	//	iMB general...
	IMBFlickrNode* node = [[[IMBFlickrNode alloc] init] autorelease];
	node.parentNode = root;
	node.parser = parser;
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


+ (IMBFlickrNode*) flickrNodeFromDict: (NSDictionary*) dict 
							 rootNode: (IMBFlickrNode*) root
							   parser: (IMBParser*) parser {
	
	if (!dict) return nil;
	
	//	extract node data from preferences dictionary...
	NSInteger method = [[dict objectForKey:IMBFlickrNodeProperty_Method] intValue];
	NSString* query = [dict objectForKey:IMBFlickrNodeProperty_Query];
	NSString* title = query; //[dict objectForKey:IMBFlickrNodeProperty_Title];
	
	if (!query || !title) {
		NSLog (@"Invalid Flickr parser user node dictionary.");
		return nil;
	}
	
	//	Flickr stuff...
	IMBFlickrNode* node = [IMBFlickrNode flickrNodeForRoot:root parser:parser];
	node.customNode = YES;
	node.icon = [NSImage imageNamed:NSImageNameFolderSmart];
	[node.icon setScalesWhenResized:YES];
	[node.icon setSize:NSMakeSize(16.0, 16.0)];

//	node.identifier = [IMBFlickrNode identifierWithMethod:method query:query];
	node.identifier = [IMBFlickrNode identifierWithQueryParams:dict];
	node.license = [[dict objectForKey:IMBFlickrNodeProperty_License] intValue];
	node.mediaSource = node.identifier;
	node.method = method;
	node.name = title;
	node.query = query;
	node.sortOrder = [[dict objectForKey:IMBFlickrNodeProperty_SortOrder] intValue];
	
	IMBFlickrHeaderViewController* viewController = [IMBFlickrHeaderViewController headerViewControllerWithParser:(IMBFlickrParser*)parser owningNode:node];
	viewController.queryParams = (NSMutableDictionary*)dict;
	viewController.buttonAction = @selector(removeQuery:);
	viewController.buttonTitle = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.button.remove",nil,IMBBundle(),@"Remove",@"Button title in Flickr Options");
	node.customHeaderViewController = viewController;

	return node;
}


+ (void) sendSelectNodeNotificationForDict:(NSDictionary*) dict {
	
	if (dict) {
//		NSInteger method = [[dict objectForKey:IMBFlickrNodeProperty_Method] intValue];
//		NSString* query = [dict objectForKey:IMBFlickrNodeProperty_Query];
//		NSString* identifier = [IMBFlickrNode identifierWithMethod:method query:query];

		NSString* identifier = [IMBFlickrNode identifierWithQueryParams:dict];
		[IMBNodeViewController selectNodeWithIdentifier:identifier];
	}
}


- (void) dealloc {
	OFFlickrAPIRequest* request = [self.attributes objectForKey:@"flickrRequest"];
	[request cancel];
	
	[(IMBFlickrHeaderViewController*)self.customHeaderViewController setOwningNode:nil];
	
	IMBRelease (_query);
	[super dealloc];
}


#pragma mark 
#pragma mark Flickr Handling

- (void) flickrAPIRequest: (OFFlickrAPIRequest*) inRequest 
  didCompleteWithResponse: (NSDictionary*) inResponseDictionary {
	
	//	get the node we associated with the request in flickrRequestWithContext: ...
	NSString* nodeIdentifier = inRequest.sessionInfo;
	IMBLibraryController* libController = [IMBLibraryController sharedLibraryControllerWithMediaType:self.parser.mediaType];
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


#pragma mark
#pragma mark Flickr Handling

- (void) clearResponse {
	[(NSMutableDictionary*)self.attributes removeObjectForKey:@"flickrResponse"];
}

// What about original size?

- (NSString *)flickrSizeFromFlickrSizeSpecifier:(FlickrSizeSpecifier)flickrSizeSpecifier
{
	NSAssert(flickrSizeSpecifier >= FlickrSizeSpecifierOriginal && flickrSizeSpecifier <= FlickrSizeSpecifierLarge, @"Illegal size for flickr");
	NSString *sizeLookup[] = { @"o", OFFlickrSmallSize, OFFlickrMediumSize, OFFlickrLargeSize };
		// Note: medium is nil, so we can't put in a dictionary.  Original not specified in objective-flickr
	return sizeLookup[flickrSizeSpecifier];
}

- (NSURL *)imageURLForDesiredSize:(FlickrSizeSpecifier)size fromPhotoDict:(NSDictionary *)photoDict context:(OFFlickrAPIContext*) context;
{
	NSURL* imageURL = nil;
	if (!imageURL && FlickrSizeSpecifierOriginal == size)
	{
		if ([photoDict objectForKey:@"url_o"])
		{
			imageURL = [NSURL URLWithString:[photoDict objectForKey:@"url_o"]];
		}
		else
		{
			size = FlickrSizeSpecifierLarge;		// downgrade to requesting large if no original
		}
	}
	if (!imageURL && FlickrSizeSpecifierLarge == size)
	{
		if ([photoDict objectForKey:@"url_l"])
		{
			imageURL = [NSURL URLWithString:[photoDict objectForKey:@"url_l"]];
		}
		else
		{
			size = FlickrSizeSpecifierMedium;		// downgrade to requesting medium if no large
		}
	}
	
	if (!imageURL && FlickrSizeSpecifierMedium == size)
	{
		if ([photoDict objectForKey:@"url_m"])
		{
			imageURL = [NSURL URLWithString:[photoDict objectForKey:@"url_m"]];
		}
		else
		{
			size = FlickrSizeSpecifierSmall;		// downgrade to requesting medium if no large
		}
	}
	
	if (!imageURL && FlickrSizeSpecifierSmall == size)
	{
		if ([photoDict objectForKey:@"url_s"])
		{
			imageURL = [NSURL URLWithString:[photoDict objectForKey:@"url_s"]];
		}
	}
	
	// Fallback.  Really we should have it by now! But search for Edward & Bella Icon has no medium size!
	if (!imageURL)
	{
		// build up URL programatically 
		NSString *flickrSize = [self flickrSizeFromFlickrSizeSpecifier:size];
		imageURL = [context photoSourceURLFromDictionary:photoDict size:flickrSize];
	}
	return imageURL;	
}



- (NSArray*) extractPhotosFromFlickrResponse: (NSDictionary*) response {
	OFFlickrAPIRequest* flickrRequest = [self.attributes objectForKey:@"flickrRequest"];

	IMBFlickrParser *parser = (IMBFlickrParser *)self.parser;
	NSArray* photos = [response valueForKeyPath:@"photos.photo"];
	NSMutableArray* objects = [NSMutableArray arrayWithCapacity:photos.count];
	for (NSDictionary* photoDict in photos) {

		IMBFlickrObject* obj = [[IMBFlickrObject alloc] init];
		
		// Only store a location if we are allowed to download
		BOOL canDownload = [[photoDict objectForKey:@"can_download"] boolValue];
		if (canDownload)
		{
			obj.location = [self imageURLForDesiredSize:parser.desiredSize fromPhotoDict:photoDict context:flickrRequest.context];
		}
		obj.name = [photoDict objectForKey:@"title"];
		
		// A lot of the metadata comes from the "extras" key we request
		NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
		[metadata addEntriesFromDictionary:photoDict];		// give metaData the whole thing!
		NSURL *webPageURL = [flickrRequest.context photoWebPageURLFromDictionary:photoDict];
		[metadata setObject:webPageURL forKey:@"webPageURL"];
		
		NSURL *quickLookURL = [self imageURLForDesiredSize:FlickrSizeSpecifierMedium fromPhotoDict:photoDict context:flickrRequest.context];
		[metadata setObject:quickLookURL forKey:@"quickLookURL"];

		// But give it a better 'description' without the nested item
		NSString *desc = [[photoDict objectForKey:@"description"] objectForKey:@"_text"];
		if (nil != desc)			[metadata setObject:desc forKey:@"descriptionHTML"];

//		NSString *can_download = [photoDict objectForKey:@"can_download"];
//		NSString *license = [photoDict objectForKey:@"license"];
//		NSString *ownerName = [photoDict objectForKey:@"ownername"];
//		NSString *photoID = [photoDict objectForKey:@"id"];
//
//		if (nil != can_download)	[metadata setObject:can_download forKey:@"can_download"];
//		if (nil != license)			[metadata setObject:license forKey:@"license"];
//		if (nil != ownerName)		[metadata setObject:ownerName forKey:@"ownername"];
//		if (nil != photoID)			[metadata setObject:photoID forKey:@"id"];

		obj.metadata = [NSDictionary dictionaryWithDictionary:metadata];
						 
		obj.parser = self.parser;
		
		NSURL* thumbnailURL = [flickrRequest.context photoSourceURLFromDictionary:photoDict size:OFFlickrThumbnailSize];
		obj.imageLocation = thumbnailURL;
		obj.imageRepresentationType = IKImageBrowserCGImageRepresentationType;
		obj.imageRepresentation = nil;	// Build lazily when needed
		
		[objects addObject:obj];
		[obj release];
	}
	return objects;
}


- (OFFlickrAPIRequest*) flickrRequestWithContext: (OFFlickrAPIContext*) context {
	OFFlickrAPIRequest* request = [self.attributes objectForKey:@"flickrRequest"];
	if (!request) {
		//	create a Flickr request for the given iMB node...
		request = [[OFFlickrAPIRequest alloc] initWithAPIContext:context];
		[(NSMutableDictionary*)self.attributes setObject:request forKey:@"flickrRequest"];
		request.requestTimeoutInterval = 60.0f;
//		[request setShouldWaitUntilDone:YES];
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


- (BOOL) hasRequest {
	return [self.attributes objectForKey:@"flickrRequest"] != nil;
}


- (BOOL) hasResponse {
	return [self.attributes objectForKey:@"flickrResponse"] != nil;
}


- (void) processResponse {	
	//	TODO: Instead of inserting the "load more" object at the end of the
	//	array, we should probably associate a sort descriptor with the image view.
	NSMutableArray* oldImages = [self.objects mutableCopy];
	IMBLoadMoreObject* loadMoreObject = nil;
	for (id object in oldImages) {
		if ([object isKindOfClass:[IMBLoadMoreObject class]]) {
			loadMoreObject = object;
			break;
		}
	}
	if (loadMoreObject) {		
		[oldImages removeObject:loadMoreObject];
	}
	
	NSMutableArray* newImages = [[self extractPhotosFromFlickrResponse:[self flickrResponse]] mutableCopy];
	[newImages removeObjectsInArray:oldImages]; //	ensure that we have no doubles
	
	[newImages insertObjects:oldImages atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, oldImages.count)]];
	
	//	add 'load more' button...
	IMBLoadMoreObject* loadMoreButton = ((IMBFlickrParser*) self.parser).loadMoreButton;
	loadMoreButton.nodeIdentifier = self.identifier;
	[newImages addObject:loadMoreButton];

	self.objects = newImages;
	
	[newImages release];
	[oldImages release];
}


- (void) setFlickrMethod: (NSString*) method
			   arguments: (NSDictionary*) arguments {
	
	[(NSMutableDictionary*)self.attributes setObject:method forKey:@"flickrMethod"];
	[(NSMutableDictionary*)self.attributes setObject:arguments forKey:@"flickrArguments"];
}


- (void) setFlickrResponse: (NSDictionary*) response {
	[(NSMutableDictionary*)self.attributes setObject:response forKey:@"flickrResponse"];
}


- (void) startFlickrRequestWithContext_onMainThread: (OFFlickrAPIContext*) context {
	OFFlickrAPIRequest* request = [self flickrRequestWithContext:context];
	if (![request isRunning]) {			
		[request setDelegate:self];	

		//	compose and start Flickr request...
		NSString* method = [IMBFlickrNode flickrMethodForMethodCode:self.method];
		NSDictionary* arguments = [self argumentsForFlickrCall];
		[request callAPIMethodWithGET:method arguments:arguments];
		
		#ifdef VERBOSE
			NSLog (@"Start Flickr request for method %@", method);
		#endif
	}	
}


- (void) startLoadRequestWithContext: (OFFlickrAPIContext*) context {
	[self performSelectorOnMainThread:@selector(startFlickrRequestWithContext_onMainThread:) withObject:context waitUntilDone:NO];
}


- (void) startLoadMoreRequestWithContext: (OFFlickrAPIContext*) context {
	self.page = self.page + 1;
	[self performSelectorOnMainThread:@selector(startFlickrRequestWithContext_onMainThread:) withObject:context waitUntilDone:NO];
}


#pragma mark
#pragma mark Properties

@synthesize customNode = _customNode;
@synthesize license = _license;
@synthesize method = _method;
@synthesize page = _page;
@synthesize query = _query;
@synthesize sortOrder = _sortOrder;


#pragma mark
#pragma mark Utilities

///	License kinds and ids as found under 
///	http://www.flickr.com/services/api/flickr.photos.licenses.getInfo.html
typedef enum {
	IMBFlickrNodeFlickrLicenseID_Undefined = 0,
	IMBFlickrNodeFlickrLicenseID_AttributionNonCommercialShareAlike = 1,
	IMBFlickrNodeFlickrLicenseID_AttributionNonCommercial = 2,
	IMBFlickrNodeFlickrLicenseID_AttributionNonCommercialNoDerivs = 3,
	IMBFlickrNodeFlickrLicenseID_Attribution = 4,
	IMBFlickrNodeFlickrLicenseID_AttributionShareAlike = 5,
	IMBFlickrNodeFlickrLicenseID_AttributionNoDerivs = 6,
	IMBFlickrNodeFlickrLicenseID_NoKnownCopyrightRestrictions = 7
} IMBFlickrNodeFlickrLicenseID;


///	Make the properties of the receiver into a dictionary with keys and values
///	that can be directly passed to the Flick method call.
///	Have a look at http://www.flickr.com/services/api/flickr.photos.search.html
///	for details and arguments of a search query.
- (NSDictionary*) argumentsForFlickrCall {
	NSMutableDictionary* arguments = [NSMutableDictionary dictionary];
	
	//	build query arguments based on method...
	if (self.query) {
		if (self.method == IMBFlickrNodeMethod_TagSearch) {
			[arguments setObject:self.query forKey:@"tags"];
			[arguments setObject:@"all" forKey:@"tag_mode"];
		} else if (self.method == IMBFlickrNodeMethod_TextSearch) {
			[arguments setObject:self.query forKey:@"text"];
		}
	}
	
	//	translate our user kinds into Flickr license kind ids...
	if (self.license == IMBFlickrNodeLicense_CreativeCommons) {
		[arguments setObject:[NSString stringWithFormat:@"%d", IMBFlickrNodeFlickrLicenseID_Attribution] forKey:@"license"];
	} else if (self.license == IMBFlickrNodeLicense_DerivativeWorks) {
		[arguments setObject:[NSString stringWithFormat:@"%d", self.license] forKey:@"license"];
	} else if (self.license == IMBFlickrNodeLicense_CommercialUse) {
		[arguments setObject:[NSString stringWithFormat:@"%d", IMBFlickrNodeFlickrLicenseID_NoKnownCopyrightRestrictions] forKey:@"license"];
	}
	
	//	determine sort order...
	NSString* sortOrder = nil;
	if (self.sortOrder == IMBFlickrNodeSortOrder_DatePostedDesc) {
		sortOrder = @"date-posted-desc";
	} else if (self.sortOrder == IMBFlickrNodeSortOrder_DatePostedAsc) {
		sortOrder = @"date-posted-asc";		
	} else if (self.sortOrder == IMBFlickrNodeSortOrder_DateTakenAsc) {
		sortOrder = @"date-taken-asc";		
	} else if (self.sortOrder == IMBFlickrNodeSortOrder_DateTakenDesc) {
		sortOrder = @"date-taken-desc";		
	} else if (self.sortOrder == IMBFlickrNodeSortOrder_InterestingnessDesc) {
		sortOrder = @"interestingness-desc";		
	} else if (self.sortOrder == IMBFlickrNodeSortOrder_InterestingnessAsc) {
		sortOrder = @"interestingness-asc";		
	} else if (self.sortOrder == IMBFlickrNodeSortOrder_Relevance) {
		sortOrder = @"relevance";		
	}
	if (sortOrder) {
		[arguments setObject:sortOrder forKey:@"sort"];
	}
	
	//	limit the search to a specific number of items...
	[arguments setObject:@"30" forKey:@"per_page"];
	
	// We are only doing photos.  Maybe later we want to do videos?
	[arguments setObject:@"photos" forKey:@"media"];

	// Extra metadata needed
	// http://www.flickr.com/services/api/flickr.photos.search.html
	[arguments setObject:@"owner_name,license,description,original_format,url_o,url_l,url_m,url_s,usage,o_dims" forKey:@"extras"];
	// Useful keys we can get from this:
	// description -> array with ...
	// original_format -> originalformat, orignalsecret
	// url_o,l, m, s ... URL to get the various sizes.  (url_l is not really documented, but works if needed.)
	// usage: can_download (& others)
	// Example of a photo that can't be downloaded: THE DECEIVING title.
	
	//	load the specified page...
	NSString* page = [NSString stringWithFormat:@"%d", self.page + 1];
	[arguments setObject:page forKey:@"page"];
	
	return arguments;
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


///	We construct here something like: 
///	  IMBFlickrParser://flickr.photos.search/tag/macintosh,apple
///
///	TOOD: Maybe it's a better idea to just go with
///	  [NSString uuid]
///	and create something like:
///	  IMBFlickrParser://12345678-12345-12345-12345678
+ (NSString*) identifierWithMethod: (NSInteger) method query: (NSString*) query {
#if 0
	//	EXPERIMENTAL...
	NSString* parserClassName = NSStringFromClass ([IMBFlickrParser class]);
	return [NSString stringWithFormat:@"%@:/%@", parserClassName, [NSString uuid]];
	//	...EXPERIMENTAL
#else
	NSString* flickrMethod = [self flickrMethodForMethodCode:method];
	if (method == IMBFlickrNodeMethod_TagSearch) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/tag"];
	} else if (method == IMBFlickrNodeMethod_TextSearch) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/text"];
	} else if (method == IMBFlickrNodeMethod_Recent) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/recent"];
	} else if (method == IMBFlickrNodeMethod_MostInteresting) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/intersting"];		// Should this be interesting?
	}
	NSString* albumPath = [NSString stringWithFormat:@"/%@/%@", flickrMethod, query];
	NSString* parserClassName = NSStringFromClass ([IMBFlickrParser class]);
	return [NSString stringWithFormat:@"%@:/%@", parserClassName, albumPath];
#endif
}

+ (NSString*) identifierWithQueryParams: (NSDictionary*) inQueryParams {
	NSString* parserClassName = NSStringFromClass ([IMBFlickrParser class]);
	NSString* uuid = [inQueryParams objectForKey:IMBFlickrNodeProperty_UUID];
	if (uuid == nil) uuid = [inQueryParams objectForKey:IMBFlickrNodeProperty_Query];
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,uuid];
}

#pragma mark -
#pragma mark Utilities
								  
// From http://gist.github.com/101674

+ (NSString *)base58EncodedValue:(long long)num {
  NSString *alphabet = @"123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ";
  int baseCount = [alphabet length];
  NSString *encoded = @"";
  while(num >= baseCount) {
	  double div = num/baseCount;
	  long long mod = (num - (baseCount * (long long)div));
	  NSString *alphabetChar = [alphabet substringWithRange: NSMakeRange(mod, 1)];
	  encoded = [NSString stringWithFormat: @"%@%@", alphabetChar, encoded];
	  num = (long long)div;
  }
  
  if(num) {
	  encoded = [NSString stringWithFormat: @"%@%@", [alphabet substringWithRange: NSMakeRange(num, 1)], encoded];
  }
  return encoded;
}
								  
+ (NSString *)descriptionOfLicense:(int)aLicenseNumber
{
	NSString *result = nil;
	switch(aLicenseNumber)
	{
		case IMBFlickrNodeFlickrLicenseID_AttributionNonCommercialShareAlike:
			result = @"Attribution-NonCommercial-ShareAlike License";
			break;
		case IMBFlickrNodeFlickrLicenseID_AttributionNonCommercial:
			result = @"Attribution-NonCommercial License";
			break;
		case IMBFlickrNodeFlickrLicenseID_AttributionNonCommercialNoDerivs:
			result = @"Attribution-NonCommercial-NoDerivs License";
			break;
		case IMBFlickrNodeFlickrLicenseID_Attribution:
			result = @"Attribution License";
			break;
		case IMBFlickrNodeFlickrLicenseID_AttributionShareAlike:
			result = @"Attribution-ShareAlike License";
			break;
		case IMBFlickrNodeFlickrLicenseID_AttributionNoDerivs:
			result = @"Attribution-NoDerivs License";
			break;
	}
	if (result)
	{
		result = [@"Creative Commons: " stringByAppendingString:result];
	}
	return result;
}

@end
