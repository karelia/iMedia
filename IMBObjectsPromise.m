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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBObjectsPromise.h"
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
	
NSString* kIMBPasteboardTypeObjectsPromise = @"com.karelia.imedia.pasteboard.objects-promise";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

// This subclass is used for local object files that can be returned immediately. In this case a promise isn't 
// really necessary, but to make the architecture more consistent, this abstraction is used nonetheless... 

@interface IMBLocalObjectsPromise : IMBObjectsPromise

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBObjectsPromise ()

@property (copy, readwrite) NSArray* objects;

- (void) _countObjects:(NSArray*)inObjects;
- (void) loadObjects:(NSArray*)inObjects;
- (void) _loadObject:(IMBObject*)inObject;
- (void) _didFinish;

@property (assign) SEL finishSelector;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBObjectsPromise

@synthesize objects = _objects;
@synthesize destinationDirectoryPath = _destinationDirectoryPath;
@synthesize error = _error;
@synthesize delegate = _delegate;
@synthesize finishSelector = _finishSelector;


//----------------------------------------------------------------------------------------------------------------------


+ (IMBObjectsPromise *)promiseFromPasteboard:(NSPasteboard *)pasteboard;
{
    IMBObjectsPromise *result = nil;
    if ([[pasteboard types] containsObject:kIMBPasteboardTypeObjectsPromise])
    {
        NSData *data = [pasteboard dataForType:kIMBPasteboardTypeObjectsPromise];
        if (data) result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    return result;
}

+ (IMBObjectsPromise *)promiseWithLocalIMBObjects:(NSArray *)objects;
{
    return [[[IMBLocalObjectsPromise alloc] initWithIMBObjects:objects] autorelease];
}

- (id) initWithIMBObjects:(NSArray*)inObjects
{
	if (self = [super init])
	{
		self.objects = inObjects;
		_URLsByObject = [[NSMutableDictionary alloc] initWithCapacity:inObjects.count];
		self.destinationDirectoryPath = [IMBConfig downloadFolderPath];
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
		_URLsByObject = [[inCoder decodeObjectForKey:@"URLsByObject"] mutableCopy];
		self.destinationDirectoryPath = [inCoder decodeObjectForKey:@"destinationDirectoryPath"];
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
	[inCoder encodeObject:_URLsByObject forKey:@"URLsByObject"];
    [inCoder encodeObject:[self destinationDirectoryPath] forKey:@"destinationDirectoryPath"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBObjectsPromise* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.objects = self.objects;
	copy->_URLsByObject = [_URLsByObject mutableCopy];
	copy.destinationDirectoryPath = self.destinationDirectoryPath;
	copy.error = self.error;
	copy.delegate = self.delegate;
	copy.finishSelector = self.finishSelector;
	
	return copy;
}


- (void) dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	IMBRelease(_objects);
	IMBRelease(_URLsByObject);
	IMBRelease(_destinationDirectoryPath);
	IMBRelease(_delegate);
	IMBRelease(_error);
	
	[super dealloc];
} 

//----------------------------------------------------------------------------------------------------------------------


- (NSArray*) fileURLs
{
    NSArray *objects = [self objects];
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[objects count]];
    
    for (IMBObject *anObject in objects)
    {
        NSURL *URL = [self fileURLForObject:anObject];
        if (URL) [result addObject:URL];
    }
    
    return result;
}


- (NSURL*) fileURLForObject:(IMBObject*)inObject
{
	return [_URLsByObject objectForKey:inObject];
}


- (IMBObject *)objectForFileURL:(NSURL *)URL;
{
    // Comparing URLs doesn't normally match file:///… and file://localhost/… as being equal, so for file URLs, cache the path and compare that instead
    NSString *localPath = ([URL isFileURL] ? [URL path] : nil);
    
    for (IMBObject *anObject in [self objects])
    {
        NSURL *aURL = [self fileURLForObject:anObject];
        if (localPath)
        {
            if ([aURL isFileURL] && [[aURL path] isEqualToString:localPath]) return anObject;
        }
        else
        {
            if ([URL isEqual:aURL]) return anObject;
        }
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
		if ([_delegate respondsToSelector:@selector(objectsPromiseDidFinish:)])
		{
			if ([NSThread isMainThread])
			{
				[_delegate performSelector:@selector(objectsPromiseDidFinish:) withObject:self];
			}
			else
			{
				[_delegate 
                 performSelectorOnMainThread:@selector(objectsPromiseDidFinish:) 
                 withObject:self 
                 waitUntilDone:NO 
                 modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
			}		
		}
        
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

- (void) setDelegate:(NSObject <IMBObjectsPromiseDelegate> *)delegate completionSelector:(SEL)selector;
{
	self.delegate = delegate;
	self.finishSelector = selector;
}


- (void) start;
{
    if (_objectCountTotal == 0)
    {
        [self _countObjects:self.objects];
        [self loadObjects:self.objects];
    }
}

// Spin a runloop (blocking the caller) until all objects are available...

- (void) waitUntilFinished
{
	while (_objectCountLoaded < _objectCountTotal)
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		[[NSRunLoop currentRunLoop] 
			runMode:NSModalPanelRunLoopMode 
			beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
			
		[pool drain];
	}
}


- (IBAction) cancel:(id)inSender
{
	_wasCanceled = YES;
}


- (BOOL) isCancelled
{
	return _wasCanceled;
}


// This is invoked when cancelling a double-click

- (void) recoveryAttempter
{ 
	NSLog(@"%s",__FUNCTION__);
}

- (void)setFileURL:(NSURL *)URL error:(NSError *)error forObject:(IMBObject *)object;
{
    // Drop down to CF to avoid copying keys
    if (URL)
    {
        CFDictionarySetValue((CFMutableDictionaryRef)_URLsByObject,
                             object,
                             (URL ? (id)URL : (id)error));
        
        
        // Post process.  We use this to embed metadata after the download. This is only really used by Flickr images right now
        [object postProcessLocalURL:URL];
        
        if ([self.delegate respondsToSelector:@selector(objectsPromise:object:didFinishLoadingAtURL:)])
        {
            [self.delegate objectsPromise:self object:object didFinishLoadingAtURL:URL];
        }
    }
    else
    {
        if ([self.delegate respondsToSelector:@selector(objectsPromise:object:didFailLoadingWithError:)])
        {
            [self.delegate objectsPromise:self object:object didFailLoadingWithError:error];
        }
    }
}

- (NSString *)description;
{
    return [[super description] stringByAppendingFormat:@" destination: %@", [self destinationDirectoryPath]];
}

@end


//----------------------------------------------------------------------------------------------------------------------


// A promise for local objects doesn't really have to do any work since no loading is required. It simply copies
// the URL for the location into our localURLs array...

#pragma mark

@implementation IMBLocalObjectsPromise

- (id) initWithIMBObjects:(NSArray*)inObjects
{
	if (self = [super initWithIMBObjects:inObjects])
	{
		// By default, IMBObjectsPromises set this to the Downloads folder. This is 
		// really inconvenient because IMBLocalObjectsPromise, in _loadObject: below,
		// takes the presence of this attribute as a cue to perform a literal copy of
		// the source file, even if it's already local to the disk. The end result is
		// e.g. when you double-click a local file to open in Photoshop, it makes an
		// unwanted copy of the file in the Downloads folder.
		self.destinationDirectoryPath = nil;
	}
	
	return self;
}

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
        [self setFileURL:localURL error:nil forObject:inObject];
		_objectCountLoaded++;
	}
	else
	{
		NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBLocalObjectsPromise.error",
			nil,IMBBundle(),
			@"The media file %@ could not be loaded (file not found)",
			@"Error when loading a object file synchronously has failed.");
		
		NSString* description = [NSString stringWithFormat:format,inObject.name];
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:description,NSLocalizedDescriptionKey,nil];
		NSError* error = [NSError errorWithDomain:kIMBErrorDomain code:fnfErr userInfo:info];

        [self setFileURL:nil error:error forObject:inObject];
		_objectCountLoaded++;
	}
}

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBRemoteObjectsPromise

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
	[self displayProgress:0.0];
}


