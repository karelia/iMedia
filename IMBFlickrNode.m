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

//	iMedia
#import "IMBFlickrNode.h"
#import "IMBFlickrParser.h"



//----------------------------------------------------------------------------------------------------------------------

@interface IMBFlickrNode ()
- (OFFlickrAPIRequest*) flickrRequestWithContext: (OFFlickrAPIContext*) context;
//	Utilities:
+ (NSDictionary*) argumentsForMethod: (NSInteger) method query: (NSString*) query;
+ (NSImage*) coreTypeIconNamed: (NSString*) name;
+ (NSString*) flickrMethodForMethodCode: (NSInteger) code;
+ (NSString*) identifierWithMethod: (NSInteger) method query: (NSString*) query;
@end

#pragma mark -

//----------------------------------------------------------------------------------------------------------------------

//	Some additions to the iMB node useful for Flickr handling:
@implementation IMBFlickrNode

NSString* const IMBFlickrNodePrefKey_Arguments = @"arguments";
NSString* const IMBFlickrNodePrefKey_Method = @"method";
NSString* const IMBFlickrNodePrefKey_Query = @"query";
NSString* const IMBFlickrNodePrefKey_Title = @"title";


#pragma mark
#pragma mark Construction

- (id) copyWithZone: (NSZone*) inZone {
	IMBFlickrNode* copy = [super copyWithZone:inZone];
	copy.customNode = self.customNode;
	return copy;
}
	

+ (IMBFlickrNode*) createGenericFlickrNodeForRoot: (IMBFlickrNode*) root
										   parser: (IMBParser*) parser {
	
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


+ (IMBFlickrNode*) flickrNodeForInterestingPhotosForRoot: (IMBFlickrNode*) root
												  parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [self createGenericFlickrNodeForRoot:root parser:parser];
	node.icon = [IMBFlickrNode coreTypeIconNamed:@"SmartFolderIcon.icns"];
	node.identifier = [self identifierWithMethod:IMBFlickrNodeMethod_MostInteresting query:@"30"];
	node.mediaSource = node.identifier;
	node.name = NSLocalizedString (@"Most Interesting", @"Flickr parser standard node name.");
	
	[node setFlickrMethod:@"flickr.interestingness.getList"
				arguments:[NSDictionary dictionaryWithObjectsAndKeys:@"30", @"per_page", nil]];
	
	return node;
}


+ (IMBFlickrNode*) flickrNodeForRecentPhotosForRoot: (IMBFlickrNode*) root
											 parser: (IMBParser*) parser {
	
	IMBFlickrNode* node = [self createGenericFlickrNodeForRoot:root parser:parser];
	node.icon = [IMBFlickrNode coreTypeIconNamed:@"SmartFolderIcon.icns"];
	node.identifier = [self identifierWithMethod:IMBFlickrNodeMethod_Recent query:@"30"];
	node.mediaSource = node.identifier;
	node.name = NSLocalizedString (@"Recent", @"Flickr parser standard node name.");
	
	[node setFlickrMethod:@"flickr.photos.getRecent"
				arguments:[NSDictionary dictionaryWithObjectsAndKeys:@"30", @"per_page", nil]];
	
	return node;
}


+ (IMBFlickrNode*) flickrNodeForRoot: (IMBFlickrNode*) root
							   title: (NSString*) title
						  identifier: (NSString*) identifier
							  method: (NSString*) method 
						   arguments: (NSDictionary*) arguments
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
	
	//	Flickr stuff...
	node.identifier = identifier;
	node.mediaSource = node.identifier;
	node.name = title;
	node.icon = [IMBFlickrNode coreTypeIconNamed:@"SmartFolderIcon.icns"];
	[node setFlickrMethod:method arguments:arguments];
	
	return node;
}


