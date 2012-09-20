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


//----------------------------------------------------------------------------------------------------------------------


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBAudioObjectViewController.h"
#import "IMBNodeViewController.h"
#import "IMBAccessRightsViewController.h"
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

@interface IMBObjectViewController ()
- (IBAction) tableViewWasDoubleClicked:(id)inSender;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBAudioObjectViewController

@synthesize audioPlayer = _audioPlayer;


//----------------------------------------------------------------------------------------------------------------------


+ (void) load
{
	[IMBObjectViewController registerObjectViewControllerClass:[self class] forMediaType:kIMBMediaTypeAudio];
}


+ (void) initialize
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSMutableDictionary* classDict = [NSMutableDictionary dictionary];
	[classDict setObject:[NSNumber numberWithUnsignedInteger:kIMBObjectViewTypeList] forKey:@"viewType"];
	[classDict setObject:[NSNumber numberWithDouble:0.5] forKey:@"iconSize"];
	[IMBConfig registerDefaultPrefs:classDict forClass:self.class];
	[pool drain];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) awakeFromNib
{
	[super awakeFromNib];
	
	ibObjectArrayController.searchableProperties = [NSArray arrayWithObjects:
		@"name",
		@"metadata.artist",
		@"metadata.album",
		@"preliminaryMetadata.artist",
		@"preliminaryMetadata.album",
		nil];
										  
	[[[ibListView tableColumnWithIdentifier:@"name"] headerCell] setStringValue:NSLocalizedStringWithDefaultValue(
		@"IMBAudioViewController.tableColumn.name", 
		nil,IMBBundle(), 
		@"Name", 
		@"Column title - should be a short word")];
			
	[[[ibListView tableColumnWithIdentifier:@"artist"] headerCell] setStringValue: NSLocalizedStringWithDefaultValue(
		@"IMBAudioViewController.tableColumn.artist", 
		nil,IMBBundle(), 
		@"Artist", 
		@"Column title - should be a short word")];
			
	[[[ibListView tableColumnWithIdentifier:@"duration"] headerCell] setStringValue: NSLocalizedStringWithDefaultValue(
		@"IMBAudioViewController.tableColumn.time", 
		nil,IMBBundle(), 
		@"Time", 
		@"Column title - should be a short word")];
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	IMBRelease(_audioPlayer);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 
#pragma mark Customize Subclass


+ (NSString*) mediaType
{
	return kIMBMediaTypeAudio;
}

+ (NSString*) nibName
{
	return @"IMBAudioObjectViewController";
}


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


#pragma mark 
#pragma mark Play Audio
 

// Upon doubleclick start playing the selection (or opens a folder in case of IMBNodeObject)...

- (IBAction) tableViewWasDoubleClicked:(id)inSender
{
	NSTableView* view = (NSTableView*)inSender;
	NSInteger row = [view clickedRow];
	NSRect rect = [self iconRectForTableView:view row:row inset:16.0];
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
			if (object != nil)
			{
                switch (object.accessibility)
				{
                    case kIMBResourceDoesNotExist:
					[IMBAccessRightsViewController showMissingResourceAlertForObject:object view:view relativeToRect:rect];
					break;
					
                    case kIMBResourceNoPermission:
					[[IMBAccessRightsViewController sharedViewController] grantAccessRightsForObjectsOfNode:self.currentNode];
					break;
					
                    case kIMBResourceIsAccessible:
					[self startPlayingSelection:inSender];
					break;
                        
                    default:
					break;
                }
			}
		}
	}
}


// If we already has some audio playing, then play the new song if the selection changes...

