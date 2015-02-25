/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2015 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2015 by Karelia Software et al.
 
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


// Author: Jörg Jacobsen, Pierre Bernard


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBAppleMediaLibraryPropertySynchronizer.h"


@interface IMBAppleMediaLibraryPropertySynchronizer ()

@property (nonatomic, retain) id observedObject;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, retain) id valueForKey;
@property (nonatomic) dispatch_semaphore_t semaphore;

@end

@implementation IMBAppleMediaLibraryPropertySynchronizer

@synthesize observedObject=_observedObject;
@synthesize key=_key;
@synthesize valueForKey=_valueForKey;
@synthesize semaphore=_semaphore;


#pragma mark Object Lifecycle

- (instancetype)init
{
	return [self initWithKey:nil ofObject:nil];
}

/**
 Designated Initializer.
 */
- (instancetype)initWithKey:(NSString *)key ofObject:(id)object
{
	if (object == nil) {
		return nil;
	}
	NSParameterAssert(key != nil);

	if (self = [super init]) {
		self.key = key;
		self.observedObject = object;
	}
	return self;
}

- (void)dealloc
{
	[self.observedObject removeObserver:self forKeyPath:self.key];

	IMBRelease(_observedObject);
	IMBRelease(_key);
	IMBRelease(_valueForKey);
	[super dealloc];
}

#pragma mark Public API

+ (NSDictionary *)mediaSourcesForMediaLibrary:(MLMediaLibrary *)mediaLibrary
{
	return [self synchronousValueForObservableKey:@"mediaSources" ofObject:mediaLibrary];
}

+ (MLMediaGroup *)rootMediaGroupForMediaSource:(MLMediaSource *)mediaSource
{
	return [self synchronousValueForObservableKey:@"rootMediaGroup" ofObject:mediaSource];
}

+ (NSArray *)mediaObjectsForMediaGroup:(MLMediaGroup *)mediaGroup
{
	return [self synchronousValueForObservableKey:@"mediaObjects" ofObject:mediaGroup];
}

+ (NSImage *)iconImageForMediaGroup:(MLMediaGroup *)mediaGroup
{
	return [self synchronousValueForObservableKey:@"iconImage" ofObject:mediaGroup];
}

#pragma mark Helper

/**
 Returns value for given key of object synchronously.

 Must not be called from main thread for keys like "mediaSources", "rootMediaGroup", "mediaObjects"
 since it would block main thread forever!
 */
+ (id)synchronousValueForObservableKey:(NSString *)key ofObject:(id)object
{
	NSAssert(![NSThread isMainThread], @"This method must not be invoked on main thread");

	IMBAppleMediaLibraryPropertySynchronizer *instance = [[self alloc] initWithKey:key ofObject:object];

	if (instance) {
		instance.semaphore = dispatch_semaphore_create(0);
		[instance.observedObject addObserver:instance forKeyPath:instance.key options:0 context:NULL];
		instance.valueForKey = [instance.observedObject valueForKey:instance.key];
//		NSLog(@"Property value %@.%@ is %@", instance.observedObject, instance.key, instance.valueForKey);

		if (!instance.valueForKey) {
			// Value not present yet, will be provided asynchronously through KVO. Wait for it.
			dispatch_semaphore_wait(instance.semaphore, DISPATCH_TIME_FOREVER);
		}
		dispatch_release(instance.semaphore);
		return instance.valueForKey;
	}
	return nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == NULL) {
		//        self.valueForKey = change[NSKeyValueChangeNewKey];
		self.valueForKey = [object valueForKey:keyPath];
//		NSLog(@"Property value %@.%@ is %@", self.observedObject, self.key, self.valueForKey);
		dispatch_semaphore_signal(self.semaphore);
	}
}

@end
