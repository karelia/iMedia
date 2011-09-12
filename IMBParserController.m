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

#import "IMBParserController.h"
#import "IMBParser.h"
#import "IMBConfig.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark GLOBLAS

static IMBParserController* sSharedParserController = nil;
static NSMutableDictionary* sRegisteredParserClasses = nil;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


@interface IMBParserController ()

// Save info about the custom parsers to the preferences and restore custom parsers from the preferences...
- (void) saveCustomParsersToPreferences;
- (void) loadCustomParsersFromPreferences;

- (BOOL)addParser:(IMBParser *)parser;
- (BOOL)removeParser:(IMBParser *)inParser;

@end


@implementation IMBParserController

@synthesize delegate = _delegate;


//----------------------------------------------------------------------------------------------------------------------


+ (IMBParserController*) sharedParserController
{
    NSAssert([NSThread isMainThread], @"IMBParserController should only accessed from the main thread");
    
	if (sSharedParserController == nil)
    {
        sSharedParserController = [[IMBParserController alloc] init];
    }
	
	return sSharedParserController;
}


//----------------------------------------------------------------------------------------------------------------------


// This method should be called from the +load method of each parser class. This lets the IMBParserController 
// know about the existence of a parser class, but it doesn't load the parser yet. Known parser classes are 
// stored in a NSMutableSet per mediaType...

+ (void) registerParserClass:(Class)inParserClass forMediaType:(NSString*)inMediaType
{
	@synchronized ([self class])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		NSMutableSet* parserClasses = [self registeredParserClassesForMediaType:inMediaType];

		if ([inParserClass conformsToProtocol:@protocol(IMBParserProtocol)])
		{
			[parserClasses addObject:inParserClass];
		}
		
		[pool drain];
	}
}


// This method can be used in rare circumstances to remove a parser from the list of known parsers. 
// Please note that this must be called before -loadParsers to have any effect...

+ (void) unregisterParserClass:(Class)inParserClass
{
	@synchronized ([self class])
	{
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		if (sRegisteredParserClasses)
		{
			for (NSString* mediaType in sRegisteredParserClasses)
			{
				NSMutableSet* parserClasses = [sRegisteredParserClasses objectForKey:mediaType];
				[parserClasses removeObject:inParserClass];
			}
		}
		
		[pool drain];
	}
}


// Returns a set of all registered parser classes for the specified media type...

+ (NSMutableSet*) registeredParserClassesForMediaType:(NSString*)inMediaType
{
	@synchronized ([self class])
	{
		if (sRegisteredParserClasses == nil)
		{
			sRegisteredParserClasses = [[NSMutableDictionary alloc] init];
		}
		
		NSMutableSet* parserClasses = [sRegisteredParserClasses objectForKey:inMediaType];
		
		if (parserClasses == nil)
		{
			parserClasses = [[NSMutableSet alloc] init];
			[sRegisteredParserClasses setObject:parserClasses forKey:inMediaType];
			[parserClasses release];
		}

		return parserClasses;
	}
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

- (id) init
{
	if (self = [super init])
	{
		_loadingCustomParsers = NO;
		
		[[NSNotificationCenter defaultCenter]				// Unload parsers before we quit, so that custom have 
			addObserver:self								// a chance to clean up (e.g. remove callbacks, etc...)
			selector:@selector(reset) 
			name:NSApplicationWillTerminateNotification 
			object:nil];
	}
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self reset];
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Loading & Unloading

// This method first loads the registered parsers and then appends the custom parser that are stored in the prefs... 

- (void) loadParsers
{
	// Iterate over all registered parsers for each media type...
		
	if (sRegisteredParserClasses)
	{
		for (NSString* mediaType in sRegisteredParserClasses)
		{
			NSMutableSet* parserClasses = [IMBParserController registeredParserClassesForMediaType:mediaType];

			for (Class parserClass in parserClasses)
			{
				// First ask the delegate whether we should load this parser...
				
				BOOL shouldLoad = YES;
				
				if ([_delegate respondsToSelector:@selector(parserController:shouldLoadParser:forMediaType:)])
				{
					shouldLoad = [_delegate parserController:self shouldLoadParser:NSStringFromClass(parserClass) forMediaType:mediaType];
				}
				
				// If yes, then create an instance, store it, and tell the delegate...
				
				if (shouldLoad)
				{
					NSArray* parserInstances = [parserClass parserInstancesForMediaType:mediaType];
					for (IMBParser *aParser in parserInstances)
                    {
                        [self addParser:aParser];
                    }
				}
			}
		}
	}
	
	// Finally load the custom parsers from the preferences and append those to our list...
	
	[self loadCustomParsersFromPreferences];
}

// Makes sure the parsers are loaded
- (NSMutableDictionary *)parsersByMediaType;
{
    if (!_loadedParsers) [self loadParsers];
    return _loadedParsers;
}


//----------------------------------------------------------------------------------------------------------------------


// Adds the specified parser to the list of loaded parsers. Please note that this will fail if either the parser
// is already in the list (we do not want duplicates) or if the delegate denied the loading...

- (BOOL) addDynamicParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
    [self parsersByMediaType]; // make sure all the regular and custom parsers are already loaded
	return [self addParser:inParser];
}


