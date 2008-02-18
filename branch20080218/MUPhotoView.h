//
//
//  MUPhotoView
//
// Copyright (c) 2006 Blake Seely
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//  * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//    LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
//    OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//  * You include a link to http://www.blakeseely.com in your final product.
//
// Version History:
//
// Version 1.0 - April 17, 2006 - Initial Release
// Version 1.1 - April 29, 2006 - Photo removal support, Added support for reduced-size drawing during live resize
// Version 1.2 - September 24, 2006 - Updated selection behavior, Changed to MIT license, Fixed issue where no images would show, fixed autoscroll

// Modified for the iMedia project http://imedia.karelia.com/

#import <Cocoa/Cocoa.h>

extern NSString *ShowCaptionChangedNotification;

//! MUPhotoView displays a grid of photos similar to iPhoto's main photo view. The class gives developers several options for providing images - via bindings or delegation.

//! MUPhotoView displays a resizeable grid of photos, similar to iPhoto's photo view functionality. MUPhotoView provides developers with two different options for passing photo information to the view
//!  Most importantly, MUPhotoView currently only deals with an array of photos. It also does not know how to find NSImage objects
//!  that are inside another object - it expects NSImage objects. The first method for providing those objects it by binding an array of NSImage objects to the "photosArray" key of the view.
//!  If this key has been bound, MUPhotoView will fetch all the images it displays from that binding. The second method is to have a delegate object provide the photos. MUPhotoView will only
//!  call the delegate's photo methods if the photosArray key has not been bound. Please see the MUPhotoViewDelegate category documentation for descriptions of the methods. 
@interface MUPhotoView : NSView {
    // Please do not access ivars directly - use the accessor methods documented below
    IBOutlet id delegate;
    
    BOOL sendsLiveSelectionUpdates;
    BOOL useHighQualityResize;
	BOOL showCaptions;
    
    NSMutableArray *photosArray;
    NSMutableArray *photosFastArray;
    NSIndexSet *selectedPhotoIndexes;
    NSMutableIndexSet *dragSelectedPhotoIndexes;
    
    NSColor *backgroundColor;
    BOOL useShadowBorder;
    BOOL useOutlineBorder;
    NSShadow *borderShadow;
    NSShadow *noShadow;
    NSColor *borderOutlineColor;
    
    BOOL useBorderSelection;
    BOOL useShadowSelection;
    NSColor *selectionBorderColor;
    NSColor *shadowBoxColor;
    float selectionBorderWidth;
    
    // spacing photos
    float photoSize;
    float photoVerticalSpacing;
    float photoHorizontalSpacing;
	NSString *autosaveName;
    
	
    NSSize gridSize;
    unsigned columns;
    unsigned rows;
    
    BOOL mouseDown;
	BOOL potentialDragDrop;
	NSPoint mouseDownPoint;
	NSPoint mouseCurrentPoint;
	NSTimer *autoscrollTimer;
    NSTimer *photoResizeTimer;
    NSDate *photoResizeTime;
    BOOL isDonePhotoResizing;
	
	NSArray *liveResizeSubviews;
	
	
	BOOL drawDropHilite;
}

#pragma mark -
// Delegate Methods
#pragma mark Delegate Methods
/** Returns the current delegate **/
- (id)delegate;
/** Sets the delegate. See the MUPhotoViewDelegate category for information about which delegate methods will get called and when.**/
- (void)setDelegate:(id)del;

#pragma mark -
// Photos Methods
#pragma mark Photo Methods
/** Returns the array of NSImage objects that MUPhotoView is currently drawing from. If nothing has been bound to the "photosArray" key and
    there has not been a call to -setPhotosArray, then this will probably return nil. If this method returns nil, then at draw time, the MUPhotoView will attempt to ask
    its delegate for the count of photos and for photos at each index. **/
- (NSArray *)photosArray;
/** Sets the array of NSImage objects that MUPhotoView uses to draw itself. If you call this method and pass nil, and the delegate is NOT nil, it will ask the delegate for
    the photos. **/
- (void)setPhotosArray:(NSArray *)aPhotosArray;

#pragma mark -
// Selection Management
#pragma mark Selection Management
    /** Returns the current NSIndexSet indicating which photos are currently selected. If this is nil, then the view is asking its delegate for the selection index information. **/
- (NSIndexSet *)selectedPhotoIndexes;
/** Sets the NSIndexSet that the view will use to indicate which photos need to appear selected in the view. By setting this value to nil, MUPhotoView will ask the delegate for
    this information. **/
- (void)setSelectedPhotoIndexes:(NSIndexSet *)aSelectedPhotoIndexes;

