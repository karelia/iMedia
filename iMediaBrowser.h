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


#import <Cocoa/Cocoa.h>

@protocol iMediaBrowser;
@class iMBLibraryNode, RBSplitView, iMBBackgroundImageView;

@interface iMediaBrowser : NSWindowController
{
	IBOutlet NSPopUpButton			*oPlaylistPopup;
	IBOutlet NSView					*oBrowserView;
	IBOutlet NSBox					*oLoadingView;
	IBOutlet RBSplitView			*oSplitView;
	IBOutlet NSView					*oPlaylistContainer;
	IBOutlet NSProgressIndicator	*oLoading;
	IBOutlet NSTextField			*oLoadingText;
	IBOutlet NSOutlineView			*oPlaylists;
	IBOutlet NSTreeController		*libraryController;

	IBOutlet NSWindow				*oInfoWindow;
	IBOutlet NSTextView				*oInfoTextView;
	IBOutlet iMBBackgroundImageView *oBackgroundImageView;
	
	@private
	NSMutableArray					*myMediaBrowsers;
	NSMutableDictionary				*myLoadedParsers;
	NSMutableArray					*myUserDroppedParsers;
	id <iMediaBrowser>				mySelectedBrowser;		// not retained
	NSToolbar						*myToolbar;
	NSLock							*myBackgroundLoadingLock;
	NSString						*myIdentifier;
	
	NSArray							*myExcludedFolders;
   
	NSArray							*myPreferredBrowserTypes;
	id								myDelegate; //not retained
	struct ___imbFlags {
		unsigned willLoadBrowser: 1;
		unsigned didLoadBrowser: 1;
		unsigned willChangeBrowser: 1;
		unsigned didChangeBrowser: 1;
		unsigned willUseParser: 1;
		unsigned didUseParser: 1;
		unsigned inSplitViewResize: 1;
		unsigned didSelectNode: 1;
		unsigned orientation: 1;
		unsigned isLoading: 1;
		unsigned willExpand: 1;
		unsigned showFilenames: 1;
		
		unsigned unused: 20;	// 32 minus the number above
	} myFlags;
   
}

+ (id)sharedBrowser;
+ (id)sharedBrowserWithoutLoading;
+ (id)sharedBrowserWithDelegate:(id)delegate;
+ (id)sharedBrowserWithDelegate:(id)delegate supportingBrowserTypes:(NSArray*)types;

// Register Other types of Browsers
+ (void)registerBrowser:(Class)aClass;
+ (void)unregisterBrowser:(Class)aClass;
+ (void)unregisterAllBrowsers;

- (id) initWithoutWindow;

/* Register different types of media parsers
 
	Default media keys are: photos, music, videos, links
*/
+ (void)registerParser:(Class)aClass forMediaType:(NSString *)media;
+ (void)unregisterParserName:(NSString*)parserClassName forMediaType:(NSString *)media;

- (void)setIdentifier:(NSString *)identifier;
- (NSString *)identifier;

- (void)setDelegate:(id)delegate;
- (id)delegate;

- (void)setPreferredBrowserTypes:(NSArray *)types;

- (id<iMediaBrowser>)selectedBrowser;

- (NSArray *)searchSelectedBrowserNodeAttribute:(NSString *)nodeKey forKey:(NSString *)key matching:(NSString *)value;

// access the playlist menu
- (NSMenu *)playlistMenu;

- (BOOL)isLoading;

// Performs the same action as dragging and dropping folders onto the playlist view
// Returns the library nodes that were added.
- (NSArray*)addCustomFolders:(NSArray*)folderPaths;

// reloads the current selected browser
- (IBAction)reloadMediaBrowser:(id)sender;

// loads the specified browser
- (void)showMediaBrowser:(NSString *)browserClassName;

- (void)setShowsFilenamesInPhotoBasedBrowsers:(BOOL)flag;	// API to set initial value
- (BOOL)prefersFilenamesInPhotoBasedBrowsers;				// binding for user defaults
- (void)setPrefersFilenamesInPhotoBasedBrowsers:(BOOL)flag;	// binding for user defaults

- (IBAction)playlistSelected:(id)sender;
- (IBAction) info:(id)sender;
- (IBAction) flipBack:(id)sender;

- (BOOL)infoWindowIsVisible;

// Setting & Getting the excluded folder list
- (NSArray *)excludedFolders;
- (void)setExcludedFolders:(NSArray *)value;

- (int) toolbarDisplayMode;
- (void) setToolbarDisplayMode:(int)aMode;
- (BOOL)toolbarIsSmall;
- (void) setToolbarIsSmall:(BOOL)aFlag;

@end

// This notification is for each specific media browser to post when their selection changes.
// this is not a playlist/album change notification
// the userInfo dictionary contains the selection with key Selection
extern NSString *iMediaBrowserSelectionDidChangeNotification;

@interface NSObject (iMediaBrowserDelegate)

// NB: These methods will be called on the main thread
// the delegate can stop the browser from loading a certain media type
- (BOOL)iMediaBrowser:(iMediaBrowser *)browser willLoadBrowser:(NSString *)browserClassname;
- (void)iMediaBrowser:(iMediaBrowser *)browser didLoadBrowser:(NSString *)browserClassname;

- (void)iMediaBrowser:(iMediaBrowser *)browser doubleClickedSelectedObjects:(NSArray*)selection;

// Contextual menu support
- (NSMenu*)iMediaBrowser:(iMediaBrowser *)browser menuForSelectedObjects:(NSArray*)selection;

// NB: These delegate methods will most likely not be called on the main thread so you will have to make sure you code can handle this.
// loading different parsers for media types
- (BOOL)iMediaBrowser:(iMediaBrowser *)browser
   willUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media;
- (void)iMediaBrowser:(iMediaBrowser *)browser
    didUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media;

// NB: These methods will be called on the main thread
// get called back if the media browser changes
- (void)iMediaBrowser:(iMediaBrowser *)browser willChangeToBrowser:(NSString *)browserClassname;
- (void)iMediaBrowser:(iMediaBrowser *)browser didChangeToBrowser:(NSString *)browserClassname;

- (void)iMediaBrowser:(iMediaBrowser *)browser didSelectNode:(iMBLibraryNode *)node;
- (void)iMediaBrowser:(iMediaBrowser *)browser willExpandOutline:(NSOutlineView *)outline row:(id)row node:(iMBLibraryNode *)node;

- (BOOL)horizontalSplitViewForMediaBrowser:(iMediaBrowser *)browser;

@end
