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

//  System
#import <Quartz/Quartz.h>

//  iMedia
#import "IMBConfig.h"
#import "IMBFlickrNode.h"
#import "IMBFlickrParser.h"
#import "IMBFlickrSession.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSString+iMedia.h"



//#define VERBOSE

@implementation IMBFlickrParser

#pragma mark 
#pragma mark Construction & Destruction

- (void) dealloc {
	IMBRelease (_flickrAPIKey);
	IMBRelease (_flickrContext);
	IMBRelease (_flickrSharedSecret);
	[super dealloc];
}


#pragma mark 
#pragma mark Parser Methods

- (IMBNode*) unpopulatedTopLevelNode: (NSError**) outError {
	//	load Flickr icon...
	NSBundle* ourBundle = [NSBundle bundleForClass:[IMBNode class]];
	NSString* pathToImage = [ourBundle pathForResource:@"Flickr" ofType:@"tiff"];
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


- (BOOL) populateNode: (IMBNode*) inNode error: (NSError**) outError {
    IMBFlickrNode* inFlickrNode = (IMBFlickrNode*) inNode;

    if (inFlickrNode.isTopLevelNode) {
        //  add subnodes...
        NSMutableArray* subnodes = [inNode mutableArrayForPopulatingSubnodes];
        [subnodes addObject:[IMBFlickrNode flickrNodeForRecentPhotosForRoot:inFlickrNode parser:self]];
        [subnodes addObject:[IMBFlickrNode flickrNodeForInterestingPhotosForRoot:inFlickrNode parser:self]];

        //  add objects...
        inFlickrNode.objects = [NSMutableArray array];
    } else {
        xpc_transaction_begin ();

        //	lazy initialize the flickr context...
        if (_flickrContext == nil) {
            //  failing to setup the Flickr API key and shared secret is an implementation error...
            NSAssert (self.flickrAPIKey, @"Flickr API key property not set!");
            NSAssert (self.flickrSharedSecret, @"Flickr shared secret property not set!");
            _flickrContext = [[OFFlickrAPIContext alloc] initWithAPIKey:self.flickrAPIKey sharedSecret:self.flickrSharedSecret];
        }	

        //  we have no subnodes...
        [inFlickrNode mutableArrayForPopulatingSubnodes];
        
        //  run flickr request...
        IMBFlickrSession* session = [[IMBFlickrSession alloc] initWithFlickrContext:_flickrContext];
        [session executeFlickRequestForNode:inFlickrNode];
        
        //  evaluate the response...
        if (!session.error) {
            #ifdef VERBOSE
                NSLog (@"RESPONSE: %@", session.response);
            #endif
            NSArray* objects = [session extractPhotosFromFlickrResponseForParserMessenger:(IMBFlickrParserMessenger*)inFlickrNode.parserMessenger];
            inFlickrNode.objects = objects;    
        } else {
            if (outError) *outError = [[session.error copy] autorelease];
        }
        [session release];                

        xpc_transaction_end ();
    }
    
    return YES;
}


- (NSData*) bookmarkForObject: (IMBObject*) inObject error: (NSError**) outError {
	if (outError) *outError = nil;
	return nil;
}


- (NSDictionary*) metadataForObject: (IMBObject*) inObject error: (NSError**) outError {
	if (outError) *outError = nil;
	return nil;
}


- (NSString*) persistentResourceIdentifierForObject: (IMBObject*) inObject {
    return [[[inObject URL] fileReferenceURL] absoluteString];
}


- (id) thumbnailForObject: (IMBObject*) inObject error: (NSError**) outError {
	if (outError) *outError = nil;
    
    xpc_transaction_begin ();

    //  determine preview URL...
    NSString* thumbnailURLString = [inObject.preliminaryMetadata objectForKey:@"url_m"];
    if (!thumbnailURLString) thumbnailURLString = [inObject.preliminaryMetadata objectForKey:@"url_s"];
    if (!thumbnailURLString) thumbnailURLString = [inObject.preliminaryMetadata objectForKey:@"url_l"];
    if (!thumbnailURLString) {
        NSString* title = @"Flickr Error";
        NSString* description = @"Can't determine image preview URL.";
        
        NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                              title,@"title",
                              description,NSLocalizedDescriptionKey,
                              nil];
        
        NSError* error = [NSError errorWithDomain:kIMBErrorDomain code:paramErr userInfo:info];        
        if (*outError) *outError = error;

        return nil;
    }

    //  load image at preview URL...
    CGImageRef image = NULL;
    NSURL* thumbnailURL = [NSURL URLWithString:thumbnailURLString];
    CGImageSourceRef source = CGImageSourceCreateWithURL ((CFURLRef)thumbnailURL, NULL);
    if (source) {
        image = CGImageSourceCreateImageAtIndex (source, 0, NULL);
        [NSMakeCollectable(image) autorelease];
        CFRelease (source);
    } else {
        NSString* title = @"Flickr Image Loading Error";
        NSString* description = @"Can't determine image source.";
        
        NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                              title,@"title",
                              description,NSLocalizedDescriptionKey,
                              nil];
        
        NSError* error = [NSError errorWithDomain:kIMBErrorDomain code:paramErr userInfo:info];        
        if (*outError) *outError = error;
    }
    return (id) image;

    xpc_transaction_end ();
}


#pragma mark 
#pragma mark Properties

@synthesize flickrAPIKey = _flickrAPIKey;
@synthesize flickrSharedSecret = _flickrSharedSecret;

@end
