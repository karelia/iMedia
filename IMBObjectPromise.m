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

#import "IMBObjectPromise.h"
#import "IMBCommon.h"
#import "IMBObject.h"
#import "IMBNode.h"
#import "IMBParser.h"
#import "IMBConfig.h"
#import "IMBLibraryController.h"
#import "NSFileManager+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS
	
NSString* kIMBObjectPromiseType = @"IMBObjectPromiseType";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBObjectPromise ()
- (void) _countObjects:(NSArray*)inObjects;
- (void) _loadObjects:(NSArray*)inObjects;
- (void) _loadObject:(IMBObject*)inObject;
- (void) _sendLoadingProgress;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBObjectPromise

@synthesize objects = _objects;
@synthesize downloadFolderPath = _downloadFolderPath;
@synthesize localFiles = _localFiles;
@synthesize error = _error;
@synthesize delegate = _delegate;
@synthesize finishSelector = _finishSelector;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithObjects:(NSArray*)inObjects
{
	if (self = [super init])
	{
		self.objects = inObjects;
		self.downloadFolderPath = [IMBConfig downloadFolderPath];
		self.localFiles = [NSMutableArray arrayWithCapacity:inObjects.count];
		self.error = nil;
		self.delegate = nil;
		self.finishSelector = NULL;

		_objectCount = 0;
		_objectIndex = 0;
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super init])
	{
		self.objects = [inCoder decodeObjectForKey:@"objects"];
		self.downloadFolderPath = [IMBConfig downloadFolderPath];
		self.localFiles = [NSMutableArray arrayWithCapacity:self.objects.count];
		self.delegate = nil;
		self.finishSelector = NULL;
		self.error = nil;

		_objectCount = 0;
		_objectIndex = 0;
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[inCoder encodeObject:self.objects forKey:@"objects"];
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBObjectPromise* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.objects = self.objects;
	copy.downloadFolderPath = self.downloadFolderPath;
	copy.localFiles = self.localFiles;
	copy.error = self.error;
	copy.delegate = self.delegate;
	copy.finishSelector = self.finishSelector;
	
	return copy;
}


- (void) dealloc
{
	IMBRelease(_objects);
	IMBRelease(_downloadFolderPath);
	IMBRelease(_localFiles);
	IMBRelease(_delegate);
	IMBRelease(_error);
	[super dealloc];
} 


//----------------------------------------------------------------------------------------------------------------------


// Count the eligible objects in the array...

- (void) _countObjects:(NSArray*)inObjects
{
	for (IMBObject* object in inObjects)
	{
		if (![object isKindOfClass:[IMBNodeObject class]])
		{
			_objectCount++;
		}
	}
}


// Load all eligible objects in the array...

- (void) _loadObjects:(NSArray*)inObjects
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


// Notify the delegate that we are going to start. If the loading is async then the delegate should 
// display a progress panel or sheet...

- (void) _sendWantsProgressUI:(BOOL)inWantsProgressUI
{
	if (_delegate != nil && [_delegate respondsToSelector:@selector(objectPromise:wantsProgressUI:)]) 
	{
		[_delegate objectPromise:self wantsProgressUI:(BOOL)inWantsProgressUI];
	}
}


// Notify the delegate of the current loading progress...

- (void) _sendLoadingProgress
{
	if (_delegate != nil)
	{
		if ([_delegate respondsToSelector:@selector(objectPromise:loadingProgress:)]) 
		{
			double fraction = _objectIndex / _objectCount;
			[_delegate objectPromise:self loadingProgress:fraction];
		}	
	}
}


// Notify the delegate that loading is done...

- (void) _sendDidFinish
{
	if (_delegate != nil)
	{
		if ([_delegate respondsToSelector:@selector(objectPromise:didFinishLoadingWithError:)])
		{
			[_delegate objectPromise:self didFinishLoadingWithError:nil];
		}
			
		if ([_delegate respondsToSelector:_finishSelector]) 
		{
			[_delegate performSelector:_finishSelector withObject:self withObject:nil];
		}	
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Start loading the objects...

- (void) startLoadingWithDelegate:(id)inDelegate finishSelector:(SEL)inSelector
{
	self.delegate = inDelegate;
	self.finishSelector = inSelector;
	
	[self _sendWantsProgressUI:NO];
	[self _countObjects:self.objects];
	[self _loadObjects:self.objects];
}


@end


//----------------------------------------------------------------------------------------------------------------------


// A promise for local files doesn't really have to do any work since no loading is required. It simply copies
// the path (value) into our localFiles array...


#pragma mark

@implementation IMBLocalObjectPromise


- (void) _loadObjects:(NSArray*)inObjects
{
	[super _loadObjects:inObjects];
	[self _sendDidFinish];
}


- (void) _loadObject:(IMBObject*)inObject
{
	// Get the path...
	
	NSString* path = nil;
	
	if ([inObject.value isKindOfClass:[NSString class]])
	{
		path = (NSString*)[inObject value];
	}
	else if ([inObject.value isKindOfClass:[NSURL class]])
	{
		path = [(NSURL*)inObject.value path];
	}
	
	// Check if the file at this path exists. If yes then add the path to the array...
	
	if (path)
	{
		BOOL exists,directory;
		exists = [[NSFileManager threadSafeManager] fileExistsAtPath:path isDirectory:&directory];
		
		if (exists && !directory)
		{
			[self.localFiles addObject:path];
			_objectIndex++;
		}
		else 
		{
			path = nil;
		}
	}
	
	// If not then add an error instead...
	
	if (path == nil)
	{
		NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBLocalObjectPromise.error",
			nil,IMBBundle(),
			@"The media file %@ could not be loaded (file not found)",
			@"Error when loading a object file synchronously has failed.");
		
		NSString* description = [NSString stringWithFormat:format,inObject.name];
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:description,NSLocalizedDescriptionKey,nil];
		NSError* error = [NSError errorWithDomain:@"com.karelia.imedia" code:fnfErr userInfo:info];
		
		[self.localFiles addObject:error];
		_objectIndex++;
	}
}


