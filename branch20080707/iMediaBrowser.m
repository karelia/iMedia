/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2008 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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
	following copyright notice: Copyright (c) 2005-2008 by Karelia Software et al.
 
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


#import "iMediaBrowser.h"
#import "iMediaBrowserProtocol.h"
#import "iMediaConfiguration.h"
#import "iMBAbstractView.h"
#import "iMBHoverButton.h"
#import "NSWindow_Flipr.h"
#import "iMBBackgroundImageView.h"
#import "iMBLibraryNode.h"

NSString *iMediaBrowserSelectionDidChangeNotification = @"iMediaSelectionChanged";

static iMediaBrowser *_sharedMediaBrowser = nil;
static NSMutableArray *_browserClasses = nil;

@interface iMediaBrowser (PrivateAPI)
- (void)setupInfoWindow;
@end

@interface iMediaBrowser (Plugins)
+ (NSArray *)findBundlesWithExtension:(NSString *)ext inFolderName:(NSString *)folder;
@end

@implementation iMediaBrowser

+ (void)initialize	// preferred over +load in most cases
{
	if ( self == [iMediaBrowser class] ) 
	{
		// Only do some work when not called because one of our subclasses does not implement +initialize

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_browserClasses = [[NSMutableArray alloc] init];
	
	// Note: Originally I wanted a custom NSURLCache, but apparently there's only one way to do this,
	// and that is to create a new sharedURLCache used by your entire application.  I don't know how
	// to have just imedia's data cached in a particular, separate cache -- if I create a custom
	// NSURLCache and reference it instead of the shared URL cache, then the data don't get saved
	// to disk ever.  So unless Apple has a better way, we are stuck 
	// Create URL cache path, so all instances of iMedia Browser can share a cache
		
	//register the default set in order
	[self registerBrowser:NSClassFromString(@"iMBPhotosView")];
	[self registerBrowser:NSClassFromString(@"iMBMusicView")];
	[self registerBrowser:NSClassFromString(@"iMBMoviesView")];
	[self registerBrowser:NSClassFromString(@"iMBLinksView")];
	//[self registerBrowser:NSClassFromString(@"iMBContactsView")];
	
	//find and load all plugins
	NSArray *plugins = [iMediaBrowser findBundlesWithExtension:@"iMediaBrowser" inFolderName:@"iMediaBrowser"];
	NSEnumerator *e = [plugins objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject])
	{
		NSBundle *b = [NSBundle bundleWithPath:cur];
		Class mainClass = [b principalClass];
		if ([mainClass conformsToProtocol:@protocol(iMediaBrowser)] || [mainClass conformsToProtocol:@protocol(iMBParser)]) 
		{
			if (![b load])
			{
				NSLog(@"Failed to load iMediaBrowser plugin: %@", cur);
				continue;
			}
			else
			{
				// Register the parser/browser.  Note that the main class might be both!
				// (Alternatively -- have a wakeup method sent to the main class to let it do its
				// own registration, in case they are separate classes.)
				
//				if ([mainClass conformsToProtocol:@protocol(iMediaBrowser)])
//				{
//					[self registerBrowser:mainClass];
//				}
//				if ([mainClass conformsToProtocol:@protocol(iMBParser)])
//				{
//					[self registerParser:mainClass];
//				}
			}
		}
		else
		{
			NSLog(@"Plugin located at: %@ does not implement either of the required protocols", cur);
		}
	}
	[pool release];
}
}

+ (id)sharedBrowser
{
	if (!_sharedMediaBrowser)
		_sharedMediaBrowser = [[iMediaBrowser alloc] init];
	return _sharedMediaBrowser;
}

+ (id)sharedBrowserWithDelegate:(id)delegate
{
	iMediaBrowser *imb = [self sharedBrowser];
	[imb setDelegate:delegate];
	return imb;
}

