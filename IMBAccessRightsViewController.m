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

#import "IMBAccessRightsViewController.h"
#import "IMBAccessRightsController.h"
#import "IMBLibraryController.h"
#import "IMBNode.h"
#import "IMBParserMessenger.h"
#import "NSFileManager+iMedia.h"
#import "IMBConfig.h"
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark TYPES

typedef void (^IMBOpenPanelCompletionHandler)(NSURL* inURL);


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBAccessRightsViewController


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Lifetime


+ (NSBundle*) bundle
{
	return [NSBundle bundleForClass:[self class]];
}


+ (NSString*) nibName
{
	return @"IMBAccessRightsController";
}


//----------------------------------------------------------------------------------------------------------------------


// Returns a singleton instance of the IMBEntitlementsController...

+ (IMBAccessRightsViewController*) sharedViewController;
{
	static IMBAccessRightsViewController* sSharedViewController = nil;
	static dispatch_once_t sOnceToken = 0;

    dispatch_once(&sOnceToken,
    ^{
		sSharedViewController = [[IMBAccessRightsViewController alloc] init];
	});

 	return sSharedViewController;
}


- (id) init
{
	if (self = [super initWithNibName:[[self class] nibName] bundle:[[self class] bundle]])
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
#pragma mark User Interface


- (void) _showForSuggestedURL:(NSURL*)inSuggestedURL completionHandler:(IMBOpenPanelCompletionHandler)inCompletionBlock;
{
	if (_isOpen == NO)
	{
		_isOpen = YES;
	
		NSOpenPanel* panel = [[[NSOpenPanel alloc] init] autorelease];
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
		
		IMBOpenPanelCompletionHandler completionBlock = [inCompletionBlock copy];

		[panel beginWithCompletionHandler:^(NSInteger button)
		{
			if (button == NSFileHandlingPanelOKButton)
			{
				NSURL* url = [panel URL];
				
//				NSString* path = [url path];
//				NSInteger mode = [[NSFileManager defaultManager] imb_modeForPath:path];
//				BOOL accessible = [[NSFileManager defaultManager] imb_isPath:path accessible:kIMBAccessRead|kIMBAccessWrite];
//				NSLog(@"%s path=%@ mode=%x accessible=%d",__FUNCTION__,path,(int)mode,(int)accessible);
				
				completionBlock(url);
			}
			else
			{
				completionBlock(nil);
			}
			
			[completionBlock release];
			_isOpen = NO;
		}];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Show an NSOpenPanel and let the user select a folder. This punches a hole into the sandbox. Then create a
// bookmark for this folder and send it to as many XPC services as possible, thus transferring the access rights
// to the XPC service processes. The XPC service processes are then responsible for persisting these access rights...

- (void) grantAccessRightsForNode:(IMBNode*)inNode completionHandler:(void(^)(void))inCompletionHandler
{
	void(^completionHandler)(void) = [inCompletionHandler copy];
	__block NSInteger completionCount = 0;
	
	IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:inNode.mediaType];
	NSArray* nodes = [libraryController topLevelNodesWithoutAccessRights];
	NSArray* urls = [libraryController urlsForNodes:nodes];
	NSURL* proposedURL = [[IMBAccessRightsController sharedAccessRightsController] commonAncestorForURLs:urls];
		
	[self _showForSuggestedURL:proposedURL completionHandler:^(NSURL* inGrantedURL)
	{
		if (inGrantedURL)
		{
			NSData* bookmark = [[IMBAccessRightsController sharedAccessRightsController] bookmarkForURL:inGrantedURL];
			
			for (IMBNode* node in nodes)
			{
				node.badgeTypeNormal = kIMBBadgeTypeLoading;
				IMBParserMessenger* messenger = node.parserMessenger;
				SBPerformSelectorAsync(messenger.connection,messenger,@selector(addAccessRightsBookmark:error:),bookmark,
			
					^(NSURL* inReceivedURL,NSError* inError)
					{
						if (inError == nil)
						{
							[libraryController reloadNodeTree:node];
							
							completionCount++;
							
							if (completionCount == nodes.count)
							{
								completionHandler();
								[completionHandler release];
							}
						}
					});
			}
		}
		else
		{
			[completionHandler release];
		}
	}];
}


// Convenience method with emtpy completion handler...

- (void) grantAccessRightsForNode:(IMBNode*)inNode
{
	[self grantAccessRightsForNode:inNode completionHandler:^{}];
}


//----------------------------------------------------------------------------------------------------------------------


@end

