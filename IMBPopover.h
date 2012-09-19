//**********************************************************************************************************************
//
//  IMBPopover.h
//
//  Author:		Peter Baumgartner, peter@baumgartner.com
//  Copyright:	©2011-2012 by IMAGINE GbR. All rights reserved.
//	Abstract:	Convenience class to dynamically create popovers from nib files
//
//**********************************************************************************************************************


@interface IMBPopover : NSPopover

+ (IMBPopover*) popoverWithNibName:(NSString*)inNibName;
- (id) initWithNibName:(NSString*)inNibName;

+ (Class) viewControllerClass;

+ (void) closeAllPopovers;

@end


//----------------------------------------------------------------------------------------------------------------------
