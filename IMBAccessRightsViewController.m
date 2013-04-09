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


// Author: Peter Baumgartner, Jörg Jacobsen


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
#import "IMBAlertPopover.h"
#import "NSImage+iMedia.h"
#import "NSURL+iMedia.h"
#import "NSString+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "NSObject+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark TYPES

typedef void (^IMBOpenPanelCompletionHandler)(NSURL* inURL);


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBAccessRightsViewController ()
@end


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
	[self imb_cancelAllCoalescedSelectors];
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark User Interface


- (void) _showForSuggestedURL:(NSURL*)inSuggestedURL name:(NSString*)inName completionHandler:(IMBOpenPanelCompletionHandler)inCompletionBlock;
{
	// Customize an NSOpenPanel so that it explains why the user needs to allow access...
	
	NSOpenPanel* panel = [NSOpenPanel openPanel];
	panel.canChooseDirectories = YES;
	panel.allowsMultipleSelection = NO;
	panel.canCreateDirectories = NO;

	panel.accessoryView = self.view;
	[panel setDirectoryURL:inSuggestedURL];

	NSString* title = NSLocalizedStringWithDefaultValue(
		@"IMBAccessRightsViewController.openPanel.title",
		nil,
		IMBBundle(),
		@"Allow Access to Media Files",
		@"NSOpenPanel title");
	
	if (inName)
	{
		title = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.openPanel.titleWithName",
			nil,
			IMBBundle(),
			@"Allow Access to %@",
			@"NSOpenPanel title");
			
		title = [NSString stringWithFormat:title,inName];
	}
	
	panel.title = title;

	panel.message = NSLocalizedStringWithDefaultValue(
		@"IMBAccessRightsViewController.openPanel.message",
		nil,
		IMBBundle(),
		@"Click the \"Allow\" button to grant access to your media files.",
		@"NSOpenPanel message");
				
	panel.prompt = NSLocalizedStringWithDefaultValue(
		@"IMBAccessRightsViewController.openPanel.prompt",
		nil,
		IMBBundle(),
		@"Allow",
		@"NSOpenPanel button");

	_warningTitle.stringValue = title;

	NSString* appName = [[NSProcessInfo processInfo] processName];
	
	NSString* format = NSLocalizedStringWithDefaultValue(
		@"IMBAccessRightsViewController.openPanel.description",
		nil,
		IMBBundle(),
		@"Due to system security features that protect your data from malicious attacks, %@ does not have the necessary rights to access your media files. To give %@ access to your media files click the \"Allow\" button.",
		@"NSOpenPanel description");

	_warningMessage.stringValue = [NSString stringWithFormat:format,appName,appName];
  
	// Run the NSOpenPanel. Please note the special saving and restoring of keyWindow. This is essential here, or
	// the Powerbox will become unresponsive the second time we try to call it. Then call the completion block...
	
	NSWindow* keyWindow = [NSApp keyWindow];
	
	NSInteger button = [panel runModal];

	if (button == NSFileHandlingPanelOKButton)
	{
		NSURL* url = [panel URL];
		inCompletionBlock(url);
	}
	else
	{
		inCompletionBlock(nil);
	}
	
	[keyWindow makeKeyWindow];
}


//----------------------------------------------------------------------------------------------------------------------
// Note that this is an empty operation if not sandboxed.

