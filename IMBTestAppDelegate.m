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


// Author: Peter Baumgartner, Dan Wood, Christoph Priebe


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBTestAppDelegate.h"
#import "IMBImageViewController.h"
#import <iMedia/iMedia.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

#define LOG_PARSERS 0
#define LOG_CREATE_NODE 0
#define LOG_POPULATE_NODE 0
#define CUSTOM_USER_INTERFACE 0


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBTestAppDelegate

@synthesize nodeViewController = _nodeViewController;
@synthesize objectViewController = _objectViewController;


//----------------------------------------------------------------------------------------------------------------------


- (void) awakeFromNib
{
	// NSLog(@"MAC OS X VERSION MIN REQUIRED = %d, MAC OS X VERSION MAX ALLOWED = %d",   MAC_OS_X_VERSION_MIN_REQUIRED, MAC_OS_X_VERSION_MAX_ALLOWED);
	
	[IMBConfig setShowsGroupNodes:YES];
	[IMBConfig setUseGlobalViewType:YES];
	
#if CUSTOM_USER_INTERFACE
	
	// Load parsers...
	
	IMBParserController* parserController = [IMBParserController sharedParserController];
	[parserController setDelegate:self];
	[parserController loadParsers];
	
	// Create libraries (singleton per mediaType)...
	
	IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:kIMBMediaTypeImage];
	[libraryController setDelegate:self];
	
	// Link the user interface (possible multiple instances) to the	singleton library...
	
	self.nodeViewController = [IMBNodeViewController viewControllerForLibraryController:libraryController];
	NSView* nodeView = self.nodeViewController.view;
	
	self.objectViewController = [IMBImageViewController viewControllerForLibraryController:libraryController];
	self.objectViewController.nodeViewController = self.nodeViewController;
	NSView* objectView = self.objectViewController.view;
	self.nodeViewController.standardObjectView = objectView;
	//	[self.nodeViewController installObjectViewForNode:nil];
	
	[nodeView setFrame:[ibWindow.contentView bounds]];
	[ibWindow setContentView:nodeView];
	[ibWindow setContentMinSize:[self.nodeViewController minimumViewSize]];
	
	// Restore window size...
	
	NSString* frame = [IMBConfig prefsValueForKey:@"windowFrame"];
	if (frame) [ibWindow setFrame:NSRectFromString(frame) display:YES animate:NO];
	
	// Load the library...
	
	[libraryController reload];
	[ibWindow makeKeyAndOrderFront:nil];
	
#else
	
	// Just open the standard iMedia panel...
	
	[self togglePanel:nil];
	
#endif
}


// Toggle panel visibility...

- (IBAction) togglePanel:(id)inSender
{
	if ([IMBPanelController isSharedPanelControllerLoaded])
	{
		IMBPanelController* controller = [IMBPanelController sharedPanelController];
		NSWindow* window = controller.window;
		
		if (window.isVisible)
		{
			[controller hideWindow:inSender];
		}
		else
		{
			[controller showWindow:inSender];
		}
	}
	else
	{
		NSArray* mediaTypes = [NSArray arrayWithObjects:kIMBMediaTypeImage,kIMBMediaTypeAudio,kIMBMediaTypeMovie,kIMBMediaTypeLink,nil];
		IMBPanelController* panelController = [IMBPanelController sharedPanelControllerWithDelegate:self mediaTypes:mediaTypes];
		[panelController showWindow:nil];
		[panelController.window makeKeyAndOrderFront:nil];		// Test app, and stand-alone app, would want this to become key.

	}
}


- (IBAction) toggleDragDestinationWindow:(id)inSender
{
	if (ibDragDestinationWindow.isVisible)
	{
		[ibDragDestinationWindow orderOut:inSender];
	}
	else
	{
		[ibDragDestinationWindow makeKeyAndOrderFront:inSender];
	}
}


// Perform cleanup and save window frame to prefs...

- (void) applicationWillTerminate:(NSNotification*)inNotification
{
	NSString* frame = NSStringFromRect(ibWindow.frame);
	if (frame) [IMBConfig setPrefsValue:frame forKey:@"windowFrame"];
}


// Cleanup...

