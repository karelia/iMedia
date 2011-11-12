/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBFolderParser.h"
#import "IMBConfig.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBNodeObject.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSString+iMedia.h"
#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBFolderParser

@synthesize fileUTI = _fileUTI;
@synthesize displayPriority = _displayPriority;

//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.fileUTI = nil;
		self.displayPriority = 5;	// default middle-of-the-pack priority
	}
	
	return self;
}

- (void) dealloc
{
	IMBRelease(_fileUTI);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods

// If we were not suplied an old node, then we will just create an empty root node. If on the other hand we were
// given a node, then we will try to recreate the same node as faithfully as possible. That means is should be 
// the node with the same position/identifier, and if it was populated before, then it should also be populated 
// afterwards...

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSFileManager *fm = [NSFileManager imb_threadSafeManager];
	NSError* error = nil;
	NSString* path = inOldNode ? inOldNode.mediaSource : self.mediaSource;
	path = [path stringByStandardizingPath];
	
	// Check if the folder exists. If not then do not return a node...
	
	BOOL exists,directory;
	exists = [fm fileExistsAtPath:path isDirectory:&directory];
	
	if (!exists || !directory) 
	{
		return nil;
	}	

	// Create an empty root node (unpopulated and without subnodes)...
	
	IMBNode* newNode = [[[IMBNode alloc] init] autorelease];
	
	if ((inOldNode == nil) || (inOldNode.isTopLevelNode == YES))
	{
		newNode.isTopLevelNode = YES;
	}
	
	newNode.mediaSource = path;
	newNode.identifier = [self identifierForPath:path];
	newNode.displayPriority = self.displayPriority;			// get node's display priority from the folder parser
	if (self.custom) newNode.displayPriority = 0;			// custom nodes are always at bottom

	NSString *betterName = [fm displayNameAtPath:[path stringByDeletingPathExtension]];
    betterName = [betterName stringByReplacingOccurrencesOfString:@"_" withString:@" "];
	newNode.name = betterName;
	
	newNode.icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:path];
	[newNode.icon setScalesWhenResized:YES];
	[newNode.icon setSize:NSMakeSize(16,16)];
	newNode.parser = self;
	newNode.leaf = NO;
	
	if (newNode.isTopLevelNode)
	{
		newNode.groupType = kIMBGroupTypeFolder;
		newNode.includedInPopup = YES;
	}
	else
	{
		newNode.groupType = kIMBGroupTypeNone;
		newNode.includedInPopup = NO;
	}
	
	// Enable FSEvents based file watching for root nodes...
	
	if (newNode.isTopLevelNode)
	{
		newNode.watcherType = kIMBWatcherTypeFSEvent;
		newNode.watchedPath = path;
	}
	else
	{
		newNode.watcherType = kIMBWatcherTypeNone;
		newNode.watchedPath = inOldNode.watchedPath;
	}
	
	// If the old node was populated, then also populate the new node...
	
	if (inOldNode.isPopulated)
	{
		[self populateNewNode:newNode likeOldNode:inOldNode options:inOptions];
	}

	if (outError) *outError = error;
	return newNode;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation. Scan the folder
// for folder or for files that match our desired UTI and create an IMBObject for each file that qualifies...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSFileManager* fm = [NSFileManager imb_threadSafeManager];
	NSWorkspace* ws = [NSWorkspace imb_threadSafeWorkspace];
	NSError* error = nil;
	NSString* folder = inNode.mediaSource;
	NSAutoreleasePool* pool = nil;
	NSInteger index = 0;
	
	NSArray* files = [fm contentsOfDirectoryAtPath:folder error:&error];
	files = [files sortedArrayUsingSelector:@selector(imb_finderCompare:)];
	
	if (error == nil)
	{
		NSMutableArray* subnodes = [NSMutableArray array];
		NSMutableArray* objects = [NSMutableArray arrayWithCapacity:files.count];
		
		inNode.displayedObjectCount = 0;
		
		NSMutableArray* folders = [NSMutableArray array];
	
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
					if (![IMBConfig isLibraryPath:path])
					{
						[folders addObject:path];
					}
					else
					{
						// NSLog(@"IGNORING LIBRARY PATH: %@", path);
					}

				}
				
				// Create an IMBVisualObject for each qualifying file...
				
				else if ([NSString imb_doesFileAtPath:path conformToUTI:_fileUTI])
				{
					NSString *betterName = [fm displayNameAtPath:[file stringByDeletingPathExtension]];
					betterName = [betterName stringByReplacingOccurrencesOfString:@"_" withString:@" "];
					
					IMBObject* object = [self objectForPath:path name:betterName index:index++];
					[objects addObject:object];
					inNode.displayedObjectCount++;
				}
			}
		}
		
		// Add a subnode and an IMBNodeObject for each folder...
				
		for (NSString* folder in folders)
		{
			if (index%32 == 0)
			{
				IMBDrain(pool);
				pool = [[NSAutoreleasePool alloc] init];
			}
			
			NSString* name = [fm displayNameAtPath:folder];
			BOOL isPackage = [ws isFilePackageAtPath:folder];
			
			if (!isPackage)
			{
				IMBNode* subnode = [[IMBNode alloc] init];
				subnode.mediaSource = folder;
				subnode.identifier = [[self class] identifierForPath:folder];
				subnode.name = name;
				subnode.icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:folder];
				[subnode.icon setScalesWhenResized:YES];
				[subnode.icon setSize:NSMakeSize(16,16)];
				subnode.parser = self;
				subnode.watchedPath = folder;				// These two lines are important to make file watching work for nested 
				subnode.watcherType = kIMBWatcherTypeNone;	// subfolders. See IMBLibraryController _reloadNodesWithWatchedPath:
				
				// Should this folder be a leaf or not?  We are going to have to scan into the directory
			
				NSArray* folderContents = [fm contentsOfDirectoryAtPath:folder error:&error];	// When we go 10.6 only, use better APIs.
				BOOL hasSubDir = NO;
				int fileCounter = 0;	// bail if this is a really full folder
				
				if (folderContents)
				{
					for (NSString *isThisADirectory in folderContents)
					{
						NSString* path = [folder stringByAppendingPathComponent:isThisADirectory];
						[fm fileExistsAtPath:path isDirectory:&hasSubDir];
						fileCounter++;
						
						// Would it be faster to use attributesOfItemAtPath:error: ????
						if (hasSubDir)
						{
							hasSubDir = YES;
							break;	// Yes, found a subdir, so we want a disclosure triangle on this
						}
						else if (fileCounter > 100)
						{
							hasSubDir = YES;	// just in case, assume there is a subfolder there
							break;
						}
					}
				}
				subnode.leaf = !hasSubDir;	// if it doesn't have a subdirectory, treat it as a leaf
				subnode.includedInPopup = NO;
				[subnodes addObject:subnode];
				[subnode release];

				IMBNodeObject* object = [[IMBNodeObject alloc] init];
				object.representedNodeIdentifier = subnode.identifier;
				object.name = name;
				object.metadata = nil;
				object.parser = self;
				object.index = index++;
				object.imageLocation = (id)folder;
				object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
				object.imageRepresentation = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:folder];

				[objects addObject:object];
				[object release];
			}
		}
		
		inNode.subnodes = subnodes;
		inNode.objects = objects;
		inNode.leaf = [subnodes count] == 0;
	}
	
	IMBDrain(pool);
					
	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helpers