#pragma mark -
// Selection Style
#pragma mark Selection Style
    /** Indicates whether the view is drawing "selected" photos with a 3px border around the photo. The appearnce is similar to iPhoto's selection style. The default value is YES. **/
- (BOOL)useBorderSelection;
/** Tells the view whether or not to indicated "selected" photos by drawing a 3px border around the photo. The appearnce is similar to iPhoto's selection style.
    The default value is YES. **/
- (void)setUseBorderSelection:(BOOL)flag;
/** Returns the current color that thew view is using to draw selection borders. If -useBorderSelection returns NO, it doesn't matter what color is returned from this method.
    The initial value for selectionBorderColor is the user's current selection color. **/
- (NSColor *)selectionBorderColor;
/** Tells the view what color border should be drawn around a "selected" photo. If -useBorderSelection returns NO, calling this method will not have any effect until
    -setUseBorderSelection:YES is callled. The selection border color defaults to the user's current selection color. **/
- (void)setSelectionBorderColor:(NSColor *)aSelectionBorderColor;
/** Indicates whether the view indicates "selected" photos by drawing a semi-transparent rounded box around the photo. The default value is NO. **/
- (BOOL)useShadowSelection;
    /** By setting this value to YES, you tell MUPhotoView to indicate a "selected" photo by drawing a semi-transparent rounded rectangle around the photo. The color and opacity
    of the rounded rectangle depend on the current background color of the view: for lighter colors, MUPhotoView will use a semi-transparent black; for darker colors, the color will
    be a semi-transparent white.**/
- (void)setUseShadowSelection:(BOOL)flag;

    /** Indicates whether the view is drawing with a high-quality, though possibly slower, algorithm for image interpolation. The default value is NO; the default setting for the machine is used. **/
- (BOOL)useHighQualityResize;
    /** By setting this value to YES, you tell MUPhotoView to draw with a higher-quality image, sacrificing speed. **/
- (void)setUseHighQualityResize:(BOOL)flag;

/** Indicates whether captions should be shown below the photo */
- (BOOL)showCaptions;
/** By setting this value to YES, you tell MUPhotoView to draw captions below the thumbnails. **/
- (void)setShowCaptions:(BOOL)flag;

#pragma mark -
// Appearance
#pragma mark Appearance
    /** Indicates whether the view is drawing a drop-shadow around each photo. The default value is YES. **/
- (BOOL)useShadowBorder;
/** Passing YES to this method will cause the view to draw a drop shadow around each photo. The default value is YES. **/
- (void)setUseShadowBorder:(BOOL)flag;
/** Indicates whether the view is currently set to draw a 1px, 50% white border around each photo. The default value is YES. **/
- (BOOL)useOutlineBorder;
/** Tells the view whether or not to draw a 1px, 50% white border around each photo. The default value is YES. **/
- (void)setUseOutlineBorder:(BOOL)flag;
/** Returns the current color being used to paint the background before drawing photos. The default value is [NSColor whiteColor]. **/
- (NSColor *)backgroundColor;
/** Tells the view to use a new color when drawing the background. If -useShadowSelection is YES, updating the background color may also affect the color being used to draw
    the shadow selection indicator. **/
- (void)setBackgroundColor:(NSColor *)aBackgroundColor;
/** Returns the current pixel size that photos are scaled to. When drawing, a photo is scalled proportionately so it's longest side is this number of pixels. **/
- (float)photoSize;
/** Tells the view to draw photos scaled so their longest side is aPhotoSize pixels long. This will cause the visible area of the view to be redrawn - and the view will attempt to
    keep the currently-visible photos near the center of the scroll area. **/
- (void)setPhotoSize:(float)aPhotoSize;
/** Returns the current autosaveName. The default value is nil **/
- (NSString *)autosaveName;
/** If set, the photo size will be stored in the user defaults with key "MUPhotoSize autosaveName"
 If not set, the phot size will be stored in the user defaults with key "MUPhotoSize"**/ 
- (void)setAutosaveName:(NSString *)value;

- (IBAction)takePhotoSizeFrom:(id)sender;

#pragma mark -
// Seriously, Don't Mess With Texas
#pragma mark Seriously, Don't Mess With Texas
// haven't tested changing these behaviors yet - there's no reason they shouldn't work... but use at your own risk.
- (float)photoVerticalSpacing;
- (void)setPhotoVerticalSpacing:(float)aPhotoVerticalSpacing;
- (float)photoHorizontalSpacing;
- (void)setPhotoHorizontalSpacing:(float)aPhotoHorizontalSpacing;
- (NSColor *)borderOutlineColor;
- (void)setBorderOutlineColor:(NSColor *)aBorderOutlineColor;
- (NSColor *)shadowBoxColor;
- (void)setShadowBoxColor:(NSColor *)aShadowBoxColor;
- (float)selectionBorderWidth;
- (void)setSelectionBorderWidth:(float)aSelectionBorderWidth;