+ (id)sharedBrowserWithDelegate:(id)delegate supportingBrowserTypes:(NSArray*)types;
{
	iMediaBrowser *imb = [self sharedBrowserWithDelegate:delegate];
    
    NSMutableArray *translatedTypes = [NSMutableArray arrayWithCapacity:[types count]];
    
    NSEnumerator *e = [types objectEnumerator];
	id cur;
	
    // this section is here for backwards compatibility.
	while (cur = [e nextObject]) 
	{
        if ([cur isEqualToString:@"iMBPhotosController"])
        {
            [translatedTypes addObject:@"iMBPhotosView"];
        }
        else if ([cur isEqualToString:@"iMBMoviesController"])
        {
            [translatedTypes addObject:@"iMBMoviesView"];
        }
        else if ([cur isEqualToString:@"iMBMusicController"])
        {
            [translatedTypes addObject:@"iMBMusicView"];
        } 
        else if ([cur isEqualToString:@"iMBContactsController"])
        {
            [translatedTypes addObject:@"iMBContactsView"];
        }
        else if ([cur isEqualToString:@"iMBLinksController"])
        {
            [translatedTypes addObject:@"iMBLinksView"];
        }
        else
        {
            [translatedTypes addObject:cur];
        }
	}

	[imb setPreferredBrowserTypes:translatedTypes];
	return imb;
}


+ (id)sharedBrowserWithoutLoading;
{
	return _sharedMediaBrowser;
}


+ (void)registerBrowser:(Class)aClass
{
	if (aClass != NULL)
	{
		[_browserClasses addObject:NSStringFromClass(aClass)];
	}
}

+ (void)unregisterBrowser:(Class)aClass
{
	if (aClass == NULL) return;
	NSEnumerator *e = [_browserClasses objectEnumerator];
	NSString *cur;
	while (cur = [e nextObject]) {
		Class bClass = NSClassFromString(cur);
		if (aClass == bClass) {
			[_browserClasses removeObject:cur];
			return;
		}
	}
}

+ (void)unregisterAllBrowsers
{
	[_browserClasses removeAllObjects];
}

+ (void)registerParser:(Class)aClass forMediaType:(NSString *)media
{
    // call method on shared iMediaConfiguration object
    [iMediaConfiguration registerParser:aClass forMediaType:media];
}    

+ (void)unregisterParserName:(NSString*)parserClassName forMediaType:(NSString *)media
{
    // call method on shared iMediaConfiguration object
    [iMediaConfiguration unregisterParserName:parserClassName forMediaType:media];
}

+ (void)unregisterParser:(Class)parserClass forMediaType:(NSString *)media
{
    // call method on shared iMediaConfiguration object
    [iMediaConfiguration unregisterParser:parserClass forMediaType:media];
}


#pragma mark -
#pragma mark Instance Methods

- (id)init
{
	if (self = [super initWithWindowNibName:@"MediaBrowser"]) {
		[self setIdentifier:@"Default"];
		myToolbar = [[NSToolbar alloc] initWithIdentifier:@"iMediaBrowserToolbar"];
	}
	return self;
}


