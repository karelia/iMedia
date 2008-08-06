//
//  NSBundle+iMedia.m
//  iMediaBrowse
//
//  Created by Matthew Tonkin on 7/05/08.
//  Copyright 2008 Matthew Tonkin. All rights reserved.
//

#import "NSBundle+iMedia.h"


@implementation NSBundle (iMedia)


- (BOOL)loadNibNamed:(NSString *)aNibName owner:(id)owner
{
	//Code adapted from http://developer.apple.com/documentation/Cocoa/Conceptual/LoadingResources/CocoaNibs/chapter_3_section_6.html

	NSNib*      aNib = [[NSNib alloc] initWithNibNamed:aNibName bundle:self];
    NSArray*    topLevelObjs = nil;
	
    BOOL success = (![aNib instantiateNibWithOwner:owner topLevelObjects:&topLevelObjs])
	// Release the raw nib data no matter what.
	[aNib release];
    
	if (!success)
	{
        NSLog(@"Warning! Could not load nib file.\n");
        return NO;
    }
	
    // Release the top-level objects so that they are just owned by the array.
    [topLevelObjs makeObjectsPerformSelector:@selector(release)];
	
	return YES;
}

@end