- (void) grantAccessRightsForObjectsOfNode:(IMBNode*)inNode
{
	if (SBIsSandboxed() && inNode.objects.count > 0 && inNode.badgeTypeNormal != kIMBBadgeTypeLoading)
	{
		IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:inNode.mediaType];

		// Get ancestor folder that encloses all objects for this node (usually the selected node)...
		
		NSMutableArray* urls = [NSMutableArray arrayWithCapacity:inNode.objects.count];
		
		for (IMBObject* object in inNode.objects)
		{
			if (object.accessibility == kIMBResourceNoPermission)
			{
				[urls addObject:object.location];
			}
		}
		
		NSURL* proposedURL = [IMBAccessRightsController commonAncestorForURLs:urls];
		
		// Show an NSOpenPanel to grant access to this folder...
		
		[self _showForSuggestedURL:proposedURL name:inNode.name completionHandler:^(NSURL* inGrantedURL)
		{
			if (inGrantedURL)
			{
				NSData* bookmark = [IMBAccessRightsController bookmarkForURL:inGrantedURL];
				
                inNode.badgeTypeNormal = kIMBBadgeTypeLoading;
                inNode.accessibility = kIMBResourceIsAccessible; // Temporarily, so that loading wheel shows again
				IMBParserMessenger* messenger = inNode.parserMessenger;
				SBPerformSelectorAsync(messenger.connection,messenger,@selector(addAccessRightsBookmark:error:),bookmark,
				
					^(NSURL* inReceivedURL,NSError* inError)
					{
						if (inError == nil)
						{
							[libraryController reloadNodeTree:inNode];
						}
					});
			}
		}];
	}
}


//----------------------------------------------------------------------------------------------------------------------
// Note that this is an empty operation (except for completion handler) if not sandboxed.
// In that case only completion handler will be called (synchronously)

+ (void) grantAccessRightsForFolder:(IMBParserMessenger*)inFolderParserMessenger completionHandler:(void(^)(void))inCompletionHandler
{
    if (SBIsSandboxed())
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
    } else {
        inCompletionHandler();
    }
}


//----------------------------------------------------------------------------------------------------------------------


+ (void) showMissingResourceAlertForNode:(IMBNode*)inNode view:(NSView*)inView relativeToRect:(NSRect)inRect
{
	NSString* name = inNode.name;
	NSString* volume = [inNode.libraryRootURL imb_externalVolumeName];
	BOOL mounted = [[NSFileManager defaultManager] imb_isVolumeMounted:volume];
	
	// For missing libraries alert the user that we cannot use this node...
	
	if (volume == nil || mounted)
	{
		NSString* title = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.missingLibraryTitle",
			nil,
			IMBBundle(),
			@"Library is Missing",
			@"Alert title");

		NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.missingLibraryMessage",
			nil,
			IMBBundle(),
			@"The %@ library cannot be used because it is missing. It may have been deleted, moved, or renamed.",
			@"Alert message");
			
		NSString* ok = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.missingLibraryButton",
			nil,
			IMBBundle(),
			@"   OK   ",
			@"Alert button");

		NSString* message = [NSString stringWithFormat:format,name];
		
		if (IMBRunningOnLionOrNewer() && inView.window != nil)
		{
			IMBAlertPopover* alert = [IMBAlertPopover warningPopoverWithHeader:title body:message footer:nil];
			alert.icon = [NSImage imb_imageNamed:@"IMBStopIcon.icns"];
			
			[alert addButtonWithTitle:ok block:^()
			{
				[alert close];
			}];
		
			[alert showRelativeToRect:inRect ofView:inView preferredEdge:NSMaxYEdge];
		}
		else
		{
			NSAlert* alert = [NSAlert
				alertWithMessageText:title
				defaultButton:ok
				alternateButton:nil
				otherButton:nil
				informativeTextWithFormat:@"%@",message];
				
			[alert runModal];
		}
	}
	
	// For libraries on an unmounted volume, ask the user to mount the volume and reload...
	
	else
	{
		NSString* title = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.offlineLibraryTitle",
			nil,
			IMBBundle(),
			@"Library is Offline",
			@"Alert title");

		NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.offlineLibraryMessage",
			nil,
			IMBBundle(),
			@"The %@ library cannot be used because it is located on a volume that is currently not mounted.\n\nMount the volume %@ and then click on the \"Reload\" button.",
			@"Alert message");
			
		NSString* ok = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.offlineLibraryButton",
			nil,
			IMBBundle(),
			@"Reload",
			@"Alert button");

