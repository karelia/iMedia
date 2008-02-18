/*
 iMedia Browser <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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
#import "iMedia.h"
#import "LibraryItemsValueTransformer.h"
#import "RBSplitView.h"
#import "RBSplitSubview.h"
#import "iMBPlacardScrollView.h"
#import "iMBHoverButton.h"
#import "NSWindow_Flipr.h"
#import "iMBBackgroundImageView.h"
#import "iMBPhotosController.h"

#import <QuickTime/QuickTime.h>
#import <QTKit/QTKit.h>

NSString *iMediaBrowserSelectionDidChangeNotification = @"iMediaSelectionChanged";

static iMediaBrowser *_sharedMediaBrowser = nil;
static NSMutableArray *_browserClasses = nil;
static NSMutableDictionary *_parsers = nil;

@interface iMediaBrowser (PrivateAPI)
- (id)initializeInstance;
- (void)resetLibraryController;
- (void)setupInfoWindow;
- (void)showMediaBrowser:(NSString *)browserClassName reuseCachedData:(BOOL)reuseCachedData;
@end

@interface iMediaBrowser (Plugins)
+ (NSArray *)findBundlesWithExtension:(NSString *)ext inFolderName:(NSString *)folder;
@end

@interface NSObject (iMediaHack)
- (id)observedObject;
@end

@implementation iMediaBrowser

+ (void)initialize	// preferred over +load in most cases
{
	if ( self == [iMediaBrowser class] ) 
	{
		// Only do some work when not called because one of our subclasses does not implement +initialize

	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_browserClasses = [[NSMutableArray alloc] init];
	_parsers = [[NSMutableDictionary dictionary] retain];
	
	// Note: Originally I wanted a custom NSURLCache, but apparently there's only one way to do this,
	// and that is to create a new sharedURLCache used by your entire application.  I don't know how
	// to have just imedia's data cached in a particular, separate cache -- if I create a custom
	// NSURLCache and reference it instead of the shared URL cache, then the data don't get saved
	// to disk ever.  So unless Apple has a better way, we are stuck 
	// Create URL cache path, so all instances of iMedia Browser can share a cache
		
	//register the default set in order
	[self registerBrowser:NSClassFromString(@"iMBPhotosController")];
	[self registerBrowser:NSClassFromString(@"iMBMusicController")];
	[self registerBrowser:NSClassFromString(@"iMBMoviesController")];
	[self registerBrowser:NSClassFromString(@"iMBLinksController")];
	//[self registerBrowser:NSClassFromString(@"iMBContactsController")];
	
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
	[imb setPreferredBrowserTypes:types];
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
	NSAssert(aClass != NULL, @"aClass is NULL");
	NSAssert(media != nil, @"media is nil");
	
	NSMutableArray *parsers = [_parsers objectForKey:media];
	if (!parsers)
	{
		parsers = [NSMutableArray array];
		[_parsers setObject:parsers forKey:media];
	}
  if (aClass != Nil)
    [parsers addObject:NSStringFromClass(aClass)];
}

+ (void)unregisterParserName:(NSString*)parserClassName forMediaType:(NSString *)media
{
	NSEnumerator *e = [[_parsers objectForKey:media] objectEnumerator];
	NSString *cur;
	while (cur = [e nextObject]) {
		if ([parserClassName isEqualToString:cur]) {
			[[_parsers objectForKey:media] removeObject:cur];
			return;
		}
	}
}

+ (void)unregisterParser:(Class)parserClass forMediaType:(NSString *)media
{
	[iMediaBrowser unregisterParserName:NSStringFromClass(parserClass) forMediaType:media];
}


#pragma mark -
#pragma mark Instance Methods

- (id)init
{
	if (self = [super initWithWindowNibName:@"MediaBrowser"]) {
		self = [self initializeInstance];
		myToolbar = [[NSToolbar alloc] initWithIdentifier:@"iMediaBrowserToolbar"];
	}
	return self;
}


- (id)initWithoutWindow 
{
	if (self = [super init]) {
		self = [self initializeInstance];
	}
	return self;
}


- (id)initializeInstance {
		// Make sure we are running Tiger
	if (NSAppKitVersionNumber < 824)  /* NSAppKitVersionNumber10_4 */
	{
		NSLog(@"ERROR - Mac OS X 10.4, or greater, required for the iMediaBrowser");
		[self release];
		return nil;
	}
	
	[QTMovie initialize];
	id libraryItemsValueTransformer = [[[LibraryItemsValueTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:libraryItemsValueTransformer forName:@"libraryItemsValueTransformer"];
	
	myBackgroundLoadingLock = [[NSLock alloc] init];
	myIdentifier = @"Default";
	
	return self;
}

- (void)dealloc
{
	if (nil != mySelectedBrowser)
	{
		[mySelectedBrowser didDeactivate];
		[[mySelectedBrowser browserView] removeFromSuperview];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[libraryController removeObserver:self forKeyPath:nil];
	
	// Begin unbind
	// Somehow the window's content view might still linger in an NSAutoreleasePool after
	// this controller has been deallocated. When the view finally gets deallocated, attempts
	// to undo bindings fail as the controller has long been deallocated. 
	// The workaround is to explicitely undo bindings now as we dealloc the controller.
	NSTableColumn *tableColumn = [[oPlaylists tableColumns] objectAtIndex:0];
	
	[tableColumn unbind:@"value"];
	[tableColumn unbind:@"editable"];
	// End unbind
	   
	[oPlaylists setDelegate:nil];
	[oPlaylists setDataSource:nil];
	[oSplitView setDelegate:nil];
	
	[[oPlaylists enclosingScrollView] release];
	[oPlaylists removeFromSuperview];
	
	[oPlaylistPopup release];
	
	[myUserDroppedParsers release];
	[myMediaBrowsers release];
	[myLoadedParsers release];
	[myToolbar release];
	[myBackgroundLoadingLock release];
	[myPreferredBrowserTypes release];
	[myIdentifier release];
	[myExcludedFolders release];

	[super dealloc];
}

- (void)setIdentifier:(NSString *)identifier
{
	if (identifier != myIdentifier)
	{
		[myIdentifier autorelease];
		myIdentifier = [identifier copy];
	}
}

- (NSString *)identifier
{
	return myIdentifier;
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
	[oLoadingText setStringValue:
		LocalizedStringInThisBundle(@"Loading...", @"Text that shows that we are loading contents")];
	[[self window] setTitle:LocalizedStringInThisBundle(@"Media", @"Window name of iMediaBrowser")];
	
	// save these since they get swapped out
	[[oPlaylists enclosingScrollView] retain];
	[oPlaylistPopup retain];
	
	// [((iMBPlacardScrollView *)[oPlaylists enclosingScrollView]) setSide:PLACARD_BOTTOM_RIGHT];
	
	myMediaBrowsers = [[NSMutableArray arrayWithCapacity:[_browserClasses count]] retain];
	myLoadedParsers = [[NSMutableDictionary alloc] init];
	myUserDroppedParsers = [[NSMutableArray alloc] init];

	if (myToolbar) 
	{
		[myToolbar setAllowsUserCustomization:NO];
		[myToolbar setShowsBaselineSeparator:YES];
		[self setToolbarDisplayMode:[self toolbarDisplayMode]];
		[self setToolbarIsSmall:[self toolbarIsSmall]];			
	}
	
	NSDictionary *d = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]];
	
	NSString *lastmySelectedBrowser = [d objectForKey:@"SelectedBrowser"];
	BOOL canRestoreLastSelectedBrowser = NO;

	// Load any plugins so they register
	NSEnumerator *e = [_browserClasses objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		Class aClass = NSClassFromString(cur);
		id <iMediaBrowser>browser = [[aClass alloc] initWithPlaylistController:libraryController];
		[browser setBrowser:self];
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
		if (myFlags.willLoadBrowser)
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
		[browser release];
		if (myFlags.didLoadBrowser)
		{
			[myDelegate iMediaBrowser:self didLoadBrowser:cur];
		}
		[oSplitView setAutosaveName:[NSString stringWithFormat:@"iMBSplitView-%@", myIdentifier] recursively:YES];
		
		if (myFlags.orientation && ![myDelegate horizontalSplitViewForMediaBrowser:self])
		{
			[oSplitView setVertical:YES];
		}
		[oSplitView restoreState:YES];
		[[oSplitView subviewAtPosition:0] setMinDimension:26.0 andMaxDimension:0.0];
		// Simulate a resize to possibly swap out outline view
		[self splitView:oSplitView changedFrameOfSubview:[oSplitView subviewAtPosition:0] from:NSZeroRect to:[[oSplitView subviewAtPosition:0] frame]];
		[oSplitView adjustSubviews];	// just to be safe.
	}
	
	if (myToolbar) 
	{
		[myToolbar setDelegate:self];
		[[self window] setToolbar:myToolbar];
		[[self window] setShowsToolbarButton:NO];	// don't use the toolbar button
	}
	
	[self setupInfoWindow];
	
	
#ifdef DEBUG
	// DEBUG -- don't load, and present an empty window.
	[oSplitView setHidden:YES];
	[oLoadingView setHidden:YES];
#else
	//select the first browser
	if ([myMediaBrowsers count] > 0) {
		if (canRestoreLastSelectedBrowser)
		{
			[myToolbar setSelectedItemIdentifier:lastmySelectedBrowser];
			[self showMediaBrowser:lastmySelectedBrowser reuseCachedData:NO];
		}
		else
		{
			[myToolbar setSelectedItemIdentifier:NSStringFromClass([[myMediaBrowsers objectAtIndex:0] class])];
			[self showMediaBrowser:NSStringFromClass([[myMediaBrowsers objectAtIndex:0] class]) reuseCachedData:NO];
		}
	}
#endif	
	if ([self window])
	{
		NSString *position = [d objectForKey:@"WindowPosition"];
		if (position) {
			NSRect r = NSRectFromString(position);
			[[self window] setFrame:r display:NO];
		}
		[[self window] setDelegate:self];
	}
	
	[libraryController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(appWillQuit:)
												 name:NSApplicationWillTerminateNotification
											   object:nil];
	
	[oPlaylists setDataSource:self];
	[oPlaylists setAllowsColumnReordering:NO];
	[oPlaylists setDelegate:self];
	[libraryController setSortDescriptors:nil];
	[oSplitView setDelegate:self];
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
	//we want to save the current selection to UD
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	NSIndexPath *selection = [libraryController selectionIndexPath];
	NSData *archivedSelection = [NSKeyedArchiver archivedDataWithRootObject:selection];
    NSString    *myDefaultsKey = [NSString stringWithFormat:@"iMB-%@", myIdentifier];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[ud objectForKey:myDefaultsKey]];
	
	[d setObject:archivedSelection forKey:[NSString stringWithFormat:@"%@Selection", NSStringFromClass([mySelectedBrowser class])]];

	// This isn't being restored -- should we?
	//	[d setObject:[NSArray arrayWithObjects:NSStringFromRect([oPlaylists frame]), NSStringFromRect([oBrowserView frame]), nil] forKey:@"SplitViewSize"];
	[d setObject:NSStringFromRect([[self window] frame]) forKey:@"WindowPosition"];
	
	[ud setObject:d forKey:myDefaultsKey];
	[oSplitView saveState:YES];
	
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
	[self showMediaBrowser:NSStringFromClass([mySelectedBrowser class]) reuseCachedData:NO];
}