@end

#pragma mark -
// Delegate Methods
#pragma mark Delegate Methods
/// The MUPhotoViewDelegate category defines the methods that a MUPhotoView may call, and that you can use provide drag and drop, double-click, selection and even photo display support
/** The MUPhotoViewDelegate category provides default implementations of all the methods the MUPhotoView may call. Overriding each of them is optional - the default implementations
    return no results, nil results, or zero as appropriate. **/
@interface NSObject (MUPhotoViewDelegate)

/** The view will call this method if all of the following are true: (a) a valid array of NSImage objects has not been bound to the @"photosArray" key, (b) 
    -setPhotosArray: has not been called and passed a valid, non-nil array, and (c) the delegate is not nil. **/
- (unsigned)photoCountForPhotoView:(MUPhotoView *)view;
/** The view will call this method if all of the following are true: (a) a valid array of NSImage objects has not been bound to the @"photosArray" key, (b) 
   -setPhotosArray: has not been called and passed a valid, non-nil array, and (c) the delegate is not nil. The delegate should return the NSImage appropriate
    to draw at the specified index. **/
- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)index;

/** If the view depends on the delegate for photos (instead of bindings), it will call this method during a live resize operation. It expects a very small version
    of the photo at the specified index in order to speed drawing in the live resize. Overriding this method is optional. The default implementation returns nil,
    which forces the view to use the regular photos during resize. Avoid doing any time-consuming image manipulation in this method or there will be no benefit
    to drawing the small images. Ideally, you would only create a small version once - either ahead of time or during this call - and then reuse it. **/
- (NSImage *)photoView:(MUPhotoView *)view fastPhotoAtIndex:(unsigned)index;

- (NSString *)photoView:(MUPhotoView *)view titleForPhotoAtIndex:(unsigned)index;
    // If a title is returned it will be drawn under the photo, if that option is set.

// selection methods - will only get called if photoSelectionIndexes has not been bound
/** The view will call this method if all of the following are true: (a) a valid NSIndexSet has not been bound to the @"photoSelectionIndexes" key, (b) 
    -setPhotoSelectionIndexes: has not been called and passed a valid, non-nil NSIndexSet, and (c) the delegate is not nil. The delegate should return an NSIndexSet filled
    with indexes appropriately representing which photos should be drawn as "selected" .**/
- (NSIndexSet *)selectionIndexesForPhotoView:(MUPhotoView *)view;
/** The view will call this method if all of the following are true: (a) a valid NSIndexSet has not been bound to the @"photoSelectionIndexes" key, (b) 
    -setPhotoSelectionIndexes: has not been called and passed a valid, non-nil NSIndexSet, and (c) the delegate is not nil. If the delegate implements this method,
    it can modify the proposed selection and return an appropriate NSIndexSet. You should only implement this method if, for some reason, you want to manipulate or look
    at the selection indexes before the view marks them as selected. **/
- (NSIndexSet *)photoView:(MUPhotoView *)view willSetSelectionIndexes:(NSIndexSet *)indexes;
/** The view will call this method if all of the following are true: (a) a valid NSIndexSet has not been bound to the @"photoSelectionIndexes" key, (b) 
    -setPhotoSelectionIndexes: has not been called and passed a valid, non-nil NSIndexSEt, and (c) the delegate is not nil. The delegate should do whatever work necessary to 
    mark the specified indexes as selected. (i.e. a subsequent call to -selectionIndexesForPhotoView: should most likely return this set or an identical one. **/
- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes;

// drag and drop
/** A delegate would use this method to specify whether the view should support drag operations. (i.e. whether the view should allow photos to be dragged out of the view.
    The semantics are identical to the -[NSDraggingSource draggingSourceOperationmaskForLocal] **/
- (unsigned int)photoView:(MUPhotoView *)view draggingSourceOperationMaskForLocal:(BOOL)isLocal;
/** The view will call this method at drag time. The delegate should pass an array indicating the types that it will put on the pasteboard for a given set of images. If
    you provide an implementation for -photoView:draggingSourceOperationMaskForLocal: that returns anything other than NO, you should also implement this method and indicate
    which types you will support. **/
//- (NSArray *)pasteboardDragTypesForPhotoView:(MUPhotoView *)view;
/** The view will call this method when it is about to initiate a drag. It will call this method once for *each* combination type returned from -pasteboardDragTypesForPhotoView:
    and each photo currently being dragged. The delegate should return the appropriate data for the given type. If you provide any implementation of
    -photoView:draggingSourceOperationMaskForLocal that returns anything other than NO, you should also implement this method. **/
