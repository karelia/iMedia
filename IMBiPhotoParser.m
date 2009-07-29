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

#import "IMBiPhotoParser.h"
#import "IMBNode.h"
#import "IMBParserController.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBiPhotoParser

@synthesize plist = _plist;


//----------------------------------------------------------------------------------------------------------------------


// Register this parser, so that it gets automatically loaded...

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBPhotosMediaType];
	[pool release];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		_plist = nil;
		self.mediaSource = nil;
		
		// Find the path to the first iPhoto library...
		
		CFArrayRef recentLibraries = CFPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",(CFStringRef)@"com.apple.iApps");
		NSArray* libraries = (NSArray*)recentLibraries;
		
		for (NSString* library in libraries)
		{
			NSURL* url = [NSURL URLWithString:library];
			self.mediaSource = [url path];
			break;
		}
		
		CFRelease(recentLibraries);
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_plist);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Parser Methods


- (IMBNode*) createNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError;
{
	NSError* error = nil;
	
	if (self.mediaSource == nil)
	{
		return nil;
	}
	
	// Create an empty root node (unpopulated and without subnodes)...
	
	IMBNode* newNode = [[IMBNode alloc] init];
	
	newNode.parentNode = inOldNode.parentNode;
	newNode.mediaSource = self.mediaSource;
	newNode.identifier = [self identifierForPath:@"/"];
	newNode.name = @"iPhoto";
//	newNode.icon = [[NSWorkspace threadSafeWorkspace] iconForFile:path];
	newNode.parser = self;
	newNode.leaf = NO;

//	// Enable FSEvents based file watching for root nodes...
//	
//	if (newNode.parentNode == nil)
//	{
//		newNode.watcherType = kIMBWatcherTypeFSEvent;
//		newNode.watchedPath = path;
//	}
//	else
//	{
//		newNode.watcherType = kIMBWatcherTypeNone;
//	}
//	
//	// If the old node had subnodes, then look for subnodes in the new node...
//	
//	if ([inOldNode.subNodes count] > 0)
//	{
//		[self expandNode:newNode options:inOptions error:&error];
//	}
//	
//	// If the old node was populated, then also populate the new node...
//	
//	if ([inOldNode.objects count] > 0)
//	{
//		[self populateNode:newNode options:inOptions error:&error];
//	}
	
	if (outError) *outError = error;
	return newNode;
}


//----------------------------------------------------------------------------------------------------------------------


// Scan the our folder for subfolders and add a subnode for each one we find...

- (BOOL) expandNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
	
	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


// The supplied node is a private copy which may be modified here in the background operation. Scan the folder
// for files that match our desired UTI and create an IMBObject for each file that qualifies...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	NSError* error = nil;
		
	// Return error...
	
	if (outError) *outError = error;
	return error == nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end
