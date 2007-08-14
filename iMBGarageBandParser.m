/*
 iMedia Browser <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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


#import "iMBGarageBandParser.h"
#import "iMBLibraryNode.h"
#import "iMediaBrowser.h"
#import "iMedia.h"
#import <QTKit/QTKit.h>

@implementation iMBGarageBandParser

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iMediaBrowser registerParser:[self class] forMediaType:@"music"];
	
	[pool release];
}

- (id)init
{
	if (self = [super initWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Music/GarageBand"]])
	{
		
	}
	return self;
}

// TODO: Speed this up by having the external MetadataTool process do the work.

// arguments should have the following input and output keys:
//
//      inputFile: the filename to parse
//
//      outputDuration: the duration of the file
//
- (void)getDurationInfo:(NSMutableDictionary *)arguments
{
    NSString *file = [arguments objectForKey:@"inputFile"];
    
    NSError *error = nil;
    QTMovie *movie = [[QTMovie alloc] initWithFile:file error:&error];
    
    if ( movie != nil && error == nil )
    {
        NSNumber *duration = [NSNumber numberWithFloat:[movie durationInSeconds] * 1000];

        [arguments setValue:duration forKey:@"outputDuration"];
        
        [movie release];
    }
}

- (void)recursivelyParse:(NSString *)path withNode:(iMBLibraryNode *)root artist:(NSString *)artist
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *contents = [fm directoryContentsAtPath:path];
	NSEnumerator *e = [contents objectEnumerator];
	NSString *cur;
	BOOL isDir;
	NSMutableArray *songs = [NSMutableArray array];
	NSMutableDictionary *rec;
	
	while (cur = [e nextObject])
	{
		NSString *filePath = [path stringByAppendingPathComponent: cur];
		
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && ![fm isPathHidden:filePath])
		{
			if (isDir)
			{
				if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"band"])
				{
					// see if we have the preview to the gb composition
					NSString *output = [filePath stringByAppendingPathComponent:@"Output/Output.aif"];
					BOOL hasSample = [fm fileExistsAtPath:output];
					rec = [NSMutableDictionary dictionary];
					[rec setObject:[[filePath lastPathComponent] stringByDeletingPathExtension] forKey:@"Name"];
					[rec setObject:filePath forKey:@"Location"];
					[rec setObject:artist forKey:@"Artist"];
					
					if (hasSample)
					{
						[rec setObject:output forKey:@"Preview"];
                        
                        NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObject:output forKey:@"inputFile"];
                        
                        [self performSelectorOnMainThread:@selector(getDurationInfo:) withObject:arguments waitUntilDone:YES];
                        
                        NSNumber *duration = [arguments objectForKey:@"outputDuration"];

                        if ( duration != nil )
                        {
							[rec setObject:duration forKey:@"Total Time"];
						}
					}
					NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:filePath];
					[rec setObject:icon forKey:@"Icon"];
					
					[songs addObject:rec];
				}
				else
				{
					iMBLibraryNode *folder = [[iMBLibraryNode alloc] init];
					[root addItem:folder];
					[folder release];
					[folder setIconName:@"folder"];
					[folder setName:[fm displayNameAtPath:filePath]];
					[self recursivelyParse:filePath withNode:folder artist:artist];
				}
			}
		}
	}
	[root setAttribute:songs forKey:@"Tracks"];
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[[iMBLibraryNode alloc] init] autorelease];
	[root setName:LocalizedStringInThisBundle(@"GarageBand", @"Name of Node")];
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForAppWithBundleIdentifier:@"com.apple.garageband"];
	if (icon)
	{
		[root setIcon:icon];
	}
	else
	{
		[root setIconName:@"folder"];
	}
	
	// Do the demo songs
	NSString *demoPath = @"/Library/Application Support/GarageBand/GarageBand Demo Songs/GarageBand Demo Songs/";
	if ([[NSFileManager defaultManager] fileExistsAtPath:demoPath])
	{
		iMBLibraryNode *demo = [[iMBLibraryNode alloc] init];
		[demo setName:LocalizedStringInThisBundle(@"GarageBand Demo Songs", @"Node name")];
		[demo setIconName:@"folder"];
		
		[self recursivelyParse:demoPath withNode:demo artist:LocalizedStringInThisBundle(@"Demo", @"artist name")];
		[root addItem:demo];
		[demo release];
	}
	
	iMBLibraryNode *myCompositions = [[[iMBLibraryNode alloc] init] autorelease];
	[myCompositions setName:LocalizedStringInThisBundle(@"My Compositions", @"Node name")];
	[myCompositions setIconName:@"folder"];
	
	[self recursivelyParse:myDatabase
				  withNode:myCompositions
					artist:NSFullUserName()];
	if ([[myCompositions attributeForKey:@"Tracks"] count])
	{
		[root addItem:myCompositions];
	}
	
	return [[root allItems] count] ? root : nil;
}

@end
