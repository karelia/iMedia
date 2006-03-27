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

Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 */

#include <Cocoa/Cocoa.h>

@class iMBLibraryNode;

@protocol iMediaBrowser <NSObject>

// designated initializer
- (id)initWithPlaylistController:(NSTreeController *)ctrl;

// used for the parser register to load the correct parsers
- (NSString *)mediaType;

// icon for the panel's NSToolbar
- (NSImage *)toolbarIcon;

// localized name for the browser
- (NSString *)name;

// the custom view below the outline view
- (NSView *)browserView;

// Give the browser an opportunity to do some setup before display
- (void)willActivate;

// if you preview media, etc and need to get notified to stop playing
- (void)didDeactivate;

// Drag and Drop support for the playlist/album
- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard;

// parsers can notify the browser to refresh if the underlying database changes
- (void)refresh;

@end

@class iMBLibraryNode;

@protocol iMBParser <NSObject>

- (id)init;
- (iMBLibraryNode *)library;
- (void)setBrowser:(id <iMediaBrowser>)browser;

@end

