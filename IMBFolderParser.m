/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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


#pragma mark HEADERS

#import "IMBFolderParser.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "NSFileManager+iMedia.h"
#import "NSWorkspace+iMedia.h"
#import "NSString+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBFolderParser

@synthesize fileUTI = _fileUTI;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		_fileUTI = nil;
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


- (IMBNode*) createNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError;
{
	NSError* error = nil;
	NSString* path = inOldNode ? inOldNode.mediaSource : self.mediaSource;
	path = [path stringByStandardizingPath];
	
	// Create an empty root node (unpopulated and without subnodes)...
	
	IMBNode* newNode = [[IMBNode alloc] init];
	
	newNode.parentNode = inOldNode.parentNode;
	newNode.mediaSource = path;
	newNode.identifier = [self identifierForPath:path]; 
	newNode.name = [[NSFileManager threadSafeManager] displayNameAtPath:path];
	newNode.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:path];
	newNode.parser = self;
	newNode.leaf = NO;

	// Enable FSEvents based file watching for root nodes...
	
	if (newNode.parentNode == nil)
	{
		newNode.watcherType = kIMBWatcherTypeFSEvent;
		newNode.watchedPath = path;
	}
	else
	{
		newNode.watcherType = kIMBWatcherTypeNone;
	}
	
	// If the old node had subnodes, then look for subnodes in the new node...
	
	if ([inOldNode.subNodes count] > 0)
	{
		[self expandNode:newNode options:inOptions error:&error];
	}
	
	// If the old node was populated, then also populate the new node...
	
	if ([inOldNode.objects count] > 0)
	{
		[self populateNode:newNode options:inOptions error:&error];
	}

	
	if (outError) *outError = error;
	return newNode;
}


//----------------------------------------------------------------------------------------------------------------------


// Scan the our folder for subfolders and add a subnode for each one we find...

- (BOOL) expandNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	NSString* folder = inNode.mediaSource;
	NSArray* files = [[NSFileManager threadSafeManager] contentsOfDirectoryAtPath:folder error:&error];
	
	if (error == nil)
	{
		NSMutableArray* subnodes = [NSMutableArray array];
		
		for (NSString* file in files)
		{
			NSString* path = [folder stringByAppendingPathComponent:file];
			
			if ([self fileAtPath:path conformsToUTI:(NSString*)kUTTypeFolder])
			{
				NSString* parserClassName = NSStringFromClass([self class]);
				
				IMBNode* subnode = [[IMBNode alloc] init];

				subnode.parentNode = inNode;
				subnode.mediaSource = path;
				subnode.identifier = [NSString stringWithFormat:@"%@:/%@",parserClassName,path];
				subnode.name = [[NSFileManager threadSafeManager] displayNameAtPath:path];
				subnode.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:path];
				subnode.parser = self;
				subnode.leaf = NO;
				
				[subnodes addObject:subnode];
				[subnode release];
			}
		}
		
		inNode.subNodes = subnodes;
	}
	
	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation. Scan the folder
// for files that match our desired UTI and create an IMBObject for each file that qualifies...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	// Get the contents of our folder...
	
	NSString* folder = inNode.mediaSource;
	NSArray* files = [[NSFileManager threadSafeManager] contentsOfDirectoryAtPath:folder error:&error];
	
	// Populate the node with one IMBObject per file. If we encounter a folder, then add a subnode...
	
	if (error == nil)
	{
		NSMutableArray* objects = [[NSMutableArray alloc] initWithCapacity:files.count];
		inNode.objects = objects;
		[objects release];

		for (NSString* file in files)
		{
			NSString* path = [folder stringByAppendingPathComponent:file];
			
			// For each file with matching UTI add an IMBObject...
			
			if ([self fileAtPath:path conformsToUTI:_fileUTI])
			{
				IMBObject* object = [[IMBObject alloc] init];
				object.value = (id)path;
				object.name = file;
				object.metadata = [self metadataForFileAtPath:path];
				
				[objects addObject:object];
				[object release];
			}
			
//			// For each folder add a subnode ...
//			
//			else if ([self fileAtPath:path conformsToUTI:(NSString*)kUTTypeFolder])
//			{
//				NSString* parserClassName = NSStringFromClass([self class]);
//				
//				IMBNode* subnode = [[IMBNode alloc] init];
//				subnode.identifier = [NSString stringWithFormat:@"%@:/%@",parserClassName,path];
//				subnode.name = [[NSFileManager threadSafeManager] displayNameAtPath:path];
//				subnode.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:path];
//				subnode.parser = self;
//				
//				[(NSMutableArray*)inNode.subNodes addObject:subnode];
//			}
		}
	}
	
	// Return error...
	
	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Helpers


- (BOOL) fileAtPath:(NSString*)inPath conformsToUTI:(NSString*)inRequiredUTI
{
	NSString* uti = [NSString UTIForFileAtPath:inPath];
	return (BOOL) UTTypeConformsTo((CFStringRef)uti,(CFStringRef)inRequiredUTI);
}


- (NSDictionary*) metadataForFileAtPath:(NSString*)inPath
{
	// To be overridden by subclass...
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end
