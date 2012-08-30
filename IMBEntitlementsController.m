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


// Author: Peter Baumgartner, Jörg Jacobson


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBEntitlementsController.h"
#import "IMBConfig.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kBookmarksPrefsKey = @"userConfirmedBookmarks";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBEntitlementsController ()

@property (retain) NSMutableDictionary* bookmarks;

- (NSData*) appScopedBookmarkForURL:(NSURL*)inURL;								// Creates an app scoped (security scoped) bookmark
- (NSData*) regularBookmarkForAppScopedBookmark:(NSData*)inAppScopedBookmark;	// Converts a security scoped bookmark to a regular bookmark

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBEntitlementsController

@synthesize bookmarks = _bookmarks;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Lifetime


// Returns a singleton instance of the IMBEntitlementsController...

+ (IMBEntitlementsController*) sharedEntitlementsController;
{
	static IMBEntitlementsController* sSharedEntitlementsController = nil;
	static dispatch_once_t sOnceToken = 0;

    dispatch_once(&sOnceToken,
    ^{
		sSharedEntitlementsController = [[IMBEntitlementsController alloc] init];
	});

    NSAssert([NSThread isMainThread], @"IMBEntitlementsController should only accessed from the main thread");
	return sSharedEntitlementsController;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		self.bookmarks = [NSMutableDictionary dictionary];
		
		// When the app quits, save the bookmarks to prefs, so that access rights persist...
		
		[[NSNotificationCenter defaultCenter]				 
			addObserver:self								
			selector:@selector(saveToPrefs) 
			name:NSApplicationWillTerminateNotification 
			object:nil];
			
		// Upon launch, load them again so that the user doesn't need to be prompted again...
		
		[self loadFromPrefs];

	}
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	IMBRelease(_bookmarks);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// Load the dictionary from the prefs, and then resolve each bookmark to a URL to make sure that the app has
// access to the respective part of the file system...

- (void) loadFromPrefs
{
	NSDictionary* bookmarks = [IMBConfig prefsValueForKey:kBookmarksPrefsKey];
	self.bookmarks = [NSMutableDictionary dictionaryWithDictionary:bookmarks];
	
	for (NSURL* key in self.bookmarks)
	{
		// Get bookmark...
		
		NSData* bookmark = [self.bookmarks objectForKey:key];
		
		NSError* error = nil;
		BOOL stale = NO;
		
		// Resolve it...
		
		NSURL* url = [NSURL
			URLByResolvingBookmarkData:bookmark
			options:NSURLBookmarkResolutionWithSecurityScope|NSURLBookmarkResolutionWithoutUI
			relativeToURL:nil
			bookmarkDataIsStale:&stale
			error:&error];
		
		// Start access, thus granting the rights. Please note that we won't balance with stopAccessing until
		// the app terminates...
		
		[url startAccessingSecurityScopedResource];
	}
}


// Save the dictionary as is to the prefs. Now also balance the startAccessingSecurityScopedResource which was
// done in the method above...
		
- (void) saveToPrefs
{
	[IMBConfig setPrefsValue:self.bookmarks forKey:kBookmarksPrefsKey];

	for (NSURL* url in self.bookmarks)
	{
		[url stopAccessingSecurityScopedResource];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark User Interface


- (BOOL) presentConfirmationUserInterfaceForURL:(NSURL*)inSuggestedURL
{
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	panel.canChooseDirectories = YES;
	panel.allowsMultipleSelection = NO;
	panel.canCreateDirectories = NO;
	
	panel.title = NSLocalizedStringWithDefaultValue(
		@"IMBEntitlementsController.openPanel.title",
		nil,
		IMBBundle(),
		@"Grant Access to Media Files",
		@"NSOpenPanel title");

	panel.message = NSLocalizedStringWithDefaultValue(
		@"IMBEntitlementsController.openPanel.message",
		nil,
		IMBBundle(),
		@"The application does not have the necessary rights to access your media files. Click the \"Confirm\" button to grant access to your media files.\n\nIf your media files are scattered throughout the file system, you may want to navigate up the file system hierarchy, before clicking the \"Confirm\" button.",
		@"NSOpenPanel message");
				
	panel.prompt = NSLocalizedStringWithDefaultValue(
		@"IMBEntitlementsController.openPanel.prompt",
		nil,
		IMBBundle(),
		@"Confirm",
		@"NSOpenPanel button");

	panel.accessoryView = nil;

	[panel setDirectoryURL:inSuggestedURL];
	NSInteger button = [panel runModal];
	
	if (button == NSOKButton)
	{
		NSURL* url = [panel URL];
			
		if ([self confirmedBookmarkForURL:url] == nil)
		{
			NSData* bookmark = [self appScopedBookmarkForURL:url];
			[self.bookmarks setObject:bookmark forKey:url];
		}
		
		return YES;
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Accessors


// Walk through our use confirmed bookmarks and check if we have one that contains the specified URL. 
// If there are more than one then just use the first one...

- (NSData*) confirmedBookmarkForURL:(NSURL*)inURL
{
	NSString* path = [inURL path];
	
	for (NSURL* url in _bookmarks)
	{
		if ([path hasPrefix:[url path]])
		{
			return [_bookmarks objectForKey:url];
		}
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Helpers


// Creates a URL for the common ancestor folder of the specified URLS...

- (NSURL*) commonAncestorForURLs:(NSArray*)inURLs
{
	if ([inURLs count] == 0) return nil;

	NSURL* firstURL = [inURLs objectAtIndex:0];
	NSString* commonPath = [[firstURL path] stringByStandardizingPath];
	
	for (NSURL* url in inURLs)
	{
		NSString* path = [[url path] stringByStandardizingPath];
		commonPath = [commonPath commonPrefixWithString:path options:NSLiteralSearch];
	}
	
	return [NSURL fileURLWithPath:commonPath];
}


// Create an app scoped SSB for the specified URL...

- (NSData*) appScopedBookmarkForURL:(NSURL*)inURL
{
	NSError* error = nil;
	
	NSData* bookmark = [inURL
		bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess
		includingResourceValuesForKeys:nil
		relativeToURL:nil
		error:&error];
		
	return bookmark;
}


// To be implmented...
	
- (NSData*) regularBookmarkForAppScopedBookmark:(NSData*)inAppScopedBookmark
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end

