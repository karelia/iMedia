/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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

#import "iMBAbstractView.h"

#import "iMBLibraryNode.h"
#import "iMediaConfiguration.h"
#import "iMBParserController.h"
#import "iMediaBrowser.h"
#import "iMBAbstractParser.h"
#import "LibraryItemsValueTransformer.h"
#import "NSPopUpButton+iMedia.h"
#import "RBSplitView.h"
#import "RBSplitSubview.h"
#import "NSBundle+iMedia.h"

#import <QTKit/QTKit.h>


NSString *iMBNativePasteboardFlavor=@"iMBNativePasteboardFlavor";
NSString *iMBControllerClassName=@"iMBControllerClassName";
NSString *iMBNativeDataArray=@"iMBNativeDataArray";

@interface NSObject (iMediaHack)
- (id)observedObject;
@end

@implementation iMBAbstractView

+ (BOOL)initializeOnce
{
    static BOOL once = NO;
    if ( !once )
    {
        // Make sure we are running Tiger
        if (NSAppKitVersionNumber < 824)  /* NSAppKitVersionNumber10_4 */
        {
            NSLog(@"ERROR - Mac OS X 10.4, or greater, required for the iMediaBrowser");
            return NO;
        }
        
        [QTMovie initialize];
        id libraryItemsValueTransformer = [[[LibraryItemsValueTransformer alloc] init] autorelease];
        [NSValueTransformer setValueTransformer:libraryItemsValueTransformer forName:@"libraryItemsValueTransformer"];
        
        once = YES;
        
        return YES;
    }
    return YES;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {
        if (![iMBAbstractView initializeOnce])
        {
            [self release];
            return nil;
        }

        backgroundLoadingLock = [[NSLock alloc] init];
    }
    return self;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[libraryController removeObserver:self forKeyPath:@"arrangedObjects"];

    [splitView setDelegate:nil];

    [[libraryView enclosingScrollView] release];
    [libraryPopUpButton release];

    [backgroundLoadingLock release];

	[super dealloc];
}

- (void)loadViewNib
{
	[[NSBundle bundleForClass:[iMBAbstractView class]] loadNibNamed:@"Abstract" owner:self];
}

- (void)awakeFromNib
{
    [loadingTextField setStringValue:
        LocalizedStringInIMedia(@"Loading...", @"Text that shows that we are loading")];

    if ( splitView != nil )
    {
        [splitView setDelegate:self];
    }
    
    if ( mediaView != nil )
    {
        [mediaView setFrame:[self bounds]];
        [self addSubview:mediaView];
    }

    if ( browserView != nil )
    {
        [browserView setFrame:[browserContainer bounds]];
        [browserContainer addSubview:browserView];
    }

    [libraryView registerForDraggedTypes:[self fineTunePlaylistDragTypes:[NSArray arrayWithObject:NSFilenamesPboardType]]];

    // save these since they get swapped out    
    [[libraryView enclosingScrollView] retain];
    [libraryPopUpButton retain];

    [splitView setAutosaveName:[NSString stringWithFormat:@"iMBSplitView-%@", [[iMediaConfiguration sharedConfiguration] identifier]] recursively:YES];

    id delegate = [[iMediaConfiguration sharedConfiguration] delegate];
    
    if ([delegate respondsToSelector:@selector(horizontalSplitViewForMediaConfiguration:)])
    {
        if (![delegate horizontalSplitViewForMediaConfiguration:[iMediaConfiguration sharedConfiguration]])
        {
            [splitView setVertical:YES];
        }
    }

    [splitView restoreState:YES];
    [[splitView subviewAtPosition:0] setMinDimension:26.0 andMaxDimension:0.0];
    // Simulate a resize to possibly swap out outline view
    [self splitView:splitView changedFrameOfSubview:[splitView subviewAtPosition:0] from:NSZeroRect to:[[splitView subviewAtPosition:0] frame]];
    [splitView adjustSubviews];	// just to be safe.

    [libraryController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];
}

- (NSImage *)toolbarIcon
{
	return nil;
}

- (NSString *)name
{
	return nil;
}

- (NSString *)mediaType
{
	return nil;
}

