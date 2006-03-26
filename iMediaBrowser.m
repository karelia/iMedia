/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 In the case of iMediaBrowse, in addition to the terms noted above, in any 
 application that uses iMediaBrowse, we ask that you give a small attribution to 
 the members of CocoaDev.com who had a part in developing the project. Including, 
 but not limited to, Jason Terhorst, Greg Hulands and Ben Dunton.
 
 Greg doesn't really want acknowledgement he just want bug fixes as he has rewritten
 practically everything but the xml parsing stuff. Please send fixes to 
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 */

#import "iMediaBrowser.h"
#import "iMediaBrowserProtocol.h"
#import "iMBLibraryNode.h"
#import "LibraryItemsValueTransformer.h"

#import <QuickTime/QuickTime.h>
#import <QTKit/QTKit.h>

NSString *iMediaBrowserSelectionDidChangeNotification = @"iMediaBrowserSelectionDidChangeNotification";

static iMediaBrowser *_sharedMediaBrowser = nil;
static NSMutableArray *_browserClasses = nil;
static NSMutableDictionary *_parsers = nil;

@interface iMediaBrowser (PrivateAPI)
- (void)resetLibraryController;
- (void)showMediaBrowser:(NSString *)browserClassName;
@end

@interface iMediaBrowser (Plugins)
+ (NSArray *)findBundlesWithExtension:(NSString *)ext inFolderName:(NSString *)folder;
@end

@interface NSObject (iMediaHack)
- (id)observedObject;
@end

@implementation iMediaBrowser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_browserClasses = [[NSMutableArray alloc] init];
	_parsers = [[NSMutableDictionary dictionary] retain];
	
	//register the default set in order
	[self registerBrowser:NSClassFromString(@"iMBPhotosController")];
	[self registerBrowser:NSClassFromString(@"iMBMusicController")];
	[self registerBrowser:NSClassFromString(@"iMBMoviesController")];
	[self registerBrowser:NSClassFromString(@"iMBLinksController")];
	
	//find and load all plugins
	NSArray *plugins = [iMediaBrowser findBundlesWithExtension:@"iMediaBrowser" inFolderName:@"iMediaBrowser"];
	NSEnumerator *e = [plugins objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject])
	{
		NSBundle *b = [NSBundle bundleWithPath:cur];
		Class mainClass = [b principalClass];
		if ([mainClass conformsToProtocol:@protocol(iMediaBrowser)])
		{
			if (![b load])
			{
				NSLog(@"Failed to load iMediaBrowser plugin: %@", cur);
				continue;
			}
			[self registerBrowser:mainClass];
		}
	}
	
	[pool release];
}

+ (id)sharedBrowser
{
	if (!_sharedMediaBrowser)
		_sharedMediaBrowser = [[iMediaBrowser alloc] init];
	return _sharedMediaBrowser;
}

+ (id)sharedBrowserWithoutLoading
{
	return _sharedMediaBrowser;
}

+ (void)registerBrowser:(Class)aClass
{
	[_browserClasses addObject:NSStringFromClass(aClass)];
}

