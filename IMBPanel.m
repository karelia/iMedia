//
//  IMBPanel.m
//  iMedia
//
//  Created by Gideon King on 2/07/10.
//  Copyright 2010 NovaMind Software. All rights reserved.
//

#import "IMBPanel.h"


@implementation IMBPanel

// This is required to work around a bug in Apple's frameworks where if you close a window with an IKImageBrowserView
// on it and there are selected images, then it gives an error message: "kCGErrorInvalidConnection: CGSGetSurfaceBounds: Invalid connection"
- (void)close {
	[self orderOut:self];
}

@end