- (void)willActivate
{
	if (!didLoadNib)
	{
		[self loadViewNib];
		didLoadNib = YES;
	}
	
    [splitView restoreState:YES];
    [splitView adjustSubviews];
    
    if (!didLoad)
    {
        if ([backgroundLoadingLock tryLock])
        {
            isLoading = YES;
        
            [splitView setHidden:YES];
            [loadingView setHidden:NO];
            [loadingProgressIndicator startAnimation:self];

            iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];

            [libraryController setAutomaticallyPreparesContent:YES];
            [libraryController bind:@"contentArray" toObject:parserController withKeyPath:@"libraryNodes" options:[NSDictionary dictionary]];

            [NSThread detachNewThreadSelector:@selector(backgroundLoadData) toTarget:self withObject:NULL];
        }
    }
}

- (void)didDeactivate
{
    [splitView saveState:YES];	
}

- (IBAction)reload:(id)sender
{
    if ([backgroundLoadingLock tryLock])
    {    
        isLoading = YES;

        [splitView setHidden:YES];
        [loadingView setHidden:NO];
        [loadingProgressIndicator startAnimation:self];

        [NSThread detachNewThreadSelector:@selector(backgroundReloadData) toTarget:self withObject:NULL];
    }
}

- (void)recursivelyAddItemsToMenu:(NSMenu *)menu withNode:(iMBLibraryNode *)node indentation:(int)indentation
{
	NSString *name = [node name];
	if (!name) name = @"";
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name
												  action:@selector(playlistPopupChanged:)
										   keyEquivalent:@""];
	NSImage *icon = [node icon];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(16,16)];
	[item setImage:icon];
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
		[libraryPopUpButton setMenu:[self playlistMenu]];
	else
		[libraryPopUpButton removeAllItems];
        
	[libraryPopUpButton setEnabled:[libraryPopUpButton numberOfItems] > 0];
}

- (void)restoreSelectedNode
{
	if ([[libraryController content] count] > 0)
	{
		// Try to select the desired node. Please note that this may fall back to parent nodes if the desired node
		// doesn't exist...
		
		NSDictionary *d = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];
		NSString *identifier = [d objectForKey:[NSString stringWithFormat:@"%@SelectionIdentifier", NSStringFromClass([self class])]];
		if (identifier)
		{
			iMBLibraryNode* node = [self libraryNodeWithIdentifier:identifier];
			[self revealLibraryNode:node];
			[self selectLibraryNode:node];

			// Since the fallback mechanism described above can change the identifier in the prefs, restore it again,
			// just i case the desired node appears in the future (due to threaded parsing)...
			
			NSString *key = [NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]];
			NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:key]];
			[d setObject:identifier forKey:[NSString stringWithFormat:@"%@SelectionIdentifier", NSStringFromClass([self class])]];
			[[NSUserDefaults standardUserDefaults] setObject:d forKey:key];
		}
	}
}

- (void)arrangedObjectsDidChange
{
	[self updatePlaylistPopup];
	[self restoreSelectedNode];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ((object == libraryController) && [keyPath isEqualToString:@"arrangedObjects"])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(arrangedObjectsDidChange) object:nil];
		[self performSelector:@selector(arrangedObjectsDidChange) withObject:nil afterDelay:0.2 inModes:[NSArray arrayWithObject:(NSString*)kCFRunLoopCommonModes]];
	}
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
	[self selectLibraryNode:selected];
}

- (IBAction)playlistSelected:(id)sender	// action from oPlaylists
{
	int row = [sender selectedRow];
	if (row < 0 || row == NSNotFound)
		return;
	
	id rowItem = [libraryView itemAtRow:row];
	if (rowItem == nil)
		return;
	
	id representedObject = [rowItem respondsToSelector:@selector(representedObject)] ? [rowItem representedObject] : [rowItem observedObject];
	if (representedObject == nil)
		return;
	
	[self selectLibraryNode:representedObject];
	
	id delegate = [[iMediaConfiguration sharedConfiguration] delegate];
	if ([delegate respondsToSelector:@selector(iMediaConfiguration:didSelectNode:)])
	{
		[delegate iMediaConfiguration:[iMediaConfiguration sharedConfiguration] didSelectNode:representedObject];
	}
}