- (void)showMediaBrowser:(NSString *)browserClassName
{
	[self showMediaBrowser:browserClassName reuseCachedData:YES];
}

- (void)showMediaBrowser:(NSString *)browserClassName reuseCachedData:(BOOL)reuseCachedData
{
	if (![NSStringFromClass([mySelectedBrowser class]) isEqualToString:browserClassName] || !reuseCachedData)
	{
		if ([myBackgroundLoadingLock tryLock])
		{
			NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]]];
			if (nil != mySelectedBrowser)
			{
				//we want to save the current selection to UD
				NSIndexPath *selection = [libraryController selectionIndexPath];
				NSData *archivedSelection = [NSKeyedArchiver archivedDataWithRootObject:selection];
		
				[d setObject:archivedSelection forKey:[NSString stringWithFormat:@"%@Selection", NSStringFromClass([mySelectedBrowser class])]];
				
				[[NSUserDefaults standardUserDefaults] setObject:d forKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]];
			}
			if (myFlags.willChangeBrowser)
			{
				[myDelegate iMediaBrowser:self willChangeToBrowser:browserClassName];
			}
			[oSplitView setHidden:YES];
			[oLoadingView setHidden:NO];
			[oLoading startAnimation:self];
			id <iMediaBrowser>browser = [self browserForClassName:browserClassName];
			NSView *view = [browser browserView];
			//remove old view
			if (nil != mySelectedBrowser)
			{
				[mySelectedBrowser didDeactivate];
				[[mySelectedBrowser browserView] removeFromSuperview];
			}
			[view setFrame:[oBrowserView bounds]];
			[oBrowserView addSubview:[view retain]];
			mySelectedBrowser = browser;
			[oPlaylists registerForDraggedTypes:[mySelectedBrowser fineTunePlaylistDragTypes:[NSArray arrayWithObject:NSFilenamesPboardType]]];
			
			//save the selected browse
			[d setObject:NSStringFromClass([mySelectedBrowser class]) forKey:@"SelectedBrowser"];
			[[NSUserDefaults standardUserDefaults] setObject:d forKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]];
			myFlags.isLoading = YES;
			[NSThread detachNewThreadSelector:@selector(backgroundLoadData:) toTarget:self withObject:[NSNumber numberWithBool:reuseCachedData]];
		}
		[myToolbar setSelectedItemIdentifier:NSStringFromClass([mySelectedBrowser class])];
	}
}