- (id)initWithoutWindow 
{
	if (self = [super init]) {
        [self setIdentifier:@"Default"];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
	if (nil != mySelectedBrowser)
	{
		[mySelectedBrowser didDeactivate];
	}
    
	[myMediaBrowsers release];
	[myToolbar release];
	[myPreferredBrowserTypes release];

	[super dealloc];
}

- (void)setIdentifier:(NSString *)identifier
{
    // call method on shared iMediaConfiguration object
    [[iMediaConfiguration sharedConfiguration] setIdentifier:identifier];
}

- (NSString *)identifier
{
    // call method on shared iMediaConfiguration object
	return [[iMediaConfiguration sharedConfiguration] identifier];
}

- (id <iMediaBrowser>)selectedBrowser 
{
	return mySelectedBrowser;
}

- (void)setPreferredBrowserTypes:(NSArray*)types
{
	[myPreferredBrowserTypes autorelease];
	myPreferredBrowserTypes = [types copy];
}

- (void)awakeFromNib
{
	[[self window] setTitle:LocalizedStringInIMedia(@"Media", @"Window name of iMediaBrowser")];
	
	[[self window] setContentMinSize:NSMakeSize(292,292)];	// not so small that we lose the back of window content
	 
	myMediaBrowsers = [[NSMutableArray arrayWithCapacity:[_browserClasses count]] retain];

	if (myToolbar) 
	{
		[myToolbar setAllowsUserCustomization:NO];
		[myToolbar setShowsBaselineSeparator:YES];
		[self setToolbarDisplayMode:[self toolbarDisplayMode]];
		[self setToolbarIsSmall:[self toolbarIsSmall]];			
	}
	
	NSDictionary *d = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];
	
	NSString *lastmySelectedBrowser = [d objectForKey:@"SelectedBrowser"];
	BOOL canRestoreLastSelectedBrowser = NO;

	// Load any plugins so they register
	NSEnumerator *e = [_browserClasses objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		Class aClass = NSClassFromString(cur);
		id <iMediaBrowser>browser = [[aClass alloc] initWithFrame:[browserTabView bounds]];

		if (![browser conformsToProtocol:@protocol(iMediaBrowser)]) {
			NSLog(@"%@ must implement the iMediaBrowser protocol", [browser class]);
			[browser release];
			continue;
		}
		
		// if we were setup with a set of browser types, lets filter now.
		if (myPreferredBrowserTypes)
		{
			if (![myPreferredBrowserTypes containsObject:cur])
			{
				[browser release];
				continue;
			}
		}
		if ([myDelegate respondsToSelector:@selector(iMediaBrowser:willLoadBrowser:)])
		{
			if (![myDelegate iMediaBrowser:self willLoadBrowser:cur])
			{
				[browser release];
				continue;
			}
		}
		if ([lastmySelectedBrowser isEqualToString:cur])
			canRestoreLastSelectedBrowser = YES;
		
		[myMediaBrowsers addObject:browser];

        NSTabViewItem *tabViewItem = [[[NSTabViewItem alloc] initWithIdentifier:cur] autorelease];
        [tabViewItem setView:(NSView *)browser];
        [browserTabView addTabViewItem:tabViewItem];
                
		[browser release];
		if ([myDelegate respondsToSelector:@selector(iMediaBrowser:didLoadBrowser:)])
		{
			[myDelegate iMediaBrowser:self didLoadBrowser:cur];
		}
	}
	
	if (myToolbar) 
	{
		[myToolbar setDelegate:self];
		[[self window] setToolbar:myToolbar];
		[[self window] setShowsToolbarButton:NO];	// don't use the toolbar button
	}
	
	[self setupInfoWindow];
	
	
	//select the first browser
	if ([myMediaBrowsers count] > 0) {
		if (canRestoreLastSelectedBrowser)
		{
			[myToolbar setSelectedItemIdentifier:lastmySelectedBrowser];
			[self showMediaBrowser:lastmySelectedBrowser];
		}
		else
		{
			[myToolbar setSelectedItemIdentifier:NSStringFromClass([[myMediaBrowsers objectAtIndex:0] class])];
			[self showMediaBrowser:NSStringFromClass([[myMediaBrowsers objectAtIndex:0] class])];
		}
	}
	if ([self window])
	{
		NSString *position = [d objectForKey:@"WindowPosition"];
		if (position) {
			NSRect r = NSRectFromString(position);
			[[self window] setFrame:r display:NO];
		}
		[[self window] setDelegate:self];
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appWillQuit:)
												 name:NSApplicationWillTerminateNotification
											   object:nil];
}