- (void) dealloc
{
	IMBRelease(_nodeViewController);
	IMBRelease(_objectViewController);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBParserController Delegate

- (BOOL) parserController:(IMBParserController*)inController shouldLoadParser:(NSString *)parserClassname forMediaType:(NSString*)inMediaType
{
	BOOL result = YES;
#if LOG_PARSERS
	NSLog(@"%s inParserClass=%@ inMediaType=%@",__FUNCTION__,parserClassname,inMediaType);
#endif
	
//	if ([parserClassname isEqualToString:@"IMBFlickrParser"])
//	{
//		// Quick check keychain.  Detailed fetching is below in "didLoadParser" though.
//		SecKeychainItemRef item = nil;
//		UInt32 stringLength;
//		char* buffer;
//		OSStatus err = SecKeychainFindGenericPassword(NULL,10,"flickr_api",0,nil,&stringLength,(void**)&buffer,&item);
//		if (err == noErr)
//		{
//			SecKeychainItemFreeContent(NULL, buffer);
//		}
//		result = (item != nil && err == noErr);
//	}
	return result;
}


- (BOOL) parserController:(IMBParserController*)inController didLoadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
#if LOG_PARSERS
	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
#endif
	
	BOOL loaded = YES;
	
	if ([inParser isKindOfClass:[IMBFlickrParser class]])
	{
		// To test this, get your own API key from flickr (noncommercial at first, but you are planning
		// on supporting flickr in iMedia on a commmercial app, you will have to apply for a commercial
		// API key at least 30 days before shipping)
		
		// Supply your own Flickr API key and shared secret, or apply for key and secret at:
		// http://flickr.com/services/api/keys/apply
		// If you already have an API key, you will find it here:  http://www.flickr.com/services/api/keys/
		
		IMBFlickrParser* flickrParser = (IMBFlickrParser*)inParser;
		flickrParser.delegate = self;
		
		// For your actual app, you would put in the hard-wired strings here.
		
		flickrParser.flickrAPIKey = nil;
		flickrParser.flickrSharedSecret = nil;
		
		// For this test application, we will ask for the flickr key out of the keychain.
		//
		// To put in a key into your keychain, create a new keychain item in Keychain Access.
		// Give it the name of "flickr_api" with the key as the account name, and the secret as the password.
		
		SecKeychainItemRef item = nil;
		UInt32 stringLength;
		char* buffer;
		OSStatus err = SecKeychainFindGenericPassword(NULL,10,"flickr_api",0,nil,&stringLength,(void**)&buffer,&item);
		if (noErr == err)
		{
			if (stringLength > 0)
			{
				flickrParser.flickrSharedSecret = [[[NSString alloc] initWithBytes:buffer length:stringLength encoding:NSUTF8StringEncoding] autorelease];
				
				// now get the 'account'
				
				SecKeychainAttribute attributes[8];
				SecKeychainAttributeList list;
				
				attributes[0].tag = kSecAccountItemAttr;
				list.count = 1;
				list.attr = attributes;
				//SecKeychainAttribute attr = list.attr[0];
				
				err = SecKeychainItemCopyContent (item, NULL, &list, NULL, NULL);
				
				// make it clear that this is the beginning of a new keychain item
				
				if (err == noErr)
				{
					flickrParser.flickrAPIKey = [[[NSString alloc] initWithBytes:attributes[0].data length:attributes[0].length encoding:NSUTF8StringEncoding] autorelease];
					SecKeychainItemFreeContent (&list, NULL);
				}
				else NSLog(@"%s unable to fetch 'flickr_api' account from keychain: status %d", __FUNCTION__, err);
			}
			else
			{
				NSLog(@"%s Empty password for 'flickr_api' account in keychain: status %d", __FUNCTION__, err);
			}
			SecKeychainItemFreeContent(NULL, buffer);
		}
		else
		{
			NSLog(@"%s Couldn't find 'flickr_api' account in keychain: status %d", __FUNCTION__, err);
			loaded = NO;
		}
	}		// end IMBFlickrParser code
	return loaded;
}


- (void) parserController:(IMBParserController*)inController willUnloadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
#if LOG_PARSERS
	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
#endif
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBLibraryController Delegate


