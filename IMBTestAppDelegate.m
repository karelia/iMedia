//
//  IMBTestAppDelegate.m
//  iMedia
//
//  Created by Peter Baumgartner on 18.07.09.
//  Copyright 2009 IMAGINE GbR. All rights reserved.
//


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
	NSView* containerView = self.nodeViewController.objectContainerView;
	
	self.objectViewController = [IMBImageViewController viewControllerForLibraryController:libraryController];
	self.objectViewController.nodeViewController = self.nodeViewController;
	NSView* objectView = self.objectViewController.view;
	[nodeViewController installStandardObjectView:objectView];

	[nodeView setFrame:[ibWindow.contentView bounds]];
	[ibWindow setContentView:nodeView];

	// Restore window size...
	
	NSString* frame = [IMBConfig prefsValueForKey:@"windowFrame"];
	if (frame) [ibWindow setFrame:NSRectFromString(frame) display:YES animate:NO];
	
	// Load the library...
	
	[libraryController reload];
	[ibWindow makeKeyAndOrderFront:nil];
	
	#else
	
	// Just open the standard iMedia panel...
	
	NSArray* mediaTypes = [NSArray arrayWithObjects:kIMBMediaTypeImage,kIMBMediaTypeAudio,kIMBMediaTypeMovie,nil];
	IMBPanelController* panelController = [IMBPanelController sharedPanelControllerWithDelegate:self mediaTypes:mediaTypes];
	[panelController showWindow:nil];
	
	#endif
}
	

// Toggle panel visibility...

- (IBAction) togglePanel:(id)inSender
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


// Save window frame to prefs...

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
		OSStatus err = SecKeychainFindGenericPassword(NULL,10,"flickr_api",0,nil,&stringLength,(void*)&buffer,&item);
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
												   (void *)&buffer,
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
				
				// make it clear that this is the beginning of a new
				// keychain item
				if (theStatus == noErr)
				{
					flickrParser.flickrAPIKey = [[[NSString alloc] initWithBytes:attributes[0].data length:attributes[0].length encoding:NSUTF8StringEncoding] autorelease];
					
				NSLog(@"Flickr credentials: %@ %@", flickrParser.flickrAPIKey, flickrParser.flickrSharedSecret);
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


@end