+ (IMBFlickrNode*) flickrNodeFromDict: (NSDictionary*) dict 
							 rootNode: (IMBFlickrNode*) root
							   parser: (IMBParser*) parser {
	
	if (!dict) return nil;
	
	//	extract node data from preferences dictionary...
	NSInteger method = [[dict objectForKey:IMBFlickrNodePrefKey_Method] intValue];
	NSString* query = [dict objectForKey:IMBFlickrNodePrefKey_Query];
	NSString* title = [dict objectForKey:IMBFlickrNodePrefKey_Title];
	
	if (!query || !title) {
		NSLog (@"Invalid Flickr parser user node dictionary.");
		return nil;
	}
	
	NSDictionary* arguments = [IMBFlickrNode argumentsForMethod:method query:query];
	NSString* flickrMethod = [IMBFlickrNode flickrMethodForMethodCode:method];
	NSString* identifier = [IMBFlickrNode identifierWithMethod:method query:query];
	IMBFlickrNode* node = [IMBFlickrNode flickrNodeForRoot:root
													 title:title
												identifier:identifier
													method:flickrMethod
												 arguments:arguments
													parser:parser];
	
	node.customNode = YES;
	return node;
}



#pragma mark
#pragma mark Flickr Handling

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


#pragma mark
#pragma mark Persistence

- (NSDictionary*) preferencesDictRepresentation {
	NSMutableDictionary* dict = [NSMutableDictionary dictionary];
	
	[dict setObject:self.name forKey:IMBFlickrNodePrefKey_Title];
	
	//	NSDictionary* 
	return dict;
}


#pragma mark
#pragma mark Properties

@synthesize customNode = _customNode;


#pragma mark
#pragma mark Utilities

+ (NSDictionary*) argumentsForMethod: (NSInteger) method query: (NSString*) query {
	NSMutableDictionary* arguments = [NSMutableDictionary dictionary];
	
	//	build query arguments based on method...
	if (query) {
		if (method == IMBFlickrNodeMethod_TagSearch) {
			[arguments setObject:query forKey:@"tags"];
			[arguments setObject:@"all" forKey:@"tag_mode"];
		} else if (method == IMBFlickrNodeMethod_TextSearch) {
			[arguments setObject:query forKey:@"text"];
		}
	}
	
	//	some arguments always needed...
	[arguments setObject:@"30" forKey:@"per_page"];
	
	return arguments;
}


+ (NSImage*) coreTypeIconNamed: (NSString*) name {
	NSBundle* coreTypes = [NSBundle	bundleWithPath:@"/System/Library/CoreServices/CoreTypes.bundle"];
	NSString* path = [coreTypes pathForResource:name ofType:nil];
	NSImage* icon = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize (16.0,16.0)];
	return icon;
}


+ (NSString*) flickrMethodForMethodCode: (NSInteger) code {
	if (code == IMBFlickrNodeMethod_TagSearch || code == IMBFlickrNodeMethod_TextSearch) {
		return @"flickr.photos.search";
	} else if (code == IMBFlickrNodeMethod_Recent) {
		return @"flickr.photos.getRecent";
	} else if (code == IMBFlickrNodeMethod_MostInteresting) {
		return @"flickr.interestingness.getList";
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
	NSString* flickrMethod = [self flickrMethodForMethodCode:method];
	if (method == IMBFlickrNodeMethod_TagSearch) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/tag"];
	} else if (method == IMBFlickrNodeMethod_TextSearch) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/text"];
	} else if (method == IMBFlickrNodeMethod_Recent) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/recent"];
	} else if (method == IMBFlickrNodeMethod_MostInteresting) {
		flickrMethod = [flickrMethod stringByAppendingString:@"/intersting"];		
	}
	NSString* albumPath = [NSString stringWithFormat:@"/%@/%@", flickrMethod, query];
	NSString* parserClassName = NSStringFromClass ([IMBFlickrParser class]);
	return [NSString stringWithFormat:@"%@:/%@", parserClassName, albumPath];
}

@end