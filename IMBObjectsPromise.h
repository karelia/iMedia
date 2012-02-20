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
	
#import "IMBURLDownloadOperation.h"
#import "IMBURLGetSizeOperation.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS
	
extern NSString* kIMBPasteboardTypeObjectsPromise;


//----------------------------------------------------------------------------------------------------------------------


@class IMBObject;
@protocol IMBObjectsPromiseDelegate;


#pragma mark 

// IMBObjectsPromise is an abstraction that sits between the iMedia framework and a client application. 
// Objects from some parsers reside on the local file system, but objects from other parser may reside on a remote 
// server or a camera device. In these cases we only have lo-res thumbnails available. To access the hi-res data, we
// first need to start an asynchronous download operation. To be as lazy as possible, IMBObjectsPromise encapsulates
// this access. The framework hands the promise to the client app, which can then trigger a download as desired...

@interface IMBObjectsPromise : NSObject <NSCopying,NSCoding>
{
  @private
	NSArray* _objects;
	CFMutableDictionaryRef _URLsByObject;
  @protected
	NSString* _destinationDirectoryPath;
	NSError* _error;
	
	int _objectCountTotal;
	int _objectCountLoaded;
	NSObject <IMBObjectsPromiseDelegate> *_delegate;
	SEL _finishSelector;
	BOOL _wasCanceled;
}


#pragma mark Creating an Object Promise

+ (IMBObjectsPromise *) promiseFromPasteboard:(NSPasteboard *)pasteboard;
+ (IMBObjectsPromise *) promiseWithLocalIMBObjects:(NSArray *)objects;
- (id) initWithIMBObjects:(NSArray*)inObjects;


#pragma mark Fulfilling the Promise

- (void) start;

// Retained due to asynchronous nature of the promise

@property (retain) NSObject <IMBObjectsPromiseDelegate> *delegate;	

// Special case until we have blocks support so you can run a custom method upon completion

- (void) setDelegate:(NSObject <IMBObjectsPromiseDelegate> *)delegate completionSelector:(SEL)selector;
- (void) waitUntilFinished;


#pragma mark Getting the Promise Status

- (BOOL) isCancelled;
@property (copy) NSError* error;  /// Contains error in case of failure	


#pragma mark Getting Attributes

// Array of IMBObjects that was supplied in the init method

@property (copy, readonly) NSArray* objects;

// Optional download folder (only needed for remote files that need to be downloaded)
// Should be preset to a reasonable default

@property (copy) NSString* destinationDirectoryPath;

// Array of URLs referencing a local copy of a file, or in the case of e.g. link objects,
// the URL to the web resource itself. Generally speaking, these URLs are suitable for
// passing to NSWorkspace's openURL: method. The order of the array matches the order -objects, but will be shorter if -fileURLForObject: returns nil.

@property (retain,readonly) NSArray* fileURLs;

// Returns nil if the object has not finished downloading, or failed. If you want error information about the individual object, implement -objectsPromise:object:didFailLoadingWithError: delegate method

- (NSURL*) fileURLForObject:(IMBObject*)inObject;

// Currently quite slow, avoid if you can as we may remove it in the future!

- (IMBObject *)objectForFileURL:(NSURL *)URL;


#pragma mark Subclass Support
- (void)setFileURL:(NSURL *)URL error:(NSError *)error forObject:(IMBObject *)object;


@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// These delegate methods can be used by a client application to display a progress panel/sheet.   
// Somewhat like NSURLConnectionDelegate: An -objectsPromiseDidFinish: message is always sent  
// Multiple-objectsPromise:didProgress: messages may be sent, but you will receive none if the 
// promise fulfils quickly (i.e. promises local files only)...

@protocol IMBObjectsPromiseDelegate
@optional

- (void) objectsPromise:(IMBObjectsPromise*)inObjectPromise didProgress:(double)inFraction;

- (void) objectsPromise:(IMBObjectsPromise*)promise
                 object:(IMBObject *)object
  didFinishLoadingAtURL:(NSURL *)fileURL;

- (void) objectsPromise:(IMBObjectsPromise*)promise
                 object:(IMBObject *)object
didFailLoadingWithError:(NSError *)error;

- (void) objectsPromiseDidFinish:(IMBObjectsPromise*)inObjectPromise;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

// This subclass is used for local object files that can be returned immediately. In this case a promise isn't 
// really necessary, but to make the architecture more consistent, this abstraction is used nonetheless... 

@interface IMBLocalObjectsPromise : IMBObjectsPromise

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

// This subclass is used for remote object files that can be downloaded from a network. NSURLDownload 
// is used to pull the object files off the network onto the local file system, where it can then be 
// accessed by the delegate... 

@interface IMBRemoteObjectsPromise : IMBObjectsPromise <IMBURLDownloadDelegate>
{
	NSMutableArray* _getSizeOperations;
	NSMutableArray* _downloadOperations;
	long long _totalBytes;
	int _downloadFileTotal;
	int _downloadFileLoaded;	// different from _objectCountLoaded, _objectCountTotal; this is downloads only

}

@property (retain) NSMutableArray* getSizeOperations;
@property (retain) NSMutableArray* downloadOperations;

- (void) loadObjects:(NSArray*)inObjects;
- (IBAction) cancel:(id)inSender;

- (void) prepareProgress;
- (void) displayProgress:(double)inFraction;

@end


//----------------------------------------------------------------------------------------------------------------------
