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


//----------------------------------------------------------------------------------------------------------------------


// Author: Christoph Priebe


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBConfig.h"
#import "IMBFlickrNode.h"
#import "IMBFlickrParser.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSString+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBFlickrParser


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
	}
	
	return self;
}

- (void) dealloc
{
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark
#pragma mark Flickr Request Handling

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


#pragma mark 
#pragma mark Parser Methods

- (IMBNode*) unpopulatedTopLevelNode:(NSError**)outError
{
	//	load Flickr icon...
	NSBundle* ourBundle = [NSBundle bundleForClass:[IMBNode class]];
	NSString* pathToImage = [ourBundle pathForResource:@"Flickr" ofType:@"png"];
	NSImage* icon = [[[NSImage alloc] initWithContentsOfFile:pathToImage] autorelease];
	
    //  create an empty root node (unpopulated and without subnodes)...	
	IMBNode* node = [[[IMBNode alloc] init] autorelease];
	node.groupType = kIMBGroupTypeInternet;	
	node.icon = icon;
	node.identifier = [self identifierForPath:@"/"];
	node.isIncludedInPopup = YES;
	node.isLeafNode = NO;
	node.isTopLevelNode = YES;
	node.mediaType = self.mediaType;
	node.mediaSource = nil;
	node.name = @"Flickr";
	node.parserIdentifier = self.identifier;
	
	return node;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
    if (inNode.isTopLevelNode) {
        IMBFlickrNode* rootNode = (IMBFlickrNode*) inNode;

        //  add subnodes...
        NSMutableArray* subnodes = [inNode mutableArrayForPopulatingSubnodes];
        [subnodes addObject:[IMBFlickrNode flickrNodeForRecentPhotosForRoot:rootNode parser:self]];
        [subnodes addObject:[IMBFlickrNode flickrNodeForInterestingPhotosForRoot:rootNode parser:self]];

        //  add objects...
        rootNode.objects = [NSMutableArray array];
    }
    
    return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// Since we know that we have local files we can use the helper method supplied by the base class...

- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	return [self bookmarkForLocalFileObject:inObject error:outError];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helpers


- (IMBObject*) objectForURL:(NSURL*)inURL name:(NSString*)inName index:(NSUInteger)inIndex;
{
	IMBObject* object = [[[IMBObject alloc] init] autorelease];
	object.location = inURL;
	object.name = inName;
	object.parserIdentifier = self.identifier;
	object.index = inIndex;
	
	object.imageRepresentationType = IKImageBrowserCGImageRepresentationType; 
	object.imageLocation = nil;             // will be loaded lazily when needed
	object.imageRepresentation = nil;		// will be loaded lazily when needed
	object.metadata = nil;					// will be loaded lazily when needed
	
	return object;
}


//----------------------------------------------------------------------------------------------------------------------


@end
