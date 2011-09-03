//
//  IMBiMovieProjectsParser.m
//  iMedia
//
//  Created by Dan Wood on 9/2/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "IMBiMovieProjectsParser.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "IMBParserController.h"
#import "IMBConfig.h"
#import "IMBNode.h"


@implementation IMBiMovieProjectsParser

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeMovie];
	[pool drain];
}

+ (NSArray*) parserInstancesForMediaType:(NSString*)inMediaType
{
	NSArray *result = [super parserInstancesForMediaType:inMediaType];
	
	NSString *moviesPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Movies"];
	NSString *projectsPath = [moviesPath stringByAppendingPathComponent:@"iMovie Projects.localized"];
	
	// Don't let the standard movie parser find this
	[IMBConfig registerLibraryPath:projectsPath];

	return result;
}


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		NSString *moviesPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Movies"];
		NSString *projectsPath = [moviesPath stringByAppendingPathComponent:@"iMovie Projects.localized"];

		self.mediaSource = projectsPath;

		self.displayPriority = 2;	// Pretty close to the top since it's an iApp
}
	
	return self;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation. Scan the folder
// for folder or for files that match our desired UTI and create an IMBObject for each file that qualifies...

// This is based upon FolderParser, but it descends into the projects and then gets the various sizes


- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSFileManager* fm = [NSFileManager imb_threadSafeManager];
	NSError* error = nil;
	NSString* folder = inNode.mediaSource;
	NSAutoreleasePool* pool = nil;
	NSInteger index = 0;
	
	NSArray* files = [fm contentsOfDirectoryAtPath:folder error:&error];
	
	if (error == nil)
	{
		files = [files sortedArrayUsingSelector:@selector(imb_finderCompare:)];

		NSMutableArray* objects = [NSMutableArray arrayWithCapacity:files.count];
		
		inNode.displayedObjectCount = 0;
				
		for (NSString* file in files)
		{
			if (index%32 == 0)
			{
				IMBDrain(pool);
				pool = [[NSAutoreleasePool alloc] init];
			}
			
			// Hidden file system items (e.g. ".thumbnails") will be skipped...
			
			if (![file hasPrefix:@"."])	
			{
				NSString* path = [folder stringByAppendingPathComponent:file];
				
				// For folders will be handled later. Just remember it for now...
				BOOL isDir = NO;
				if ([fm fileExistsAtPath:path isDirectory:&isDir] && isDir) 
				{
					if ([[file pathExtension] isEqualToString:@"rcproject"])
					{
						NSString *betterName = [fm displayNameAtPath:[file stringByDeletingPathExtension]];
						betterName = [betterName stringByReplacingOccurrencesOfString:@"_" withString:@" "];

						// Now to go through each file in the Movies directory
						NSString *moviesPath = [path stringByAppendingPathComponent:@"Movies"];
						
						NSArray* sizes = [fm contentsOfDirectoryAtPath:moviesPath error:&error];
						
						if (error == nil)
						{
							sizes = [sizes sortedArrayUsingSelector:@selector(imb_finderCompare:)];
														
							for (NSString* sizeFile in sizes)
							{
								// Hidden file system items (e.g. ".thumbnails") will be skipped...
								
								if (![sizeFile hasPrefix:@"."])	
								{
									NSString* sizedPath = [moviesPath stringByAppendingPathComponent:sizeFile];
	
									NSString *nameWithSize = [NSString stringWithFormat:@"%@ — %@", betterName, [sizeFile stringByDeletingPathExtension]];
									IMBObject* object = [self objectForPath:sizedPath name:nameWithSize index:index++];
									[objects addObject:object];
									inNode.displayedObjectCount++;
								}
							}
						}
					}
				}
			}
		}
		
		// Add a subnode and an IMBNodeObject for each folder...
		
		
		
		inNode.objects = objects;
		inNode.leaf = YES;				// ?? I think
	}
	
	IMBDrain(pool);
	
	if (outError) *outError = error;
	return error == nil;
}

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	IMBNode *result = [super nodeWithOldNode:inOldNode options:inOptions error:outError];
	result.groupType = kIMBGroupTypeLibrary;
	return result;
}

@end
