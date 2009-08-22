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
#import "IMBObject.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS
	
NSString* kIMBObjectPromiseType = @"IMBObjectPromiseType";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBObjectPromise

@synthesize objects = _objects;
@synthesize localFiles = _localFiles;
@synthesize delegate = _delegate;
@synthesize finishSelector = _finishSelector;
@synthesize error = _error;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithObjects:(NSArray*)inObjects
{
	if (self = [super init])
	{
		self.delegate = nil;
		self.finishSelector = NULL;
		self.objects = inObjects;
		self.localFiles = [NSMutableArray arrayWithCapacity:inObjects.count];
		self.error = nil;
	}
	
	return self;
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBObjectPromise* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.objects = self.objects;
	copy.localFiles = self.localFiles;
	copy.delegate = self.delegate;
	copy.finishSelector = self.finishSelector;
	copy.error = self.error;
	
	return copy;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[inCoder encodeObject:self.objects forKey:@"objects"];
//	[inCoder encodeObject:self.localFiles forKey:@"localFiles"];
}


- (id) initWithCoder:(NSCoder*)inCoder
{
	if (self = [super init])
	{
		self.objects = [inCoder decodeObjectForKey:@"objects"];
		self.localFiles = [NSMutableArray arrayWithCapacity:self.objects.count];
		self.delegate = nil;
		self.finishSelector = NULL;
		self.error = nil;
	}
	
	return self;
}


- (void) dealloc
{
	IMBRelease(_objects);
	IMBRelease(_localFiles);
	IMBRelease(_delegate);
	IMBRelease(_error);
	[super dealloc];
} 


//----------------------------------------------------------------------------------------------------------------------


- (void) startLoadingWithDelegate:(id)inDelegate finishSelector:(SEL)inSelector
{
	self.delegate = inDelegate;
	self.finishSelector = inSelector;
	
	_hasWillStartLoading	 = _delegate != nil && [_delegate respondsToSelector:@selector(objectPromiseWillStartLoading:)];
	_hasNameProgress		 = _delegate != nil && [_delegate respondsToSelector:@selector(objectPromise:name:progress:)];
	_hasDidFinishLoading	 = _delegate != nil && [_delegate respondsToSelector:@selector(objectPromise:didFinishLoadingWithError:)];
	_hasCustomFinishSelector = _delegate != nil && [_delegate respondsToSelector:inSelector];
}


@end


//----------------------------------------------------------------------------------------------------------------------


// A promise for local files doesn't really have to do any work since no loading is required. The delegate
// methods for progress display are probably not necessary...


#pragma mark

@implementation IMBLocalObjectPromise


- (void) startLoadingWithDelegate:(id)inDelegate finishSelector:(SEL)inSelector
{
	// Start and notify the delegate...
	
	[super startLoadingWithDelegate:inDelegate finishSelector:inSelector];
	if (_hasWillStartLoading) [_delegate objectPromiseWillStartLoading:self];
	
	// Copy the path (value) of each object into our paths array...
	
	NSUInteger n  = [self.objects count];
	NSUInteger i  = 0;
	for (IMBObject* object in self.objects)
	{
		NSString* path = (NSString*)[object value];
		[self.localFiles addObject:path];
		
		double fraction = (double)(++i) / (double)(n);
		if (_hasNameProgress) [_delegate objectPromise:self name:object.name progress:fraction];
	}

	// Notify the delegate that we are done...
	
	if (_hasDidFinishLoading) [_delegate objectPromise:self didFinishLoadingWithError:nil];
	if (_hasCustomFinishSelector) [_delegate performSelector:_finishSelector withObject:self withObject:nil];
}

@end


//----------------------------------------------------------------------------------------------------------------------


// A promise for remote files needs to start NSURL downloads...


#pragma mark

@implementation IMBRemoteObjectPromise


- (void) startLoadingWithDelegate:(id)inDelegate finishSelector:(SEL)inSelector
{
	// Make sure this object stays alive until the loading has finished...
	
	[self retain];

	// Start and notify the delegate...
	
	[super startLoadingWithDelegate:inDelegate finishSelector:inSelector];
	if (_hasWillStartLoading) [_delegate objectPromiseWillStartLoading:self];

//	NSUInteger n  = [self.objects count];
//	NSUInteger i  = 0;
//	
//	for (IMBObject* object in self.objects)
//	{
//		NSURL* url = (NSURL*)[object value];
//		NSURLRequest* request = [NSURLRequest requestWithURL:url];
//		NSURLDownload* download = nil;
//		// ...
//	}

	// Notify the delegate that we are done...
	
	if (_hasDidFinishLoading) [_delegate objectPromise:self didFinishLoadingWithError:nil];
	if (_hasCustomFinishSelector) [_delegate performSelector:_finishSelector withObject:self withObject:nil];
	
	[self release];
}


@end


//----------------------------------------------------------------------------------------------------------------------


