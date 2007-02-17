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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>  

*/

#import <Cocoa/Cocoa.h>

@protocol iMediaBrowser;
@class iMBLibraryNode, RBSplitView;

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
	
	@private
	NSMutableArray					*myMediaBrowsers;
	NSMutableDictionary				*myLoadedParsers;
	NSMutableArray					*myUserDroppedParsers;
	id <iMediaBrowser>				mySelectedBrowser;		// not retained
	NSToolbar						*myToolbar;
	NSLock							*myBackgroundLoadingLock;
	NSString						*myIdentifier;
	
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
+ (NSURLCache *)sharedURLCache;	// use this instead of [NSURLCache sharedURLCache] to store cache across applications

// Register Other types of Browsers
+ (void)registerBrowser:(Class)aClass;
+ (void)unregisterBrowser:(Class)aClass;

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

- (void)setShowsFilenamesInPhotoBasedBrowsers:(BOOL)flag;
- (BOOL)showsFilenamesInPhotoBasedBrowsers;

- (IBAction)playlistSelected:(id)sender;

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
