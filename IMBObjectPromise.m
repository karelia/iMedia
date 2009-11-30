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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBObjectPromise.h"
#import "IMBCommon.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBNOdeObject.h"
#import "IMBParser.h"
#import "IMBConfig.h"
#import "IMBOperationQueue.h"
#import "IMBLibraryController.h"
#import "IMBURLDownloadOperation.h"
#import "NSFileManager+iMedia.h"
#import "NSData+SKExtensions.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS
	
NSString* kIMBObjectPromiseType = @"com.karelia.imedia.IMBObjectPromiseType";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBObjectPromise ()
- (void) _countObjects:(NSArray*)inObjects;
- (void) loadObjects:(NSArray*)inObjects;
- (void) _loadObject:(IMBObject*)inObject;
- (void) _didFinish;

@property (retain) NSMutableDictionary* objectsToLocalURLs;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBObjectPromise

@synthesize objectsToLocalURLs = _objectsToLocalURLs;
@synthesize downloadFolderPath = _downloadFolderPath;
@synthesize error = _error;
@synthesize delegate = _delegate;
@synthesize finishSelector = _finishSelector;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithObjects:(NSArray*)inObjects
{
	if (self = [super init])
	{
		self.objectsToLocalURLs = [NSMutableDictionary dictionaryWithCapacity:inObjects.count];

		// Start our mapping with all null objects (need to fulfill these promises)
		for (IMBObject* thisObject in inObjects)
		{
			[self.objectsToLocalURLs setObject:[NSNull null] forKey:thisObject];
		}
		
		self.downloadFolderPath = [IMBConfig downloadFolderPath];
		self.error = nil;
		self.delegate = nil;
		self.finishSelector = NULL;

		_objectCountTotal = 0;
		_objectCountLoaded = 0;
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super init])
	{
		self.objectsToLocalURLs = [inCoder decodeObjectForKey:@"objectsToLocalURLs"];
		self.downloadFolderPath = [IMBConfig downloadFolderPath];
		self.delegate = nil;
		self.finishSelector = NULL;
		self.error = nil;

		_objectCountTotal = 0;
		_objectCountLoaded = 0;
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[inCoder encodeObject:self.objectsToLocalURLs forKey:@"objectsToLocalURLs"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBObjectPromise* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.objectsToLocalURLs = self.objectsToLocalURLs;
	copy.downloadFolderPath = self.downloadFolderPath;
	copy.error = self.error;
	copy.delegate = self.delegate;
	copy.finishSelector = self.finishSelector;
	
	return copy;
}


- (void) dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	IMBRelease(_objectsToLocalURLs);
	IMBRelease(_downloadFolderPath);
	IMBRelease(_delegate);
	IMBRelease(_error);
	
	[super dealloc];
} 

//----------------------------------------------------------------------------------------------------------------------


- (NSArray*) objects
{
	return [self.objectsToLocalURLs allKeys];
}


- (NSArray*) localURLs
{
	return [self.objectsToLocalURLs allValues];
}


- (NSURL*) localURLForObject:(IMBObject*)inObject
{
	NSURL* foundURL = [self.objectsToLocalURLs objectForKey:inObject];
	if ([foundURL isKindOfClass:[NSNull class]])
	{
		foundURL = nil;
	}
	
	return foundURL;
}


//----------------------------------------------------------------------------------------------------------------------


// Count the eligible objects in the array...

- (void) _countObjects:(NSArray*)inObjects
{
	for (IMBObject* object in inObjects)
	{
		if (![object isKindOfClass:[IMBNodeObject class]])
		{
			_objectCountTotal++;
		}
	}
}


// Load all eligible objects in the array...

- (void) loadObjects:(NSArray*)inObjects
{
	for (IMBObject* object in inObjects)
	{
		if (![object isKindOfClass:[IMBNodeObject class]])
		{
			[self _loadObject:object];
		}
	}
}


// Load the specified object...

- (void) _loadObject:(IMBObject*)inObject
{
	// To be overridden by subclass...
}


// Notify the delegate that loading is done...

