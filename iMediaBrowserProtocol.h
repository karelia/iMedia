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


#include <Cocoa/Cocoa.h>

@class iMBLibraryNode, iMediaBrowser;

@protocol iMediaBrowser <NSObject>

// designated initializer
- (id)initWithPlaylistController:(NSTreeController *)ctrl;
- (void)setBrowser:(iMediaBrowser *)browser;

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

// Access the root nodes
- (NSArray *)rootNodes;

- (Class)parserForFolderDrop; //must respond to initWithContentsOfFile:

// Allows you to specify what you can support being dragged to the playlist outline view.
// defaultTypes contains any types that lower level objects support
- (NSArray*)fineTunePlaylistDragTypes:(NSArray *)defaultTypes;

// Allows you to override drags to the play list. (e.g to allow drops on library nodes themselves).
// The tryDefault parameter is used to let the calling code know whether it should try its own handling
// if you return NSDragOperationNone. If you return any other value, then tryDefault is ignored and the caller will
// not try its own handling.
- (NSDragOperation)playlistOutlineView:(NSOutlineView *)outlineView
						  validateDrop:(id <NSDraggingInfo>)info
						  proposedItem:(id)item
					proposedChildIndex:(int)aIndex
					tryDefaultHandling:(BOOL*)tryDefault;

// Use this to do your own handling of drags to the playlist. If you want to let the default handling be tried,
// return NO and set tryDefault to YES. If you return YES, then tryDefault is ignored and no default handling is performed.
- (BOOL)playlistOutlineView:(NSOutlineView *)outlineView
				 acceptDrop:(id <NSDraggingInfo>)info
					   item:(id)item
				 childIndex:(int)aIndex
		 tryDefaultHandling:(BOOL*)tryDefault;
		 
// There is a #ifed out version of a simple implementation of the above dragging messages in iMBPhotosController.m.
// Look for SAMPLE_INCOMING_DRAG 

// If you want to limit the type of folders that can be dragged to the playlist by the default folder dropping code
// override this. iMBAbstractController implements this to prevent packages being dropped. 
- (BOOL)allowPlaylistFolderDrop:(NSString*)path;


@end

@class iMBLibraryNode;

@protocol iMBParser <NSObject>

- (NSArray *)librariesReusingCache:(BOOL)reuseCachedData;	// return NSArray of iMBLibraryNode
- (void)setBrowser:(id <iMediaBrowser>)browser;

@end

