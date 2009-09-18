/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <Quartz/Quartz.h>

/*!	@class IMBQuickLookController
	@abstract Use of IMBQuickLookController is required on Leopard, but optional on Snow Leopard.
	If you choose to use this class on Snow Leopard, you must implement these three methods in a class in your responder chain:
<pre>
- (BOOL)acceptsPreviewPanelControl:(id)panel
{
	return YES;
}

- (void)beginPreviewPanelControl:(id)panel
{
	[[IMBQuickLookController sharedController] beginPreviewPanelControl:panel];
}

- (void)endPreviewPanelControl:(id)panel
{
	[[IMBQuickLookController sharedController] endPreviewPanelControl:panel];
}
</pre>

	If you do this, IMBQuickLookController will act as a bridge between the Snow Leopard API that the OS expects and the API that works on Leopard.
	You then set the data source for the IMBQuickLookController, and implement those methods as you would on Leopard.
*/

@interface IMBQuickLookController : NSObject
#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1060
 <QLPreviewPanelDataSource,QLPreviewPanelDelegate>
#endif
{
	BOOL _available;
	id _dataSource;
	NSArray *_URLs;
}

+ (IMBQuickLookController *)sharedController;

- (void)beginPreviewPanelControl:(id)panel;
- (void)endPreviewPanelControl:(id)panel;

- (void)setDataSource:(id)inDataSource;

- (void)update:(id)inSender;
- (BOOL)isOpen;
- (void)toggle:(id)inSender;

- (BOOL)validateQuickLookMenuItem:(NSMenuItem *)inMenuItem;

- (BOOL)handleKeyDownEvent:(NSEvent *)inEvent;

@end

@protocol IMBQuickLookControllerDataSource

/*!	@method URLsForQuickLookController:
	@abstract Provide the URLs for the selected files to be previewed.
	Required. */
- (NSArray *)URLsForQuickLookController:(IMBQuickLookController *)inController;

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@optional
#endif

/*!	@method quickLookController:handleEvent:
	@abstract Give the data source an opportunity to do something about key presses.
	Optional. Return YES if you handle the event. */
- (BOOL)quickLookController:(IMBQuickLookController *)inController handleEvent:(NSEvent *)inEvent;

/*!	@method currentIndexForQuickLookController:
	@abstract Return the index into the URLs array for the currently selected item.
	Optional. If not implemented, a value of zero is used. */
- (unsigned int)currentIndexForQuickLookController:(IMBQuickLookController *)inController;

/*!	@method quickLookController:frameForURL:
	@abstract The origin frame for the zooming effect.
	Optional. Either this or quickLookController:frameForSelectedItemAtIndex: must be implemented. */
- (NSRect)quickLookController:(IMBQuickLookController *)inController frameForURL:(NSURL *)inURL;

/*!	@method quickLookController:frameForSelectedItemAtIndex:
	@abstract The origin frame for the zooming effect.
	Optional. Either this or quickLookController:frameForURL: must be implemented. */
- (NSRect)quickLookController:(IMBQuickLookController *)inController frameForSelectedItemAtIndex:(NSUInteger)inIndex;

/*!	@method quickLookControllerDidDisplay:
	@abstract Notification that the panel has been displayed.
	Optional. */
- (void)quickLookControllerDidDisplay:(IMBQuickLookController *)inController;

@end
