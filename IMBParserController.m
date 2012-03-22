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


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBParserController.h"
#import "IMBParserMessenger.h"
#import "IMBParser.h"
#import "IMBConfig.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBLAS

static NSMutableDictionary* sRegisteredParserMessengerClasses = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


@interface IMBParserController ()

- (BOOL) addParserMessenger:(IMBParserMessenger*)inParserMessenger;
- (BOOL) removeParserMessenger:(IMBParserMessenger*)inParserMessenger;
- (void) saveUserAddedParserMessengersToPreferences;
- (void) loadUserAddedParserMessengersFromPreferences;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


@implementation IMBParserController

@synthesize delegate = _delegate;


//----------------------------------------------------------------------------------------------------------------------


// Returns a singleton instance of the IMBParserController...

+ (IMBParserController*) sharedParserController
{
	static IMBParserController* sSharedParserController = nil;
	static dispatch_once_t sOnceToken = 0;

    dispatch_once(&sOnceToken,
    ^{
		sSharedParserController = [[IMBParserController alloc] init];
	});

    NSAssert([NSThread isMainThread], @"IMBParserController should only accessed from the main thread");
	return sSharedParserController;
}


//----------------------------------------------------------------------------------------------------------------------


// This method should be called from the +load method of each parser class. This lets the IMBParserController 
// know about the existence of a parser class, but it doesn't load the parser yet. Known parser classes are 
// stored in a NSMutableSet per mediaType...

+ (void) registerParserMessengerClass:(Class)inParserMessengerClass forMediaType:(NSString*)inMediaType
{
	@synchronized([self class])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		NSMutableSet* parserMessengerClasses = [self registeredParserMessengerClassesForMediaType:inMediaType];
		[parserMessengerClasses addObject:inParserMessengerClass];
		[pool drain];
	}
}


// This method can be used in rare circumstances to remove a parser from the list of known parsers. 
// Please note that this must be called before -loadParsers to have any effect...

+ (void) unregisterParserMessengerClass:(Class)inParserMessengerClass
{
	@synchronized([self class])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		if (sRegisteredParserMessengerClasses)
		{
			for (NSString* mediaType in sRegisteredParserMessengerClasses)
			{
				NSMutableSet* parserMessengerClasses = [sRegisteredParserMessengerClasses objectForKey:mediaType];
				[parserMessengerClasses removeObject:inParserMessengerClass];
			}
		}
		
		[pool drain];
	}
}


// Returns a set of all registered parser classes for the specified media type...