- (void)toolbarItemChanged:(id)sender
{
	[self showMediaBrowser:[sender itemIdentifier] reuseCachedData:YES];
}

- (void)backgroundLoadData:(id)reuseCachedDataArgument
{	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
   
	BOOL reuseCachedData = [reuseCachedDataArgument boolValue];
	[self resetLibraryController];
	NSMutableArray *root = [NSMutableArray array];
	NSArray *parsers = [_parsers objectForKey:[mySelectedBrowser mediaType]];
	NSEnumerator *e = [parsers objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject])
	{
		Class parserClass = NSClassFromString(cur);
		if (![parserClass conformsToProtocol:@protocol(iMBParser)])
		{
			NSLog(@"Media Parser %@ does not conform to the iMBParser protocol. Skipping parser.");
			continue;
		}
		if (myFlags.willUseParser)
		{
			if (![myDelegate iMediaBrowser:self willUseMediaParser:cur forMediaType:[mySelectedBrowser mediaType]])
			{
				continue;
			}
		}
		
		id <iMBParser>parser = [myLoadedParsers objectForKey:cur];
		if (!parser)
		{
			parser = [[parserClass alloc] init];
			if (parser == nil)
			{
				continue;
			}
			[myLoadedParsers setObject:parser forKey:cur];
			[parser release];
		}
		//set the browser the parser is in
		[parser setBrowser:mySelectedBrowser];
#ifdef DEBUG
//		NSDate *timer = [NSDate date];
#endif
		NSArray *libraries = [parser librariesReusingCache:reuseCachedData];
#ifdef DEBUG
		//		NSLog(@"Time to load parser (%@): %.3f", NSStringFromClass(parserClass), fabs([timer timeIntervalSinceNow]));
#endif
		if (libraries)
		{
			[root addObjectsFromArray:libraries];
		}
		if (myFlags.didUseParser)
		{
			[myDelegate iMediaBrowser:self didUseMediaParser:cur forMediaType:[mySelectedBrowser mediaType]];
		}
	}
	
	NSSortDescriptor *priorityOrderSortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"prioritySortOrder" 
																				 ascending:NO] autorelease];
	NSSortDescriptor *nameSortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"name" 
																		ascending:YES 
																		 selector:@selector(caseInsensitiveCompare:)] autorelease];
	NSArray *librarySortDescriptor = [NSArray arrayWithObjects:priorityOrderSortDescriptor, nameSortDescriptor, nil];
	
	[root sortUsingDescriptors:librarySortDescriptor];
	
	// Do any user dropped folders
	NSDictionary *d = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]];
	NSArray *drops = [d objectForKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)mySelectedBrowser className]]];
	e = [drops objectEnumerator];
	NSString *drop;
	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir;
	Class aClass = [mySelectedBrowser parserForFolderDrop];
	
	[myUserDroppedParsers removeAllObjects]; // Clear out the old ones as otherwise we just grow and grow (and leak parsers)
	while ((drop = [e nextObject]))
	{
		if ([fm fileExistsAtPath:drop isDirectory:&isDir] && isDir)
		{
			iMBAbstractParser *parser = [[aClass alloc] initWithContentsOfFile:drop];
			[parser setBrowser:mySelectedBrowser];
			NSArray *nodes = [parser librariesReusingCache:YES];	// should be only 1 but let's enum
			
			NSEnumerator *e = [nodes objectEnumerator];
			iMBLibraryNode *node;
			
			while (node = [e nextObject])
			{
				[node setParser:parser];
				[node setName:[drop lastPathComponent]];
				[node setIconName:@"folder"];
				[root addObject:node];
			}
			
			[myUserDroppedParsers addObject:parser];
			[parser release];
		}
	}
	
	[libraryController performSelectorOnMainThread:@selector(setContent:) withObject:root waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(controllerLoadedData:) withObject:self waitUntilDone:YES];
	
	[pool release];
}