//		NSString* cancel = NSLocalizedStringWithDefaultValue(
//			@"IMBAccessRightsViewController.cancel",
//			nil,
//			IMBBundle(),
//			@"Cancel",
//			@"Alert button");

		NSString* message = [NSString stringWithFormat:format,name,volume];
		
		if (IMBRunningOnLionOrNewer() && inView.window != nil)
		{
			IMBAlertPopover* alert = [IMBAlertPopover warningPopoverWithHeader:title body:message footer:nil];
			alert.icon = [NSImage imb_imageNamed:@"IMBStopIcon.icns"];
//+			alert.behavior = NSPopoverBehaviorApplicationDefined;
			
//			[alert addButtonWithTitle:cancel block:^()
//			{
//				[alert close];
//			}];

			[alert addButtonWithTitle:ok block:^()
			{
				[[IMBLibraryController sharedLibraryControllerWithMediaType:inNode.mediaType] reload];
				[alert close];
			}];
		
			[alert showRelativeToRect:inRect ofView:inView preferredEdge:NSMaxYEdge];
		}
		else
		{
			NSAlert* alert = [NSAlert
				alertWithMessageText:title
				defaultButton:ok
				alternateButton:nil
				otherButton:nil
				informativeTextWithFormat:@"%@",message];
				
			NSInteger button = [alert runModal];
			
			if (button == NSOKButton)
			{
				[[IMBLibraryController sharedLibraryControllerWithMediaType:inNode.mediaType] reload];
			}
		}
	}
	
}


//----------------------------------------------------------------------------------------------------------------------


+ (void) showMissingResourceAlertForObject:(IMBObject*)inObject view:(NSView*)inView relativeToRect:(NSRect)inRect
{
	NSString* name = inObject.name;
	NSString* volume = [inObject.location imb_externalVolumeName];
	BOOL mounted = [[NSFileManager defaultManager] imb_isVolumeMounted:volume];
	
	// For missing objects alert the user that we cannot use this object...
	
	if (volume == nil || mounted)
	{
		NSString* title = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.missingObjectTitle",
			nil,
			IMBBundle(),
			@"Media File is Missing",
			@"Alert title");

		NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.missingObjectMessage",
			nil,
			IMBBundle(),
			@"The file %@ cannot be used because it is missing. It may have been deleted, moved, or renamed.",
			@"Alert message");
			
		NSString* ok = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.missingObjectButton",
			nil,
			IMBBundle(),
			@"   OK   ",
			@"Alert button");

		NSString* message = [NSString stringWithFormat:format,name];
		
		if (IMBRunningOnLionOrNewer() && inView.window != nil)
		{
			IMBAlertPopover* alert = [IMBAlertPopover warningPopoverWithHeader:title body:message footer:nil];
			alert.icon = [NSImage imb_imageNamed:@"IMBStopIcon.icns"];
		
			[alert addButtonWithTitle:ok block:^()
			{
				[alert close];
			}];
		
			[alert showRelativeToRect:inRect ofView:inView preferredEdge:NSMaxYEdge];
		}
		else
		{
			NSAlert* alert = [NSAlert
				alertWithMessageText:title
				defaultButton:ok
				alternateButton:nil
				otherButton:nil
				informativeTextWithFormat:@"%@",message];
				
			[alert runModal];
		}
	}

	// For objects on an unmounted volume, ask the user to mount the volume and reload...
	
	else
	{
		NSString* title = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.IMBAccessRightsViewController.offlineObjectTitle",
			nil,
			IMBBundle(),
			@"Media File is Offline",
			@"Alert title");

		NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.offlineObjectMessage",
			nil,
			IMBBundle(),
			@"The file \"%@\" cannot be used because it is located on a volume that is currently not mounted.\n\nMount the volume %@ and then click on the \"Reload\" button.",
			@"Alert message");
			
		NSString* ok = NSLocalizedStringWithDefaultValue(
			@"IMBAccessRightsViewController.offlineObjectButton",
			nil,
			IMBBundle(),
			@"Reload",
			@"Alert button");

