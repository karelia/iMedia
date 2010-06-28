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
	NSLog(@"MAC OS X VERSION MIN REQUIRED = %d, MAC OS X VERSION MAX ALLOWED = %d", 
		  MAC_OS_X_VERSION_MIN_REQUIRED,
		  MAC_OS_X_VERSION_MAX_ALLOWED);
		  
		  
	[IMBConfig registerDefaultValues];
	[IMBConfig setShowsGroupNodes:YES];
	
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
	[self.nodeViewController installStandardObjectView:objectView];

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
//			[IMBPanelController cleanupSharedPanelController];
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

- (BOOL) controller:(IMBParserController*)inController shouldLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType
{
	#if LOG_PARSERS
	NSLog(@"%s inParserClass=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParserClass),inMediaType);
	#endif
	
	if ([NSStringFromClass(inParserClass) isEqualToString:@"IMBFlickrParser"])
	{
		SecKeychainItemRef item = nil;
		UInt32 stringLength;
		char* buffer;
		OSStatus err = SecKeychainFindGenericPassword(NULL,10,"flickr_api",0,nil,&stringLength,(void**)&buffer,&item);
		if (err == noErr)
		{
			SecKeychainItemFreeContent(NULL, buffer);
		}
		return item != nil && err == noErr;
	}
	
	return YES;
}


- (void) controller:(IMBParserController*)inController willLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType
{
	#if LOG_PARSERS
	NSLog(@"%s inParserClass=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParserClass),inMediaType);
	#endif
}


- (void) controller:(IMBParserController*)inController didLoadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
	#if LOG_PARSERS
	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
	#endif

	if ([inParser isKindOfClass:[IMBFlickrParser class]])
	{
		// To test this, get your own API key from flickr (noncommercial at first, but you are planning
		// on supporting flickr in iMedia on a commmercial app, you will have to apply for a commercial
		// API key at least 30 days before shipping)
		
		#warning Supply your own Flickr API key and shared secret, or apply for key and secret at: http://flickr.com/services/api/keys/apply
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
		OSStatus theStatus = noErr;
		char *buffer;
		UInt32 stringLength;
		
		theStatus = SecKeychainFindGenericPassword(NULL,
												   10,	// length of name
												   "flickr_api",
												   0,
												   nil,
												   &stringLength,
												   (void**)&buffer,
												   &item);
		
		if (noErr == theStatus)
		{
			if (stringLength > 0)
			{
				flickrParser.flickrSharedSecret = [[[NSString alloc] initWithBytes:buffer length:stringLength encoding:NSUTF8StringEncoding] autorelease];
				
				// now get the 'account'
				
				SecKeychainAttribute attributes[8];
				SecKeychainAttribute attr;
				SecKeychainAttributeList list;
				
				attributes[0].tag = kSecAccountItemAttr;
				list.count = 1;
				list.attr = attributes;
				attr = list.attr[0];
				
				theStatus = SecKeychainItemCopyContent (item, NULL, &list, NULL, NULL);
				
				// make it clear that this is the beginning of a new keychain item
				
				if (theStatus == noErr)
				{
					flickrParser.flickrAPIKey = [[[NSString alloc] initWithBytes:attributes[0].data length:attributes[0].length encoding:NSUTF8StringEncoding] autorelease];
					SecKeychainItemFreeContent (&list, NULL);
				}
				else NSLog(@"%@ unable to fetch 'flickr_api' account from keychain: status %d", NSStringFromSelector(_cmd), theStatus);
			}
			else
			{
				NSLog(@"%@ Empty password for 'flickr_api' account in keychain: status %d", NSStringFromSelector(_cmd), theStatus);
			}
			SecKeychainItemFreeContent(NULL, buffer);
		}
		else
		{
			NSLog(@"%@ Couldn't find 'flickr_api' account in keychain: status %d", NSStringFromSelector(_cmd), theStatus);
		}
	}		// end IMBFlickrParser code
}


- (void) controller:(IMBParserController*)inController willUnloadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
	#if LOG_PARSERS
	NSLog(@"%s inParser=%@ inMediaType=%@",__FUNCTION__,NSStringFromClass(inParser.class),inMediaType);
	#endif
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark IMBLibraryController Delegate


- (BOOL) controller:(IMBLibraryController*)inController shouldCreateNodeWithParser:(IMBParser*)inParser
{
	#if LOG_CREATE_NODE
	NSLog(@"%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif

	return YES;
}


- (void) controller:(IMBLibraryController*)inController willCreateNodeWithParser:(IMBParser*)inParser
{
	#if LOG_CREATE_NODE
	NSLog(@"		%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif
}


- (void) controller:(IMBLibraryController*)inController didCreateNode:(IMBNode*)inNode withParser:(IMBParser*)inParser
{
	#if LOG_CREATE_NODE
	NSLog(@"		%s inParser=%@",__FUNCTION__,NSStringFromClass(inParser.class));
	#endif
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) controller:(IMBLibraryController*)inController shouldPopulateNode:(IMBNode*)inNode
{
	#if LOG_POPULATE_NODE
	NSLog(@"%s inNode=%@",__FUNCTION__,inNode.name);
	#endif

	return YES;
}


- (void) controller:(IMBLibraryController*)inController willPopulateNode:(IMBNode*)inNode
{
	#if LOG_POPULATE_NODE
	NSLog(@"		%s inNode=%@",__FUNCTION__,inNode.name);
	#endif
}


- (void) controller:(IMBLibraryController*)inController didPopulateNode:(IMBNode*)inNode
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
	[dict setObject:@"Tagged 'Macintosh' & 'Apple'" forKey:IMBFlickrNodeProperty_Title];
	[dict setObject:[NSNumber numberWithInt:IMBFlickrNodeMethod_TagSearch] forKey:IMBFlickrNodeProperty_Method];
	[dict setObject:@"macintosh, apple" forKey:IMBFlickrNodeProperty_Query];
	[defaultNodes addObject:dict];
	
	//	tag search for 'iphone' and 'screenshot'...
	dict = [NSMutableDictionary dictionary];
	[dict setObject:@"Tagged 'iPhone' & 'Screenshot'" forKey:IMBFlickrNodeProperty_Title];
	[dict setObject:[NSNumber numberWithInt:IMBFlickrNodeMethod_TagSearch] forKey:IMBFlickrNodeProperty_Method];
	[dict setObject:@"iphone, screenshot" forKey:IMBFlickrNodeProperty_Query];
	[defaultNodes addObject:dict];
	
	//	text search for 'tree'...
	dict = [NSMutableDictionary dictionary];
	[dict setObject:@"Search for 'Tree'" forKey:IMBFlickrNodeProperty_Title];
	[dict setObject:[NSNumber numberWithInt:IMBFlickrNodeMethod_TextSearch] forKey:IMBFlickrNodeProperty_Method];
	[dict setObject:@"tree" forKey:IMBFlickrNodeProperty_Query];
	[defaultNodes addObject:dict];
	
	return defaultNodes;
}


//----------------------------------------------------------------------------------------------------------------------


@end
