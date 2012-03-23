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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBFolderParserMessenger.h"
#import "IMBFolderParser.h"
#import "SBUtilities.h"
#import <XPCKit/XPCKit.h>

//#import "IMBConfig.h"
#import "IMBNode.h"
#import "IMBObject.h"
//#import "IMBNodeObject.h"
//#import "NSFileManager+iMedia.h"
//#import "NSWorkspace+iMedia.h"
//#import "NSString+iMedia.h"
//#import <Quartz/Quartz.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBFolderParserMessenger

@synthesize fileUTI = _fileUTI;
@synthesize displayPriority = _displayPriority;


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) parserClassName
{
	return @"IMBFolderParser";
}

					
+ (NSString*) identifier
{
	return @"com.karelia.imedia.folder";
}


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
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


- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super initWithCoder:inCoder]))
	{
		self.fileUTI = [inCoder decodeObjectForKey:@"fileUTI"];
		self.displayPriority = [inCoder decodeIntegerForKey:@"displayPriority"];
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[super encodeWithCoder:inCoder];
	[inCoder encodeObject:self.fileUTI forKey:@"fileUTI"];
	[inCoder encodeInteger:self.displayPriority forKey:@"displayPriority"];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
	IMBFolderParserMessenger* copy = (IMBFolderParserMessenger*)[super copyWithZone:inZone];
	
	copy.fileUTI = self.fileUTI;
	copy.displayPriority = self.displayPriority;
	
	return copy;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark XPC Methods


// This method is called on the XPC service side. The default implementation just returns a single parser instance. 
// Subclasses like iPhoto, Aperture, or Lightroom may opt to return multiple instances (preconfigured with correct 
// mediaSource) if multiple libraries are detected...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
	IMBFolderParser* parser = (IMBFolderParser*)[self newParser];
	parser.identifier = [[self class] identifier];
	parser.mediaType = self.mediaType;
	parser.mediaSource = self.mediaSource;
	parser.fileUTI = self.fileUTI;
	parser.displayPriority = self.displayPriority;
	parser.isUserAdded = self.isUserAdded;
	
	NSArray* parsers = [NSArray arrayWithObject:parser];
	[parser release];
	return parsers;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark App Methods


// Add a 'Show in Finder' command to the context menu...

- (void) willShowContextMenu:(NSMenu*)inMenu forNode:(IMBNode*)inNode
{
	NSString* title = NSLocalizedStringWithDefaultValue(
		@"IMBObjectViewController.menuItem.revealInFinder",
		nil,IMBBundle(),
		@"Show in Finder",
		@"Menu item in context menu of IMBObjectViewController");
	
	NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
	[item setRepresentedObject:inNode.mediaSource];
	[item setTarget:self];
	[inMenu addItem:item];
	[item release];
}


- (void) willShowContextMenu:(NSMenu*)inMenu forObject:(IMBObject*)inObject
{
//	if ([inObject isKindOfClass:[IMBNodeObject class]])
//	{
//		NSString* title = NSLocalizedStringWithDefaultValue(
//			@"IMBObjectViewController.menuItem.revealInFinder",
//			nil,IMBBundle(),
//			@"Show in Finder",
//			@"Menu item in context menu of IMBObjectViewController");
//		
//		IMBNode* node = [self nodeWithIdentifier:((IMBNodeObject*)inObject).representedNodeIdentifier];
//		NSString* path = (NSString*) [node mediaSource];
//		
//		NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title action:@selector(revealInFinder:) keyEquivalent:@""];
//		[item setRepresentedObject:path];
//		[item setTarget:self];
//		[inMenu addItem:item];
//		[item release];
//	}
}


- (IBAction) revealInFinder:(id)inSender
{
	NSURL* url = (NSURL*)[inSender representedObject];
	NSString* path = [url path];
	NSString* folder = [path stringByDeletingLastPathComponent];
	[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:folder];
}


//----------------------------------------------------------------------------------------------------------------------


@end
