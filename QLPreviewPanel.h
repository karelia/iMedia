/*! @header QLPreviewPanel.h
This class is private in 10.5 and public in 10.6, so is defined here
to seperate it from the QuickLook Controller class.
This header is not included by the umbrealla header for the framework,
for compatibility with BXServices users compiling against 10.6 headers.
If you want to avoid the warnings for undefined methods, you need to
include <BXServices/QLPreviewPanel.h> yourself.
*/


#define QLPreviewPanelClass NSClassFromString(@"QLPreviewPanel")


@interface NSPanel (QLPreviewPanel_Common)
// the only methods common to both leopard and snow leopard
+ (id)sharedPreviewPanel;
- (void)setDelegate:(id)delegate;
@end


#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1060

#import <Quartz/Quartz.h>

#else

@interface NSObject (QLPreviewPanelController)
- (BOOL)acceptsPreviewPanelControl:(id)panel;
- (void)beginPreviewPanelControl:(id)panel;
- (void)endPreviewPanelControl:(id)panel;
@end


@interface NSObject (QLPreviewPanelDataSource)
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id)panel;
- (id)previewPanel:(id)panel previewItemAtIndex:(NSInteger)index;
@end


@interface NSObject (QLPreviewPanelDelegate)
- (BOOL)previewPanel:(id)panel handleEvent:(NSEvent *)event;
- (NSRect)previewPanel:(id)panel sourceFrameOnScreenForPreviewItem:(id)item;
- (id)previewPanel:(id)panel transitionImageForPreviewItem:(id)item contentRect:(NSRect *)contentRect;
@end



@interface NSPanel (QLPreviewPanel_SnowLeopard)
// some of these are defined as properties, but are included here as methods
// so that the header can be harmlessly included when compiling against 10.4
+ (BOOL)sharedPreviewPanelExists;
- (id)currentController;
- (void)updateController;
- (id)dataSource;
- (void)setDataSource:(id)dataSource;
- (void)reloadData;
- (void)refreshCurrentPreviewItem;
- (NSInteger)currentPreviewItemIndex;
- (void)setCurrentPreviewItemIndex:(NSInteger)index;
- (id)currentPreviewItem;
- (id)displayState;
- (void)setDisplayState:(id)displayState;
- (id)delegate;
- (BOOL)enterFullScreenMode:(NSScreen *)screen withOptions:(NSDictionary *)options;
- (void)exitFullScreenModeWithOptions:(NSDictionary *)options;
- (BOOL)isInFullScreenMode;
@end

#endif

#if MAC_OS_X_VERSION_MIN_REQUIRED < 1060

