//**********************************************************************************************************************
//
//  IMBAlertPopover.m
//
//  Author:		Peter Baumgartner, peter@baumgartner.com
//  Copyright:	©2011 by IMAGINE GbR. All rights reserved.
//	Abstract:	Subclass for alert popovers
//
//**********************************************************************************************************************


#pragma HEADERS

#import "IMBAlertPopover.h"
#import "IMBAlertPopoverViewController.h"


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBAlertPopover


//----------------------------------------------------------------------------------------------------------------------


+ (IMBAlertPopover*) stopPopoverWithHeader:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter
{
	NSURL* url = [[NSBundle bundleForClass:[self class]] URLForResource:@"IMBStopIcon" withExtension:@"icns"];
	NSImage* icon = [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
	return [self alertPopoverWithIcon:icon header:inHeader body:inBody footer:inFooter];
}


+ (IMBAlertPopover*) warningPopoverWithHeader:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter
{
	NSImage* icon = [NSImage imageNamed:NSImageNameCaution];
	return [self alertPopoverWithIcon:icon header:inHeader body:inBody footer:inFooter];
}


+ (IMBAlertPopover*) notePopoverWithHeader:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter
{
	NSURL* url = [[NSBundle bundleForClass:[self class]] URLForResource:@"IMBNoteIcon" withExtension:@"icns"];
	NSImage* icon = [[[NSImage alloc] initWithContentsOfURL:url] autorelease];
	return [self alertPopoverWithIcon:icon header:inHeader body:inBody footer:inFooter];
}


//----------------------------------------------------------------------------------------------------------------------


+ (Class) viewControllerClass
{
	return [IMBAlertPopoverViewController class];
}


+ (IMBAlertPopover*) alertPopoverWithIcon:(NSImage*)inIcon header:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter
{
	return [[[[self class] alloc] initWithIcon:inIcon header:inHeader body:inBody footer:inFooter] autorelease];
}


- (id) initWithIcon:(NSImage*)inIcon header:(NSString*)inHeader body:(NSString*)inBody footer:(NSString*)inFooter
{
	self = [self initWithNibName:@"IMBAlertPopoverViewController"];
	
	if (self)
	{
		IMBAlertPopoverViewController* controller = (IMBAlertPopoverViewController*)self.contentViewController;
		controller.icon = inIcon;
		controller.headerString = inHeader;
		controller.bodyString = inBody;
		controller.footerString = inFooter;
	}
	
	return self;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) setIcon:(NSImage*)inIcon
{
	IMBAlertPopoverViewController* controller = (IMBAlertPopoverViewController*)self.contentViewController;
	controller.icon = inIcon;
}


- (NSImage*) icon
{
	IMBAlertPopoverViewController* controller = (IMBAlertPopoverViewController*)self.contentViewController;
	return controller.icon;
}


//----------------------------------------------------------------------------------------------------------------------


- (void) setHeaderTextColor:(NSColor*)inColor
{
	[(IMBAlertPopoverViewController*)self.contentViewController setHeaderTextColor:inColor];
}


- (void) setBodyTextColor:(NSColor*)inColor
{
	[(IMBAlertPopoverViewController*)self.contentViewController setBodyTextColor:inColor];
}


- (void) setFooterTextColor:(NSColor*)inColor
{
	[(IMBAlertPopoverViewController*)self.contentViewController setFooterTextColor:inColor];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) addButtonWithTitle:(NSString*)inTitle block:(IMBButtonBlockType)inBlock
{
	[(IMBAlertPopoverViewController*)self.contentViewController addButtonWithTitle:inTitle block:inBlock];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) showProgressIndicator
{
	[(IMBAlertPopoverViewController*)self.contentViewController showProgressIndicator];
}


- (void) hideProgressIndicator
{
	[(IMBAlertPopoverViewController*)self.contentViewController hideProgressIndicator];
}


//----------------------------------------------------------------------------------------------------------------------


@end
