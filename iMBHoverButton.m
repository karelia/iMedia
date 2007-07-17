//
//  iMBHoverButton.m
//  iMediaBrowse
//
//  Created by Dan Wood on 1/23/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "iMBHoverButton.h"

@implementation iMBHoverButton

- (id)initWithFrame:(NSRect)aFrame
{
	if ((self = [super initWithFrame:aFrame]) != nil) {
		iMBHoverButtonCell *theCell = [[[iMBHoverButtonCell allocWithZone:[self zone]] init] autorelease];
		[self setCell:theCell];

		[self setButtonType:NSMomentaryChangeButton];
		[self setShowsBorderOnlyWhileMouseInside:YES];
		[self setBordered:NO];
		[self setTitle:@""];
		[self setImagePosition:NSImageOnly];

		NSString *p  = [[NSBundle bundleForClass:[self class]] pathForResource:@"i" ofType:@"tiff"];
		NSString *p2 = [[NSBundle bundleForClass:[self class]] pathForResource:@"i2" ofType:@"tiff"];
		NSImage *im  = [[[NSImage alloc] initWithContentsOfFile:p ] autorelease];
		NSImage *im2 = [[[NSImage alloc] initWithContentsOfFile:p2] autorelease];
		[self setImage:im];
		[self setAlternateImage:im2];
		
		[theCell setImageDimsWhenDisabled:YES];
	}
	return self;
}

@end

@implementation iMBHoverButtonCell

- (void)mouseEntered:(NSEvent *)event
{
	NSImage *image = [[self image] retain];
	NSImage *alternateImage = [[self alternateImage] retain];
	[self setImage:alternateImage];
	[self setAlternateImage:image];
	[image release];
	[alternateImage release];
}

- (void)mouseExited:(NSEvent *)event
{
	NSImage *image = [[self image] retain];
	NSImage *alternateImage = [[self alternateImage] retain];
	[self setImage:alternateImage];
	[self setAlternateImage:image];
	[image release];
	[alternateImage release];
}


@end
