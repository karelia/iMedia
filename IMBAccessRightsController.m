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

#import "IMBAccessRightsController.h"
#import "IMBConfig.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kBookmarksPrefsKey = @"userConfirmedBookmarks";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBAccessRightsController ()

- (NSData*) appScopedBookmarkForURL:(NSURL*)inURL;								// Creates an app scoped (security scoped) bookmark

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBAccessRightsController

@synthesize bookmarks = _bookmarks;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Lifetime


// Returns a singleton instance of the IMBEntitlementsController...

+ (IMBAccessRightsController*) sharedAccessRightsController;
{
	static IMBAccessRightsController* sSharedEntitlementsController = nil;
	static dispatch_once_t sOnceToken = 0;

    dispatch_once(&sOnceToken,
    ^{
		sSharedEntitlementsController = [[IMBAccessRightsController alloc] initWithNibName:[self nibName] bundle:[self bundle]];
	});

    NSAssert([NSThread isMainThread], @"IMBEntitlementsController should only accessed from the main thread");
	return sSharedEntitlementsController;
}


+ (NSBundle*) bundle
{
	return [NSBundle bundleForClass:[self class]];
}


+ (NSString*) nibName
{
	return @"IMBAccessRightsController";
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithNibName:(NSString*)inNibName bundle:(NSBundle*)inBundle
{
	if (self = [super initWithNibName:inNibName bundle:inBundle])
	{
		self.bookmarks = [NSMutableArray array];
		
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


// Helper method to resolve an app scoped SSB to a URL...

- (NSURL*) _urlForBookmark:(NSData*)inBookmark
{
	NSError* error = nil;
	BOOL stale = NO;
		
	return [NSURL
		URLByResolvingBookmarkData:inBookmark
		options:NSURLBookmarkResolutionWithSecurityScope|NSURLBookmarkResolutionWithoutUI
		relativeToURL:nil
		bookmarkDataIsStale:&stale
		error:&error];
}


// Load the dictionary from the prefs, and then resolve each bookmark to a URL to make sure that the app has
// access to the respective part of the file system. Start access, thus granting the rights. Please note that
// we won't balance with stopAccessing until the app terminates...

- (void) loadFromPrefs
{
	NSArray* bookmarks = [IMBConfig prefsValueForKey:kBookmarksPrefsKey];
	self.bookmarks = [NSMutableArray arrayWithArray:bookmarks];
	
	for (NSData* bookmark in self.bookmarks)
	{
		NSURL* url = [self _urlForBookmark:bookmark];
		[url startAccessingSecurityScopedResource];
	}
}


// Save the dictionary as is to the prefs. Now also balance the startAccessingSecurityScopedResource which was
// done in the method above. Stop accessing this url, thus balancing the call in the previous method...
		
- (void) saveToPrefs
{
	[IMBConfig setPrefsValue:self.bookmarks forKey:kBookmarksPrefsKey];

	for (NSData* bookmark in self.bookmarks)
	{
		NSURL* url = [self _urlForBookmark:bookmark];
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
		@"Click the \"Confirm\" button to grant access to your media files.",
		@"NSOpenPanel message");
				
	panel.prompt = NSLocalizedStringWithDefaultValue(
		@"IMBEntitlementsController.openPanel.prompt",
		nil,
		IMBBundle(),
		@"Confirm",
		@"NSOpenPanel button");

	panel.accessoryView = self.view;

	[panel setDirectoryURL:inSuggestedURL];
	NSInteger button = [panel runModal];
	
	if (button == NSOKButton)
	{
		NSURL* url = [panel URL];
			
		if ([self confirmedBookmarkForURL:url] == nil)
		{
			NSData* bookmark = [self appScopedBookmarkForURL:url];
			[self.bookmarks addObject:bookmark];
		}
		
		return YES;
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Accessors


// Walk through our user confirmed bookmarks and check if we have one that contains the specified URL. 
// If there are more than one then just use the first one. Please note that we won't return the app
// scoped SSB directly, but we'll create a regular bookmark instead and return that - because the XPC
// service wouldn't be able to use an app scoped SSB anyway...

- (NSData*) confirmedBookmarkForURL:(NSURL*)inURL
{
	NSString* path = [inURL path];
	
	for (NSData* bookmark in self.bookmarks)
	{
		NSURL* url = [self _urlForBookmark:bookmark];

		if ([path hasPrefix:[url path]])
		{
			url = [self _urlForBookmark:bookmark];
			
			NSError* error = nil;
			NSData* regularBookmark = [url
				bookmarkDataWithOptions:0
				includingResourceValuesForKeys:nil
				relativeToURL:nil
				error:&error];
				
			return regularBookmark;
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


//----------------------------------------------------------------------------------------------------------------------


@end