+ (void)unregisterBrowser:(Class)aClass
{
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

+ (void)registerParser:(Class)aClass forMediaType:(NSString *)media
{
	NSMutableArray *parsers = [_parsers objectForKey:media];
	if (!parsers)
	{
		parsers = [NSMutableArray array];
		[_parsers setObject:parsers forKey:media];
	}
	[parsers addObject:NSStringFromClass(aClass)];
}

+ (void)unregisterParser:(Class)aClass forMediaType:(NSString *)media
{
	NSEnumerator *e = [[_parsers objectForKey:media] objectEnumerator];
	NSString *cur;
	while (cur = [e nextObject]) {
		Class bClass = NSClassFromString(cur);
		if (aClass == bClass) {
			[[_parsers objectForKey:media] removeObject:cur];
			return;
		}
	}
}

- (id)init
{
	if (self = [super initWithWindowNibName:@"MediaBrowser"]) {
		id libraryItemsValueTransformer = [[[LibraryItemsValueTransformer alloc] init] autorelease];
		[NSValueTransformer setValueTransformer:libraryItemsValueTransformer forName:@"libraryItemsValueTransformer"];
		myBackgroundLoadingLock = [[NSLock alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[myMediaBrowsers release];
	[myLoadedParsers release];
	[myToolbar release];
	[myBackgroundLoadingLock release];
	[super dealloc];
}

- (void)awakeFromNib
{
	myMediaBrowsers = [[NSMutableArray arrayWithCapacity:[_browserClasses count]] retain];
	myLoadedParsers = [[NSMutableDictionary alloc] init];
	
	myToolbar = [[NSToolbar alloc] initWithIdentifier:@"iMediaBrowserToolbar"];
	
	[myToolbar setAllowsUserCustomization:NO];
	[myToolbar setShowsBaselineSeparator:YES];
	[myToolbar setSizeMode:NSToolbarSizeModeSmall];
	
	NSEnumerator *e = [_browserClasses objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		if (myFlags.willLoadBrowser)
		{
			if (![myDelegate iMediaBrowser:self willLoadBrowser:cur])
			{
				continue;
			}
		}
		Class aClass = NSClassFromString(cur);
		id <iMediaBrowser>browser = [[aClass alloc] initWithPlaylistController:libraryController];
		if (![browser conformsToProtocol:@protocol(iMediaBrowser)]) {
			NSLog(@"%@ must implement the iMediaBrowser protocol");
			continue;
		}
		[myMediaBrowsers addObject:browser];
		[browser release];
		if (myFlags.didLoadBrowser)
		{
			[myDelegate iMediaBrowser:self didLoadBrowser:cur];
		}
	}
	
	[myToolbar setDelegate:self];
	[[self window] setToolbar:myToolbar];
	
	//select the first browser
	if ([myMediaBrowsers count] > 0) {
		//see if the last selected browser is in user defaults
		NSString *lastmySelectedBrowser = [[NSUserDefaults standardUserDefaults] objectForKey:@"iMediaBrowsermySelectedBrowser"];
		if (lastmySelectedBrowser)
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
	
	NSString *position = [[NSUserDefaults standardUserDefaults] objectForKey:@"iMediaBrowserWindowPosition"];
	if (position) {
		NSRect r = NSRectFromString(position);
		[[self window] setFrame:r display:NO];
	}
	[[self window] setDelegate:self];
	[oPlaylists setDataSource:self];
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

- (void)showMediaBrowser:(NSString *)browserClassName
{
	if (![NSStringFromClass([mySelectedBrowser class]) isEqualToString:browserClassName])
	{
		if ([myBackgroundLoadingLock tryLock])
		{
			[oSplitView setHidden:YES];
			[oLoadingView setHidden:NO];
			[oLoading startAnimation:self];
			id <iMediaBrowser>browser = [self browserForClassName:browserClassName];
			NSView *view = [browser browserView];
			//remove old view
			[mySelectedBrowser didDeactivate];
			[[mySelectedBrowser browserView] removeFromSuperview];
			[view setFrame:[oBrowserView bounds]];
			[oBrowserView addSubview:[view retain]];
			mySelectedBrowser = browser;
			//save the selected browse
			[[NSUserDefaults standardUserDefaults] setObject:NSStringFromClass([mySelectedBrowser class]) forKey:@"iMediaBrowsermySelectedBrowser"];
			[NSThread detachNewThreadSelector:@selector(backgroundLoadData:) toTarget:self withObject:nil];
		}
		[myToolbar setSelectedItemIdentifier:NSStringFromClass([mySelectedBrowser class])];
	}
}

- (void)toolbarItemChanged:(id)sender
{
	[self showMediaBrowser:[sender itemIdentifier]];
}

- (void)backgroundLoadData:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
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
		if (myFlags.willLoadBrowser)
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
			[myLoadedParsers setObject:parser forKey:cur];
			[parser release];
		}
		
		iMBLibraryNode *library = [parser library];
		if (library) // it is possible for a parser to return nil if the db for it doesn't exist
		{
			[root addObject:library];
		}
		
		if (myFlags.didUseParser)
		{
			[myDelegate iMediaBrowser:self didUseMediaParser:cur forMediaType:[mySelectedBrowser mediaType]];
		}
	}
	[libraryController setContent:root];
	[self performSelectorOnMainThread:@selector(controllerLoadedData:) withObject:self waitUntilDone:NO];
	
	[pool release];
}

- (void)controllerLoadedData:(id)sender
{
	[oLoadingView setHidden:YES];
	[oSplitView setHidden:NO];
	[oLoading stopAnimation:self];
	[myBackgroundLoadingLock unlock];
	if ([[libraryController content] count] > 0)
	{
		[oPlaylists expandItem:[oPlaylists itemAtRow:0]];
	}
}

#pragma mark -
#pragma mark Delegate

- (void)setDelegate:(id)delegate
{
	myFlags.willLoadBrowser = [myDelegate respondsToSelector:@selector(iMediaBrowser:willLoadBrowser:)];
	myFlags.didLoadBrowser = [myDelegate respondsToSelector:@selector(iMediaBrowser:didLoadBrowser:)];
	myFlags.willUseParser = [myDelegate respondsToSelector:@selector(iMediaBrowser:willUseMediaParser:forMediaType:)];
	myFlags.didUseParser = [myDelegate respondsToSelector:@selector(iMediaBrowser:didUseMediaParser:forMediaType:)];
	myFlags.willChangeBrowser = [myDelegate respondsToSelector:@selector(iMediaBrowser:willChangeBrowser:)];
	myFlags.didChangeBrowser = [myDelegate respondsToSelector:@selector(iMediaBrowser:didChangeBrowser:)];
	
	myDelegate = delegate;
}

- (id)delegate
{
	return myDelegate;
}

#pragma mark -
#pragma mark Window Delegate Methods

- (void)windowDidMove:(NSNotification *)aNotification
{
	NSString *pos = NSStringFromRect([[self window] frame]);
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
	[ud setObject:pos forKey:@"iMediaBrowserWindowPosition"];
	[ud synchronize];
}

- (void)resetLibraryController
{
	int controllerCount = [[libraryController arrangedObjects] count];
	for(controllerCount; controllerCount != 0;--controllerCount)
	{
		[libraryController removeObjectAtArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:controllerCount-1]];
	}
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
			[item setImage:[cur toolbarIcon]];
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
	
	while (cur = [e nextObject])
	{
		[mySelectedBrowser writePlaylist:[cur observedObject] toPasteboard:pboard];
	}
	return YES;
}

- (BOOL) outlineView: (NSOutlineView *)ov
	isItemExpandable: (id)item { return NO; }

- (int)  outlineView: (NSOutlineView *)ov
         numberOfChildrenOfItem:(id)item { return 0; }

- (id)   outlineView: (NSOutlineView *)ov
			   child:(int)index
			  ofItem:(id)item { return nil; }

- (id)   outlineView: (NSOutlineView *)ov
         objectValueForTableColumn:(NSTableColumn*)col
			  byItem:(id)item { return nil; }


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
	
    // look for bundles in the following places:
	
    //application wrapper
    [bundles addObjectsFromArray:[iMediaBrowser findModulesInDirectory:[[NSBundle mainBundle] resourcePath]
														 withExtension:ext]];
	
    // ~/Library/
    [bundles addObjectsFromArray:[iMediaBrowser findModulesInDirectory:[NSString stringWithFormat:@"%@/Library/%@", NSHomeDirectory(), folder]
														 withExtension:ext]];
	
    // /Local/Library/
    [bundles addObjectsFromArray:[iMediaBrowser findModulesInDirectory:[NSString stringWithFormat:@"/Library/%@", folder]
														 withExtension:ext]];
	
    // /System/Library/
    [bundles addObjectsFromArray:[iMediaBrowser findModulesInDirectory:[NSString stringWithFormat:@"/System/Library/%@", folder]
														 withExtension:ext]];
	
    // /Network/Library/
    [bundles addObjectsFromArray:[iMediaBrowser findModulesInDirectory:[NSString stringWithFormat:@"/Network/Library/%@", folder]
														 withExtension:ext]];
	return bundles;
}

@end