@interface NSPanel (QLPreviewPanel_Leopard)
+ (id)_previewPanel;
+ (BOOL)isSharedPreviewPanelLoaded;
- (id)initWithContentRect:(NSRect)fp8 styleMask:(unsigned int)fp24 backing:(unsigned int)fp28 defer:(BOOL)fp32;
- (id)initWithCoder:(id)fp8;
- (void)dealloc;
- (BOOL)isOpaque;
- (BOOL)canBecomeKeyWindow;
- (BOOL)canBecomeMainWindow;
- (BOOL)shouldIgnorePanelFrameChanges;
- (BOOL)isOpen;
- (void)setFrame:(NSRect)fp8 display:(BOOL)fp24 animate:(BOOL)fp28;
- (id)_subEffectsForWindow:(id)fp8 itemFrame:(NSRect)fp12 transitionWindow:(id *)fp28;
- (id)_scaleEffectForItemFrame:(NSRect)fp8 transitionWindow:(id *)fp24;
- (void)_invertCurrentEffect;
- (NSRect)_currentItemFrame;
- (void)setAutosizesAndCenters:(BOOL)fp8;
- (BOOL)autosizesAndCenters;
- (void)makeKeyAndOrderFront:(id)fp8;
- (void)makeKeyAndOrderFrontWithEffect:(int)fp8;
- (void)makeKeyAndGoFullscreenWithEffect:(int)fp8;
- (void)makeKeyAndOrderFrontWithEffect:(int)fp8 canClose:(BOOL)fp12;
- (void)_makeKeyAndOrderFrontWithEffect:(int)fp8 canClose:(BOOL)fp12 willOpen:(BOOL)fp16 toFullscreen:(BOOL)fp20;
- (int)openingEffect;
- (void)closePanel;
- (void)close;
- (void)closeWithEffect:(int)fp8;
- (void)closeWithEffect:(int)fp8 canReopen:(BOOL)fp12;
- (void)_closeWithEffect:(int)fp8 canReopen:(BOOL)fp12;
- (void)windowEffectDidTerminate:(id)fp8;
- (void)_close:(id)fp8;
- (void)sendEvent:(id)fp8;
- (void)selectNextItem;
- (void)selectPreviousItem;
- (void)setURLs:(id)fp8 currentIndex:(unsigned int)fp12 preservingDisplayState:(BOOL)fp16;
- (void)setURLs:(id)fp8 preservingDisplayState:(BOOL)fp12;
- (void)setURLs:(id)fp8;
- (id)URLs;
- (unsigned int)indexOfCurrentURL;
- (void)setIndexOfCurrentURL:(unsigned int)fp8;
- (id)sharedPreviewView;
- (void)setSharedPreviewView:(id)fp8;
- (void)setCyclesSelection:(BOOL)fp8;
- (BOOL)cyclesSelection;
- (void)setShowsAddToiPhotoButton:(BOOL)fp8;
- (BOOL)showsAddToiPhotoButton;
- (void)setShowsiChatTheaterButton:(BOOL)fp8;
- (BOOL)showsiChatTheaterButton;
- (void)setShowsFullscreenButton:(BOOL)fp8;
- (BOOL)showsFullscreenButton;
- (void)setShowsIndexSheetButton:(BOOL)fp8;
- (BOOL)showsIndexSheetButton;
- (void)setAutostarts:(BOOL)fp8;
- (BOOL)autostarts;
- (void)setPlaysDuringPanelAnimation:(BOOL)fp8;
- (BOOL)playsDuringPanelAnimation;
- (void)setDeferredLoading:(BOOL)fp8;
- (BOOL)deferredLoading;
- (void)setEnableDragNDrop:(BOOL)fp8;
- (BOOL)enableDragNDrop;
- (void)start:(id)fp8;
- (void)stop:(id)fp8;
- (void)setShowsIndexSheet:(BOOL)fp8;
- (BOOL)showsIndexSheet;
- (void)setShareWithiChat:(BOOL)fp8;
- (BOOL)shareWithiChat;
- (void)setPlaysSlideShow:(BOOL)fp8;
- (BOOL)playsSlideShow;
- (void)setIsFullscreen:(BOOL)fp8;
- (BOOL)isFullscreen;
- (void)setMandatoryClient:(id)fp8;
- (id)mandatoryClient;
- (void)setForcedContentTypeUTI:(id)fp8;
- (id)forcedContentTypeUTI;
- (void)setDocumentURLs:(id)fp8;
- (void)setDocumentURLs:(id)fp8 preservingDisplayState:(BOOL)fp12;
- (void)setDocumentURLs:(id)fp8 itemFrame:(NSRect)fp12;
- (void)setURLs:(id)fp8 itemFrame:(NSRect)fp12;
- (void)setAutoSizeAndCenterOnScreen:(BOOL)fp8;
- (void)setShowsAddToiPhoto:(BOOL)fp8;
- (void)setShowsiChatTheater:(BOOL)fp8;
- (void)setShowsFullscreen:(BOOL)fp8;
@end

@interface NSObject (QLPreviewPanelDelegate_Leopard)
//		previewPanel:didChangeDisplayStateForDocumentURL:
//		previewPanel:didChangeDisplayStateForURL:
//		previewPanel:didLoadPreviewForDocumentURL:
//		previewPanel:didLoadPreviewForURL:
//		previewPanel:didShowPreviewForURL:
//		previewPanel:frameForDocumentURL:
//		previewPanel:frameForURL:
//		previewPanel:shouldHandleEvent:
//		previewPanel:shouldOpenURL:
//		previewPanel:syncDisplayState:forURL:
//		previewPanel:transitionImageForURL:frame:
//		previewPanel:willLoadPreviewForDocumentURL:
//		previewPanel:willLoadPreviewForURL:

- (NSRect)previewPanel:(NSPanel *)inPanel frameForURL:(NSURL *)inURL;
- (BOOL)previewPanel:(NSPanel *)panel shouldHandleEvent:(NSEvent *)event;
@end

#endif