- (void)recursivelyAddItemsToMenu:(NSMenu *)menu withNode:(iMBLibraryNode *)node indentation:(int)indentation
{
	NSString *name = [node name];
	if (!name) name = @"";
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name
												  action:@selector(playlistPopupChanged:)
										   keyEquivalent:@""];
	NSImage *icon = [[NSImage alloc] initWithData:[[node icon] TIFFRepresentation]];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(16,16)];
	[item setImage:icon];
	[icon release];
	[item setTarget:self];
	[item setRepresentedObject:node];
	[item setIndentationLevel:indentation];
	[menu addItem:item];
	[item release];
	
	NSEnumerator *e = [[node allItems] objectEnumerator];
	iMBLibraryNode *cur;
	
	while (cur = [e nextObject])
	{
		[self recursivelyAddItemsToMenu:menu withNode:cur indentation:indentation+1];
	}
}

- (void)updatePlaylistPopup
{
	if ([[libraryController content] count] > 0)
		[oPlaylistPopup setMenu:[self playlistMenu]];
	else
		[oPlaylistPopup removeAllItems];
	[oPlaylistPopup setEnabled:[oPlaylistPopup numberOfItems] > 0];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ((object == libraryController) && [keyPath isEqualToString:@"arrangedObjects"])
	{
		[self updatePlaylistPopup];
	}
}


