//
//  IMBSmartFolderNodeObject.m
//  iMedia
//
//  Created by Dan Wood on 1/4/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "IMBSmartFolderNodeObject.h"


@implementation IMBSmartFolderNodeObject

+ (NSImage *)icon;		// usable from other places for a smart folder
{
	static NSImage *sSmartFolderImage = nil;
	if (!sSmartFolderImage)
	{
		// Get high-resolution version of smart folder icon directly from CoreTypes
		NSBundle* coreTypes = [NSBundle	bundleWithPath:@"/System/Library/CoreServices/CoreTypes.bundle"];
		if (coreTypes)
		{
			NSString* smartPath = [coreTypes pathForResource:@"SmartFolderIcon.icns" ofType:nil];
			if (smartPath)
			{
				sSmartFolderImage = [[NSImage alloc] initWithContentsOfFile:smartPath];
			}
		}
		if (!sSmartFolderImage)
		{
			sSmartFolderImage = [[NSImage imageNamed:NSImageNameFolderSmart] retain];		// fall-back low-resolution version :-(
		}
	}
	return sSmartFolderImage;
}

// Override to show a folder icon ALWAYS instead of a generic file icon...

- (NSImage*) icon
{
	return [IMBSmartFolderNodeObject icon];
}


@end
