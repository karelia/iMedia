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
#import "IMBParserMessenger.h"
#import "NSFileManager+iMedia.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBConfig.h"
#import "SBUtilities.h"
#import "IMBFileSystemObserver.h"


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
	return @"IMBAccessRightsViewController";
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
	
		NSOpenPanel* panel = [NSOpenPanel openPanel];
		panel.canChooseDirectories = YES;
		panel.allowsMultipleSelection = NO;
		panel.canCreateDirectories = NO;
		
		panel.accessoryView = self.view;
		[panel setDirectoryURL:inSuggestedURL];

		panel.title = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.openPanel.title",
			nil,
			IMBBundle(),
			@"Confirm Access to Media Files",
			@"NSOpenPanel title");

		panel.message = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.openPanel.message",
			nil,
			IMBBundle(),
			@"Click the \"Confirm\" button to grant access to your media files.",
			@"NSOpenPanel message");
					
		panel.prompt = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.openPanel.prompt",
			nil,
			IMBBundle(),
			@"Confirm",
			@"NSOpenPanel button");

		_warningTitle.stringValue = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.openPanel.title",
			nil,
			IMBBundle(),
			@"Confirm Access to Media Files",
			@"NSOpenPanel title");

        NSString* appName = [[NSProcessInfo processInfo] processName];
        
        NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.openPanel.description",
			nil,
			IMBBundle(),
			@"Due to new system security features that protect your data from malicious attacks, %@ does not have the necessary rights to access your media files. To give %@ access to your media files click the \"Confirm\" button.\n\nIf your media files are scattered across your hard disk, you may want to navigate up and select the whole hard disk, before clicking the \"Confirm\" button.",
			@"NSOpenPanel description");

        _warningMessage.stringValue = [NSString stringWithFormat:format,appName,appName];
        
		IMBOpenPanelCompletionHandler completionBlock = [inCompletionBlock copy];

		// We really wanted to use [panel runModal] here, because working modally (i.e. blocking everything until
		// the panel is dismissed) would be the right thing here. However, runModal has a serious bug in sandboxed
		// apps. It simply stops working the second time you show an NSOpenPanel. It freezes, until you send the app
		// the the background and bring it to the front again.
		
		// For this reason we had to use the modern completion block based API - which has the drawback that it
		// doesn't work modally. To guard against having two NSOpenPanels showing at the same time, we introduced
		// the stupid _isOpen flag...
		
		[panel beginWithCompletionHandler:^(NSInteger button)
		{
			if (button == NSFileHandlingPanelOKButton)
			{
				NSURL* url = [panel URL];
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
	
	// Calculate the best possible folder to select...
	
	IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:inNode.mediaType];
	NSArray* nodes = [libraryController topLevelNodesWithoutAccessRights];
	NSArray* urls = [libraryController libraryRootURLsForNodes:nodes];
	NSURL* proposedURL = [IMBAccessRightsController commonAncestorForURLs:urls];
	
	// Show an NSOpenPanel with this folder...
	
	[self _showForSuggestedURL:proposedURL completionHandler:^(NSURL* inGrantedURL)
	{
		if (inGrantedURL)
		{
			// Create bookmark...
			
			NSData* bookmark = [IMBAccessRightsController bookmarkForURL:inGrantedURL];
			
			// Send it to XPC services of all nodes that do not have access rights (thus blessing the XPC services)...
			
			for (IMBNode* node in nodes)
			{
				node.badgeTypeNormal = kIMBBadgeTypeLoading;
				node.isAccessible = YES; // Temporarily set to yes so that loading wheel shows again
				
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
			
			// Also send it to the FSEvents service, so that it can do its job...
			
			[[IMBFileSystemObserver sharedObserver] addAccessRights:bookmark];
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


- (void) grantAccessRightsForObjectsOfNode:(IMBNode*)inNode completionHandler:(void(^)(void))inCompletionHandler
{
	if (inNode.objects.count > 0)
	{
		IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:inNode.mediaType];
		void(^completionHandler)(void) = [inCompletionHandler copy];

		// Get ancestor folder that encloses all objects for this node (usually the selected node)...
		
		NSMutableArray* urls = [NSMutableArray arrayWithCapacity:inNode.objects.count];
		
		for (IMBObject* object in inNode.objects)
		{
			if (!object.isAccessible)
			{
				[urls addObject:object.location];
			}
		}
		
		NSURL* proposedURL = [IMBAccessRightsController commonAncestorForURLs:urls];
		
		// Show an NSOpenPanel to grant access to this folder...
		
		[self _showForSuggestedURL:proposedURL completionHandler:^(NSURL* inGrantedURL)
		{
			if (inGrantedURL)
			{
				NSData* bookmark = [IMBAccessRightsController bookmarkForURL:inGrantedURL];
				
				IMBParserMessenger* messenger = inNode.parserMessenger;
				SBPerformSelectorAsync(messenger.connection,messenger,@selector(addAccessRightsBookmark:error:),bookmark,
				
					^(NSURL* inReceivedURL,NSError* inError)
					{
						if (inError == nil)
						{
							[libraryController reloadNodeTree:inNode];
							completionHandler();
							[completionHandler release];
						}
					});
			}
			else
			{
				[completionHandler release];
			}
		}];
	}
}


- (void) grantAccessRightsForObjectsOfNode:(IMBNode*)inNode
{
	[self grantAccessRightsForObjectsOfNode:inNode completionHandler:^{}];
}


//----------------------------------------------------------------------------------------------------------------------


+ (void) grantAccessRightsForFolder:(IMBParserMessenger*)inFolderParserMessenger completionHandler:(void(^)(void))inCompletionHandler
{
    IMBParserMessenger* messenger = inFolderParserMessenger;
    void(^completionHandler)(void) = [inCompletionHandler copy];
    
    // Create bookmark...
    
    NSURL* url = messenger.mediaSource;
    NSData* bookmark = [IMBAccessRightsController bookmarkForURL:url];
    
    // Send it to the XPC service, so it has access to the folder...
    
    SBPerformSelectorAsync(messenger.connection,messenger,@selector(addAccessRightsBookmark:error:),bookmark,

        ^(NSURL* inReceivedURL,NSError* inError)
        {
            NSLog(@"%s  url=%@  error=%@",__FUNCTION__,inReceivedURL,inError);
            completionHandler();
            [completionHandler release];
        });

    // Also send it to the FSEvents service, so that it can do its job...
    
    [[IMBFileSystemObserver sharedObserver] addAccessRights:bookmark];
}


//----------------------------------------------------------------------------------------------------------------------


@end