- (void)setupInfoWindow 
{
	// set up special button
	NSButton *but = [[self window] standardWindowButton:NSWindowCloseButton];
	NSView *container = [but superview];
	float containerWidth = [container frame].size.width;
	NSRect frame = [but frame];
	NSButton *iButton = [[[iMBHoverButton alloc] initWithFrame:NSMakeRect(frame.origin.x + containerWidth - 11 - 11,frame.origin.y+2,11,11)] autorelease];
	[iButton setAutoresizingMask:NSViewMinYMargin|NSViewMinXMargin];
	
	[iButton setAction:@selector(info:)];
	[iButton setTarget:self];
	[container addSubview:iButton];
	
	// Now do another button on the flip-side
	but = [oInfoWindow standardWindowButton:NSWindowCloseButton];
	container = [but superview];
	containerWidth = [container frame].size.width;
	frame = [but frame];
	iButton = [[[iMBHoverButton alloc] initWithFrame:NSMakeRect(frame.origin.x + containerWidth - 11 - 11,frame.origin.y+2,11,11)] autorelease];
	[iButton setAutoresizingMask:NSViewMinYMargin|NSViewMinXMargin];
	
	[iButton setAction:@selector(flipBack:)];
	[iButton setTarget:self];
	[container addSubview:iButton];
	
	// get flipping window ready
	[NSWindow flippingWindow];
	[oInfoTextView setDrawsBackground:NO];
	//[oInfoTextView setTextContainerInset:NSMakeSize(2,2)];
	NSScrollView *scrollView = [oInfoTextView enclosingScrollView];
	[scrollView setDrawsBackground:NO];
	[[scrollView contentView] setCopiesOnScroll:NO];
	
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Info" ofType:@"html"];
	
	NSData *htmlContents = [NSData dataWithContentsOfFile:path];
	NSAttributedString *attr = [[[NSAttributedString alloc] initWithHTML:htmlContents documentAttributes:nil] autorelease];
	[[oInfoTextView textStorage] setAttributedString:attr];
	
	// set up cursors in text
	NSEnumerator* attrRuns = [[[oInfoTextView textStorage] attributeRuns] objectEnumerator];
	NSTextStorage* run;
	while ((run = [attrRuns nextObject])) {
		if ([run attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL]) {
			[run addAttribute:NSCursorAttributeName value:[NSCursor pointingHandCursor] range:NSMakeRange(0,[run length])];
		}
	};
}

- (void)appWillQuit:(NSNotification *)notification
{
	// TODO: Saving the defaults should be handled in didDeactivate rather than here.

	//we want to save the current selection to UD
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSIndexPath *selection = [[mySelectedBrowser controller] selectionIndexPath];
	NSData *archivedSelection = [NSKeyedArchiver archivedDataWithRootObject:selection];
    NSString    *myDefaultsKey = [NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[ud objectForKey:myDefaultsKey]];
	
	[d setObject:archivedSelection forKey:[NSString stringWithFormat:@"%@Selection", NSStringFromClass([mySelectedBrowser class])]];

	// This isn't being restored -- should we?
	//	[d setObject:[NSArray arrayWithObjects:NSStringFromRect([oPlaylists frame]), NSStringFromRect([oBrowserView frame]), nil] forKey:@"SplitViewSize"];
	[d setObject:NSStringFromRect([[self window] frame]) forKey:@"WindowPosition"];
	
	[ud setObject:d forKey:myDefaultsKey];
	
	[ud synchronize];
}

- (id <iMediaBrowser>)browserForClassName:(NSString *)name
{
	NSEnumerator *e = [myMediaBrowsers objectEnumerator];
	id <iMediaBrowser>cur;
	
	while (cur = [e nextObject]) 
	{
		NSString *className = NSStringFromClass([cur class]);
		if ([className isEqualToString:name])
		{
			return cur;
		}
	}
	return nil;
}

- (IBAction)reloadMediaBrowser:(id)sender
{
    // call method on selected browser (should be removed from the public interface and here as it is handled by iMBAbstractView)
	[mySelectedBrowser reload:sender];
}

