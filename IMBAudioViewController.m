/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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

#import "IMBAudioViewController.h"
#import "IMBNodeViewController.h"
#import "IMBCommon.h"
#import "IMBObject.h"
#import "IMBNode.h"
#import "IMBFolderParser.h"
#import "NSWorkspace+iMedia.h"
#import <QTKit/QTKit.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBAudioViewController

@synthesize playingAudio = _playingAudio;


//----------------------------------------------------------------------------------------------------------------------


- (void) dealloc
{
	IMBRelease(_playingAudio);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) mediaType
{
	return kIMBMediaTypeAudio;
}


+ (NSString*) nibName
{
	return @"IMBAudioView";
}


//----------------------------------------------------------------------------------------------------------------------


- (NSImage*) icon
{
	return [[NSWorkspace threadSafeWorkspace] iconForAppWithBundleIdentifier:@"com.apple.iTunes"];
}


- (NSString*) displayName
{
	return NSLocalizedStringWithDefaultValue(
		@"AudioDisplayName",
		nil,IMBBundle(),
		@"Audio",
		@"mediaType display name");
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) objectCountFormatSingular
{
	return NSLocalizedStringWithDefaultValue(
		@"AudioCountFormatSingular",
		nil,IMBBundle(),
		@"%d song",
		@"Format string for object count in singluar");
}


+ (NSString*) objectCountFormatPlural
{
	return NSLocalizedStringWithDefaultValue(
		@"AudioCountFormatPlural",
		nil,IMBBundle(),
		@"%d songs",
		@"Format string for object count in plural");
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTableViewDelegate
 

// Upon doubleclick start playing the selection...

- (IBAction) tableViewWasDoubleClicked:(id)inSender
{
//	IMBNode* selectedNode = [_nodeViewController selectedNode];
	NSIndexSet* rows = [ibListView selectedRowIndexes];
	NSUInteger row = [rows firstIndex];
		
	while (row != NSNotFound)
	{
		IMBObject* object = (IMBObject*) [[ibObjectArrayController arrangedObjects] objectAtIndex:row];

		if ([object isKindOfClass:[IMBNodeObject class]])
		{
			IMBNode* node = (IMBNode*)object.value;
			[_nodeViewController expandSelectedNode];
			[_nodeViewController selectNode:node];
		}
		else
		{
			[self play:inSender];
			return;
		}
		
		row = [rows indexGreaterThanIndex:row];
	}
}


// If we already has some audio playing, then play the new song if the selection changes...

- (void) tableViewSelectionDidChange:(NSNotification*)inNotification
{
	if (self.playingAudio.rate > 0.0)
	{
		[self play:nil];
	}
	else
	{
		self.playingAudio = nil;
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) play:(id)inSender
{
	// First stop any audio that may currently be playing...
	
	[self.playingAudio stop];
	self.playingAudio = nil;
	
	// Start playing what the new selection...
	
	NSIndexSet* rows = [ibListView selectedRowIndexes];
	NSUInteger row = [rows firstIndex];
		
	if (row != NSNotFound)
	{
		IMBObject* object = (IMBObject*) [[ibObjectArrayController arrangedObjects] objectAtIndex:row];
		[self playAudioObject:object];
	}
}


- (void) playAudioObject:(IMBObject*)inObject
{
	// Create a QTMovie for the selected item...
	
	NSError* error = nil;
	QTMovie* movie = nil;
	
	if ([inObject.value isKindOfClass:[NSString class]])
	{
		NSString* path = (NSString*)[inObject value];
		movie = [QTMovie movieWithFile:path error:&error];
	}
	else if ([inObject.value isKindOfClass:[NSURL class]])
	{
		NSURL* url = (NSURL*)[inObject value];
		movie = [QTMovie movieWithURL:url error:&error];
	}
	
	// Start playing it...
	
	if (error == nil)
	{
		[movie gotoBeginning];
		[movie play];
		self.playingAudio = movie;
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end