- (void)controllerLoadedData:(id)sender
{
	[oLoadingView setHidden:YES];
	[oSplitView setHidden:NO];
	[oLoading stopAnimation:self];
	[myBackgroundLoadingLock unlock];
	if ([[libraryController content] count] > 0)
	{
		// select the previous selection
		NSDictionary *d = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]];
		NSData *archivedSelection = [d objectForKey:[NSString stringWithFormat:@"%@Selection", NSStringFromClass([mySelectedBrowser class])]];
		
		if (archivedSelection)
		{
			NSIndexPath *selection = [NSKeyedUnarchiver unarchiveObjectWithData:archivedSelection];
			
			@try
			{
				[libraryController setSelectionIndexPath:selection];
			}
			@catch (NSException *ex) {
				NSLog(@"Exception caught in setSelectionIndexPath, ignoring");
			}
		}
		else
		{
			[oPlaylists expandItem:[oPlaylists itemAtRow:0]];
		}
		[oPlaylistPopup selectItemWithRepresentedObject:[[libraryController selectedObjects] lastObject]];
	}
	
	[mySelectedBrowser willActivate];
	
	if (myFlags.didChangeBrowser)
	{
		[myDelegate iMediaBrowser:self didChangeToBrowser:NSStringFromClass([mySelectedBrowser class])];
	}
	myFlags.isLoading = NO;
}

- (BOOL)isLoading
{
	return myFlags.isLoading;
}

- (NSMenu *)playlistMenu
{
	NSEnumerator *e = [[libraryController content] objectEnumerator];
	iMBLibraryNode *cur;
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"playlists"];
	
	while (cur = [e nextObject])
	{
		[self recursivelyAddItemsToMenu:menu withNode:cur indentation:0];
	}
	
	return [menu autorelease];
}

- (void)playlistPopupChanged:(id)sender
{
	iMBLibraryNode *selected = [sender representedObject];
	NSIndexPath *theIndex = [selected indexPath];
	NSIndexPath *full = nil;
	unsigned int *idxs = (unsigned int *)malloc(sizeof(unsigned int) * ([theIndex length] + 1));
	
	idxs[0] = [[libraryController content] indexOfObject:[selected root]];
	
	int i = 0;
	for (i = 0; i < [theIndex length]; i++)
	{
		idxs[i+1] = [theIndex indexAtPosition:i];
	}
	full = [NSIndexPath indexPathWithIndexes:idxs length:i+1];
	[libraryController setSelectionIndexPath:full];
	free (idxs);
}

- (IBAction)playlistSelected:(id)sender	// action from oPlaylists
{
	id rowItem = [oPlaylists itemAtRow:[sender selectedRow]];
	id representedObject = [rowItem respondsToSelector:@selector(representedObject)] ? [rowItem representedObject] : [rowItem observedObject];

	if ([[representedObject parser] respondsToSelector:@selector(iMediaBrowser:didSelectNode:)])
	{
		[[representedObject parser] iMediaBrowser:self didSelectNode:representedObject];
	}
	if (myFlags.didSelectNode)
	{
		[myDelegate iMediaBrowser:self didSelectNode:representedObject];
	}
}

