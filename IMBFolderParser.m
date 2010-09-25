/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithMediaType:(NSString*)inMediaType
{
	if (self = [super initWithMediaType:inMediaType])
	{
		self.fileUTI = nil;
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
	NSError* error = nil;
	NSString* path = inOldNode ? inOldNode.mediaSource : self.mediaSource;
	path = [path stringByStandardizingPath];
	
	// Check if the folder exists. If not then do not return a node...
	
	BOOL exists,directory;
	exists = [[NSFileManager imb_threadSafeManager] fileExistsAtPath:path isDirectory:&directory];
	
	if (!exists || !directory) 
	{
		return nil;
	}	

	// Create an empty root node (unpopulated and without subnodes)...
	
	IMBNode* newNode = [[[IMBNode alloc] init] autorelease];
	
	newNode.parentNode = inOldNode.parentNode;
	newNode.mediaSource = path;
	newNode.identifier = [self identifierForPath:path]; 
	newNode.name = [[NSFileManager imb_threadSafeManager] displayNameAtPath:path];
	newNode.icon = [self iconForPath:path];
	newNode.parser = self;
	newNode.leaf = NO;
	
	if (newNode.isRootNode)
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
	
	if (newNode.isRootNode)
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
	
	if (inOldNode.subNodes.count > 0 || inOldNode.objects.count > 0)
	{
		[self populateNode:newNode options:inOptions error:&error];
	}

	if (outError) *outError = error;
	return newNode;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation. Scan the folder
// for folder or for files that match our desired UTI and create an IMBObject for each file that qualifies...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	NSString* folder = inNode.mediaSource;
	NSArray* files = [[NSFileManager imb_threadSafeManager] contentsOfDirectoryAtPath:folder error:&error];
	NSAutoreleasePool* pool = nil;
	NSInteger index = 0;
	
	if (error == nil)
	{
		NSMutableArray* subnodes = [[NSMutableArray alloc] init];
		inNode.subNodes = subnodes;
		[subnodes release];
		
		NSMutableArray* objects = [[NSMutableArray alloc] initWithCapacity:files.count];
		inNode.objects = objects;
		[objects release];

		NSMutableArray* folders = [NSMutableArray array];
	
		for (NSString* file in files)
		{
			if (index%32 == 0)
			{
				IMBRelease(pool);
				pool = [[NSAutoreleasePool alloc] init];
			}
			
			// Hidden file system items (e.g. ".thumbnails") will be skipped...
			
			if (![file hasPrefix:@"."])	
			{
				NSString* path = [folder stringByAppendingPathComponent:file];
				
				// For folders will be handled later. Just remember it for now...
				
				if ([self fileAtPath:path conformToimb_doesUTI:(NSString*)kUTTypeFolder])
				{
					[folders addObject:path];
				}
				
				// Create an IMBVisualObject for each qualifying file...
				
				else if ([self fileAtPath:path conformToimb_doesUTI:_fileUTI])
				{
					IMBObject* object = [self objectForPath:path name:file index:index++];
					[objects addObject:object];
				}
			}
		}
		
		// Add a subnode and an IMBNodeObject for each folder...
				
		for (NSString* folder in folders)
		{
			if (index%32 == 0)
			{
				IMBRelease(pool);
				pool = [[NSAutoreleasePool alloc] init];
			}
			
			NSString* name = [[NSFileManager imb_threadSafeManager] displayNameAtPath:folder];
			
			IMBNode* subnode = [[IMBNode alloc] init];
			subnode.parentNode = inNode;
			subnode.mediaSource = folder;
			subnode.identifier = [[self class] identifierForPath:folder];
			subnode.name = name;
			subnode.icon = [self iconForPath:folder]; //[[NSWorkspace imb_threadSafeWorkspace] iconForFile:folder];
			subnode.parser = self;
			subnode.watchedPath = folder;				// These two lines are important to make file watching work for nested 
			subnode.watcherType = kIMBWatcherTypeNone;	// subfolders. See IMBLibrarController _reloadNodesWithWatchedPath:
			subnode.leaf = NO;
			subnode.includedInPopup = NO;
			[subnodes addObject:subnode];
			[subnode release];

			IMBNodeObject* object = [[IMBNodeObject alloc] init];
			object.location = (id)subnode;
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
	
	IMBRelease(pool);
					
	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helpers


- (BOOL) fileAtPath:(NSString*)inPath conformToimb_doesUTI:(NSString*)inRequiredUTI
{
	NSString* uti = [NSString imb_UTIForFileAtPath:inPath];
	return (BOOL) UTTypeConformsTo((CFStringRef)uti,(CFStringRef)inRequiredUTI);
}


- (NSImage*) iconForPath:(NSString*)inPath
{
	NSImage* icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:inPath];
	[icon setScalesWhenResized:YES];
	[icon setSize:NSMakeSize(16,16)];
	return icon;
}
	

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


+ (NSString*) identifierForPath:(NSString*)inPath
{
	NSString* parserClassName = NSStringFromClass([self class]);
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,inPath];
}
	

//----------------------------------------------------------------------------------------------------------------------


- (IMBObject*) objectForPath:(NSString*)inPath name:(NSString*)inName index:(NSUInteger)inIndex
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
		
		IMBNode* node = (IMBNode*) [inObject location];
		NSString* path = (NSString*) [node mediaSource];
		
		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
		[item setRepresentedObject:path];
		[item setTarget:self];
		[inMenu addItem:item];
		[item release];
	}
}


- (IBAction) revealInFinder:(id)inSender
{
	NSString* path = (NSString*)[inSender representedObject];
	NSString* folder = [path stringByDeletingLastPathComponent];
	[[NSWorkspace imb_threadSafeWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
}


//----------------------------------------------------------------------------------------------------------------------


@end
