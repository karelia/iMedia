//**********************************************************************************************************************
//
//  BXPopover.m
//
//  Author:		Peter Baumgartner, peter@baumgartner.com
//  Copyright:	©2011-2012 by IMAGINE GbR. All rights reserved.
//	Abstract:	Convenience class to dynamically create popovers from nib files
//
//**********************************************************************************************************************


#pragma HEADERS

#import "IMBPopover.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma CONSTANTS

#define kIMBCloseAllPopoversNotification @"IMBCloseAllPopovers"


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBPopover


//----------------------------------------------------------------------------------------------------------------------


+ (Class) viewControllerClass
{
	return [NSViewController class];
}


+ (IMBPopover*) popoverWithNibName:(NSString*)inNibName
{
	return [[[[self class] alloc] initWithNibName:inNibName] autorelease];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithNibName:(NSString*)inNibName
{
	self = [super init];
	
	if (self)
	{
		self.contentViewController = [[[[self.class viewControllerClass] alloc]
			initWithNibName:inNibName 
			bundle:[NSBundle bundleForClass:[self class]]]
			autorelease];
			
		self.behavior = NSPopoverBehaviorTransient;
		
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(close)
			name:kIMBCloseAllPopoversNotification
			object:nil];
	}
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// When showing a popover in its parent view, then also listen to scrolling that might happen in the parent view...

- (void) showRelativeToRect:(NSRect)inRect ofView:(NSView*)inParentView preferredEdge:(NSRectEdge)inPreferredEdge
{
	[super showRelativeToRect:inRect ofView:inParentView preferredEdge:inPreferredEdge];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self 
		selector:@selector(didScrollParentView:) 
		name:NSViewBoundsDidChangeNotification
		object:inParentView.superview];

}


// When the positionRect scrolls out of sight, then auto-close the popover...

- (void) didScrollParentView:(NSNotification*)inNotification
{
	NSClipView* clipview = (NSClipView*)[inNotification object];
	
	NSRect popoverRect = self.positioningRect;
	NSRect visibleRect = clipview.documentVisibleRect;
	
	if (! NSIntersectsRect(popoverRect,visibleRect))
	{
		[self performClose:self];
	}
}


//----------------------------------------------------------------------------------------------------------------------


+ (void) closeAllPopovers
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kIMBCloseAllPopoversNotification object:nil];
}


//----------------------------------------------------------------------------------------------------------------------


@end