// Tell delegate to display the current progress (must be done in main thread)...

- (void) displayProgress:(double)inFraction
{
	if (_delegate)
	{
		if ([_delegate respondsToSelector:@selector(objectsPromise:didProgress:)])
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
	[_delegate objectsPromise:self didProgress:[inFraction doubleValue]];
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
				
				NSString* downloadFolderPath = self.destinationDirectoryPath;
				
				if (downloadFolderPath == nil)
				{
					downloadFolderPath = [[NSFileManager imb_threadSafeManager] imb_sharedTemporaryFolder:@"downloads"];
				}
				
				NSString* filename = [[url path] lastPathComponent];
				
				// Determine local path .... We should probably have stored this in _namesOfPromisedFilesDroppedAtDestination
				// so that we know what to do.  With an explicit drag to the finder, we probably want to make a copy using
				// this technique -- but for double-clicking, we probably just want to re-open if it is downloaded already.
				// 
				// So ... this remains not-quite-finished. :-)
				/*
				 NSString* name = [[object path] lastPathComponent];
				 NSString *base = [name stringByDeletingPathExtension];
				 NSString *ext = [name pathExtension];
				 NSString *newPath = [fileManager imb_generateUniqueFileNameAtPath:dropDestPath base:base extension:ext];
				 name = [newPath lastPathComponent];
				*/
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
	
    // TODO: This would run faster if iterated _URLsByObject directly since would skip objects that hadn't loaded
	for (NSURL* url in self.fileURLs)
	{
		if ([url isFileURL])
        {
            NSError* error = nil;
            [mgr removeItemAtPath:[url path] error:&error];
        }
	}
	
	// Cleanup...
	
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
	IMBObject* object = (IMBObject*) inOperation.delegateReference;
	[self setFileURL:[NSURL fileURLWithPath:inOperation.localPath] error:nil forObject:object];
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
	IMBObject* object = (IMBObject*) inOperation.delegateReference;
	[self setFileURL:nil error:inOperation.error forObject:object];
	
	self.error = inOperation.error;
	_objectCountLoaded++;	// for check on all promises
	_downloadFileLoaded++;	// for checking on actual downloads

	if (_objectCountLoaded >= _objectCountTotal)
	{
		[self performSelectorOnMainThread:@selector(_didFinish) 
			withObject:nil 
			waitUntilDone:YES 
			modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
			
		[self release];
	}	  
}

@end


//----------------------------------------------------------------------------------------------------------------------