- (void) tableViewSelectionDidChange:(NSNotification*)inNotification
{
	NSTableView* tableview = (NSTableView*)inNotification.object;
	NSInteger row = [tableview selectedRow];
//	NSRect rect = [self iconRectForTableView:tableview row:row inset:16.0];
	NSArray* objects = [ibObjectArrayController arrangedObjects];
	IMBObject* object = row>=0 ? [objects objectAtIndex:row] : nil;
	
    if (object != nil)
    {
        switch (object.accessibility)
		{
            case kIMBResourceDoesNotExist:
//			[IMBAccessRightsViewController showMissingResourceAlertForObject:object view:tableview relativeToRect:rect];
			break;
			
            case kIMBResourceNoPermission:
			[[IMBAccessRightsViewController sharedViewController] grantAccessRightsForObjectsOfNode:self.currentNode];
			break;
			
            case kIMBResourceIsAccessible:
			if (self.audioPlayer.rate > 0.0) [self startPlayingSelection:nil];
			break;
                
            default:
			break;
        }
    }
	else
	{
		self.audioPlayer = nil;
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Invoked e.g. when double-clicking on a specific audio file. First stop any audio that may currently be playing.
// Start playing whatever the current selection is...

- (IBAction) startPlayingSelection:(id)inSender
{
	[self setIsPlaying:NO];
	[self setIsPlaying:YES];
}


//----------------------------------------------------------------------------------------------------------------------


// Starts playing with the current selection...
			
- (void) setIsPlaying:(BOOL)inPlaying
{
	if ([self isPlaying] != inPlaying)
	{
		if (inPlaying)
		{
			NSArray* objects = [ibObjectArrayController arrangedObjects];
			NSIndexSet* rows = [[self listView] selectedRowIndexes];
			NSUInteger row = [rows firstIndex];
				
			if (row != NSNotFound && row < [objects count])
			{
				IMBObject* object = (IMBObject*) [objects objectAtIndex:row];

				if (object.accessibility == kIMBResourceDoesNotExist)
				{
					[IMBAccessRightsViewController showMissingResourceAlertForObject:object view:nil relativeToRect:NSZeroRect];
				}
				else if (object.accessibility == kIMBResourceNoPermission)
				{
					[[IMBAccessRightsViewController sharedViewController] grantAccessRightsForObjectsOfNode:self.currentNode];
				}
				else
				{
					[self playAudioObject:object];
				}
			}
		}
		else
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:QTMovieDidEndNotification object:nil];	
			[self.audioPlayer stop];

			[self willChangeValueForKey:@"isPlaying"];
			self.audioPlayer = nil;	
			[self didChangeValueForKey:@"isPlaying"];
		}
	}
}


- (BOOL) isPlaying
{
	return (self.audioPlayer != nil);
}


//----------------------------------------------------------------------------------------------------------------------


- (void) playAudioObject:(IMBObject*)inObject
{
	// Since we may be running in a sandbox, we have to request a bookmark and resolve, in order to gain 
	// access to the audio file...
	
	[inObject requestBookmarkWithCompletionBlock:^(NSError* inError)
	{
		NSError* error = inError;
		NSURL* url = nil;
		QTMovie* movie = nil;
		
		// Get the URL for the audio file. GarageBand files require special attention as the "playable"  
		// file resides inside the document package...
			
		if (error == nil)
		{
			url = [inObject URLByResolvingBookmark];
			
			if ([[[url pathExtension] lowercaseString] isEqualToString:@"band"])
			{
				NSURL* output = [url URLByAppendingPathComponent:@"Output/Output.aif"];
				BOOL exists = [url checkResourceIsReachableAndReturnError:NULL];
				if (exists) url = output;
			}
		}	

		// Create a QTMovie for the selected item...
			
		if (error == nil)
		{
			movie = [QTMovie movieWithURL:url error:&error];
			
			[[NSNotificationCenter defaultCenter] 
				addObserver:self 
				selector:@selector(_movieDidEnd:) 
				name:QTMovieDidEndNotification 
				object:movie];
		}
		
		// Start playing it...
		
		if (movie)
		{
			[movie gotoBeginning];
			[movie play];
			
			[self willChangeValueForKey:@"isPlaying"];
			self.audioPlayer = movie;
			[self didChangeValueForKey:@"isPlaying"];
		}
		
		// Handle errors...
		
		else
		{
			dispatch_async(dispatch_get_main_queue(),^()
			{
				[NSApp presentError:error];
			});
		}
	}];
}


//----------------------------------------------------------------------------------------------------------------------


// When regular playback stops at end of file, reset our state so that highlight disappears on button...

- (void) _movieDidEnd:(NSNotification*)inNotification
{
	[self setIsPlaying:NO];
}


//----------------------------------------------------------------------------------------------------------------------


// Stop playing audio when we are leaving this panel...

- (void) willHideView
{
	[self.audioPlayer stop];
	self.audioPlayer = nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Stop playing audio when Quicklook panel is shown...

- (IBAction) quicklook:(id)inSender
{
	[self setIsPlaying:NO];
	[super quicklook:inSender];
}


//----------------------------------------------------------------------------------------------------------------------


@end

