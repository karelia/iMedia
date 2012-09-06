/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
*/


//----------------------------------------------------------------------------------------------------------------------


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBGarageBandParser.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "SBUtilities.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBGarageBandParser

@synthesize appPath = _appPath;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if ((self = [super init]))
	{
		self.fileUTI = @"com.apple.garageband.project"; 
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_appPath);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods


- (IMBNode*) unpopulatedTopLevelNode:(NSError**)outError
{
	NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:self.appPath];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(16.0,16.0)];
	
	// Create an empty (unpopulated) root node...
	
	IMBNode* node = [[[IMBNode alloc] initWithParser:self topLevel:YES] autorelease];
	node.icon = icon;
	node.name = @"GarageBand";
	node.identifier = [self identifierForPath:@"/"];
	node.groupType = kIMBGroupTypeLibrary;
	node.isLeafNode = NO;

	return node;
}


//----------------------------------------------------------------------------------------------------------------------


// Paths to important folders containing songs...

- (NSString*) userSongsPath
{
	return [SBHomeDirectory() stringByAppendingPathComponent:@"Music/GarageBand"];
}


//- (NSString*) demoSongsPath
//{
//	return @"/Library/Application Support/GarageBand/GarageBand Demo Songs/";
//}


- (BOOL) populateNode:(IMBNode*)inNode error:(NSError**)outError
{
	if (inNode.isTopLevelNode)
	{
		NSMutableArray* subnodes = [inNode mutableArrayForPopulatingSubnodes];
		NSFileManager *fileManager = [[NSFileManager alloc] init];
			
		NSString* userSongsPath = [self userSongsPath];
		if ([fileManager fileExistsAtPath:userSongsPath])
		{
			NSString* userSongsName = NSLocalizedStringWithDefaultValue(
				@"IMBGarageBandParser.usersongs.name",
				nil,IMBBundle(),
				@"My Compositions",
				@"Name of node in IMBGarageBandParser");
		
			IMBNode* subnode = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
			subnode.identifier = [self identifierForPath:userSongsPath];
			subnode.icon = [self iconForItemAtURL:[NSURL fileURLWithPath:userSongsPath isDirectory:YES] error:NULL];
			subnode.name = userSongsName;
			subnode.mediaSource = [NSURL fileURLWithPath:userSongsPath];
			subnode.isIncludedInPopup = YES;
			subnode.isLeafNode = YES;
			[subnodes addObject:subnode];
		}
		
//		NSString* demoSongsPath = [self demoSongsPath];
//        if ([fileManager fileExistsAtPath:demoSongsPath])
//		{
//			NSString* demoSongsName = NSLocalizedStringWithDefaultValue(
//				@"IMBGarageBandParser.demosongs.name",
//				nil,IMBBundle(),
//				@"Demo Songs",
//				@"Name of node in IMBGarageBandParser");
//
//			IMBNode* subnode = [[[IMBNode alloc] init] autorelease];
//			subnode.identifier = [self identifierForPath:userSongsPath];
//			subnode.icon = [self iconForItemAtURL:[NSURL fileURLWithPath:demoSongsPath isDirectory:YES] error:NULL];
//			subnode.name = demoSongsName;
//			subnode.mediaType = self.mediaType;
//			subnode.mediaSource = [NSURL fileURLWithPath:demoSongsPath];
//			subnode.parserIdentifier = self.identifier;
//			subnode.isTopLevelNode = NO;
//			subnode.isIncludedInPopup = YES;
//			subnode.isLeafNode = YES;
//			[subnodes addObject:subnode];
//		}

        [fileManager release];
		inNode.objects = [NSMutableArray arrayWithCapacity:0];	// Important to mark node as populated!
		
		return YES;
	}
	else
	{
		return [super populateNode:inNode error:outError];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Return metadata specific to GarageBand files...

- (NSDictionary*) metadataForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSURL *url = inObject.URL;
	url = [url URLByAppendingPathComponent:@"Output/metadata.plist"];
	NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithContentsOfURL:url];
	
	if (metadata)
	{
		[metadata setObject:[url path] forKey:@"path"];

		NSNumber* duration = [metadata objectForKey:@"com_apple_garageband_metadata_songDuration"];
		[metadata setObject:duration forKey:@"duration"];

		NSString* artist = [metadata objectForKey:@"com_apple_garageband_metadata_artistName"];
		[metadata setObject:artist forKey:@"artist"];

		NSString* album = [metadata objectForKey:@"com_apple_garageband_metadata_albumName"];
		[metadata setObject:album forKey:@"album"];
	}
	
	if (outError) *outError = nil;
	return metadata;
}


//----------------------------------------------------------------------------------------------------------------------


@end
