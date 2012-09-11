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

//  XPC Kit
#import <XPCKit/XPCKit.h>

//  Media Browser
#import "IMBConfig.h"
#import "IMBFlickrParserMessenger.h"
#import "IMBFlickrParser.h"
#import "IMBFolderParser.h"
#import "IMBLoadMoreObject.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBParserController.h"
#import "SBUtilities.h"



#pragma mark 

@implementation IMBFlickrParserMessenger

#pragma mark 
#pragma mark Construction & Destruction

+ (void) load {
    @autoreleasepool {
        [IMBParserController registerParserMessengerClass:self forMediaType:[self mediaType]];
    }
}


- (id) init {
	if ((self = [super init])) {
		self.desiredSize = [IMBConfig flickrDownloadSize];
        [self loadFlickrAPIKeyAndSharedSecretFromKeychain];
	}
	
	return self;
}


- (void) dealloc {
	IMBRelease (_flickrAPIKey);
	IMBRelease (_flickrSharedSecret);
	IMBRelease (_loadMoreButton);
	[super dealloc];
}


- (id) initWithCoder: (NSCoder*) inCoder {
	if ((self = [super initWithCoder:inCoder])) {
        self.desiredSize = [inCoder decodeIntegerForKey:@"desiredSize"];
        self.flickrAPIKey = [inCoder decodeObjectForKey:@"flickrAPIKey"];
        self.flickrSharedSecret = [inCoder decodeObjectForKey:@"flickrSharedSecret"];
	}
	
	return self;
}


- (void) encodeWithCoder: (NSCoder*) inCoder {
	[inCoder encodeInteger:self.desiredSize forKey:@"desiredSize"];
	[inCoder encodeObject:self.flickrAPIKey forKey:@"flickrAPIKey"];
	[inCoder encodeObject:self.flickrSharedSecret forKey:@"flickrSharedSecret"];

	[super encodeWithCoder:inCoder];
}


- (id) copyWithZone: (NSZone*) inZone {
	IMBFlickrParserMessenger* copy = (IMBFlickrParserMessenger*)[super copyWithZone:inZone];
	
    copy.desiredSize = self.desiredSize;
    copy.flickrAPIKey = self.flickrAPIKey;
    copy.flickrSharedSecret = self.flickrSharedSecret;
    
	return copy;
}


#pragma mark 
#pragma mark Parser Messenger

+ (NSString*) mediaType {
	return kIMBMediaTypeImage;
}


+ (NSString*) parserClassName {
	return @"IMBFlickrParser";
}


+ (NSString*) identifier {
	return @"com.karelia.imedia.Flickr";
}


+ (NSString*) xpcSerivceIdentifier {
	return @"com.karelia.imedia.Flickr";
}


#pragma mark 
#pragma mark Properties

@synthesize desiredSize = _desiredSize;
@synthesize flickrAPIKey = _flickrAPIKey;
@synthesize flickrSharedSecret = _flickrSharedSecret;


- (IMBLoadMoreObject*) loadMoreButton {
    //	lazy initialize the 'load more' button...
    if (_loadMoreButton == nil) {
        _loadMoreButton = [[IMBLoadMoreObject alloc] init];
        _loadMoreButton.clickAction = @selector (loadMoreImages:);
        _loadMoreButton.parserMessenger = self;
        _loadMoreButton.target = self;
    }

	return _loadMoreButton;
}


#pragma mark 
#pragma mark XPC Methods

- (NSArray*) parserInstancesWithError: (NSError**) outError {
	IMBFlickrParser* parser = (IMBFlickrParser*)[self newParser];
    parser.flickrAPIKey = self.flickrAPIKey;
    parser.flickrSharedSecret = self.flickrSharedSecret;
	parser.identifier = [[self class] identifier];
	parser.mediaType = self.mediaType;
	parser.mediaSource = self.mediaSource;
    parser.parserMessenger = self;
	
	NSArray* parsers = [NSArray arrayWithObject:parser];
	[parser release];
	return parsers;
}


#pragma mark 
#pragma mark App Methods

// Add a 'Show in Finder' command to the context menu...
- (void) willShowContextMenu: (NSMenu*) inMenu forNode: (IMBNode*) inNode {
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


- (void) willShowContextMenu: (NSMenu*) inMenu forObject: (IMBObject*) inObject {
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


- (IBAction) revealInFinder: (id) inSender {
	NSURL* url = (NSURL*)[inSender representedObject];
	NSString* path = [url path];
	NSString* folder = [path stringByDeletingLastPathComponent];
	[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
}


#pragma mark
#pragma mark Utilities

- (void) loadFlickrAPIKeyAndSharedSecretFromKeychain {
    // To test this, get your own API key from flickr (noncommercial at first, but you are planning on supporting flickr in iMedia on a commmercial app, you will have to apply for a commercial API key at least 30 days before shipping)
    
    // Supply your own Flickr API key and shared secret, or apply for key and secret at: http://flickr.com/services/api/keys/apply
    // If you already have an API key, you will find it here:  http://www.flickr.com/services/api/keys/
    
    // For your actual app, you would put in the hard-wired strings here.
    
    self.flickrAPIKey = nil;
    self.flickrSharedSecret = nil;
    
    // For this test application, we will ask for the flickr key out of the keychain. To put in a key into your keychain, create a new keychain item in Keychain Access. Give it the name of "flickr_api" with the key as the account name, and the secret as the password.
    
    SecKeychainItemRef item = nil;
    UInt32 stringLength;
    char* buffer;
    OSStatus err = SecKeychainFindGenericPassword (NULL, 10, "flickr_api", 0, nil, &stringLength, (void**)&buffer, &item);
    if (noErr == err) {
        if (stringLength > 0) {
            self.flickrSharedSecret = [[[NSString alloc] initWithBytes:buffer length:stringLength encoding:NSUTF8StringEncoding] autorelease];
            
            // now get the 'account'
            
            SecKeychainAttribute attributes[8];
            SecKeychainAttributeList list;
            
            attributes[0].tag = kSecAccountItemAttr;
            list.count = 1;
            list.attr = attributes;
            //SecKeychainAttribute attr = list.attr[0];
            
            err = SecKeychainItemCopyContent (item, NULL, &list, NULL, NULL);
            
            // make it clear that this is the beginning of a new keychain item
            
            if (err == noErr) {
                self.flickrAPIKey = [[[NSString alloc] initWithBytes:attributes[0].data length:attributes[0].length encoding:NSUTF8StringEncoding] autorelease];
                SecKeychainItemFreeContent (&list, NULL);
            } else {
                NSLog (@"%s unable to fetch 'flickr_api' account from keychain: status %ld", __FUNCTION__, (long)err);
            }
        } else {
            NSLog (@"%s Empty password for 'flickr_api' account in keychain: status %ld", __FUNCTION__, (long)err);
        }
        SecKeychainItemFreeContent (NULL, buffer);
    } else {
        NSLog(@"%s Couldn't find 'flickr_api' account in keychain: status %ld", __FUNCTION__, (long)err);
    }
}

@end