- (void)outlineViewItemWillExpand:(NSNotification *)notification	// notification from oPlaylists
{
	NSOutlineView *theOutline = [notification object];
	id rowItem = [[notification userInfo] objectForKey:@"NSObject"];
	id representedObject = [rowItem respondsToSelector:@selector(representedObject)] ? [rowItem representedObject] : [rowItem observedObject];

	if (myFlags.willExpand)
	{
		[myDelegate iMediaBrowser:self willExpandOutline:theOutline row:rowItem node:representedObject];
	}
	if ([[representedObject parser] respondsToSelector:@selector(iMediaBrowser:willExpandOutline:row:node:)])
	{
		[[representedObject parser] iMediaBrowser:self willExpandOutline:theOutline row:rowItem node:representedObject];
	}
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
	NSMutableArray *results = [NSMutableArray array];
	if ([folders count])
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isDir;
		NSEnumerator *e = [folders objectEnumerator];
		NSString *cur;
		Class aClass = [mySelectedBrowser parserForFolderDrop];
		NSMutableArray *content = [NSMutableArray arrayWithArray:[libraryController content]];
		NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]]];
		NSMutableArray *drops = [NSMutableArray arrayWithArray:[d objectForKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)mySelectedBrowser className]]]];
		
		while ((cur = [e nextObject]))
		{
			if (![drops containsObject:cur] && [fm fileExistsAtPath:cur isDirectory:&isDir] && isDir && [mySelectedBrowser allowPlaylistFolderDrop:cur])
			{
				iMBAbstractParser *parser = [[aClass alloc] initWithContentsOfFile:cur];
				NSArray *nodes = [parser librariesReusingCache:NO];
				
				NSEnumerator *e = [nodes objectEnumerator];
				iMBLibraryNode *node;
				
				while (node = [e nextObject])
				{
					[node setParser:parser];
					[node setName:[cur lastPathComponent]];
					[node setIconName:@"folder"];
					[content addObject:node];
					[results addObject:node];
				}
				[myUserDroppedParsers addObject:parser];
				[parser release];
				
				[drops addObject:cur];
			}
		}
		
		[libraryController setContent:content];
		
		[d setObject:drops forKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)mySelectedBrowser className]]];
		[[NSUserDefaults standardUserDefaults] setObject:d forKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]];
	}
	
	return results;
}

// This is a method that a client can call to set the default value of whether
// captions are shown.  Users can override this by checking checkbox on "back" of window.

- (void)setShowsFilenamesInPhotoBasedBrowsers:(BOOL)flag
{
	myFlags.showFilenames = flag;
}

// variation of the above that also sets a preference - for binding

- (void)setPrefersFilenamesInPhotoBasedBrowsers:(BOOL)flag
{
	[self setShowsFilenamesInPhotoBasedBrowsers:flag];	// set internal value

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:flag], @"flag", 
		nil];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:ShowCaptionChangedNotification
						  object:self
						userInfo:info];
	
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:[NSString stringWithFormat:@"iMBShowCaptions-%@", myIdentifier]];

}

- (BOOL)prefersFilenamesInPhotoBasedBrowsers
{
	id preferred = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMBShowCaptions-%@", myIdentifier]];
	if (nil != preferred)
	{
		return [preferred boolValue];
	}
	return myFlags.showFilenames;	// return the fallback set through code
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

- (IBAction) clearCache:(id)sender
{
	if ([mySelectedBrowser respondsToSelector:@selector(clearCache)])
	{
		id browser = ((id)mySelectedBrowser);
		[browser clearCache];
	}
	else
	{
		NSBeep();
	}
}

- (NSArray *)excludedFolders {
    return [[myExcludedFolders retain] autorelease];
}

- (void)setExcludedFolders:(NSArray *)value
{
    if (myExcludedFolders != value)
    {
        [myExcludedFolders release];
        myExcludedFolders = [value copy];
    }
}

#pragma mark -
#pragma mark Bindings for toolbar

// TODO: Store in defaults too. (What does this comment mean? cmeyer 2007-08-14.)

- (int) toolbarDisplayMode
{
	int displayMode = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"iMBToolbarMode-%@", myIdentifier]];
	if (0 == displayMode) displayMode = NSToolbarDisplayModeIconAndLabel;
	return displayMode;
}
- (void) setToolbarDisplayMode:(int)aMode
{
	[[NSUserDefaults standardUserDefaults]
		setInteger:aMode
			forKey:[NSString stringWithFormat:@"iMBToolbarMode-%@", myIdentifier]];
	[myToolbar setDisplayMode:aMode];
}