+ (NSMutableSet*) registeredParserMessengerClassesForMediaType:(NSString*)inMediaType
{
	@synchronized([self class])
	{
		if (sRegisteredParserMessengerClasses == nil)
		{
			sRegisteredParserMessengerClasses = [[NSMutableDictionary alloc] init];
		}
		
		NSMutableSet* parserMessengerClasses = [sRegisteredParserMessengerClasses objectForKey:inMediaType];
		
		if (parserMessengerClasses == nil)
		{
			parserMessengerClasses = [[NSMutableSet alloc] init];
			[sRegisteredParserMessengerClasses setObject:parserMessengerClasses forKey:inMediaType];
			[parserMessengerClasses release];
		}

		return parserMessengerClasses;
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

- (id) init
{
	if (self = [super init])
	{
		// Unload all IMBParserMessengers before we quit, so that they have a chance to clean up 
		// (e.g. remove callbacks, etc...)
		
		[[NSNotificationCenter defaultCenter]				 
			addObserver:self								
			selector:@selector(saveUserAddedParserMessengersToPreferences) 
			name:NSApplicationWillTerminateNotification 
			object:nil];

		[[NSNotificationCenter defaultCenter]				 
			addObserver:self								
			selector:@selector(unloadParserMessengers) 
			name:NSApplicationWillTerminateNotification 
			object:nil];
	}
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self unloadParserMessengers];
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Loading & Unloading


// This method first loads the registered IMBParserMessengers and then append the custom IMBParserMessengers  
// that are stored in the prefs... 

- (void) loadParserMessengers
{
	if (sRegisteredParserMessengerClasses)
	{
		for (NSString* mediaType in sRegisteredParserMessengerClasses)
		{
			NSMutableSet* parserMessengerClasses = [IMBParserController registeredParserMessengerClassesForMediaType:mediaType];

			for (Class parserMessengerClass in parserMessengerClasses)
			{
				BOOL shouldLoad = YES;
				
				if ([_delegate respondsToSelector:@selector(parserController:shouldLoadParserMessengerWithIdentifier:)])
				{
					shouldLoad = [_delegate parserController:self shouldLoadParserMessengerWithIdentifier:[parserMessengerClass identifier]];
				}
				
				if (shouldLoad)
				{
					IMBParserMessenger* parserMessenger = [[parserMessengerClass alloc] init];
					[self addParserMessenger:parserMessenger];
					[parserMessenger release];
				}
			}
		}
	}
	
	// Finally load the custom parsers from the preferences and append those to our list...
	
	[self loadUserAddedParserMessengersFromPreferences];
}


//----------------------------------------------------------------------------------------------------------------------


// Unload all IMBParserMessengers...

- (void) unloadParserMessengers
{
	NSArray* keys = [_loadedParserMessengers allKeys];
	NSUInteger n = [keys count];
	
	for (NSUInteger i=0; i<n; i++)
    {
		NSString* mediaType = [keys objectAtIndex:i];
        NSArray* parserMessengers = [_loadedParserMessengers objectForKey:mediaType];
        NSUInteger m = parserMessengers.count;
		
        for (NSUInteger j=0; j<m; j++)
        {
			IMBParserMessenger* parserMessenger = [parserMessengers objectAtIndex:0];
			[self removeParserMessenger:parserMessenger];
        }
    }
    
    IMBRelease(_loadedParserMessengers)
}


//----------------------------------------------------------------------------------------------------------------------


- (NSArray*) loadedParserMessengersForMediaType:(NSString*)inMediaType
{
	return [_loadedParserMessengers objectForKey:inMediaType];
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) addParserMessenger:(IMBParserMessenger*)inParserMessenger
{
    // Check if inParserFactory is already in the list. If yes then bail out early...
	
	NSString* mediaType = inParserMessenger.mediaType;
	NSMutableArray* parserMessengers = [_loadedParserMessengers objectForKey:mediaType];
	
	for (IMBParserMessenger* parserMessenger in parserMessengers)
	{
		if ([parserMessenger.mediaSource isEqual:inParserMessenger.mediaSource] && 
			[parserMessenger.mediaType isEqual:inParserMessenger.mediaType])
		{
			return NO;
		}
	}
	
	// Add it to the list...
	
    if (_loadedParserMessengers == nil)
	{
		_loadedParserMessengers = [[NSMutableDictionary alloc] init];
    }
	
	if (parserMessengers == nil)
    {
        parserMessengers = [[NSMutableArray alloc] initWithCapacity:1];
        [_loadedParserMessengers setObject:parserMessengers forKey:mediaType];
        [parserMessengers release];
    }
    
	[parserMessengers addObject:inParserMessenger];
    
    // Tell the delegate...
	
	if ([_delegate respondsToSelector:@selector(parserController:didLoadParserMessenger:)])
	{
		[_delegate parserController:self didLoadParserMessenger:inParserMessenger];
	}
    
    return YES;
}


//----------------------------------------------------------------------------------------------------------------------


- (BOOL) removeParserMessenger:(IMBParserMessenger*)inParserMessenger
{
	NSString* mediaType = inParserMessenger.mediaType;
	NSMutableArray* parserMessengers = [_loadedParserMessengers objectForKey:mediaType];
	NSUInteger index = [parserMessengers indexOfObjectIdenticalTo:inParserMessenger];
	
	if (index != NSNotFound) 
	{
		if ([_delegate respondsToSelector:@selector(parserController:willUnloadParserMessenger:)])
		{
			[_delegate parserController:self willUnloadParserMessenger:inParserMessenger];
		}
		
		[parserMessengers removeObjectAtIndex:index];
		
		if (parserMessengers.count == 0)
		{
			[_loadedParserMessengers removeObjectForKey:mediaType];
		}
		
		if (_loadedParserMessengers.count == 0)
		{
			IMBRelease(_loadedParserMessengers);
		}
		
		return YES;
	}	
	
	return NO;	
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark User Added Folders


// Adds a IMBParserMessenger list of loaded IMBParserMessengers and saves the resulting list to the prefs...

- (BOOL) addUserAddedParserMessenger:(IMBParserMessenger*)inParserMessenger
{
	inParserMessenger.isUserAdded = YES;
	
	BOOL didAdd = [self addParserMessenger:inParserMessenger];
	
	if (didAdd)
	{
		[self saveUserAddedParserMessengersToPreferences];
	}
	
	return didAdd;
}


// Removes a IMBParserMessenger list of loaded IMBParserMessengers and saves the resulting list to the prefs...

- (BOOL) removeUserAddedParserMessenger:(IMBParserMessenger*)inParserMessenger
{
	BOOL didRemove = NO;

	if (inParserMessenger.isUserAdded)
	{
		didRemove = [self removeParserMessenger:inParserMessenger];
		
		if (didRemove)
		{
			[self saveUserAddedParserMessengersToPreferences];
		}
	}
	
	return didRemove;
}


// Create a list containing information about all loaded custom parsers. This list is stored in the prefs...

- (void) saveUserAddedParserMessengersToPreferences
{
	if (_loadedParserMessengers)
	{
		NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
		NSMutableArray* userAddedParserMessengers = [NSMutableArray array];
		
		for (NSString* mediaType in _loadedParserMessengers)
		{
			NSArray* parsersMessengers = [self loadedParserMessengersForMediaType:mediaType];
			
			for (IMBParserMessenger* parsersMessenger in parsersMessengers)
			{
				if (parsersMessenger.isUserAdded)
				{
					NSData* data = [NSKeyedArchiver archivedDataWithRootObject:parsersMessenger];
					[userAddedParserMessengers addObject:data];
				}
			}
		}
		
		[prefs setObject:userAddedParserMessengers forKey:@"userAddedParserMessengers"];
		[IMBConfig setPrefs:prefs forClass:[self class]];
	}
}


// Restore the custom parser instances from the list which was stored in the prefs. The flag _loadingCustomParsers
// is used to skip the saveCustomParsersToPreferences method call when calling addCustomParser:forMediaType: which
// is totally useless while we are loading from the prefs...

- (void) loadUserAddedParserMessengersFromPreferences
{
	NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
	NSArray* userAddedParserMessengers = [prefs objectForKey:@"userAddedParserMessengers"];
	
	for (NSData* data in userAddedParserMessengers)
	{
		IMBParserMessenger* parsersMessenger = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		[self addParserMessenger:parsersMessenger];
	}
}



//----------------------------------------------------------------------------------------------------------------------


@end

