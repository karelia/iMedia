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
#import "NSFileManager+iMedia.h"
#import "IMBConfig.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

static NSString* kBookmarksPrefsKey = @"accessRightsBookmarks";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBAccessRightsController ()

- (NSURL*) _urlForBookmark:(NSData*)inBookmark;

- (NSData*) _appScopedBookmarkForURL:(NSURL*)inURL;	
- (NSURL*) _urlForAppScopedBookmark:(NSData*)inBookmark;

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
	static IMBAccessRightsController* sSharedAccessRightsController = nil;
	static dispatch_once_t sOnceToken = 0;

    dispatch_once(&sOnceToken,
    ^{
		sSharedAccessRightsController = [[IMBAccessRightsController alloc] init];
	});

	return sSharedAccessRightsController;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		// Load persisted bookmarks upon launch
		
		[self loadFromPrefs];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_bookmarks);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Accessors


// Check if we have a bookmark that grants us access to the specified URL...

- (BOOL) hasBookmarkForURL:(NSURL*)inURL
{
	NSString* path = [inURL path];
	
	for (NSData* bookmark in self.bookmarks)
	{
		NSURL* url = [self _urlForBookmark:bookmark];

		if ([path hasPrefix:[url path]])
		{
			return YES;
		}
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


// If we do not have an appropriate bookmark in our list yet, then add it and save it to user's preferences
// (bookmarks must be saved instantaneously because there is no guaranteed hook to utilize when an XPC service
//  is terminated)

- (NSURL*) addBookmark:(NSData*)inBookmark
{
	NSURL* url = [self _urlForBookmark:inBookmark];
	
    @synchronized(self)
    {
        if (![self hasBookmarkForURL:url])
        {
            if ([url startAccessingSecurityScopedResource])
            {
                [self.bookmarks addObject:inBookmark];                
                [self saveToPrefs];
            } else {
                // Could not access resource for whatever reason
                return nil;
            }
            return url;
        }
    }
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Persistence


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
		BOOL started = [url startAccessingSecurityScopedResource];

        // For debugging purposes
        
		NSString* path = [url path];
		
		BOOL accessible = [[NSFileManager defaultManager]
			imb_isPath:path
			accessible:kIMBAccessRead|kIMBAccessWrite];
	
		NSLog(@"%s path=%@ started=%d accessible=%d",__FUNCTION__,path,started,accessible);
	}
}


// Save bookmarks list (SSBs) to user's preferences

- (void) saveToPrefs
{
    // Only SSBs are persistent
    
    NSMutableArray* SSBs = [NSMutableArray arrayWithCapacity:[self.bookmarks count]];
    NSData* anSSB = nil;
    NSURL* aURL = nil;
	for (NSData* bookmark in self.bookmarks)
	{
        aURL = [self _urlForBookmark:bookmark];
        anSSB = [self _appScopedBookmarkForURL:aURL];
        [SSBs addObject:anSSB];
    }
	[IMBConfig setPrefsValue:SSBs forKey:kBookmarksPrefsKey];
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


//----------------------------------------------------------------------------------------------------------------------


- (NSData*) bookmarkForURL:(NSURL*)inURL
{
	NSError* error = nil;
	
	NSData* bookmark = [inURL
		bookmarkDataWithOptions:0
		includingResourceValuesForKeys:nil
		relativeToURL:nil
		error:&error];

	NSLog(@"%s inURL=%@ error=%@",__FUNCTION__,inURL,error);
		
	return bookmark;
}


// Helper method to resolve a regular bookmark to a URL...

- (NSURL*) _urlForBookmark:(NSData*)inBookmark
{
	NSError* error = nil;
	BOOL stale = NO;
		
	NSURL* url = [NSURL
		URLByResolvingBookmarkData:inBookmark
		options:0
		relativeToURL:nil
		bookmarkDataIsStale:&stale
		error:&error];

	NSLog(@"%s url=%@ error=%@",__FUNCTION__,url,error);
		
	return url;
}


//----------------------------------------------------------------------------------------------------------------------


// Create an app scoped SSB for the specified URL...

- (NSData*) _appScopedBookmarkForURL:(NSURL*)inURL
{
	NSError* error = nil;
	
	NSData* bookmark = [inURL
		bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope/*|NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess*/
		includingResourceValuesForKeys:nil
		relativeToURL:nil
		error:&error];

	NSLog(@"%s inURL=%@ error=%@",__FUNCTION__,inURL,error);
		
	return bookmark;
}


// REsolve an app scoped SSB to a URL...

- (NSURL*) _urlForAppScopedBookmark:(NSData*)inBookmark
{
	NSError* error = nil;
	BOOL stale = NO;
		
	NSURL* url = [NSURL
		URLByResolvingBookmarkData:inBookmark
		options:NSURLBookmarkResolutionWithSecurityScope
		relativeToURL:nil
		bookmarkDataIsStale:&stale
		error:&error];

	NSLog(@"%s url=%@ error=%@",__FUNCTION__,url,error);
		
	return url;
}


//----------------------------------------------------------------------------------------------------------------------


@end

