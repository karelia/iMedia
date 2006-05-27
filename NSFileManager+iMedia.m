//
//  NSFileManager+iMedia.m
//  iMediaBrowse
//
//  Created by Greg Hulands on 27/05/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NSFileManager+iMedia.h"


@implementation NSFileManager (iMedia)

- (BOOL)isPathHidden:(NSString *)path
{
	BOOL isHidden = NO;
	OSStatus ret;
	NSURL *url = [NSURL fileURLWithPath:path];
	LSItemInfoRecord rec;
	
	ret = LSCopyItemInfoForURL((CFURLRef)url, kLSRequestAllInfo, &rec);
	if (ret == noErr)
	{
		if (rec.flags & kLSItemInfoIsInvisible)
		{
			isHidden = YES;
		}
	}
	return isHidden;
}

@end