- (BOOL)toolbarIsSmall
{
	int sizeMode = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"iMBToolbarSizeMode-%@", myIdentifier]];
	if (0 == sizeMode) sizeMode = NSToolbarSizeModeSmall;
	return (sizeMode == NSToolbarSizeModeSmall);
}

- (void) setToolbarIsSmall:(BOOL)aFlag
{
	int sizeMode = (aFlag ? NSToolbarSizeModeSmall : NSToolbarSizeModeRegular);
	[myToolbar setSizeMode:sizeMode];
	[[NSUserDefaults standardUserDefaults]
		setInteger:sizeMode
			forKey:[NSString stringWithFormat:@"iMBToolbarSizeMode-%@", myIdentifier]];
}


#pragma mark -
#pragma mark Delegate

- (void)setDelegate:(id)delegate
{
	myFlags.willLoadBrowser = [delegate respondsToSelector:@selector(iMediaBrowser:willLoadBrowser:)];
	myFlags.didLoadBrowser = [delegate respondsToSelector:@selector(iMediaBrowser:didLoadBrowser:)];
	myFlags.willUseParser = [delegate respondsToSelector:@selector(iMediaBrowser:willUseMediaParser:forMediaType:)];
	myFlags.didUseParser = [delegate respondsToSelector:@selector(iMediaBrowser:didUseMediaParser:forMediaType:)];
	myFlags.willChangeBrowser = [delegate respondsToSelector:@selector(iMediaBrowser:willChangeBrowser:)];	
	myFlags.didChangeBrowser = [delegate respondsToSelector:@selector(iMediaBrowser:didChangeBrowser:)];
	myFlags.didSelectNode = [delegate respondsToSelector:@selector(iMediaBrowser:didSelectNode:)];
	myFlags.willExpand = [delegate respondsToSelector:@selector(iMediaBrowser:willExpandOutline:row:node:)];
	myFlags.orientation = [delegate respondsToSelector:@selector(horizontalSplitViewForMediaBrowser:)];
	myDelegate = delegate;	// not retained
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
	[mySelectedBrowser willActivate];
}

- (void)resetLibraryController
{
	int controllerCount = [[libraryController arrangedObjects] count];
	for(; controllerCount != 0;--controllerCount)
	{
		[libraryController removeObjectAtArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:controllerCount-1]];
	}
}

#pragma mark -
#pragma mark NSSplitView Delegate Methods

- (void)splitView:(RBSplitView*)sender changedFrameOfSubview:(RBSplitSubview*)subview from:(NSRect)fromRect to:(NSRect)toRect;
{
	if (subview == [oSplitView subviewAtPosition:0])
	{
		if (myFlags.inSplitViewResize) return; // stop possible recursion from NSSplitView
		myFlags.inSplitViewResize = YES;
		if (![oSplitView isVertical])
		{
			if(toRect.size.height <= 50 && ![[[oSplitView subviewAtPosition:0] subviews] containsObject:oPlaylistPopup])
			{
				// select the currently selected item in the playlist
				[oPlaylistPopup selectItemWithRepresentedObject:[[libraryController selectedObjects] lastObject]];
				[[oSplitView subviewAtPosition:0] replaceSubview:[oPlaylists enclosingScrollView] with:oPlaylistPopup];
				NSRect frame = [oPlaylistPopup frame];
				frame.origin.y = [[oSplitView subviewAtPosition:0] frame].size.height - frame.size.height;
				frame.origin.x = 0;
				frame.size.width = [[oSplitView subviewAtPosition:0] frame].size.width;
				[oPlaylistPopup setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
				[oPlaylistPopup setFrame:frame];
			}
			
			if(toRect.size.height > 50 && [[[oSplitView subviewAtPosition:0] subviews] containsObject:oPlaylistPopup])
			{
				NSScrollView *scrollView = [oPlaylists enclosingScrollView];
				NSRect frame = [scrollView frame];
				frame.size.height = [[oSplitView subviewAtPosition:0] frame].size.height;
				frame.size.width = [[oSplitView subviewAtPosition:0] frame].size.width;
				[scrollView setFrame:frame];
				[[oSplitView subviewAtPosition:0] replaceSubview:oPlaylistPopup with:scrollView];
			}
		}
		myFlags.inSplitViewResize = NO;
	}
}

/*  NOT SURE HOW TO TRANSLATE THIS QUITE YET

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	if (![sender isVertical])
		return NSHeight([sender frame]) - 200;
	else
		return NSWidth([sender frame]) - 200;
}
*/


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

// This Code is from http://theocacao.com/document.page/130

#pragma mark -
#pragma mark NSOutlineView Hacks for Drag and Drop

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	NSEnumerator *e = [items objectEnumerator];
	id cur;
	[pboard declareTypes:[NSArray array] owner:nil]; // clear the pasteboard incase the browser decides not to add anything
	while (cur = [e nextObject])
	{
		id representedObject = [cur respondsToSelector:@selector(representedObject)] ? [cur representedObject] : [cur observedObject];

		[mySelectedBrowser writePlaylist:representedObject toPasteboard:pboard];
	}
	return [[pboard types] count] != 0;
}

