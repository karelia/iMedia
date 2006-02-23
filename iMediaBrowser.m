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
#import "LibraryItemsValueTransformer.h"

#import <QuickTime/QuickTime.h>
#import <QTKit/QTKit.h>

static iMediaBrowser *_sharedMediaBrowser = nil;
static NSMutableArray *_browserClasses = nil;

@interface iMediaBrowser (PrivateAPI)
- (void)resetLibraryController;
@end

@implementation iMediaBrowser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_browserClasses = [[NSMutableArray alloc] init];
	//register the default set in order
	[self registerBrowser:NSClassFromString(@"iMBPhotosController")];
	[self registerBrowser:NSClassFromString(@"iMBMusicController")];
	[self registerBrowser:NSClassFromString(@"iMBMoviesController")];
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

- (id)init
{
	if (self = [super initWithWindowNibName:@"MediaBrowser"]) {
		id libraryItemsValueTransformer = [[[LibraryItemsValueTransformer alloc] init] autorelease];
		[NSValueTransformer setValueTransformer:libraryItemsValueTransformer forName:@"libraryItemsValueTransformer"];
		myBackgroundLoadingLock = [[NSLock alloc] init];
	}
	return self;
}

- (void)awakeFromNib
{
	myMediaBrowsers = [[NSMutableArray arrayWithCapacity:[_browserClasses count]] retain];
	myToolbar = [[NSToolbar alloc] initWithIdentifier:@"iMediaBrowserToolbar"];
	
	[myToolbar setAllowsUserCustomization:NO];
	[myToolbar setShowsBaselineSeparator:YES];
	[myToolbar setSizeMode:NSToolbarSizeModeSmall];
	
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"mediaMenu"];
	NSMenuItem *item;
	NSEnumerator *e = [_browserClasses objectEnumerator];
	NSString *cur;
	
	while (cur = [e nextObject]) {
		Class aClass = NSClassFromString(cur);
		id <iMediaBrowser>browser = [[aClass alloc] initWithPlaylistController:libraryController];
		if (![browser conformsToProtocol:@protocol(iMediaBrowser)]) {
			NSLog(@"%@ must implement the iMediaBrowser protocol");
			continue;
		}
		[myMediaBrowsers addObject:browser];
		[browser release];
	}
	
	[myToolbar setDelegate:self];
	[[self window] setToolbar:myToolbar];
	
	//select the first browser
	if ([myMediaBrowsers count] > 0) {
		//see if the last selected browser is in user defaults
		NSString *lastSelectedBrowser = [[NSUserDefaults standardUserDefaults] objectForKey:@"iMediaBrowserSelectedBrowser"];
		if (lastSelectedBrowser)
		{
			[myToolbar setSelectedItemIdentifier:lastSelectedBrowser];
			[self showMediaBrowser:lastSelectedBrowser];
		}
		else
		{
			[myToolbar setSelectedItemIdentifier:[myMediaBrowsers objectAtIndex:0]];
			[self showMediaBrowser:[myMediaBrowsers objectAtIndex:0]];
		}
	}
	
	NSString *position = [[NSUserDefaults standardUserDefaults] objectForKey:@"iMediaBrowserWindowPosition"];
	if (position) {
		NSRect r = NSRectFromString(position);
		[[self window] setFrame:r display:NO];
	}
	[[self window] setDelegate:self];
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
	if ([myBackgroundLoadingLock tryLock])
	{
		[oSplitView setHidden:YES];
		[oLoadingView setHidden:NO];
		[oLoading startAnimation:self];
		id <iMediaBrowser>browser = [self browserForClassName:browserClassName];
		NSView *view = [browser browserView];
		//remove old view
		[selectedBrowser didDeactivate];
		[[selectedBrowser browserView] removeFromSuperview];
		[view setFrame:[oBrowserView bounds]];
		[oBrowserView addSubview:[view retain]];
		selectedBrowser = browser;
		//save the selected browse
		[[NSUserDefaults standardUserDefaults] setObject:NSStringFromClass([selectedBrowser class]) forKey:@"iMediaBrowserSelectedBrowser"];
		[NSThread detachNewThreadSelector:@selector(backgroundLoadData:) toTarget:self withObject:nil];
	}
	[myToolbar setSelectedItemIdentifier:NSStringFromClass([selectedBrowser class])];
}

- (void)toolbarItemChanged:(id)sender
{
	[self showMediaBrowser:[sender itemIdentifier]];
}

- (void)backgroundLoadData:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self resetLibraryController];
	[libraryController setContent:[selectedBrowser loadDatabase]];
	[self performSelectorOnMainThread:@selector(controllerLoadedData:) withObject:self waitUntilDone:NO];
	
	[pool release];
}

- (void)controllerLoadedData:(id)sender
{
	[oLoadingView setHidden:YES];
	[oSplitView setHidden:NO];
	[oLoading stopAnimation:self];
	[myBackgroundLoadingLock unlock];
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
			[item setImage:[cur menuIcon]];
			[item setTarget:self];
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

@end
