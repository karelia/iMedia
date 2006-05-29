/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
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
		NSString *fileName = [filePath lastPathComponent];
		
		if ([fm fileExistsAtPath:filePath isDirectory:&isDir] && isDir && ![fm isPathHidden:cur])
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
					// we need to load it into a qt movie so we can get the duration
					QTDataReference *ref = [QTDataReference dataReferenceWithReferenceToFile:output];
					NSError *error = nil;
					QTMovie *movie = [[QTMovie alloc] initWithAttributes:
						[NSDictionary dictionaryWithObjectsAndKeys: 
							ref, QTMovieDataReferenceAttribute,
							[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
							nil] error:&error];
					if (movie)
					{
						QTTime duration = [movie duration];
						NSNumber *time = [NSNumber numberWithDouble:GetMovieDuration( [movie quickTimeMovie] )];
						[rec setObject:time forKey:@"Total Time"];
					}
					[movie release];
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
				[folder setName:[fm displayNameAtPath:[cur lastPathComponent]]];
				[self recursivelyParse:filePath withNode:folder artist:artist];
			}
		}
	}
	[root setAttribute:songs forKey:@"Tracks"];
}

- (iMBLibraryNode *)parseDatabase
{
	iMBLibraryNode *root = [[iMBLibraryNode alloc] init];
	[root setName:LocalizedStringInThisBundle(@"Garage Band", @"Name of Node")];
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
	
	iMBLibraryNode *myCompositions = [[iMBLibraryNode alloc] init];
	[myCompositions setName:LocalizedStringInThisBundle(@"My Compositions", @"Node name")];
	[myCompositions setIconName:@"folder"];
	
	[self recursivelyParse:myDatabase
				  withNode:myCompositions
					artist:NSFullUserName()];
	[root addItem:myCompositions];
	
	return [root autorelease];
}

@end
