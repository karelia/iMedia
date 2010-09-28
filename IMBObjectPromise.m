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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBObjectPromise.h"
#import "IMBCommon.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBButtonObject.h"
#import "IMBParser.h"
#import "IMBConfig.h"
#import "IMBOperationQueue.h"
#import "IMBLibraryController.h"
#import "IMBURLDownloadOperation.h"
#import "IMBURLGetSizeOperation.h"
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

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBObjectPromise

@synthesize objects = _objects;
@synthesize objectsToLocalURLs = _objectsToLocalURLs;
@synthesize downloadFolderPath = _downloadFolderPath;
@synthesize error = _error;
@synthesize delegate = _delegate;
@synthesize finishSelector = _finishSelector;


//----------------------------------------------------------------------------------------------------------------------


+ (IMBObjectPromise *)objectPromiseFromPasteboard:(NSPasteboard *)pasteboard;
{
    IMBObjectPromise *result = nil;
    if ([[pasteboard types] containsObject:kIMBObjectPromiseType])
    {
        NSData *data = [pasteboard dataForType:kIMBObjectPromiseType];
        if (data) result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    return result;
}

- (id) initWithIMBObjects:(NSArray*)inObjects
{
	if (self = [super init])
	{
		self.objects = inObjects;
		self.objectsToLocalURLs = [NSMutableDictionary dictionaryWithCapacity:inObjects.count];
		self.downloadFolderPath = [IMBConfig downloadFolderPath];
		self.error = nil;
		self.delegate = nil;
		self.finishSelector = NULL;

		_objectCountTotal = 0;
		_objectCountLoaded = 0;
		_wasCanceled = NO;
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super init])
	{
		self.objects = [inCoder decodeObjectForKey:@"objects"];
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
	[inCoder encodeObject:self.objects forKey:@"objects"];
	[inCoder encodeObject:self.objectsToLocalURLs forKey:@"objectsToLocalURLs"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBObjectPromise* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.objects = self.objects;
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
	
	IMBRelease(_objects);
	IMBRelease(_objectsToLocalURLs);
	IMBRelease(_downloadFolderPath);
	IMBRelease(_delegate);
	IMBRelease(_error);
	
	[super dealloc];
} 

//----------------------------------------------------------------------------------------------------------------------


- (NSArray*) localURLs
{
	NSMutableArray* localURLs = [NSMutableArray array];
	
	for (IMBObject* object in _objects)
	{
		NSURL* url = [self localURLForObject:object];
		
		if (url)
		{
			[localURLs addObject:url];
		}
	}
	
	return localURLs;
}


- (NSURL*) localURLForObject:(IMBObject*)inObject
{
	NSURL* url = [self.objectsToLocalURLs objectForKey:inObject];
	
	if (url != nil && [url isKindOfClass:[NSURL class]])
	{
		return url;
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Count the eligible objects in the array...

- (void) _countObjects:(NSArray*)inObjects
{
	for (IMBObject* object in inObjects)
	{
		if (![object isKindOfClass:[IMBButtonObject class]])
		{
			NSURL* url = [object URL];
			if (url)	// if unable to download, URL will be nil
			{
				_objectCountTotal++;
			}
		}
	}
}


// Load all eligible objects in the array...

- (void) loadObjects:(NSArray*)inObjects
{
	for (IMBObject* object in inObjects)
	{
		if (![object isKindOfClass:[IMBButtonObject class]])
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
				[_delegate performSelector:_finishSelector withObject:self];
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


- (IBAction) cancel:(id)inSender
{
	_wasCanceled = YES;
}


- (BOOL) wasCanceled
{
	return _wasCanceled;
}


// This is invoked when cancelling a double-click

- (void) recoveryAttempter
{
	NSLog(@"%s",__FUNCTION__);
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
	
	NSURL* localURL = [inObject URL];
	
	// For file URLs, only add if the file at the path exists...
	
	if ([localURL isFileURL])
	{
		BOOL exists,directory;
		exists = [[NSFileManager imb_threadSafeManager] fileExistsAtPath:[localURL path] isDirectory:&directory];
		
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
		
		if (self.downloadFolderPath)
		{
			// Now, copy this to the download folder path ... ?
			NSString *fullPath = [self.downloadFolderPath stringByAppendingPathComponent:[[localURL path] lastPathComponent]];
			NSError *err = nil;
			[[NSFileManager imb_threadSafeManager] copyItemAtPath:[localURL path] toPath:fullPath error:&err];
			if (err)
			{
				NSLog(@"%@", err);
			}
		}
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
@synthesize getSizeOperations = _getSizeOperations;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithIMBObjects:(NSArray*)inObjects
{
	if (self = [super initWithIMBObjects:inObjects])
	{
		self.getSizeOperations = [NSMutableArray array];
		self.downloadOperations = [NSMutableArray array];
		_totalBytes = 0;
		_downloadFileTotal = 0;
		_downloadFileLoaded = 0;
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		self.getSizeOperations = [NSMutableArray array];
		self.downloadOperations = [NSMutableArray array];
		_totalBytes = 0;
		_downloadFileTotal = 0;
		_downloadFileLoaded = 0;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_getSizeOperations);
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

- (void) startDownload;
{
	// Add the the total number of bytes to be downloaded...
	_totalBytes = 0;
	for (IMBURLGetSizeOperation* getSizeOp in self.getSizeOperations)
	{
		_totalBytes += getSizeOp.bytesTotal;
	}
	
	// Start downloading once we have the size of each and every single file to be downloaded...
	
	for (IMBURLDownloadOperation* downloadOp in self.downloadOperations)
	{
		[[IMBOperationQueue sharedQueue] addOperation:downloadOp];
	}
	
	// Switch progress from indeterminate to linear...
	
	[self displayProgress:0.0];
}


// Load all objects...

- (void) loadObjects:(NSArray*)inObjects
{	
	_downloadFileTotal = 0;	// We will be counting number of files below
	
	// Retain self until all download operations have finished. We are going to release self in the   
	// didFinish: and didReceiveError: delegate messages...
	
	[self retain];
	
	// Create all download operations...

	for (IMBObject* object in inObjects)
	{
		if (![object isKindOfClass:[IMBButtonObject class]])
		{
			NSURL* url = [object URL];
			
			if (url)	// if unable to download, URL will be nil
			{
				// If we don't have a download folder yet, then use temporary directory...
				
				NSString* downloadFolderPath = self.downloadFolderPath;
				
				if (downloadFolderPath == nil)
				{
					downloadFolderPath = [[NSFileManager imb_threadSafeManager] imb_sharedTemporaryFolder:@"downloads"];
				}
				
				NSString* filename = [[url path] lastPathComponent];
				NSString* localPath = [downloadFolderPath stringByAppendingPathComponent:filename];

				IMBURLGetSizeOperation* getSizeOp = [[[IMBURLGetSizeOperation alloc] initWithURL:url delegate:self] autorelease];
				IMBURLDownloadOperation* downloadOp = [[[IMBURLDownloadOperation alloc] initWithURL:url delegate:self] autorelease];
				downloadOp.delegateReference = object;				
				downloadOp.downloadFolderPath = downloadFolderPath;
				
				// If we already have a local file, and the option key is not down, then use the local file...
				
				unsigned eventModifierFlags = [[NSApp currentEvent] modifierFlags];				
				if ([[NSFileManager imb_threadSafeManager] fileExistsAtPath:localPath]
					&& 0 == (eventModifierFlags & NSAlternateKeyMask))
				{
					downloadOp.localPath = localPath;	// Indicate already-ready local path, meaning that no download needs to actually happen
					[self didFinish:downloadOp];
				}
				
				// This will be a real download.  Make sure we have the progress window showing now.
				// Show the progress, which is indeterminate for now as we do not know the file sizes yet...
				
				else
				{
					_downloadFileTotal++;
					[self.getSizeOperations addObject:getSizeOp];
					[self.downloadOperations addObject:downloadOp];
				}
			}
		}
	}

	if (_downloadFileTotal > 0)
	{
		[self prepareProgress];
		
		const int kNumberOfFilesToCountFilesInsteadOfBytes = 8;
		
		if (1 == _downloadFileTotal)	// 1 file: Don't do a GetSize operation, just start downloading; get size when response is there
		{
			[self.getSizeOperations removeAllObjects];
			[self startDownload];
		}
		else if (_downloadFileTotal >= kNumberOfFilesToCountFilesInsteadOfBytes)	// Lots of files. Progress in FILES, not bytes
		{
			[self.getSizeOperations removeAllObjects];
			[self startDownload];
		}
		else	// A few files. We pre-count bytes, then download with progress showing # bytes downloaded
		{
			NSInvocationOperation* startDownloadOp = [[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(startDownload) object:nil] autorelease];
			
			// Make the got-sizes operation dependent on all of the get-sizes operatons, and then make the download operations
			// each dependent on got-sizes.
			
			for (IMBURLGetSizeOperation* getSizeOp in self.getSizeOperations)
			{
				[startDownloadOp addDependency:getSizeOp];	// startDownloadOp is dependent on each getSize
				[[IMBOperationQueue sharedQueue] addOperation:getSizeOp];
			}
			
			[[IMBOperationQueue sharedQueue] addOperation:startDownloadOp];
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------


- (IBAction) cancel:(id)inSender
{
	_wasCanceled = YES;
	
	// Cancel outstanding operations...
	
	for (IMBURLGetSizeOperation* op in self.getSizeOperations)
	{
		[op cancel];
	}
	
	for (IMBURLDownloadOperation* op in self.downloadOperations)
	{
		[op cancel];
	}
	
	// Trash any files that we already have...
	
	NSFileManager* mgr = [NSFileManager imb_threadSafeManager];
	
	for (NSURL* url in self.localURLs)
	{
		if ([url isKindOfClass:[NSURL class]])
		{
			if ([url isFileURL])
			{
				NSError* error = nil;
				[mgr removeItemAtPath:[url path] error:&error];
			}
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

- (void) didGetLength:(long long)inExpectedLength;
{
	if (0 == _totalBytes && 1 == _downloadFileTotal)	// If we didn't have a length before, set the expected length and start the progress
	{
		_totalBytes = inExpectedLength;
		[self displayProgress:0.0];
	}
}

// We received some data, so display the current progress...

- (void) didReceiveData:(IMBURLDownloadOperation*)inOperation
{
	if (_totalBytes > 0)
	{
		// Get currrent count of bytes
		long long currentBytes = 0;
		for (IMBURLDownloadOperation* op in self.downloadOperations)
		{
			currentBytes += [op bytesDone];
		}
		
		double fraction = (double)currentBytes / (double)_totalBytes;
		[self displayProgress:fraction];
	}
}


// A download has finished. Store the URL to the downloaded file. Once all downloads are complete, we can hide 
// the progress UI, Notify the delegate and release self...

- (void) didFinish:(IMBURLDownloadOperation*)inOperation
{
	[self.objectsToLocalURLs setObject:[NSURL fileURLWithPath:inOperation.localPath] forKey:inOperation.delegateReference];
	_objectCountLoaded++;	// for check on all promises
	
	if ([inOperation bytesDone] > 0)	// Is this a real download?
	{
		_downloadFileLoaded++;
		if (0 == _totalBytes)	// Possibly display per-file progress
		{
			double fraction = (double)_downloadFileLoaded / (double)_downloadFileTotal;
			[self displayProgress:fraction];
		}
	}
	
	if (_objectCountLoaded >= _objectCountTotal)		// Totally done?
	{
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
	_objectCountLoaded++;	// for check on all promises
	_downloadFileLoaded++;	// for checking on actual downloads

	if (_objectCountLoaded >= _objectCountTotal)
	{
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
