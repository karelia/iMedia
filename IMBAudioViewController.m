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

#import "IMBAudioViewController.h"
#import "IMBNodeViewController.h"
#import "IMBObjectArrayController.h"
#import "IMBPanelController.h"
#import "IMBCommon.h"
#import "IMBConfig.h"
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


+ (void) initialize
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSMutableDictionary* classDict = [NSMutableDictionary dictionary];
	[classDict setObject:[NSNumber numberWithUnsignedInteger:kIMBObjectViewTypeList] forKey:@"viewType"];
	[classDict setObject:[NSNumber numberWithDouble:0.5] forKey:@"iconSize"];
	[IMBConfig registerDefaultPrefs:classDict forClass:self.class];
	[pool release];
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
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
	return [[NSWorkspace imb_threadSafeWorkspace] imb_iconForAppWithBundleIdentifier:@"com.apple.iTunes"];
}

- (NSString*) displayName
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBAudioViewController.displayName",
		nil,IMBBundle(),
		@"Audio",
		@"mediaType display name");
}


//----------------------------------------------------------------------------------------------------------------------


+ (NSString*) objectCountFormatSingular
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBAudioViewController.countFormatSingular",
		nil,IMBBundle(),
		@"%d track",
		@"Format string for object count in singluar");
}

+ (NSString*) objectCountFormatPlural
{
	return NSLocalizedStringWithDefaultValue(
		@"IMBAudioViewController.countFormatPlural",
		nil,IMBBundle(),
		@"%d tracks",
		@"Format string for object count in plural");
}


//----------------------------------------------------------------------------------------------------------------------


// The Audio panel doesn't have an icon view...

- (void) setViewType:(NSUInteger)inViewType
{
	if (inViewType < 1) inViewType = 1;
	if (inViewType > 2) inViewType = 2;
	[super setViewType:inViewType];
}


- (NSUInteger) viewType
{
	NSUInteger viewType = [super viewType];
	if (viewType < 1) viewType = 1;
	if (viewType > 2) viewType = 2;
	return viewType;
}


//----------------------------------------------------------------------------------------------------------------------


// Stop playing audio as we are leaving this panel...

- (void) willHideView
{
	[self.playingAudio stop];
	self.playingAudio = nil;
}


- (IBAction) quicklook:(id)inSender
{
#if IMB_COMPILING_WITH_SNOW_LEOPARD_OR_NEWER_SDK
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		[self setIsPlaying:NO];
		[super quicklook:inSender];
	}
	else	// Don't quicklook on 10.5 .. instead, play the current selection.
#endif
	{
		[self startPlayingSelection:inSender];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark NSTableViewDelegate
 

// Upon doubleclick start playing the selection (or opens a folder in case of IMBNodeObject)...

- (IBAction) tableViewWasDoubleClicked:(id)inSender
{
	NSInteger row = [(NSTableView*)inSender clickedRow];
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	NSInteger count = [objects count];
	
	if (row>=0 && row<count)
	{
		IMBObject* object = [objects objectAtIndex:row];
		
		if ([object isKindOfClass:[IMBNodeObject class]])
		{
			[super tableViewWasDoubleClicked:inSender];		// handled in superclass
		}
		else
		{
			[self startPlayingSelection:inSender];
		}
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


- (void) setIsPlaying:(BOOL)shouldPlay
{
	if ([self isPlaying] != shouldPlay)
	{
		if (shouldPlay)
		{
			// starts playing with the current selection
			NSArray* objects = [ibObjectArrayController arrangedObjects];
			NSIndexSet* rows = [[self listView] selectedRowIndexes];
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
			[[NSNotificationCenter defaultCenter] removeObserver:self name:QTMovieDidEndNotification object:nil];	
			[self.playingAudio stop];
			self.playingAudio = nil;	
		}
	}
}


- (BOOL) isPlaying
{
	return (self.playingAudio != nil);
}


//----------------------------------------------------------------------------------------------------------------------


// Invoked e.g. when double-clicking on a specific song file. First stop any audio that may currently be playing.
// Start playing whatever the current selection is...

- (IBAction) startPlayingSelection:(id)inSender
{
	[self setIsPlaying:NO];
	[self setIsPlaying:YES];
}


- (void) playAudioObject:(IMBObject*)inObject
{
	// GarageBand files require special attention as the "playable" file resides inside the document package...
	
	NSString* path = [inObject path];

	if ([[[path pathExtension] lowercaseString] isEqualToString:@"band"])
	{
		NSString* output = [path stringByAppendingPathComponent:@"Output/Output.aif"];
		BOOL exists = [[NSFileManager imb_threadSafeManager] fileExistsAtPath:output];
		if (exists) path = output;
	}

	// Create a QTMovie for the selected item...
	
	NSError* error = nil;
	QTMovie* movie = [QTMovie movieWithFile:path error:&error];
	
	[[NSNotificationCenter defaultCenter] 
		addObserver:self 
		selector:@selector(_movieDidEnd:) 
		name:QTMovieDidEndNotification 
		object:movie];

	// Start playing it...
	
	if (error == nil)
	{
		[movie gotoBeginning];
		[movie play];
		self.playingAudio = movie;
	}
}


// When regular playback stops at end of file, reset our state so that highlight disappears on button...

- (void) _movieDidEnd:(NSNotification*)inNotification
{
	[self setIsPlaying:NO];
}


//----------------------------------------------------------------------------------------------------------------------


@end

