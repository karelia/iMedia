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


// Author: Christoph Priebe


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import <XPCKit/XPCKit.h>

#import "IMBConfig.h"
#import "IMBFlickrParserMessenger.h"
#import "IMBFlickrParser.h"
#import "IMBFolderParser.h"
#import "IMBLoadMoreObject.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBParserController.h"
#import "SBUtilities.h"



//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBFlickrParserMessenger

//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) mediaType
{
	return kIMBMediaTypeImage;
}

+ (NSString*) parserClassName
{
	return @"IMBFlickrParser";
}


+ (NSString*) identifier
{
	return @"com.karelia.imedia.Flickr";
}


+ (NSString*) xpcSerivceIdentifier
{
	return @"com.karelia.imedia.Flickr";
}


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
    @autoreleasepool {
        [IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
    }
}


- (id) init
{
	if ((self = [super init]))
    {
		// setup desired size to get, from delegate
		self.desiredSize = [IMBConfig flickrDownloadSize];

        //	lazy initialize the 'load more' button...
        if (_loadMoreButton == nil) {
            _loadMoreButton = [[IMBLoadMoreObject alloc] init];
            _loadMoreButton.clickAction = @selector (loadMoreImages:);
            _loadMoreButton.parserMessenger = self;
            _loadMoreButton.target = self;
        }
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease (_loadMoreButton);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super initWithCoder:inCoder]))
	{
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
	IMBFlickrParserMessenger* copy = (IMBFlickrParserMessenger*)[super copyWithZone:inZone];
	
	return copy;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Properties

@synthesize desiredSize = _desiredSize;

- (IMBLoadMoreObject*) loadMoreButton {
	return _loadMoreButton;
}


#pragma mark 
#pragma mark XPC Methods

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
	IMBFlickrParser* parser = (IMBFlickrParser*)[self newParser];
	parser.identifier = [[self class] identifier];
	parser.mediaType = self.mediaType;
	parser.mediaSource = self.mediaSource;
	
	NSArray* parsers = [NSArray arrayWithObject:parser];
	[parser release];
	return parsers;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark App Methods

// Add a 'Show in Finder' command to the context menu...
- (void) willShowContextMenu:(NSMenu*)inMenu forNode:(IMBNode*)inNode
{
	NSString* title = NSLocalizedStringWithDefaultValue(
		@"IMBObjectViewController.menuItem.revealInFinder",
		nil,IMBBundle(),
		@"Show in Finder",
		@"Menu item in context menu of IMBObjectViewController");
	
	NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
	[item setRepresentedObject:inNode.mediaSource];
	[item setTarget:self];
	[inMenu addItem:item];
	[item release];
}


- (void) willShowContextMenu:(NSMenu*)inMenu forObject:(IMBObject*)inObject
{
//	if ([inObject isKindOfClass:[IMBNodeObject class]])
//	{
//		NSString* title = NSLocalizedStringWithDefaultValue(
//			@"IMBObjectViewController.menuItem.revealInFinder",
//			nil,IMBBundle(),
//			@"Show in Finder",
//			@"Menu item in context menu of IMBObjectViewController");
//		
//		IMBNode* node = [self nodeWithIdentifier:((IMBNodeObject*)inObject).representedNodeIdentifier];
//		NSString* path = (NSString*) [node mediaSource];
//		
//		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
//		[item setRepresentedObject:path];
//		[item setTarget:self];
//		[inMenu addItem:item];
//		[item release];
//	}
}


- (IBAction) revealInFinder:(id)inSender
{
	NSURL* url = (NSURL*)[inSender representedObject];
	NSString* path = [url path];
	NSString* folder = [path stringByDeletingLastPathComponent];
	[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
}


//----------------------------------------------------------------------------------------------------------------------


@end