//		NSString* cancel = NSLocalizedStringWithDefaultValue(
//			@"IMBAccessRightsViewController.cancel",
//			nil,
//			IMBBundle(),
//			@"Cancel",
//			@"Alert button");

		NSString* message = [NSString stringWithFormat:format,name,volume];
		
		if (IMBRunningOnLionOrNewer() && inView.window != nil)
		{
			IMBAlertPopover* alert = [IMBAlertPopover warningPopoverWithHeader:title body:message footer:nil];
			alert.icon = [NSImage imb_imageNamed:@"IMBStopIcon.icns"];
//			alert.behavior = NSPopoverBehaviorApplicationDefined;
		
//			[alert addButtonWithTitle:cancel block:^()
//			{
//				[alert close];
//			}];

			[alert addButtonWithTitle:ok block:^()
			{
				[[IMBLibraryController sharedLibraryControllerWithMediaType:inObject.mediaType] reload];
				[alert close];
			}];
		
			[alert showRelativeToRect:inRect ofView:inView preferredEdge:NSMaxYEdge];
		}
		else
		{
			NSAlert* alert = [NSAlert
				alertWithMessageText:title
				defaultButton:ok
				alternateButton:nil
				otherButton:nil
				informativeTextWithFormat:@"%@",message];
				
			NSInteger button = [alert runModal];
			
			if (button == NSOKButton)
			{
				[[IMBLibraryController sharedLibraryControllerWithMediaType:inObject.mediaType] reload];
			}
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark IMBAccessRequester Protocol

// Show an NSOpenPanel and let the user select a folder. This punches a hole into the sandbox. Then create a
// bookmark for this folder and send it to as many XPC services as possible, thus transferring the access rights
// to the XPC service processes. The XPC service processes are then responsible for persisting these access rights...
// Note that this is an empty operation if not sandboxed.

- (void) requestAccessToNode:(IMBNode *)inNode completion:(IMBRequestAccessCompletionHandler)inCompletion
{
    if (SBIsSandboxed())
    {
        // Calculate the best possible folder to select...
        
        IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:inNode.mediaType];
        NSArray* nodes = [libraryController topLevelNodesWithoutAccessRights];
        IMBNode* node = nodes.count==1 ? [nodes objectAtIndex:0] : nil;
        NSArray* urls = [libraryController libraryRootURLsForNodes:nodes];
        NSURL* proposedURL = [IMBAccessRightsController commonAncestorForURLs:urls];
        
        // Show an NSOpenPanel with this folder...
        
        [self _showForSuggestedURL:proposedURL name:node.name completionHandler:^(NSURL* inGrantedURL)
         {
             if (inGrantedURL)
             {
                 // Create bookmark...
                 
                 NSData* bookmark = [IMBAccessRightsController bookmarkForURL:inGrantedURL];
                 
                 // Send it to XPC services of all nodes that do not have access rights (thus blessing the XPC services)...
                 
                 NSArray* mediaTypes = [IMBLibraryController knownMediaTypes];
                 NSString* path = [inGrantedURL path];
                 
                 for (NSString* mediaType in mediaTypes)
                 {
                     IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:mediaType];
                     NSArray* nodes = [libraryController topLevelNodesWithoutAccessRights];
                     
                     for (IMBNode* node in nodes)
                     {
                         if ([node.libraryRootURL.path hasPathPrefix:path])
                         {
                             node.badgeTypeNormal = kIMBBadgeTypeLoading;
                             node.accessibility = kIMBResourceIsAccessible; // Temporarily, so that loading wheel shows again
                             
                             IMBParserMessenger* messenger = node.parserMessenger;
                             SBPerformSelectorAsync(messenger.connection,messenger,@selector(addAccessRightsBookmark:error:),bookmark,
                                                    
                                                    ^(NSURL* inReceivedURL,NSError* inError)
                                                    {
                                                        inCompletion(inError == nil, YES);
                                                    });
                         }
                     }
                 }
                 
                 // Also send it to the FSEvents service, so that it can do its job...
                 
                 [[IMBFileSystemObserver sharedObserver] addAccessRights:bookmark];
             }
         }];
    }
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Helpers



//----------------------------------------------------------------------------------------------------------------------


@end