- (void) _didFinish
{
	if (_delegate != nil)
	{
		if ([_delegate respondsToSelector:_finishSelector]) 
		{
			if ([NSThread isMainThread])
			{
				[_delegate performSelector:_finishSelector withObject:self withObject:self.error];
			}
			else
			{
				[_delegate 
					performSelectorOnMainThread:_finishSelector 
					withObject:self 
					waitUntilDone:NO 
					modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
			}	
		}	
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Start loading the objects...

- (void) startLoadingWithDelegate:(id)inDelegate finishSelector:(SEL)inSelector
{
	self.delegate = inDelegate;
	self.finishSelector = inSelector;
	[self _countObjects:self.objects];
	[self loadObjects:self.objects];
}


// Spin a runloop (blocking the caller) until all objects are available...

- (void) waitUntilDone
{
	while (_objectCountLoaded < _objectCountTotal)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		[[NSRunLoop currentRunLoop] 
			runMode:NSModalPanelRunLoopMode 
			beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
			
		[pool release];
	}
}

@end


//----------------------------------------------------------------------------------------------------------------------


// A promise for local objects doesn't really have to do any work since no loading is required. It simply copies
// the URL for the location into our localURLs array...

#pragma mark

@implementation IMBLocalObjectPromise

- (void) loadObjects:(NSArray*)inObjects
{
	[super loadObjects:inObjects];
	[self _didFinish];
}


- (void) _loadObject:(IMBObject*)inObject
{
	// Get the path...
	
	NSURL* localURL = [inObject url];
	
	// For file URLs, only add if the file at the path exists...
	
	if ([localURL isFileURL])
	{
		BOOL exists,directory;
		exists = [[NSFileManager threadSafeManager] fileExistsAtPath:[localURL path] isDirectory:&directory];
		
		if (!exists || directory)
		{
			localURL = nil;
		}
	}

	// If we have a valid URL, add it to our array. If we were not able to construct a suitable URL, 
	// then issue an error instead...		
	
	if (localURL != nil)
	{	
		[self.objectsToLocalURLs setObject:localURL forKey:inObject];
		_objectCountLoaded++;
	}
	else
	{
		NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBLocalObjectPromise.error",
			nil,IMBBundle(),
			@"The media file %@ could not be loaded (file not found)",
			@"Error when loading a object file synchronously has failed.");
		
		NSString* description = [NSString stringWithFormat:format,inObject.name];
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:description,NSLocalizedDescriptionKey,nil];
		NSError* error = [NSError errorWithDomain:kIMBErrorDomain code:fnfErr userInfo:info];

		[self.objectsToLocalURLs setObject:error forKey:inObject];

		_objectCountLoaded++;
	}
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBRemoteObjectPromise

@synthesize downloadOperations = _downloadOperations;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithObjects:(NSArray*)inObjects
{
	if (self = [super initWithObjects:inObjects])
	{
		self.downloadOperations = [NSMutableArray array];
		_totalBytes = 0;
		_currentBytes = 0;
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		self.downloadOperations = [NSMutableArray array];
		_totalBytes = 0;
		_currentBytes = 0;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_downloadOperations);
	[super dealloc];
} 


//----------------------------------------------------------------------------------------------------------------------


// Tell delegate to prepare the progress UI (must be done in main thread)...

- (void) prepareProgress
{
	if (_delegate)
	{
		if ([_delegate respondsToSelector:@selector(prepareProgressForObjectPromise:)])
		{
			if ([NSThread isMainThread])
			{
				[_delegate performSelector:@selector(prepareProgressForObjectPromise:) withObject:self];
			}
			else
			{
				[_delegate 
					performSelectorOnMainThread:@selector(prepareProgressForObjectPromise:) 
					withObject:self 
					waitUntilDone:NO 
					modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
			}		
		}
	}
}


// Tell delegate to display the current progress (must be done in main thread)...

- (void) displayProgress:(double)inFraction
{
	if (_delegate)
	{
		if ([_delegate respondsToSelector:@selector(displayProgress:forObjectPromise:)])
		{
			[self performSelectorOnMainThread:@selector(__displayProgress:) 
				  withObject:[NSNumber numberWithDouble:inFraction] 
				  waitUntilDone:NO 
				  modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		}
	}
}


- (void) __displayProgress:(NSNumber*)inFraction
{
	[_delegate displayProgress:[inFraction doubleValue] forObjectPromise:self];
}


// Tell delegate to remove the progress UI (must be done in main thread)...

- (void) cleanupProgress
{
	if (_delegate)
	{
		if ([_delegate respondsToSelector:@selector(cleanupProgressForObjectPromise:)])
		{
			if ([NSThread isMainThread])
			{
				[_delegate performSelector:@selector(cleanupProgressForObjectPromise:) withObject:self];
			}
			else
			{
				[_delegate 
					performSelectorOnMainThread:@selector(cleanupProgressForObjectPromise:) 
					withObject:self 
					waitUntilDone:NO 
					modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
			}		
		}
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Load all objects...

- (void) loadObjects:(NSArray*)inObjects
{	
	// Retain self until all download operations have finished. We are going to release self in the   
	// didFinish: and didReceiveError: delegate messages...
	
	[self retain];
	
	// Show the progress, which is indeterminate for now as we do not know the file sizes yet...
	
	[self prepareProgress];

	// Create all download operations...
	
	for (IMBObject* object in inObjects)
	{
		if (![object isKindOfClass:[IMBNodeObject class]])
		{
			NSURL* url = [object url];
			IMBURLDownloadOperation* op = [[IMBURLDownloadOperation alloc] initWithURL:url delegate:self];
			op.delegateReference = object;
			op.downloadFolderPath = self.downloadFolderPath;
			[self.downloadOperations addObject:op];
			[op release];
		}
	}

	// Get combined file sizes so that the progress bar can be configured...
	
	_totalBytes = 0;
	
	for (IMBURLDownloadOperation* op in self.downloadOperations)
	{
		_totalBytes += [op getSize];
	}

	// Start downloading...
	
	for (IMBURLDownloadOperation* op in self.downloadOperations)
	{
		[[IMBOperationQueue sharedQueue] addOperation:op];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) cancel:(id)inSender
{
	// Cancel outstanding operations...
	
	for (IMBURLDownloadOperation* op in self.downloadOperations)
	{
		[op cancel];
	}
	
	// Trash any files that we already have...
	
	NSFileManager* mgr = [NSFileManager threadSafeManager];
	
	for (NSURL* url in self.localURLs)
	{
		if ([url isFileURL])
		{
			NSError* error = nil;
			[mgr removeItemAtPath:[url path] error:&error];
		}
	}
	
	// Cleanup...
	
	[self cleanupProgress];
		
	[self performSelectorOnMainThread:@selector(_didFinish) 
		withObject:nil 
		waitUntilDone:YES 
		modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];

	[self release];
}


//----------------------------------------------------------------------------------------------------------------------


// We received some data, so display the current progress...

- (void) didReceiveData:(IMBURLDownloadOperation*)inOperation
{
	_currentBytes = 0;

	for (IMBURLDownloadOperation* op in self.downloadOperations)
	{
		_currentBytes += [op bytesDone];
	}
	
	double fraction = (double)_currentBytes / (double)_totalBytes;
	[self displayProgress:fraction];
}


// A download has finished. Store the URL to the downloaded file. Once all downloads are complete, we can hide 
// the progress UI, Notify the delegate and release self...

- (void) didFinish:(IMBURLDownloadOperation*)inOperation
{
	[self.objectsToLocalURLs setObject:[NSURL fileURLWithPath:inOperation.localPath] forKey:inOperation.delegateReference];
	_objectCountLoaded++;
	
	if (_objectCountLoaded >= _objectCountTotal)
	{
		NSLog(@"%s",__FUNCTION__);
		[self cleanupProgress];
		
		[self performSelectorOnMainThread:@selector(_didFinish) 
			withObject:nil 
			waitUntilDone:YES 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];

		[self release];
	}	  
}


// If an error has occured in one of the downloads, then store the error instead of the file path, but everything 
// else is the same as in the previous method...

- (void) didReceiveError:(IMBURLDownloadOperation*)inOperation
{
	[self.objectsToLocalURLs setObject:inOperation.error forKey:inOperation.delegateReference];
	self.error = inOperation.error;
	_objectCountLoaded++;

	if (_objectCountLoaded >= _objectCountTotal)
	{
		NSLog(@"%s",__FUNCTION__);
		[self cleanupProgress];
		
		[self performSelectorOnMainThread:@selector(_didFinish) 
			withObject:nil 
			waitUntilDone:YES 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
			
		[self release];
	}	  
}

@end


//----------------------------------------------------------------------------------------------------------------------