- (void)outlineViewItemWillExpand:(NSNotification *)notification	// notification from oPlaylists
{
	NSOutlineView *theOutline = [notification object];
	id rowItem = [[notification userInfo] objectForKey:@"NSObject"];
	id representedObject = [rowItem respondsToSelector:@selector(representedObject)] ? [rowItem representedObject] : [rowItem observedObject];
    
    id delegate = [[iMediaConfiguration sharedConfiguration] delegate];

	if ([delegate respondsToSelector:@selector(iMediaConfiguration:willExpandOutline:row:node:)])
	{
		[delegate iMediaConfiguration:[iMediaConfiguration sharedConfiguration] willExpandOutline:theOutline row:rowItem node:representedObject];
	}
}

- (NSArray *)addCustomFolders:(NSArray *)folders
{
	NSMutableArray *results = [NSMutableArray array];

	if ([folders count])
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSEnumerator *folderEnumerator = [folders objectEnumerator];
		NSString *currentFolder;
		NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]]];
		NSMutableArray *customFolders = [NSMutableArray arrayWithArray:[d objectForKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)self className]]]];
		
		while ((currentFolder = [folderEnumerator nextObject]))
		{
            BOOL isDirectory;
			if (![customFolders containsObject:currentFolder] && [fm fileExistsAtPath:currentFolder isDirectory:&isDirectory] && isDirectory && [self allowPlaylistFolderDrop:currentFolder])
			{
                iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];
                
                [results addObjectsFromArray:[parserController addCustomFolderPath:currentFolder]];
				
				[customFolders addObject:currentFolder];
			}
		}
		
		[d setObject:customFolders forKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)self className]]];
		[[NSUserDefaults standardUserDefaults] setObject:d forKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];
	}

	return results;
}

- (void)backgroundLoadData
{	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];

    // Start parsing any custom folders that have been added
	NSDictionary *d = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];
	NSArray *customFolders = [d objectForKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)self className]]];
    
    // precalculate on the thread
    [parserController buildLibraryNodesWithCustomFolders:customFolders];

	[self performSelectorOnMainThread:@selector(controllerLoadedData:) withObject:self waitUntilDone:YES];
	
	[pool release];
}

- (void)backgroundReloadData
{	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];
    
    [parserController rebuildLibrary];
    
	[self performSelectorOnMainThread:@selector(controllerLoadedData:) withObject:self waitUntilDone:YES];
	
	[pool release];
}

- (void)controllerLoadedData:(id)sender
{
	[loadingView setHidden:YES];
	[splitView setHidden:NO];
	[loadingProgressIndicator stopAnimation:self];
	[backgroundLoadingLock unlock];

	[self restoreSelectedNode];
	
	isLoading = NO;
    didLoad = YES;
}

- (BOOL)hasCustomFolderParser
{
    return [[iMediaConfiguration sharedConfiguration] hasCustomFolderParserForMediaType:[self mediaType]];
}

- (NSArray*)fineTunePlaylistDragTypes:(NSArray *)defaultTypes
{
	return defaultTypes;
}

- (BOOL)allowPlaylistFolderDrop:(NSString*)path
{
	return ![[NSWorkspace sharedWorkspace] isFilePackageAtPath:path];
}

- (NSDragOperation)playlistOutlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)aIndex tryDefaultHandling:(BOOL*)tryDefault

{
	*tryDefault = YES;
	return NSDragOperationNone;
}

- (BOOL)playlistOutlineView:(NSOutlineView *)outlineView
				 acceptDrop:(id <NSDraggingInfo>)info
					   item:(id)item
				 childIndex:(int)aIndex
		 tryDefaultHandling:(BOOL*)tryDefault
{
	*tryDefault = YES;
	return NO;
}

- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard
{
	
}

- (NSTreeController *)controller
{
	return [[libraryController retain] autorelease];
}

- (BOOL)isLoading
{
    return isLoading;
}

- (void)refresh
{
    [libraryController rearrangeObjects];
}

- (void)postSelectionChangeNotification:(NSArray *)selectedObjects
{
	NSEvent *evt = [NSApp currentEvent];
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
		selectedObjects, @"Selection", 
		evt, @"Event",
		selectedObjects, @"records", // XXX legacy keys for backwards compatability
		evt, @"event", nil];	// XXX legacy key for backwards compatability
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserSelectionDidChangeNotification
														object:self
													  userInfo:info];
	
	if ([selectedObjects count] > 0) {
		NSDictionary *record = [selectedObjects objectAtIndex:0];
		NSString *path = [record valueForKey:@"ImagePath"];
		
		NSLog(@"%@", [iMediaBrowser enhancedRecordForPath:path ofMediaType:@"photos"]);
	}
}

