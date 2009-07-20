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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

//#import "IMBCommon.h"
//#import "IMBNodeTreeController.h"
//#import "IMBObjectArrayController.h"
//#import "IMBOutlineView.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBLibraryController;
@class IMBNodeTreeController;
@class IMBObjectArrayController;
@class IMBOutlineView;
@class IKImageBrowserView;
@class IMBNode;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


// This controller is instantiated per mediaType and per window. Consider an example: If we have a document based 
// app that uses the photos, music, and video types, we have three IMBLibraryControllers (one for each media type).
// If we have 3 documents open (and each document has its own user interface for iMedia), we need a total of 3x3=9
// instances of IMBUserInterfaceController...


@interface IMBUserInterfaceController : NSObject
{
	IMBLibraryController* _libraryController;
	
	IBOutlet NSSplitView* ibSplitView;
	
	IBOutlet IMBNodeTreeController* ibNodeTreeController;
	IBOutlet IMBOutlineView* ibNodeOutlineView;
	IBOutlet NSPopUpButton* ibNodePopupButton;
	NSString* _selectedNodeIdentifier;
	NSMutableArray* _expandedNodeIdentifiers;
	
	IBOutlet IMBObjectArrayController* ibObjectArrayController;
	IBOutlet NSTabView* ibObjectTabView;
	IBOutlet NSTableView* ibObjectTableView;
	IBOutlet IKImageBrowserView* ibObjectImageBrowserView;
	NSInteger _objectViewType;
	double _objectIconSize;
	
//	IBOutlet NSSlider* ibSizeSlider;
//	IBOutlet NSSearchField* ibSearchField;
	
}

// Library...

@property (retain) IMBLibraryController* libraryController;
@property (readonly) NSString* mediaType;

// Nodes (sourcelist)...

@property (readonly) IMBNodeTreeController* nodeTreeController;
@property (readonly) IMBOutlineView* nodeOutlineView;
@property (readonly) NSPopUpButton* nodePopupButton;

- (IBAction) selectNodeFromPopup:(id)inSender;

@property (retain) NSString* selectedNodeIdentifier;
@property (retain) NSMutableArray* expandedNodeIdentifiers;

- (void) selectNodeWithIdentifier:(NSString*)inIdentifier;
- (void) selectNode:(IMBNode*)inNode;
- (IMBNode*) selectedNode;


- (BOOL) canReload;
- (IBAction) reload:(id)inSender;

- (BOOL) canAddNode;
- (IBAction) addNode:(id)inSender;

- (BOOL) canRemoveNode;
- (IBAction) removeNode:(id)inSender;

// Objects (media files)...

@property (readonly) IMBObjectArrayController* objectArrayController;
@property (readonly) NSTabView* objectTabView;
@property (readonly) NSTableView* objectTableView;
@property (readonly) IKImageBrowserView* objectImageBrowserView;
@property (readonly) NSString* objectCountString;
@property (assign) NSInteger objectViewType;
@property (assign) double objectIconSize;

@end


//----------------------------------------------------------------------------------------------------------------------