//- (NSData *)photoView:(MUPhotoView *)view pasteboardDataForPhotoAtIndex:(unsigned)index dataType:(NSString *)type;
- (void)photoView:(MUPhotoView *)view fillPasteboardForDrag:(NSPasteboard *)pboard;

// drag and drop receiving - Equivalent to the NSDraggingDestination methods
- (NSDragOperation)photoView:(MUPhotoView *)view draggingEntered:(id <NSDraggingInfo>)sender;
- (void)photoView:(MUPhotoView *)view draggingExited:(id <NSDraggingInfo>)sender;
- (BOOL)photoView:(MUPhotoView *)view performDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL)photoView:(MUPhotoView *)view prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (void)photoView:(MUPhotoView *)view concludeDragOperation:(id <NSDraggingInfo>)sender;

// double-click support
/** The view will call this delegate method when the user double-clicks on the photo at the specified index. If you do not wish to support any double-click behavior, then you
    don't need to override this method. **/
- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)index withFrame:(NSRect)frame;

// photo removal support
/** The view will call this delegate method when the user selects photos and presses the delete key. The delegate should use this method to alter the photos that will
    be removed by returning an appropriate NSIndexSet. The delegate will get this method even if the photos array is set via bindings. If the photos array is not set
    via bindings, overriding this method is still optional. The default implementation of this method simply returns the an empty index set. **/
- (NSIndexSet *)photoView:(MUPhotoView *)view willRemovePhotosAtIndexes:(NSIndexSet *)indexes;

/** The view will call this delegate method when the user selects photos and presses the delete key. The view will first call the willRemovePhotosAtIndexes: method to give
    the delegate a chance to modify the behavior. If the photo array is set via bindings, the view will remove the specified photos and then call this method. Note that in that
    case, the indexes passed to this method no longer have meaning because the array has already been modified. If the photos array is NOT set via bindings, the delegate should
    override this method and do the appropriate removals itself. The default implementation does nothing. **/
- (void)photoView:(MUPhotoView *)view didRemovePhotosAtIndexes:(NSIndexSet *)indexes;

// Tool tip support
- (NSString *)photoView:(MUPhotoView *)view tooltipForPhotoAtIndex:(unsigned)index;

@end


// private methods. Do not call or override.
@interface MUPhotoView (PrivateAPI)

// set internal grid and my frame based on array size, photo size, and width
- (void)updateGridAndFrame;

// will fetch from the internal array if not nil, from delegate otherwise
- (unsigned)photoCount;
- (NSImage *)photoAtIndex:(unsigned)index;
- (NSImage *)fastPhotoAtIndex:(unsigned)index;
- (void)updatePhotoResizing;
- (NSString *)titleAtIndex:(unsigned)index;

// This may be the actual photo, or a fast photo, or a placeholder image
- (NSImage*) currentDisplayImageAtIndex:(unsigned)thisPhotoIndex allowsShadows:(BOOL *)allowShadows;

// placement and hit detection

// The central powerhouse for determining geometry distribution on a given index, with a given photo and title.
// By consolidating a lot of this stuff into one freakin' method name, we are assured that hit detection matches
// up with drawing, even as optional features like caption titles bloom... - DCJ, July 2007
- (void)getDrawingRectsAtIndex:(unsigned)photoIndex withPhoto:(NSImage *)cellPhoto withTitle:(NSString*)title outGridRect:(NSRect *)outGridRect outPhotoRect:(NSRect *)outPhotoRect outTitleRect:(NSRect *)outTitleRect;

- (NSSize)scaledPhotoSizeForSize:(NSSize)size;
- (NSImage *)scalePhoto:(NSImage *)image;
- (unsigned)photoIndexForPoint:(NSPoint)point;
- (NSRange)photoIndexRangeForRect:(NSRect)rect;
- (NSRect)gridRectForIndex:(unsigned)index;
- (NSRect)rectCenteredInRect:(NSRect)rect withSize:(NSSize)size;
- (NSRect)photoRectForIndex:(unsigned)index;
- (NSSize)sizeOfTitleWithCurrentAttributes:(NSString*)title;

// selection
- (BOOL)isPhotoSelectedAtIndex:(unsigned)index;
- (NSIndexSet *)selectionIndexes;
- (void)setSelectionIndexes:(NSIndexSet *)indexes;
- (NSBezierPath *)shadowBoxPathForRect:(NSRect)rect;

// photo removal
- (void)removePhotosAtIndexes:(NSIndexSet *)indexes;

// scaling
- (NSImage *)scaleImage:(NSImage *)image toSize:(float)size;

// For fast re-drawing during drag and selection
- (void)dirtyDisplayRectsForNewSelection:(NSIndexSet *)newSelection oldSelection:(NSIndexSet *)oldSelection;
@end
