#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

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

@interface IMBQuickLookController : NSResponder
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

/*!	@method URLsForIMBQuickLookController:
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