- (NSArray *)rootNodes
{
	NSMutableArray *nodes = [NSMutableArray array];
	NSEnumerator *e = [[browserController content] object];
	id cur;
	
	while (cur = [e nextObject])
	{
		id representedObject = [cur respondsToSelector:@selector(representedObject)] ? [cur representedObject] : [cur observedObject];
		[nodes addObject:representedObject];
	}
	return nodes;
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

		[self writePlaylist:representedObject toPasteboard:pboard];
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
	BOOL success = [self playlistOutlineView:ov acceptDrop:info item:item childIndex:aIndex tryDefaultHandling:&doDefault];
	if (success || !doDefault)
		return success;

    NSArray *folders = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	NSArray* addedNodes = [self addCustomFolders:folders];
	if ([addedNodes count] > 0) 
	{
		iMBLibraryNode* node = [addedNodes objectAtIndex:0];
		[self selectLibraryNode:node];
	}
	
	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(int)aIndex
{
	BOOL doDefault = YES;
	NSDragOperation dragOp = [self playlistOutlineView:outlineView validateDrop:info proposedItem:item proposedChildIndex:aIndex tryDefaultHandling:&doDefault];
	
	if ((dragOp != NSDragOperationNone) || !doDefault)
		return dragOp;

    if ([[iMediaConfiguration sharedConfiguration] hasCustomFolderParserForMediaType:[self mediaType]])
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
				if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir && [self allowPlaylistFolderDrop:path])
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
	NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]]];
	NSMutableArray *customFolders = [NSMutableArray arrayWithArray:[d objectForKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)self className]]]];
	
    iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];

    // items should be an array of library nodes
    NSArray *customFoldersRemoved = [parserController removeLibraryNodes:items];
    
    [customFolders removeObjectsInArray:customFoldersRemoved];

    // beep if no folders were removed
	if ([customFoldersRemoved count] == 0)
	{
		NSBeep ();
	}
	
	[d setObject:customFolders forKey:[NSString stringWithFormat:@"%@Dropped", [(NSObject*)self className]]];
	[[NSUserDefaults standardUserDefaults] setObject:d forKey:[NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]]];
}

#pragma mark -
#pragma mark iMBLibraryOutlineView Delegate Methods

- (NSMenu *)outlineView:(NSOutlineView *)outlineView menuForEvent:(NSEvent *)theEvent
{
    NSPoint point = [outlineView convertPoint:[theEvent locationInWindow] fromView:NULL];

    int row = [outlineView rowAtPoint:point];

    id treeNode = [outlineView itemAtRow:row];
    
    iMBLibraryNode *libraryNode = ([treeNode respondsToSelector:@selector(representedObject)]) ?
		[treeNode representedObject] : [treeNode observedObject];

    NSMenu *menu = [[[NSMenu alloc] init] autorelease];

    NSMenuItem *addCustomFoldersMenuItem = [[[NSMenuItem alloc] initWithTitle:LocalizedStringInIMedia(@"Add Custom Folders...", @"Add custom folders contextual menu item")
                                                                       action:@selector(addCustomFoldersAction:) keyEquivalent:@""] autorelease];
    [addCustomFoldersMenuItem setTarget:self];
    [menu addItem:addCustomFoldersMenuItem];

    NSMenuItem *removeCustomFoldersMenuItem = [[[NSMenuItem alloc] initWithTitle:LocalizedStringInIMedia(@"Remove Custom Folder", @"Remove custom folder contextual menu item")
                                                                          action:@selector(removeCustomFolderAction:) keyEquivalent:@""] autorelease];
    [removeCustomFoldersMenuItem setRepresentedObject:libraryNode];
    [removeCustomFoldersMenuItem setTarget:self];
    [menu addItem:removeCustomFoldersMenuItem];
    
    return menu;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(addCustomFoldersAction:))
        return YES;
    
    if ([menuItem action] == @selector(removeCustomFolderAction:))
    {
        iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];
        iMBLibraryNode *libraryNode = [menuItem representedObject];
        if (libraryNode != NULL && [parserController canRemoveLibraryNode:libraryNode])
            return YES;
        return NO;
    }
    
    if ([menuItem action] == @selector(delete:))
    {
        iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];
        id rowItem = [libraryView itemAtRow:[libraryView selectedRow]];
        iMBLibraryNode *libraryNode = [rowItem respondsToSelector:@selector(representedObject)] ? [rowItem representedObject] : [rowItem observedObject];
        if (libraryNode != NULL && [parserController canRemoveLibraryNode:libraryNode])
            return YES;
        return NO;
    }

    return YES; // [super validateMenuItem:menuItem];	// there is no super!
}