- (void)showMediaBrowser:(NSString *)browserClassName
{
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]]];
    if (nil != mySelectedBrowser)
    {
        // TODO: Saving the defaults should be handled in didDeactivate rather than here.

        //we want to save the current selection to UD
        NSIndexPath *selection = [[mySelectedBrowser controller] selectionIndexPath];
        NSData *archivedSelection = [NSKeyedArchiver archivedDataWithRootObject:selection];

        [d setObject:archivedSelection forKey:[NSString stringWithFormat:@"%@Selection", NSStringFromClass([mySelectedBrowser class])]];
        
        [[NSUserDefaults standardUserDefaults] setObject:d forKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];
    }

    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:willChangeToBrowser:)])
    {
        [myDelegate iMediaBrowser:self willChangeToBrowser:browserClassName];
    }
    
    if (nil != mySelectedBrowser)
    {
        [mySelectedBrowser didDeactivate];
    }

	[browserTabView selectTabViewItemWithIdentifier:browserClassName];
    mySelectedBrowser = [[browserTabView tabViewItemAtIndex:[browserTabView indexOfTabViewItemWithIdentifier:browserClassName]] view];
    
    //save the selected browse
    [d setObject:NSStringFromClass([mySelectedBrowser class]) forKey:@"SelectedBrowser"];
    [[NSUserDefaults standardUserDefaults] setObject:d forKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];

    [mySelectedBrowser willActivate];

    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:didChangeToBrowser:)])
    {
        [myDelegate iMediaBrowser:self didChangeToBrowser:browserClassName];
    }
}

- (void)toolbarItemChanged:(id)sender
{
	[self showMediaBrowser:[sender itemIdentifier]];
}

- (BOOL)isLoading
{
	return [mySelectedBrowser isLoading];
}

- (NSMenu *)playlistMenu
{
    // call method on selected browser (should be removed from the public interface and here as it is handled by iMBAbstractView)
    return [(iMBAbstractView *)mySelectedBrowser playlistMenu];
}

- (IBAction)playlistSelected:(id)sender	// action from oPlaylists
{
    // call method on selected browser (should be removed from the public interface and here as it is handled by iMBAbstractView)
    [(iMBAbstractView *)mySelectedBrowser playlistSelected:sender];
}

- (NSArray *)searchSelectedBrowserNodeAttribute:(NSString *)nodeKey forKey:(NSString *)key matching:(NSString *)value
{
	NSMutableArray *results = [NSMutableArray array];
	NSEnumerator *e = [[mySelectedBrowser rootNodes] objectEnumerator];
	iMBLibraryNode *cur;
	
	while (cur = [e nextObject])
	{
		[results addObjectsFromArray:[cur searchAttribute:nodeKey withKeys:[NSArray arrayWithObjects:key, nil] matching:value]];
	}
	return results;
}



- (NSArray*)addCustomFolders:(NSArray*)folders
{
    // call method on selected browser (should be removed from the public interface and here as it is handled by iMBAbstractView)
    return [(iMBAbstractView *)mySelectedBrowser addCustomFolders:folders];
}

// This is a method that a client can call to set the default value of whether
// captions are shown.  Users can override this by checking checkbox on "back" of window.

- (void)setShowsFilenamesInPhotoBasedBrowsers:(BOOL)flag
{
    // call method on shared iMediaConfiguration object
    [[iMediaConfiguration sharedConfiguration] setShowsFilenamesInPhotoBasedBrowsers:flag];
}

// variation of the above that also sets a preference - for binding

- (void)setPrefersFilenamesInPhotoBasedBrowsers:(BOOL)flag
{
    // call method on shared iMediaConfiguration object
    [[iMediaConfiguration sharedConfiguration] setPrefersFilenamesInPhotoBasedBrowsers:flag];
}

- (BOOL)prefersFilenamesInPhotoBasedBrowsers
{
    // call method on shared iMediaConfiguration object
    return [[iMediaConfiguration sharedConfiguration] prefersFilenamesInPhotoBasedBrowsers];
}

- (IBAction)showWindow:(id)sender;
{
	// If we are actually showing the back of the window, flip to the front.
	if ([oInfoWindow isVisible])
	{
		[self flipBack:sender];
	}
	else
	{
		[super showWindow:sender];
	}
}

- (BOOL)infoWindowIsVisible
{
	return [oInfoWindow isVisible];
}

- (NSWindow *)infoWindow;
{
	return oInfoWindow;
}

- (IBAction) info:(id)sender
{
	[oInfoWindow setFrame:[[self window] frame] display:NO];
	[[self window] flipToShowWindow:oInfoWindow forward:YES reflectInto:oBackgroundImageView];
}

- (IBAction) flipBack:(id)sender
{
	[[self window] setFrame:[oInfoWindow frame] display:NO];	// not really needed unless window is resized
	[oInfoWindow flipToShowWindow:[self window] forward:NO reflectInto:nil];
}