- (BOOL) libraryController:(IMBLibraryController*)inController shouldCreateNodeWithParser:(IMBParser*)inParser
{
#if LOG_CREATE_NODE
	NSLog(@"%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
#endif
	
	return YES;
}


- (void) libraryController:(IMBLibraryController*)inController willCreateNodeWithParser:(IMBParser*)inParser
{
#if LOG_CREATE_NODE
	NSLog(@"		%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
#endif
}


- (void) libraryController:(IMBLibraryController*)inController didCreateNode:(IMBNode*)inNode withParser:(IMBParser*)inParser
{
#if LOG_CREATE_NODE
	NSLog(@"		%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
#endif
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) libraryController:(IMBLibraryController*)inController shouldPopulateNode:(IMBNode*)inNode
{
#if LOG_POPULATE_NODE
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
#endif
	
	return YES;
}


- (void) libraryController:(IMBLibraryController*)inController willPopulateNode:(IMBNode*)inNode
{
#if LOG_POPULATE_NODE
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
#endif
}


- (void) libraryController:(IMBLibraryController*)inController didPopulateNode:(IMBNode*)inNode
{
#if LOG_POPULATE_NODE
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
#endif
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark IMBFlickrParser Delegate

- (NSArray*) flickrParserSetupDefaultQueries:(IMBFlickrParser*)inFlickrParser
{
	NSMutableArray* defaultNodes = [NSMutableArray array];
	
	//	tag search for 'macintosh' and 'apple'...
	NSMutableDictionary* dict = [NSMutableDictionary dictionary];
	//	[dict setObject:@"Tagged 'Macintosh' & 'Apple'" forKey:IMBFlickrNodeProperty_Title];
	[dict setObject:[NSNumber numberWithInt:IMBFlickrNodeMethod_TagSearch] forKey:IMBFlickrNodeProperty_Method];
	[dict setObject:@"macintosh, apple" forKey:IMBFlickrNodeProperty_Query];
	[defaultNodes addObject:dict];
	
	//	tag search for 'iphone' and 'screenshot'...
	dict = [NSMutableDictionary dictionary];
	//	[dict setObject:@"Tagged 'iPhone' & 'Screenshot'" forKey:IMBFlickrNodeProperty_Title];
	[dict setObject:[NSNumber numberWithInt:IMBFlickrNodeMethod_TagSearch] forKey:IMBFlickrNodeProperty_Method];
	[dict setObject:@"iphone, screenshot" forKey:IMBFlickrNodeProperty_Query];
	[defaultNodes addObject:dict];
	
	//	text search for 'tree'...
	dict = [NSMutableDictionary dictionary];
	//	[dict setObject:@"Search for 'Tree'" forKey:IMBFlickrNodeProperty_Title];
	[dict setObject:[NSNumber numberWithInt:IMBFlickrNodeMethod_TextSearch] forKey:IMBFlickrNodeProperty_Method];
	[dict setObject:@"tree" forKey:IMBFlickrNodeProperty_Query];
	[defaultNodes addObject:dict];
	
	return defaultNodes;
}

@end

//----------------------------------------------------------------------------------------------------------------------

#pragma mark -
#pragma mark Debugging Convenience

#ifdef DEBUG

/*!	Override debugDescription so it's easier to use the debugger.  Not compiled for non-debug versions.
 */
@implementation NSDictionary ( OverrideDebug )

- (NSString *)debugDescription
{
	return [self description];
}

@end

@implementation NSArray ( OverrideDebug )

- (NSString *)debugDescription
{
	if ([self count] > 20)
	{
		NSArray *subArray = [self subarrayWithRange:NSMakeRange(0,20)];
		return [NSString stringWithFormat:@"%@ [... %d items]", [subArray description], [self count]];
	}
	else
	{
		return [self description];
	}
}

@end

@implementation NSSet ( OverrideDebug )

- (NSString *)debugDescription
{
	return [self description];
}

@end

@implementation NSData ( description )

- (NSString *)description
{
	unsigned char *bytes = (unsigned char *)[self bytes];
	unsigned length = [self length];
	NSMutableString *buf = [NSMutableString stringWithFormat:@"NSData %d bytes:\n", length];
	int i, j;
	
	for ( i = 0 ; i < length ; i += 16 )
	{
		if (i > 1024)		// don't print too much!
		{
			[buf appendString:@"\n...\n"];
			break;
		}
		for ( j = 0 ; j < 16 ; j++ )
		{
			int offset = i+j;
			if (offset < length)
			{
				[buf appendFormat:@"%02X ",bytes[offset]];
			}
			else
			{
				[buf appendFormat:@"   "];
			}
		}
		[buf appendString:@"| "];
		for ( j = 0 ; j < 16 ; j++ )
		{
			int offset = i+j;
			if (offset < length)
			{
				unsigned char theChar = bytes[offset];
				if (theChar < 32 || theChar > 127)
				{
					theChar ='.';
				}
				[buf appendFormat:@"%c", theChar];
			}
		}
		[buf appendString:@"\n"];
	}
	[buf deleteCharactersInRange:NSMakeRange([buf length]-1, 1)];
	return buf;
}

@end

#endif