- (void)addCustomFoldersAction:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    // That has got to be one of the most repetitive Cocoa lines of code ;-)
    
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanCreateDirectories:YES];
    [openPanel setPrompt:LocalizedStringInIMedia(@"Add", @"Add custom folders button")];
    [openPanel setCanChooseFiles:NO];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setResolvesAliases:YES];
    
    if ([openPanel runModalForDirectory:NULL file:NULL types:NULL] == NSOKButton)
    {
        NSArray *folders = [openPanel filenames];
        NSArray* addedNodes = [self addCustomFolders:folders];
        if ([addedNodes count] > 0) 
        {
            iMBLibraryNode* node = [addedNodes objectAtIndex:0];
			[self selectLibraryNode:node];
        }
    }
}

- (void)removeCustomFolderAction:(id)sender
{
    iMBLibraryNode *libraryNode = [sender representedObject];

    [self outlineView:libraryView deleteItems:[NSArray arrayWithObject:libraryNode]];
}

- (void)delete:(id)sender
{
    id rowItem = [libraryView itemAtRow:[libraryView selectedRow]];

    iMBLibraryNode *libraryNode = [rowItem respondsToSelector:@selector(representedObject)] ? [rowItem representedObject] : [rowItem observedObject];
    
    [self outlineView:libraryView deleteItems:[NSArray arrayWithObject:libraryNode]];
}

#pragma mark -
#pragma mark NSSplitView Delegate Methods

- (void)splitView:(RBSplitView*)sender changedFrameOfSubview:(RBSplitSubview*)subview from:(NSRect)fromRect to:(NSRect)toRect;
{
	if (subview == [splitView subviewAtPosition:0])
	{
		if (inSplitViewResize) return; // stop possible recursion from NSSplitView
		inSplitViewResize = YES;
		if (![splitView isVertical])
		{
			if(toRect.size.height <= 50 && ![[[splitView subviewAtPosition:0] subviews] containsObject:libraryPopUpButton])
			{
				// select the currently selected item in the playlist
				[libraryPopUpButton selectItemWithRepresentedObject:[[libraryController selectedObjects] lastObject]];
				[[splitView subviewAtPosition:0] replaceSubview:[libraryView enclosingScrollView] with:libraryPopUpButton];
				NSRect frame = [libraryPopUpButton frame];
				frame.origin.y = [[splitView subviewAtPosition:0] frame].size.height - frame.size.height;
				frame.origin.x = 0;
				frame.size.width = [[splitView subviewAtPosition:0] frame].size.width;
				[libraryPopUpButton setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
				[libraryPopUpButton setFrame:frame];
			}
			
			if(toRect.size.height > 50 && [[[splitView subviewAtPosition:0] subviews] containsObject:libraryPopUpButton])
			{
				NSScrollView *scrollView = [libraryView enclosingScrollView];
				NSRect frame = [scrollView frame];
				frame.size.height = [[splitView subviewAtPosition:0] frame].size.height;
				frame.size.width = [[splitView subviewAtPosition:0] frame].size.width;
				[scrollView setFrame:frame];
				[[splitView subviewAtPosition:0] replaceSubview:libraryPopUpButton with:scrollView];
			}
		}
		inSplitViewResize = NO;
	}
}

#pragma mark -
#pragma mark Selectig & Revealing


- (iMBLibraryNode*) libraryNodeWithIdentifier:(NSString*)inIdentifier
{
	if (inIdentifier)
	{
		iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];
		return [parserController libraryNodeWithIdentifier:inIdentifier];
	}
	
	return nil;
}