- (NSArray *)excludedFolders {
    // call method on shared iMediaConfiguration object
    return [[iMediaConfiguration sharedConfiguration] excludedFolders];
}

- (void)setExcludedFolders:(NSArray *)value
{
    // call method on shared iMediaConfiguration object
    [[iMediaConfiguration sharedConfiguration] setExcludedFolders:value];
}

#pragma mark -
#pragma mark Bindings for toolbar

// TODO: Store in defaults too. (What does this comment mean? cmeyer 2007-08-14.)

- (int) toolbarDisplayMode
{
	int displayMode = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"iMBToolbarMode-%@", [self identifier]]];
	if (0 == displayMode) displayMode = NSToolbarDisplayModeIconAndLabel;
	return displayMode;
}
- (void) setToolbarDisplayMode:(int)aMode
{
	[[NSUserDefaults standardUserDefaults]
		setInteger:aMode
			forKey:[NSString stringWithFormat:@"iMBToolbarMode-%@", [self identifier]]];
	[myToolbar setDisplayMode:aMode];
}

- (BOOL)toolbarIsSmall
{
	int sizeMode = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"iMBToolbarSizeMode-%@", [self identifier]]];
	if (0 == sizeMode) sizeMode = NSToolbarSizeModeSmall;
	return (sizeMode == NSToolbarSizeModeSmall);
}

- (void) setToolbarIsSmall:(BOOL)aFlag
{
	int sizeMode = (aFlag ? NSToolbarSizeModeSmall : NSToolbarSizeModeRegular);
	[myToolbar setSizeMode:sizeMode];
	[[NSUserDefaults standardUserDefaults]
		setInteger:sizeMode
			forKey:[NSString stringWithFormat:@"iMBToolbarSizeMode-%@", [self identifier]]];
}


#pragma mark -
#pragma mark Delegate

- (void)setDelegate:(id)delegate
{
	myDelegate = delegate;	// not retained
    
    [[iMediaConfiguration sharedConfiguration] setDelegate:self];
}

- (id)delegate
{
	return myDelegate;
}

#pragma mark -
#pragma mark Window Delegate Methods
- (void)windowWillClose:(NSNotification *)aNotification
{
	[mySelectedBrowser didDeactivate];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	// TODO: Why is this needed? It does not update the photos without it. But why?

	// the browser will already be active; to balance calls, call deactivate first.
	[mySelectedBrowser didDeactivate];
	[mySelectedBrowser willActivate];
}


#pragma mark -
#pragma mark NSToolbar Delegate Methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar 
	 itemForItemIdentifier:(NSString *)itemIdentifier 
 willBeInsertedIntoToolbar:(BOOL)flag
{
	NSEnumerator *e = [myMediaBrowsers objectEnumerator];
	id <iMediaBrowser>cur;
	
	while (cur = [e nextObject]) 
	{
		NSString *className = NSStringFromClass([cur class]);
		if ([className isEqualToString:itemIdentifier])
		{
			NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
			[item setLabel:[cur name]];
			[item setTarget:self];
			NSImage *image = [cur toolbarIcon];
			[image setScalesWhenResized:YES];
			[item setImage:image];
			[item setAction:@selector(toolbarItemChanged:)];
			return [item autorelease];
		}
	}
	return nil;
}

- (NSArray *)allControllerClassNames
{
	NSMutableArray *identifiers = [NSMutableArray array];
	NSEnumerator *e = [myMediaBrowsers objectEnumerator];
	id <iMediaBrowser>cur;
	
	while (cur = [e nextObject]) 
	{
		[identifiers addObject:NSStringFromClass([cur class])];
	}
	return identifiers;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return [self allControllerClassNames];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [self allControllerClassNames];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [self allControllerClassNames];
}

#pragma mark -
#pragma mark iMediaConfiguration Delegate Methods

- (BOOL)iMediaConfiguration:(iMediaConfiguration *)configuration willLoadBrowser:(NSString *)browserClassname
{
    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:willLoadBrowser:)])
    {
        return [myDelegate iMediaBrowser:self willLoadBrowser:browserClassname];
    }
    
    return YES;
}