- (BOOL) outlineView: (NSOutlineView *)ov
	isItemExpandable: (id)item { return NO; }

- (int)  outlineView: (NSOutlineView *)ov
         numberOfChildrenOfItem:(id)item { return 0; }

- (id)   outlineView: (NSOutlineView *)ov
			   child:(int)aIndex
			  ofItem:(id)item { return nil; }

- (id)   outlineView: (NSOutlineView *)ov
         objectValueForTableColumn:(NSTableColumn*)col
			  byItem:(id)item { return nil; }

- (BOOL) outlineView: (NSOutlineView *)ov
          acceptDrop: (id )info
                item: (id)item
          childIndex: (int)aIndex
{
	BOOL doDefault = YES;
	BOOL success = [mySelectedBrowser playlistOutlineView:ov acceptDrop:info item:item childIndex:aIndex tryDefaultHandling:&doDefault];
	if (success || !doDefault)
		return success;

    NSArray *folders = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	NSArray* addedNodes = [self addCustomFolders:folders];
	if ([addedNodes count] > 0) 
	{
		iMBLibraryNode* node = [addedNodes objectAtIndex:0];
		NSIndexPath* indexPath = [NSIndexPath indexPathWithIndex:[[libraryController content] indexOfObject:node]];
		[libraryController setSelectionIndexPath:indexPath];
	}
	
	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)aIndex
{
	BOOL doDefault = YES;
	NSDragOperation dragOp = [mySelectedBrowser playlistOutlineView:outlineView validateDrop:info proposedItem:item proposedChildIndex:aIndex tryDefaultHandling:&doDefault];
	
	if ((dragOp != NSDragOperationNone) || !doDefault)
		return dragOp;
		
	if ([mySelectedBrowser parserForFolderDrop])
	{
		NSPasteboard *pboard = [info draggingPasteboard];
		if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
		{
			NSArray *folders = [pboard propertyListForType:NSFilenamesPboardType];
			if ([folders count] > 0)
			{
				NSString* path = [folders objectAtIndex:0];
				NSFileManager *fm = [NSFileManager defaultManager];
				
				BOOL isDir;
				if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir && [mySelectedBrowser allowPlaylistFolderDrop:path])
				{
					[outlineView setDropItem:nil dropChildIndex:NSOutlineViewDropOnItemIndex]; // Target the whole view
					return NSDragOperationCopy;
				}
			}
		}
	}
	return NSDragOperationNone;
}

- (void)outlineView:(NSOutlineView *)olv deleteItems:(NSArray *)items
{
	NSEnumerator *e = [items objectEnumerator];
	iMBLibraryNode *cur;
	
	NSMutableArray *content = [NSMutableArray arrayWithArray:[libraryController content]];
	NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]]];
	NSMutableArray *drops = [NSMutableArray arrayWithArray:[d objectForKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)mySelectedBrowser className]]]];
	
	BOOL foundSomethingToDelete = NO;
	while ((cur = [e nextObject]))
	{
		// we can only delete dragged folders
		NSEnumerator *g = [myUserDroppedParsers objectEnumerator];
		id parser;
		
		while ((parser = [g nextObject]))
		{
			if ([cur parser] == parser)
			{
				[drops removeObject:[parser databasePath]];
				[myUserDroppedParsers removeObject:parser];
				[content removeObject:cur];
				foundSomethingToDelete = YES;
				break;
			}
		}
	}
	if (!foundSomethingToDelete)
	{
		NSBeep ();
	}
	
	[libraryController setContent:content];
	[d setObject:drops forKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)mySelectedBrowser className]]];
	[[NSUserDefaults standardUserDefaults] setObject:d forKey:[NSString stringWithFormat:@"iMB-%@", myIdentifier]];
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
