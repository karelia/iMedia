//**********************************************************************************************************************
//
//  IMBAlertPopover.h
//
//  Author:		Peter Baumgartner, peter@baumgartner.com
//  Copyright:	©2011 by IMAGINE GbR. All rights reserved.
//	Abstract:	Subclass for alert popovers
//
//**********************************************************************************************************************


#pragma mark HEADERS

#import "IMBPopover.h"
#import "IMBAlertPopoverViewController.h"


//----------------------------------------------------------------------------------------------------------------------


@interface IMBAlertPopover : IMBPopover

// Convienience methods...

+ (IMBAlertPopover*) stopPopoverWithHeader:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter;
+ (IMBAlertPopover*) warningPopoverWithHeader:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter;
+ (IMBAlertPopover*) notePopoverWithHeader:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter;

// Designated initializer...

+ (IMBAlertPopover*) alertPopoverWithIcon:(NSImage*)inIcon header:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter;
- (id) initWithIcon:(NSImage*)inIcon header:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter;

// Icon...

@property (strong) NSImage* icon;

// Optional buttons...

- (void) addButtonWithTitle:(NSString*)inTitle block:(IMBButtonBlockType)inBlock;

// Custom text colors...

- (void) setHeaderTextColor:(NSColor*)inColor;
- (void) setBodyTextColor:(NSColor*)inColor;
- (void) setFooterTextColor:(NSColor*)inColor;

// Optional progress wheel...

- (void) showProgressIndicator;
- (void) hideProgressIndicator;

@end


//----------------------------------------------------------------------------------------------------------------------