// To be overridden by subclass...
	
- (NSDictionary*) metadataForFileAtPath:(NSString*)inPath
{
	return nil;
}


// To be overridden by subclass...
	
- (NSString*) metadataDescriptionForMetadata:(NSDictionary*)inMetadata
{
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


- (IMBObject*) objectForPath:(NSString*)inPath name:(NSString*)inName index:(NSUInteger)inIndex;
{
	IMBObject* object = [[[IMBObject alloc] init] autorelease];
	object.location = (id)inPath;
	object.name = inName;
	object.parser = self;
	object.index = inIndex;
	
	object.imageRepresentationType = IKImageBrowserCGImageRepresentationType; 
	object.imageLocation = inPath;
	object.imageRepresentation = nil;		// will be loaded lazily when needed
	object.metadata = nil;					// will be loaded lazily when needed
	
	return object;
}


// Loaded lazily when actually needed for display. This method may be called on a background thread, 
// so setters should only be called to the main thread...

- (void) loadMetadataForObject:(IMBObject*)inObject
{
	if (![inObject isKindOfClass:[IMBNodeObject class]])
	{
		NSDictionary* metadata = [self metadataForFileAtPath:inObject.path];
		NSString* description = [self metadataDescriptionForMetadata:metadata];
		
		if ([NSThread isMainThread])
		{
			inObject.metadata = metadata;
			inObject.metadataDescription = description;
		}
		else
		{
			NSArray* modes = [NSArray arrayWithObject:NSRunLoopCommonModes];
			[inObject performSelectorOnMainThread:@selector(setMetadata:) withObject:metadata waitUntilDone:NO modes:modes];
			[inObject performSelectorOnMainThread:@selector(setMetadataDescription:) withObject:description waitUntilDone:NO modes:modes];
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Add a 'Reveal in Finder' command to the context menu...

- (void) willShowContextMenu:(NSMenu*)inMenu forObject:(IMBObject*)inObject
{
	if ([inObject isKindOfClass:[IMBNodeObject class]])
	{
		NSString* title = NSLocalizedStringWithDefaultValue(
			@"IMBObjectViewController.menuItem.revealInFinder",
			nil,IMBBundle(),
			@"Reveal in Finder",
			@"Menu item in context menu of IMBObjectViewController");
		
		IMBNode* node = [self nodeWithIdentifier:((IMBNodeObject*)inObject).representedNodeIdentifier];
		NSString* path = (NSString*) [node mediaSource];
		
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
		[item setRepresentedObject:path];
		[item setTarget:self];
		[inMenu addItem:item];
		[item release];
	}
}


- (void) willShowContextMenu:(NSMenu*)inMenu forNode:(IMBNode*)inNode
{
	NSString* title = NSLocalizedStringWithDefaultValue(
		@"IMBObjectViewController.menuItem.revealInFinder",
		nil,IMBBundle(),
		@"Reveal in Finder",
		@"Menu item in context menu of IMBObjectViewController");
	
	NSString* path = (NSString*) [inNode mediaSource];
	
	NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
	[item setRepresentedObject:path];
	[item setTarget:self];
	[inMenu addItem:item];
	[item release];
}


- (IBAction) revealInFinder:(id)inSender
{
	NSString* path = (NSString*)[inSender representedObject];
	NSString* folder = [path stringByDeletingLastPathComponent];
	[[NSWorkspace imb_threadSafeWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
}


//----------------------------------------------------------------------------------------------------------------------


@end
