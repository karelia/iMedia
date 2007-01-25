//
//  iMBSpotlightPhotoParser.m
//  iMediaBrowse
//
//  Created by Dan Wood on 11/1/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "iMBSpotlightPhotoParser.h"
#import "iMedia.h"


@implementation iMBSpotlightPhotoParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	//
	//
	//
	// COMMENTED OUT FOR NOW -- WE DON'T WANT TO ACTIVATE THIS UNTIL IT'S READY
	//
	//
	//
	//[iMediaBrowser registerParser:[self class] forMediaType:@"photos"];
	
	[pool release];
}

- (id)init
{
	// we would probably want some pseudo-folders of differing ages, and also exclude iphoto, aperture results, etc.
	if (self = [super initWithPredicateString:@"kMDItemContentTypeTree == \"public.image\" and kMDItemFSCreationDate > $YESTERDAY"])
	{
		
	}
	return self;
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *favs = [[iMBLibraryNode alloc] init];
	[favs setName:LocalizedStringInThisBundle(@"Spotlight", @"Spotlight searching pseudo-folder name")];
	[favs setIconName:@"spotlight"];
	
	return [favs autorelease];
}

@end
