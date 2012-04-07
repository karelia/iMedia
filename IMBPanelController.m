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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBPanelController.h"
#import "IMBParserController.h"
#import "IMBLibraryController.h"
#import "IMBNodeViewController.h"
#import "IMBObjectViewController.h"
#import "IMBHoverButton.h"
#import "NSWindow_Flipr.h"
#import "IMBConfig.h"
#import "IMBCommon.h"
#import "IMBQLPreviewPanel.h"
#import "NSWorkspace+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

NSString* kIMBImageBrowserShowTitlesNotification = @"IMBImageBrowserShowTitlesNotification";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static IMBPanelController* sSharedPanelController = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// This is a private class in the user interface of IMBPanelController. Used in the xib file...

@interface IMBBackgroundImageView : NSImageView

@end


@implementation IMBBackgroundImageView

- (BOOL) isOpaque
{
	return YES;
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBPanelController ()
@property (retain) NSString* oldMediaType;
- (void) setupInfoWindow;
- (IBAction) flipBackToMainWindow:(id)inSender;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBPanelController

@synthesize delegate = _delegate;
@synthesize mediaTypes = _mediaTypes;
@synthesize nodeViewControllers = _nodeViewControllers;
@synthesize loadedLibraries = _loadedLibraries;
@synthesize oldMediaType = _oldMediaType;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Instantiation


// Convenience method for loading/initializing the shared panel controller with default media types and no delegate

+ (IMBPanelController*) sharedPanelController
{
	if (sSharedPanelController == nil)
	{
		sSharedPanelController = [self sharedPanelControllerWithDelegate:nil mediaTypes:[NSArray arrayWithObjects:
			kIMBMediaTypeImage,
			kIMBMediaTypeAudio,
			kIMBMediaTypeMovie,
			kIMBMediaTypeLink,
			nil]];
	}
	
	return sSharedPanelController;
}


+ (IMBPanelController*) sharedPanelControllerWithDelegate:(id)inDelegate mediaTypes:(NSArray*)inMediaTypes
{
	if (sSharedPanelController == nil)
	{
		sSharedPanelController = [[IMBPanelController alloc] init];
		sSharedPanelController.delegate = inDelegate;
		sSharedPanelController.mediaTypes = inMediaTypes;
		
		[sSharedPanelController loadControllers];
	}

	return sSharedPanelController;
}


+ (BOOL) isSharedPanelControllerLoaded;
{
    return sSharedPanelController != nil;
}


+ (void) cleanupSharedPanelController
{
	[sSharedPanelController saveStateToPreferences];
//	[sSharedPanelController.window close];
	IMBRelease(sSharedPanelController);
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (id) init
{
	if (self = [super initWithWindowNibName:@"IMBPanel"])
	{
		self.nodeViewControllers = [NSMutableDictionary dictionary];
		self.loadedLibraries = [NSMutableDictionary dictionary];
		
		[[NSNotificationCenter defaultCenter] 
			addObserver:self 
			selector:@selector(applicationWillTerminate:) 
			name:NSApplicationWillTerminateNotification 
			object:nil];
	}
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	IMBRelease(_mediaTypes);
	IMBRelease(_nodeViewControllers);
	IMBRelease(_loadedLibraries);
	IMBRelease(_oldMediaType);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

- (void) loadControllers
{
	IMBLibraryController* libraryController = nil;
	IMBNodeViewController* nodeViewController = nil;
	IMBObjectViewController* objectViewController = nil;
	
	// Load the parsers...
	
	IMBParserController* parserController = [IMBParserController sharedParserController];
	[parserController setDelegate:self.delegate];
	[parserController loadParserMessengers];
	
	for (NSString* mediaType in self.mediaTypes)
	{
		// Load the library for each media type...
		
		libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:mediaType];
		[libraryController setDelegate:self.delegate];

		// Create the top-level view controller (IMBNodeViewController) with attached standard
		// object view (IMBObjectViewController) for each media type...
	
		nodeViewController = [IMBNodeViewController viewControllerForLibraryController:libraryController];
		objectViewController = [IMBObjectViewController viewControllerForLibraryController:libraryController];
		nodeViewController.standardObjectViewController = objectViewController;
		[self.nodeViewControllers setObject:nodeViewController forKey:mediaType];
	}
}


// Retrieve the correct controller...

- (IMBNodeViewController*) nodeViewControllerForMediaType:(NSString*)inMediaType
{
	return [self.nodeViewControllers objectForKey:inMediaType];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) windowDidLoad
{
	// Make sure that add tabs to the window doesn't trigger premature library loading. We want to do this lazily...
	
	_isLoadingWindow = YES;
	
    // There's generally no need for the media browser to be key window...
	
    [(NSPanel*)self.window setBecomesKeyOnlyIfNeeded:YES];
    
	[ibTabView setDelegate:self];
	[ibToolbar setAllowsUserCustomization:NO];
	
	[self setupInfoWindow];
	
	[ibGridPrompt setStringValue:NSLocalizedStringWithDefaultValue(
		@"IMB.option.gridPrompt",
		nil,
		IMBBundle(),
		@"Photo Grids:",
		@"back of window")];
		
	[ibToolbarPrompt setStringValue:NSLocalizedStringWithDefaultValue(
		@"IMB.option.toolbar", 
		nil,
		IMBBundle(),
		@"Toolbar:", 
		@"back of window")];
		
	[ibShowTitles setTitle:NSLocalizedStringWithDefaultValue(
		@"IMB.option.showTitles", 
		nil,
		IMBBundle(),
		@"Show Titles", 
		@"back of window checkbox")];
		
	[ibSmallSize setTitle:NSLocalizedStringWithDefaultValue(
		@"IMB.option.smallSize", 
		nil,
		IMBBundle(),
		@"Small size", 
		@"back of window checkbox")];
	
	[[ibToolbarPopup itemAtIndex:0] setTitle:NSLocalizedStringWithDefaultValue(
		@"IMB.option.toolbarSize.iconAndText", 
		nil,
		IMBBundle(),
		@"Icon & Text", 
		@"back of window toolbar popup menu item")];
		
	[[ibToolbarPopup itemAtIndex:1] setTitle:NSLocalizedStringWithDefaultValue(
		@"IMB.option.toolbarSize.iconOnly", 
		nil,
		IMBBundle(),
		@"Icon Only", 
		@"back of window toolbar popup menu item")];
		
	[[ibToolbarPopup itemAtIndex:2] setTitle:NSLocalizedStringWithDefaultValue(
		@"IMB.option.toolbarSize.textOnly", 
		nil,
		IMBBundle(),
		@"Text Only", 
		@"back of window toolbar popup menu item")];

	// Create a tab for each controller and install the subviews in it. We query each node controller for its 
	// minimum size so we can be sure to constrain our panel's minimum to suit the most restrictive controller...
	
	NSSize largestMinimumSize = NSMakeSize(0,0);
	
	for (NSString* mediaType in self.nodeViewControllers)
	{
		IMBNodeViewController* nodeViewController = [_nodeViewControllers objectForKey:mediaType];
		NSView* nodeView = [nodeViewController view];
		[nodeView setFrame:[ibTabView bounds]];
		
		// Query each node controller for its minimum size so we can be sure to constrain our panel's minimum to 
		// suit the most restrictive controller...

		NSSize thisNodeViewMinimumSize = [nodeViewController minimumViewSize];
		
		if (thisNodeViewMinimumSize.height > largestMinimumSize.height)
		{
			largestMinimumSize.height = thisNodeViewMinimumSize.height;
		}
		
		if (thisNodeViewMinimumSize.width > largestMinimumSize.width)
		{
			largestMinimumSize.width = thisNodeViewMinimumSize.width;
		}
		
		// Install the views in the window hierarchy...
		
		[nodeViewController installObjectViewForNode:nil];

		NSTabViewItem* item = [[NSTabViewItem alloc] initWithIdentifier:mediaType];
		[item setLabel:mediaType];
		[item setView:nodeView];
		[ibTabView addTabViewItem:item];
		[item release];
		
		// Now that the view hierarchy is established, restore any previously known state...
		
		[nodeViewController restoreState];
//		[objectViewController restoreState];
	}
		
	// Restore window size and selected tab...
	
	_isLoadingWindow = NO;

	[self.window setContentMinSize:largestMinimumSize];
	[self restoreStateFromPreferences];
}


//----------------------------------------------------------------------------------------------------------------------


// We need to save preferences before tha app quits...
		
- (void) applicationWillTerminate:(NSNotification*)inNotification
{
	[self saveStateToPreferences];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) saveStateToPreferences
{
	NSString* frame = NSStringFromRect(self.window.frame);
	if (frame) [IMBConfig setPrefsValue:frame forKey:@"windowFrame"];
	
	int sizeMode = 	[ibToolbar sizeMode];
	BOOL isSmall = (sizeMode == NSToolbarSizeModeSmall);
	[IMBConfig setPrefsValue:[NSNumber numberWithBool:isSmall] forKey:@"toolbarIsSmall"];
	
	NSToolbarDisplayMode displayMode = [ibToolbar displayMode];
	[IMBConfig setPrefsValue:[NSNumber numberWithInt:displayMode] forKey:@"toolbarDisplayMode"];

	NSString* mediaType = ibTabView.selectedTabViewItem.identifier;
	if (mediaType) [IMBConfig setPrefsValue:mediaType forKey:@"selectedMediaType"];

}


- (void) restoreStateFromPreferences
{
	NSString* frame = [IMBConfig prefsValueForKey:@"windowFrame"];
	if (frame) [self.window setFrame:NSRectFromString(frame) display:YES animate:NO];

	NSString* toolbarDisplayMode = [IMBConfig prefsValueForKey:@"toolbarDisplayMode"];
	if (toolbarDisplayMode) [ibToolbar setDisplayMode:[toolbarDisplayMode intValue]];

	NSString* toolbarIsSmall = [IMBConfig prefsValueForKey:@"toolbarIsSmall"];
	BOOL small = (nil == toolbarIsSmall) ? NO : [toolbarIsSmall boolValue];
	int sizeMode = (small ? NSToolbarSizeModeSmall : NSToolbarSizeModeRegular);
	[ibToolbar setSizeMode:sizeMode];

	NSString* mediaType = [IMBConfig prefsValueForKey:@"selectedMediaType"];
	NSTabViewItem* tabViewItem = [ibTabView selectedTabViewItem];

	if (mediaType)
	{
		if ([tabViewItem.identifier isEqualToString:mediaType])
		{
			[self tabView:ibTabView willSelectTabViewItem:tabViewItem];
			[self tabView:ibTabView didSelectTabViewItem:tabViewItem];
		}
		else
		{
			[ibTabView selectTabViewItemWithIdentifier:mediaType];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Show/Hide

// If we are actually showing the back of the window, flip to the front...

- (IBAction) showWindow:(id)inSender
{
	if (self.isInfoWindowVisible)
	{
		[self flipBackToMainWindow:inSender];
	}
	else
	{
		[super showWindow:inSender];
	}
}


// Provide a "symmetric" name to -showWindow...

- (IBAction) hideWindow:(id)inSender
{
	[self.window orderOut:nil];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (void) setupInfoWindow
{
	// set up special button
	NSButton *but = [[self window] standardWindowButton:NSWindowCloseButton];
	NSView *container = [but superview];
	float containerWidth = [container frame].size.width;
	NSRect frame = [but frame];
	NSButton *iButton = [[[IMBHoverButton alloc] initWithFrame:NSMakeRect(frame.origin.x + containerWidth - 11 - 11,frame.origin.y+2,11,11)] autorelease];
	[iButton setAutoresizingMask:NSViewMinYMargin|NSViewMinXMargin];
	
	[iButton setAction:@selector(showInfoWindow:)];
	[iButton setTarget:self];
	[container addSubview:iButton];
	
	// Now do another button on the flip-side
	but = [ibInfoWindow standardWindowButton:NSWindowCloseButton];
	container = [but superview];
	containerWidth = [container frame].size.width;
	frame = [but frame];
	iButton = [[[IMBHoverButton alloc] initWithFrame:NSMakeRect(frame.origin.x + containerWidth - 11 - 11,frame.origin.y+2,11,11)] autorelease];
	[iButton setAutoresizingMask:NSViewMinYMargin|NSViewMinXMargin];
	
	[iButton setAction:@selector(flipBack:)];
	[iButton setTarget:self];
	[container addSubview:iButton];
	
	// get flipping window ready
	[NSWindow flippingWindow];
	[ibInfoTextView setDrawsBackground:NO];
	//[ibInfoTextView setTextContainerInset:NSMakeSize(2,2)];
	NSScrollView *scrollView = [ibInfoTextView enclosingScrollView];
	[scrollView setDrawsBackground:NO];
	[[scrollView contentView] setCopiesOnScroll:NO];
	
	NSAttributedString *attr = nil;
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Credits" ofType:@"html"];
	
	NSData *htmlContents = [NSData dataWithContentsOfFile:path];
	if (htmlContents)
	{
		NSMutableString *htmlString = [[[NSMutableString alloc] initWithData:htmlContents encoding:NSUTF8StringEncoding] autorelease];
		
		NSString* imediaDescription = NSLocalizedStringWithDefaultValue(
			@"IMB.introduction",
			nil,IMBBundle(),
			@"An extensible component to allow browsing of multiple media types.",
			@"HTML style text shown on credits for iMedia");
		
		NSString* availableLink = NSLocalizedStringWithDefaultValue(
			@"IMB.availableLink",
			nil,IMBBundle(),
			@"Available at <a href='http://karelia.com/imedia/'>karelia.com/imedia</a>",
			@"HTML markup to show link to iMedia home page");
	
		NSString* credits = NSLocalizedStringWithDefaultValue(
			@"IMB.credits",
			nil,IMBBundle(),
			@"Credits:",
			@"HTML style text shown on credits for iMedia, introducting who wrote the software");
	
		NSString* localization = NSLocalizedStringWithDefaultValue(
			@"IMB.localization",
			nil,IMBBundle(),
			@"Localization:",
			@"HTML style text shown on credits for iMedia, to introduct who did localization");
	
		NSString* licenseIntro = NSLocalizedStringWithDefaultValue(
			@"IMB.licenseIntro",
			nil,IMBBundle(),
			@"The iMedia Browser Framework is licensed under the following terms:",
			@"HTML style text shown on credits for iMedia");
		
		// Localize some stuff.  Note that we're working in HTML here so watch for & < >
		
		[htmlString replaceOccurrencesOfString:@"{IMB.introduction}"
									withString:imediaDescription
									   options:0
										 range:NSMakeRange(0,[htmlString length])];
		[htmlString replaceOccurrencesOfString:@"{IMB.availableLink}"
									withString:availableLink
									   options:0
										 range:NSMakeRange(0,[htmlString length])];
		[htmlString replaceOccurrencesOfString:@"{IMB.credits}"
									withString:credits
									   options:0
										 range:NSMakeRange(0,[htmlString length])];
		[htmlString replaceOccurrencesOfString:@"{IMB.localization}"
									withString:localization
									   options:0
										 range:NSMakeRange(0,[htmlString length])];
		[htmlString replaceOccurrencesOfString:@"{IMB.licenseIntro}"
									withString:licenseIntro
									   options:0
										 range:NSMakeRange(0,[htmlString length])];
		
		NSData *backToData = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
		attr = [[[NSAttributedString alloc] initWithHTML:backToData documentAttributes:nil] autorelease];
	}
	else
	{
		attr = [[[NSAttributedString alloc] initWithString:@"Unable to load Info"] autorelease];
	}

	[[ibInfoTextView textStorage] setAttributedString:attr];
	
	// set up cursors in text
	
	NSEnumerator* attrRuns = [[[ibInfoTextView textStorage] attributeRuns] objectEnumerator];
	NSTextStorage* run;
	while ((run = [attrRuns nextObject]))
	{
		if ([run attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL])
		{
			[run addAttribute:NSCursorAttributeName value:[NSCursor pointingHandCursor] range:NSMakeRange(0,[run length])];
		}
	};
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) showInfoWindow:(id)inSender
{
	[ibInfoWindow setFrame:[[self window] frame] display:NO];
	[[self window] flipToShowWindow:ibInfoWindow forward:YES reflectInto:ibBackgroundImageView];
}


- (IBAction) flipBackToMainWindow:(id)inSender
{
	[[self window] setFrame:[ibInfoWindow frame] display:NO];	// not really needed unless window is resized
	[ibInfoWindow flipToShowWindow:[self window] forward:NO reflectInto:nil];
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) isInfoWindowVisible
{
	return [ibInfoWindow isVisible];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTabViewDelegate


// Ask the delegate whether we are allowed to switch to another media type...

- (BOOL) tabView:(NSTabView*)inTabView shouldSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{
	NSString* mediaType = inTabViewItem.identifier;
	
	if (_delegate!=nil && [_delegate respondsToSelector:@selector(panelController:shouldShowPanelForMediaType:)])
	{
		return [_delegate panelController:self shouldShowPanelForMediaType:mediaType];
	}
	
	return YES;
}


//----------------------------------------------------------------------------------------------------------------------


// We are about to switch tabs...

- (void) tabView:(NSTabView*)inTabView willSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{
	if (!_isLoadingWindow)
	{
		self.oldMediaType = inTabView.selectedTabViewItem.identifier;
		NSString* newMediaType = inTabViewItem.identifier;

		// If the library for the new tab has been loaded yet then do it now...
		
		if ([_loadedLibraries objectForKey:newMediaType] == nil)
		{
			IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:newMediaType];
			[libraryController reload];
			[_loadedLibraries setObject:newMediaType forKey:newMediaType];
		}
		
		// Notify the controllers...

		IMBNodeViewController* oldNodeViewController = [self nodeViewControllerForMediaType:_oldMediaType];
		IMBObjectViewController* oldObjectViewController = (IMBObjectViewController*)oldNodeViewController.objectViewController;
		[oldObjectViewController willHideView];
		
		IMBNodeViewController* newNodeViewController = [self nodeViewControllerForMediaType:newMediaType];
		IMBObjectViewController* newObjectViewController = (IMBObjectViewController*)newNodeViewController.objectViewController;
		[newObjectViewController willShowView];
		
		// Notify the delegate...

		if (_delegate!=nil && [_delegate respondsToSelector:@selector(panelController:willHidePanelForMediaType:)])
		{
			[_delegate panelController:self willHidePanelForMediaType:_oldMediaType];
		}

		if (_delegate!=nil && [_delegate respondsToSelector:@selector(panelController:willShowPanelForMediaType:)])
		{
			[_delegate panelController:self willShowPanelForMediaType:newMediaType];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Notify the delegate that we did switch...

- (void) tabView:(NSTabView*)inTabView didSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{
	if (!_isLoadingWindow)
	{
		NSString* newMediaType = inTabViewItem.identifier;
		[ibToolbar setSelectedItemIdentifier:newMediaType];
		
		// Notify the controllers...

		IMBNodeViewController* oldNodeViewController = [self nodeViewControllerForMediaType:_oldMediaType];
		IMBObjectViewController* oldObjectViewController = (IMBObjectViewController*)oldNodeViewController.objectViewController;
		[oldObjectViewController didHideView];

		IMBNodeViewController* newNodeViewController = [self nodeViewControllerForMediaType:newMediaType];
		IMBObjectViewController* newObjectViewController = (IMBObjectViewController*)newNodeViewController.objectViewController;
		[newObjectViewController didShowView];

		// Notify the delegate...

		if (_delegate!=nil && [_delegate respondsToSelector:@selector(panelController:didHidePanelForMediaType:)])
		{
			[_delegate panelController:self didHidePanelForMediaType:_oldMediaType];
		}

		if (_delegate!=nil && [_delegate respondsToSelector:@selector(panelController:didShowPanelForMediaType:)])
		{
			[_delegate panelController:self didShowPanelForMediaType:newMediaType];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSToolbarDelegate


- (NSArray*) toolbarAllowedItemIdentifiers:(NSToolbar*)inToolbar
{
	return self.mediaTypes;
}


- (NSArray*) toolbarDefaultItemIdentifiers:(NSToolbar*)inToolbar
{
	return self.mediaTypes;
}


- (NSArray*) toolbarSelectableItemIdentifiers:(NSToolbar*)inToolbar
{
	return self.mediaTypes;
}


- (NSToolbarItem*) toolbar:(NSToolbar*)inToolbar itemForItemIdentifier:(NSString*)inIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	IMBNodeViewController* nodeViewController = [self nodeViewControllerForMediaType:inIdentifier];

	NSString* name = [nodeViewController displayName];
	NSImage* icon = [nodeViewController icon];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(32,32)];

	NSToolbarItem* item = [[[NSToolbarItem alloc] initWithItemIdentifier:inIdentifier] autorelease];
	if (icon) [item setImage:icon];
	if (name) [item setLabel:name];
	[item setAction:@selector(selectTabViewItemWithIdentifier:)];
	[item setTarget:self];
	
	return item;
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) selectTabViewItemWithIdentifier:(id)inSender
{
	NSToolbarItem* item = (NSToolbarItem*)inSender;
	return [ibTabView selectTabViewItemWithIdentifier:item.itemIdentifier];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) setToolbarDisplayMode:(int)aMode
{
	[ibToolbar setDisplayMode:aMode];
}


- (int) toolbarDisplayMode
{
	int displayMode = [ibToolbar displayMode];
	if (0 == displayMode) displayMode = NSToolbarDisplayModeIconAndLabel;
	return displayMode;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) setToolbarIsSmall:(BOOL)aFlag
{
	int sizeMode = (aFlag ? NSToolbarSizeModeSmall : NSToolbarSizeModeRegular);
	[ibToolbar setSizeMode:sizeMode];
}


- (BOOL)toolbarIsSmall
{
	int sizeMode = 	[ibToolbar sizeMode];
	if (0 == sizeMode) sizeMode = NSToolbarSizeModeRegular;
	return (sizeMode == NSToolbarSizeModeSmall);
}


//----------------------------------------------------------------------------------------------------------------------


- (void) setPrefersFilenamesInPhotoBasedBrowsers:(BOOL)aFlag
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBImageBrowserShowTitlesNotification object:
	 [NSNumber numberWithBool:aFlag]];

	[IMBConfig setPrefsValue:[NSNumber numberWithBool:aFlag] forKey:@"prefersFilenamesInPhotoBasedBrowsers"];
}


- (BOOL)prefersFilenamesInPhotoBasedBrowsers
{
	NSString* filenames = [IMBConfig prefsValueForKey:@"prefersFilenamesInPhotoBasedBrowsers"];
	BOOL flag = (nil == filenames) ? YES : [filenames boolValue];
	return flag;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark QuickLook


- (void) keyDown:(NSEvent*)inEvent
{
    NSString* key = [inEvent charactersIgnoringModifiers];
	
    if([key isEqual:@" "])
	{
		NSString* mediaType = [[ibTabView selectedTabViewItem] identifier];
		IMBNodeViewController* nodeViewController = [self nodeViewControllerForMediaType:mediaType];
		IMBObjectViewController* objectViewController = (IMBObjectViewController*)nodeViewController.objectViewController;
		[objectViewController quicklook:self];
    } 
	else
	{
        [super keyDown:inEvent];
    }
}


- (BOOL) acceptsPreviewPanelControl:(QLPreviewPanel*)inPanel
{
	return YES;
}


- (void) beginPreviewPanelControl:(QLPreviewPanel*)inPanel
{
	NSString* mediaType = [[ibTabView selectedTabViewItem] identifier];
	IMBNodeViewController* nodeViewController = [self nodeViewControllerForMediaType:mediaType];
	IMBObjectViewController* objectViewController = (IMBObjectViewController*)nodeViewController.objectViewController;
	inPanel.delegate = objectViewController;
	inPanel.dataSource = objectViewController;
}


- (void) endPreviewPanelControl:(QLPreviewPanel*)inPanel
{
    inPanel.delegate = nil;
    inPanel.dataSource = nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end