- (iMBLibraryNode*) selectedLibraryNode
{
	NSArray* selection = [libraryController selectedObjects];
	if ([selection count]) return [selection lastObject];
	return nil;
}


- (NSString*) selectedLibraryNodeIdentifier
{
	return [[self selectedLibraryNode] identifier];
}


- (void) selectLibraryNodeWithIdentifier:(NSString*)inIdentifier
{
	iMBLibraryNode* node = [self libraryNodeWithIdentifier:inIdentifier];
	[self selectLibraryNode:node];
}


- (void) selectLibraryNode:(iMBLibraryNode*)inLibraryNode
{
	if (inLibraryNode)
	{
		// Select the correct node in the NSOutlineView...
		
		iMBParserController *parserController = [[iMediaConfiguration sharedConfiguration] parserControllerForMediaType:[self mediaType]];
		NSIndexPath* indexPath = [inLibraryNode indexPathForRootArray:[parserController mutableLibraryNodes]];
		
		if (![indexPath isEqual:[libraryController selectionIndexPath]])
		{
			[libraryController setSelectionIndexPath:indexPath];
		}
		
		// Also select the same node in the popup...
		
		if ([[libraryPopUpButton selectedItem] representedObject] != inLibraryNode)
		{
			[libraryPopUpButton selectItemWithRepresentedObject:inLibraryNode];
		}
		
		// Store identifier in preferences...
		
		NSString *identifier = [inLibraryNode recursiveIdentifier];
		NSString *key = [NSString stringWithFormat:@"iMB-%@", [[iMediaConfiguration sharedConfiguration] identifier]];
		NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:key]];
		[d setObject:identifier forKey:[NSString stringWithFormat:@"%@SelectionIdentifier", NSStringFromClass([self class])]];
		[[NSUserDefaults standardUserDefaults] setObject:d forKey:key];
	}
}


- (void) revealLibraryNodeWithIdentifier:(NSString*)inIdentifier
{
	iMBLibraryNode* node = [self libraryNodeWithIdentifier:inIdentifier];
	[self revealLibraryNode:node];
}


- (iMBLibraryNode*) _nodeForProxy:(id)inProxy
{
	return (iMBLibraryNode*)([inProxy respondsToSelector:@selector(representedObject)] ? [inProxy representedObject] : [inProxy observedObject]);
}


- (BOOL) _subtree:(id)inProxy containsLibraryNode:(iMBLibraryNode*)inLibraryNode
{
	iMBLibraryNode* node = [self _nodeForProxy:inProxy];
	if (node == inLibraryNode) return YES;

	int level = [libraryView levelForItem:inProxy];
	int row = [libraryView rowForItem:inProxy];
	unsigned int i,n = [libraryView numberOfRows];
	
	for (i=row+1; i<n; i++)
	{
		id proxy = [libraryView itemAtRow:i];
		int lvl = [libraryView levelForItem:proxy];
		if (lvl<=level) break;
		
		iMBLibraryNode* node = [self _nodeForProxy:proxy];
		if (node == inLibraryNode) return YES;
	}
	
	return NO;
}


- (void) revealLibraryNode:(iMBLibraryNode*)inLibraryNode
{
	if (inLibraryNode)
	{
		// First expand everything, so that we have access to ALL nodes. Please note that we 
		// are doing this with reverse enumeration so that we do not mess up indexes...
		
		int i,n = [libraryView numberOfRows];
		id proxy;
		
		for (i=n-1; i>=0; i--)
		{
			if (proxy = [libraryView itemAtRow:i])
			{
				[libraryView expandItem:proxy expandChildren:YES];
			}	
		}

		// Then we can collapse every subtree that does not contain our node, so that we do not  
		// waste any display space in the outline view...
		
		for (i=0; i<[libraryView numberOfRows]; i++)
		{
			if (proxy = [libraryView itemAtRow:i])
			{
				iMBLibraryNode* node = [self _nodeForProxy:proxy];
				
				if (![self _subtree:proxy containsLibraryNode:inLibraryNode] || node==inLibraryNode)
				{
					[libraryView collapseItem:proxy collapseChildren:YES];
				}
			}
		}
	}
}

@end