// No loading progress needed...

- (void) _sendWantsProgressUI:(BOOL)inWantsProgressUI
{
	[super _sendWantsProgressUI:NO];
}


- (void) _sendLoadingProgress
{

}


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBRemoteObjectPromise

@synthesize urlToLocalFileMap = _urlToLocalFileMap;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithObjects:(NSArray*)inObjects
{
	if (self = [super initWithObjects:inObjects])
	{
		self.urlToLocalFileMap = [NSMutableDictionary dictionary];
	}
	
	return self;
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super initWithCoder:inCoder])
	{
		self.urlToLocalFileMap = [NSMutableDictionary dictionary];
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_urlToLocalFileMap);
	[super dealloc];
} 


//----------------------------------------------------------------------------------------------------------------------


// Let the delegate know that we want progress UI since this is a lengthy operation...

- (void) _sendWantsProgressUI:(BOOL)inWantsProgressUI
{
	[super _sendWantsProgressUI:YES];
}


// Load all objects. A dumb client is automatically blocked (synchrnous loading)...

- (void) _loadObjects:(NSArray*)inObjects
{
	// Ask delegate whether async loading is supported (default is NO)...
	
	BOOL async = NO;
	
	if ([_delegate respondsToSelector:@selector(objectPromiseShouldStartLoadingAsynchronously:)])
	{
		async = [_delegate objectPromiseShouldStartLoadingAsynchronously:self];
	}

	// Load the objects...
	
	[super _loadObjects:inObjects];
	
	// If synchronous, then block the caller until download is complete...
	
	if (!async)
	{
		#warning TODO
		
//		while (_objectIndex < _objectCount)
//		{
//			[[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
//		}
	}
}


// A promise for remote files needs to start NSURL downloads...

- (void) _loadObject:(IMBObject*)inObject
{
	NSURL* url = (NSURL*)[inObject value];
	NSURLRequest* request = [NSURLRequest requestWithURL:url];
	NSURLDownload* download = [[NSURLDownload alloc] initWithRequest:request delegate:self];
	
	NSString* downloadFolderPath = self.downloadFolderPath;
	NSString* filename = [[url path] lastPathComponent];
	NSString* localFilePath = [downloadFolderPath stringByAppendingPathComponent:filename];
	
	[download setDestination:localFilePath allowOverwrite:NO];
	[download setDeletesFileUponFailure:YES];
}


// The file was created. Store the local filename in our urlToLocalFileMap...

- (void) download:(NSURLDownload*)inDownload didCreateDestination:(NSString*)inPath
{
	NSString* key = [[[inDownload request] URL] absoluteString];
	[self.urlToLocalFileMap setObject:inPath forKey:key];
}


// Display progress in the UI...

- (void) download:(NSURLDownload*)inDownload didReceiveDataOfLength:(NSUInteger)inLength
{
	[self _sendLoadingProgress];
}


// After a successful download store the path of the downloaded file...

- (void) downloadDidFinish:(NSURLDownload*)inDownload
{
	NSString* key = [[[inDownload request] URL] absoluteString];
	NSString* path = [self.urlToLocalFileMap objectForKey:key];	
	
	if (path)
	{
		BOOL exists,directory;
		exists = [[NSFileManager threadSafeManager] fileExistsAtPath:path isDirectory:&directory];
		if (!exists || directory) path = nil;
	}
	
	if (path)
	{
		[self.localFiles addObject:path];
		_objectIndex++;
	}
	else
	{
		NSString* format = NSLocalizedStringWithDefaultValue(
			@"IMBLocalObjectPromise.error",
			nil,IMBBundle(),
			@"The media file %@ could not be loaded (file not found)",
			@"Error when loading a object file synchronously has failed.");
		
		NSString* description = [NSString stringWithFormat:format,key];
		NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:description,NSLocalizedDescriptionKey,nil];
		NSError* error = [NSError errorWithDomain:@"com.karelia.imedia" code:fnfErr userInfo:info];

		[self.localFiles addObject:error];
		_objectIndex++;
	}
	
	[self _sendLoadingProgress];
	if (_objectIndex >= _objectCount) [self _sendDidFinish];
	[inDownload release];
}


// In case of an error store the error and abort...

- (void) download:(NSURLDownload*)inDownload didFailWithError:(NSError*)inError
{
	[self.localFiles addObject:inError];
	_objectIndex++;

	[self _sendLoadingProgress];
	if (_objectIndex >= _objectCount) [self _sendDidFinish];
	[inDownload release];
}


@end


//----------------------------------------------------------------------------------------------------------------------


