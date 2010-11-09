/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES
	
@class IMBObjectViewController;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// We have to declare a fake prototypes because the 10.6 runtime interrogates our compliance with the protocol,
// rather that interrogating the presence of the particular method we implement...

#if IMB_SHOULD_DECLARE_DUMMY_PROTOCOLS

@protocol NSTabViewDelegate <NSObject> 
@end

#endif


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBPanelController : NSWindowController <NSTabViewDelegate>
{
	IBOutlet NSTabView* ibTabView;
	IBOutlet NSToolbar* ibToolbar;		// should track the ibTabView
	id _delegate;
	NSArray* _mediaTypes;
	NSMutableArray* _viewControllers;
	NSMutableDictionary* _loadedLibraries;
	NSString* _oldMediaType;
}

+ (void) registerViewControllerClass:(Class)inViewControllerClass forMediaType:(NSString*)inMediaType;

+ (IMBPanelController*) sharedPanelController;
+ (IMBPanelController*) sharedPanelControllerWithDelegate:(id)inDelegate mediaTypes:(NSArray*)inMediaTypes;
+ (BOOL) isSharedPanelControllerLoaded;
+ (void) cleanupSharedPanelController;

@property (assign) id delegate;
@property (retain) NSArray* mediaTypes;
@property (retain) NSMutableArray* viewControllers;
@property (retain) NSMutableDictionary* loadedLibraries;
@property (retain) NSString* oldMediaType;

- (void) loadControllers;
- (IMBObjectViewController*) objectViewControllerForMediaType:(NSString*)inMediaType;
- (IBAction) showWindow:(id)inSender;
- (IBAction) hideWindow:(id)inSender;

- (void) saveStateToPreferences;
- (void) restoreStateFromPreferences;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBPanelDelegate

@optional

- (BOOL) controller:(IMBPanelController*)inController shouldShowPanelForMediaType:(NSString*)inMediaType;
- (void) controller:(IMBPanelController*)inController willShowPanelForMediaType:(NSString*)inMediaType;
- (void) controller:(IMBPanelController*)inController didShowPanelForMediaType:(NSString*)inMediaType;
- (void) controller:(IMBPanelController*)inController willHidePanelForMediaType:(NSString*)inMediaType;
- (void) controller:(IMBPanelController*)inController didHidePanelForMediaType:(NSString*)inMediaType;

@end


//----------------------------------------------------------------------------------------------------------------------


