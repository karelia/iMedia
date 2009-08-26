/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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


#pragma mark HEADERS

#import "IMBPanelController.h"
#import "IMBParserController.h"
#import "IMBLibraryController.h"
#import "IMBNodeViewController.h"
#import "IMBImageViewController.h"
#import "IMBAudioViewController.h"
#import "IMBMovieViewController.h"
#import "IMBConfig.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBALS

static IMBPanelController* sSharedPanelController = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBPanelController

@synthesize delegate = _delegate;
@synthesize mediaTypes = _mediaTypes;
@synthesize viewControllers = _viewControllers;



//----------------------------------------------------------------------------------------------------------------------


+ (IMBPanelController*) sharedPanelController
{
	if (sSharedPanelController == nil)
	{
		sSharedPanelController = [self sharedPanelControllerWithDelegate:nil mediaTypes:[NSArray arrayWithObjects:
			kIMBMediaTypeImage,
			kIMBMediaTypeAudio,
			kIMBMediaTypeMovie,
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
	}

	return sSharedPanelController;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super initWithWindowNibName:@"IMBPanel"])
	{
		self.viewControllers = [NSMutableArray array];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_mediaTypes);
	IMBRelease(_viewControllers);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) showWindow:(id)inSender
{
	[self.window makeKeyAndOrderFront:nil];
}


- (IBAction) hideWindow:(id)inSender
{
	[self.window orderOut:nil];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) windowDidLoad
{
	[ibTabView setDelegate:self];
	[ibToolbar setSizeMode:NSToolbarSizeModeSmall];
	
	// Load the parsers...
	
	IMBParserController* parserController = [IMBParserController sharedParserController];
	[parserController setDelegate:self.delegate];
	[parserController loadParsers];

	for (NSString* mediaType in self.mediaTypes)
	{
		// Load the library for each media type...
		
		IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:mediaType];
		[libraryController setDelegate:self];
		[libraryController reload];

		// Load the views for each media type...
		
		IMBNodeViewController* nodeViewController = [IMBNodeViewController viewControllerForLibraryController:libraryController];
		[self.viewControllers addObject:nodeViewController];
		NSView* nodeView = [nodeViewController view];
		NSView* containerView = [nodeViewController objectContainerView];
		IMBObjectViewController* objectViewController = nil;
		NSView* objectView = nil;
		
		if ([mediaType isEqualToString:kIMBMediaTypeImage])
		{
			objectViewController = [IMBImageViewController viewControllerForLibraryController:libraryController];
		}
		else if ([mediaType isEqualToString:kIMBMediaTypeAudio])
		{
			objectViewController = [IMBAudioViewController viewControllerForLibraryController:libraryController];
		}
		else if ([mediaType isEqualToString:kIMBMediaTypeMovie])
		{
			objectViewController = [IMBMovieViewController viewControllerForLibraryController:libraryController];
		}
		
		[self.viewControllers addObject:objectViewController];
		objectViewController.nodeViewController = nodeViewController;
		objectView = objectViewController.view;
		[objectView setFrame:[containerView bounds]];
		[containerView addSubview:objectView];

		// Create a tab for and toolbar item for each view...
		
		[nodeView setFrame:[ibTabView bounds]];
		
		NSTabViewItem* item = [[NSTabViewItem alloc] initWithIdentifier:mediaType];
		[item setLabel:mediaType];
		[item setView:nodeView];
		[ibTabView addTabViewItem:item];
		[item release];
		
		[ibToolbar setAllowsUserCustomization:NO];

	}
		
	// Restore window size...
	
	NSString* frame = [IMBConfig prefsValueForKey:@"windowFrame"];
	if (frame) [self.window setFrame:NSRectFromString(frame) display:YES animate:NO];
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
	NSToolbarItem* item = [[[NSToolbarItem alloc] initWithItemIdentifier:inIdentifier] autorelease];
	NSImage* icon = nil;
	
	for (IMBObjectViewController* controller in self.viewControllers)
	{
		if ([controller.mediaType isEqualToString:inIdentifier])
		{
			icon = [controller iconForMediaType];
			[icon setScalesWhenResized:YES];
			[icon setSize:NSMakeSize(32,32)];
		}
	}

	if (icon) [item setImage:icon];
	[item setLabel:inIdentifier];
	
	[item setAction:@selector(selectTabViewItemWithIdentifier:)];
	[item setTarget:self];
	
	return item;
}


- (IBAction) selectTabViewItemWithIdentifier:(id)inSender
{
	NSToolbarItem* item = (NSToolbarItem*)inSender;
	return [ibTabView selectTabViewItemWithIdentifier:item.itemIdentifier];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTabViewDelegate


- (BOOL) tabView:(NSTabView*)inTabView shouldSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{
	return YES;
}


- (void) tabView:(NSTabView*)inTabView willSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{

}


- (void) tabView:(NSTabView*)inTabView didSelectTabViewItem:(NSTabViewItem*)inTabViewItem
{

}


//----------------------------------------------------------------------------------------------------------------------


@end