- (void)iMediaConfiguration:(iMediaConfiguration *)configuration didLoadBrowser:(NSString *)browserClassname
{
    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:didLoadBrowser:)])
    {
        [myDelegate iMediaBrowser:self didLoadBrowser:browserClassname];
    }
}

- (void)iMediaConfiguration:(iMediaConfiguration *)configuration doubleClickedSelectedObjects:(NSArray*)selection
{
    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:doubleClickedSelectedObjects:)])
    {
        [myDelegate iMediaBrowser:self doubleClickedSelectedObjects:selection];
    }
}

- (NSMenu*)iMediaConfiguration:(iMediaConfiguration *)configuration menuForSelectedObjects:(NSArray*)selection
{
    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:menuForSelectedObjects:)])
    {
        return [myDelegate iMediaBrowser:self menuForSelectedObjects:selection];
    }
    
    return nil;
}

- (BOOL)iMediaConfiguration:(iMediaConfiguration *)configuration willUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media
{
    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:willUseMediaParser:forMediaType:)])
    {
        return [myDelegate iMediaBrowser:self willUseMediaParser:parserClassname forMediaType:media];
    }
    
    return YES;
}

- (void)iMediaConfiguration:(iMediaConfiguration *)configuration didUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media
{
    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:didUseMediaParser:forMediaType:)])
    {
        [myDelegate iMediaBrowser:self didUseMediaParser:parserClassname forMediaType:media];
    }
}

- (void)iMediaConfiguration:(iMediaConfiguration *)configuration didSelectNode:(iMBLibraryNode *)node
{
    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:didSelectNode:)])
    {
        [myDelegate iMediaBrowser:self didSelectNode:node];
    }
}

- (void)iMediaConfiguration:(iMediaConfiguration *)configuration willExpandOutline:(NSOutlineView *)outline row:(id)row node:(iMBLibraryNode *)node
{
    if ([myDelegate respondsToSelector:@selector(iMediaBrowser:willExpandOutline:row:node:)])
    {
        [myDelegate iMediaBrowser:self willExpandOutline:outline row:row node:node];
    }
}

- (BOOL)horizontalSplitViewForMediaConfiguration:(iMediaConfiguration *)configuration
{
    if ([myDelegate respondsToSelector:@selector(horizontalSplitViewForMediaConfiguration:)])
    {
        return [myDelegate horizontalSplitViewForMediaConfiguration:configuration];
    }
    
    return YES;
}

@end

@implementation iMediaBrowser (Plugins)

+ (NSArray *)findModulesInDirectory:(NSString*)scanDir withExtension:(NSString *)ext
{
    NSEnumerator	*e;
    NSString		*dir;
    BOOL			isDir;
	NSMutableArray	*bundles = [NSMutableArray array];
	
    // make sure scanDir exists and is a directory.
    if (![[NSFileManager defaultManager] fileExistsAtPath:scanDir isDirectory:&isDir]) return nil;
    if (!isDir) return nil;
	
    // scan the dir for .ext directories.
    e = [[[NSFileManager defaultManager] directoryContentsAtPath:scanDir] objectEnumerator];
    while (dir = [e nextObject]) {
		if ([[dir pathExtension] isEqualToString:ext]) {
			
            [bundles addObject:[NSString stringWithFormat:@"%@/%@", scanDir, dir]];
        }
    }
	return bundles;
}


+ (NSArray *)findBundlesWithExtension:(NSString *)ext inFolderName:(NSString *)folder
{
	NSMutableArray *bundles = [NSMutableArray array];
		
    //application wrapper
    [bundles addObjectsFromArray:[iMediaBrowser findModulesInDirectory:[[NSBundle mainBundle] resourcePath]
														 withExtension:ext]];

	NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
	NSEnumerator *e = [dirs objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject])
	{
		[bundles addObjectsFromArray:[iMediaBrowser findModulesInDirectory:[cur stringByAppendingPathComponent:folder]
															 withExtension:ext]];
	}
	return bundles;
}

@end