// Removes a parser instance from the list of loaded parsers...

- (BOOL) removeDynamicParser:(IMBParser*)inParser
{
	return [self removeParser:inParser];
}


//----------------------------------------------------------------------------------------------------------------------


// Adds the parser as a custom parser to the list of loaded parsers and saves the resulting list to the prefs...

- (BOOL) addCustomParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
	BOOL didAdd = [self addDynamicParser:inParser forMediaType:inMediaType];
	
	if (didAdd)
	{
		inParser.custom = YES;
		[self saveCustomParsersToPreferences];
	}
	
	return didAdd;
}


// Removes a custom parser from the list of loaded parsers and saves the resulting list to the prefs...

- (BOOL) removeCustomParser:(IMBParser*)inParser
{
	BOOL didRemove = NO;
	BOOL isCustom = inParser.isCustom;

	if (isCustom)
	{
		didRemove = [self removeDynamicParser:inParser];
		
		if (didRemove)
		{
			[self saveCustomParsersToPreferences];
		}
	}
	
	return didRemove;

//	NSString* mediaType = inParser.mediaType;
//	NSMutableArray* parsers = [self loadedParsersForMediaType:mediaType];
//	BOOL exists = [parsers indexOfObjectIdenticalTo:inParser] != NSNotFound;
//	BOOL custom = inParser.isCustom;
//	
//	if (exists && custom) 
//	{
//		if (_delegate != nil && [_delegate respondsToSelector:@selector(parserController:willUnloadParser:forMediaType:)])
//		{
//			[_delegate parserController:self willUnloadParser:inParser forMediaType:mediaType];
//		}
//		
//		[parsers removeObject:inParser];
//		[self saveCustomParsersToPreferences];
//		return YES;
//	}	
//	
//	return NO;	
}


//----------------------------------------------------------------------------------------------------------------------


// Create a list containing information about all loaded custom parsers. This list is stored in the prefs...

- (void) saveCustomParsersToPreferences
{
	if (_loadedParsers != nil && _loadingCustomParsers == NO)
	{
		NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
		NSMutableArray* customParsers = [NSMutableArray array];
		
		for (NSString* mediaType in _loadedParsers)
		{
			NSArray* parsers = [_loadedParsers objectForKey:mediaType];
			
			for (IMBParser* parser in parsers)
			{
				if (parser.isCustom)
				{
					NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
						NSStringFromClass([parser class]),@"className",
						parser.mediaSource,@"mediaSource",
						parser.mediaType,@"mediaType",
						nil];
						
					[customParsers addObject:info];	
				}
			}
		}
		
		[prefs setObject:customParsers forKey:@"customParsers"];
		[IMBConfig setPrefs:prefs forClass:[self class]];
	}
}


// Restore the custom parser instances from the list which was stored in the prefs. The flag _loadingCustomParsers
// is used to skip the saveCustomParsersToPreferences method call when calling addCustomParser:forMediaType: which
// is totally useless while we are loading from the prefs...

