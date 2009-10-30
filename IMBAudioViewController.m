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
#import "IMBObjectArrayController.h"
#import "IMBPanelController.h"
#import "IMBCommon.h"
#import "IMBObject.h"
#import "IMBNode.h"
#import "IMBNodeObject.h"
#import "IMBFolderParser.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import <QTKit/QTKit.h>


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBAudioViewController

@synthesize playingAudio = _playingAudio;


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
	[IMBPanelController registerViewControllerClass:[self class] forMediaType:kIMBMediaTypeAudio];
}


- (void) awakeFromNib
{
	[super awakeFromNib];
	
	ibObjectArrayController.searchableProperties = [NSArray arrayWithObjects:
		@"name",
		@"metadata.artist",
		@"metadata.album",
		nil];
}


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


- (void) willHideView
{
	[self.playingAudio stop];
	self.playingAudio = nil;
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
			IMBNode* node = (IMBNode*)object.location;
			[_nodeViewController expandSelectedNode];
			[_nodeViewController selectNode:node];
		}
		else
		{
			[self startPlayingSelection:inSender];
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
		[self startPlayingSelection:nil];
	}
	else
	{
		self.playingAudio = nil;
	}
}


//----------------------------------------------------------------------------------------------------------------------

- (BOOL) isPlaying
{
	return (self.playingAudio != nil);
}

- (void) setIsPlaying:(BOOL)shouldPlay
{
	if ([self isPlaying] != shouldPlay)
	{
		if (shouldPlay)
		{
			// starts playing with the current selection
			NSArray* objects = [ibObjectArrayController arrangedObjects];
			NSIndexSet* rows = [ibListView selectedRowIndexes];
			NSUInteger row = [rows firstIndex];
				
			if (row != NSNotFound && row < [objects count])
			{
				IMBObject* object = (IMBObject*) [objects objectAtIndex:row];
				
				// Sets self.playingAudio 
				[self playAudioObject:object];
			}
		}
		else
		{
			[self.playingAudio stop];
			self.playingAudio = nil;		
		}
	}
}

// Invoked e.g. when double-clicking on a specific song file
- (IBAction) startPlayingSelection:(id)inSender
{
	// First stop any audio that may currently be playing...
	[self setIsPlaying:NO];
	
	// Start playing whatever the current selection is...
	[self setIsPlaying:YES];
}


- (void) playAudioObject:(IMBObject*)inObject
{
	// GarageBand files require special attention as the "playable" file resides inside the document package...
	
	NSString* path = [inObject path];

	if ([[[path pathExtension] lowercaseString] isEqualToString:@"band"])
	{
		NSString* output = [path stringByAppendingPathComponent:@"Output/Output.aif"];
		BOOL exists = [[NSFileManager threadSafeManager] fileExistsAtPath:output];
		if (exists) path = output;
	}

	// Create a QTMovie for the selected item...
	
	NSError* error = nil;
	QTMovie* movie = [QTMovie movieWithFile:path error:&error];
	
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