- (void) loadCustomParsersFromPreferences
{
	_loadingCustomParsers = YES;
	
	NSMutableDictionary* prefs = [IMBConfig prefsForClass:[self class]];
	NSArray* customParsers = [prefs objectForKey:@"customParsers"];
	
	for (NSDictionary* info in customParsers)
	{
		Class parserClass = NSClassFromString([info objectForKey:@"className"]);
		NSString* mediaType = [info objectForKey:@"mediaType"];
		IMBParser* parser = [[parserClass alloc] initWithMediaType:mediaType];
		
		parser.mediaSource = [info objectForKey:@"mediaSource"];
		parser.custom = YES;
		
		[self addCustomParser:parser forMediaType:parser.mediaType];
		[parser release];
	}
	
	_loadingCustomParsers = NO;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark Parsers, Core

- (NSArray *)parsersForMediaType:(NSString *)mediaType;
{
    NSMutableDictionary *parsers = [self parsersByMediaType];
    return [[[parsers objectForKey:mediaType] copy] autorelease];   // copy so clients don't get to see any mutations
}

// Returns all loaded parsers...

- (NSArray *)parsers
{
    [self parsersByMediaType];  // make sure is loaded
	NSMutableArray* result = nil;
	
    result = [NSMutableArray array];
    
    for (NSString* mediaType in _loadedParsers)
    {	
        NSArray* parsersForMediaType = [_loadedParsers objectForKey:mediaType];
        [result addObjectsFromArray:parsersForMediaType];
    }
    
	return result;
}

- (BOOL)addParser:(IMBParser *)parser;
{
    // Check if the parser is already in the list...
	NSString *mediaType = [parser mediaType];
	NSMutableArray* parsers = [_loadedParsers objectForKey:mediaType];
	
	for (IMBParser *aParser in parsers)
	{
		if ([parser.mediaSource isEqual:aParser.mediaSource] && [parser.mediaType isEqual:aParser.mediaType])
		{
            // It's already in the list, so effectively was added
			return YES;
		}
	}
	
	// Ask the delegate if we are allowed to load the parser...
	if ([_delegate respondsToSelector:@selector(parserController:shouldLoadParser:)])
    {
        if (![_delegate parserController:self shouldLoadParser:parser]) return NO;
    }
    else
    {
        if (![parser canBeUsed]) return NO;
    }
    
    
	// Add it to the list
    if (!_loadedParsers) _loadedParsers = [[NSMutableDictionary alloc] init];
    
	if (!parsers)
    {
        parsers = [[NSMutableArray alloc] initWithCapacity:1];
        [_loadedParsers setObject:parsers forKey:mediaType];
        [parsers release];
    }
    
	[parsers addObject:parser];
    
    
    // Tell the delegate...
    if ([_delegate respondsToSelector:@selector(parserController:didLoadParser:forMediaType:)])
    {
        [_delegate parserController:self didLoadParser:parser forMediaType:mediaType];
    }
    
    return YES;
}

- (BOOL)removeParser:(IMBParser *)inParser;
{
	NSString* mediaType = inParser.mediaType;
	NSMutableArray* parsers = [_loadedParsers objectForKey:mediaType];
	NSUInteger index = [parsers indexOfObjectIdenticalTo:inParser];
	
	if (index != NSNotFound) 
	{
		if ([_delegate respondsToSelector:@selector(parserController:willUnloadParser:forMediaType:)])
		{
			[_delegate parserController:self willUnloadParser:inParser forMediaType:mediaType];
		}
		
		[parsers removeObjectAtIndex:index];
		return YES;
	}	
	
	return NO;	
}



//----------------------------------------------------------------------------------------------------------------------


// Unload all parsers that are already loaded...

- (void) reset
{
	for (NSString* mediaType in _loadedParsers)
    {
        NSArray* parsers = [_loadedParsers objectForKey:mediaType];
        
        for (IMBParser* parser in parsers)
        {
            if ([_delegate respondsToSelector:@selector(parserController:willUnloadParser:forMediaType:)])
            {
                [_delegate parserController:self willUnloadParser:parser forMediaType:mediaType];
            }
        }
    }
    
    IMBRelease(_loadedParsers)
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Debugging

#ifdef DEBUG

// Logs the list of registered parser classes. Please note that these classes may not have been instantiated yet...

- (void) logRegisteredParserClasses
{
	NSMutableString* text = [NSMutableString string];
	
	if (sRegisteredParserClasses)
	{
		for (NSString* mediaType in sRegisteredParserClasses)
		{
			[text appendFormat:@"\tmediaType = %@\n",mediaType];
			
			NSSet* parserClasses = [sRegisteredParserClasses objectForKey:mediaType];
			
			for (Class parserClass in parserClasses)
			{
				[text appendFormat:@"\t\t%@\n",NSStringFromClass(parserClass)];
			}
		}
	}
		
	NSLog(@"%s\n\n%@\n",__FUNCTION__,text);
}


// Logs the list of loaded parsers. This list may differ from the registered classes (because the delegate denied
// loading or custom parsers have been added)...

- (void) logParsers
{
	NSMutableString* text = [NSMutableString string];
	
	if (_loadedParsers)
	{
		for (NSString* mediaType in _loadedParsers)
		{
			[text appendFormat:@"\tmediaType = %@\n",mediaType];
			
			NSArray* parsers = [_loadedParsers objectForKey:mediaType];
			
			for (IMBParser* parser in parsers)
			{
				[text appendFormat:@"\t\t%@\n",[parser description]];
			}
		}
	}
		
	NSLog(@"%s\n\n%@\n",__FUNCTION__,text);
}

#endif

- (IMBParser *) parserOfClass:(Class)class forMediaType:(NSString *)aMediaType;
{
    NSParameterAssert(class);
    
    NSArray *parsers = [[self parsersByMediaType] objectForKey:aMediaType];
    for (IMBParser* parser in parsers)
    {
        if ([parser isMemberOfClass:class])
        {
            return parser;
        }
    }
    
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


@end

