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

#import "IMBObjectArrayController.h"
#import "IMBObject.h"
#import "IMBParser.h"
#import "IMBCommon.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CONSTANTS

const NSString* kSearchStringContext = @"searchString";


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@implementation IMBObjectArrayController

@synthesize delegate = _delegate;
@synthesize searchableProperties = _searchableProperties;
@synthesize searchString = _searchString;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{

	}
	
	return self; 
}


- (void) awakeFromNib
{
	[self addObserver:self forKeyPath:@"searchString" options:0 context:(void*)kSearchStringContext];
}


- (void) dealloc
{
	[self removeObserver:self forKeyPath:@"searchString"];
	IMBRelease(_searchableProperties);
	IMBRelease(_searchString);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 


- (IBAction) search:(id)inSender
{
	[self setSearchString:[inSender stringValue]];
}


- (IBAction) resetSearch:(id)inSender
{
	if ([_searchString length])
	{
		[ibSearchField setStringValue:@""];
		[self search:ibSearchField];
	}	
}


- (void) observeValueForKeyPath:(NSString*)inKeyPath ofObject:(id)inObject change:(NSDictionary*)inChange context:(void*)inContext
{
    if (inContext == (void*)kSearchStringContext)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(rearrangeObjects) object:nil];
		[self performSelector:@selector(rearrangeObjects) withObject:nil afterDelay:0.0 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	}
	else
	{
		[super observeValueForKeyPath:inKeyPath ofObject:inObject change:inChange context:inContext];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// Set default values, and keep reference to new object -- see arrangeObjects:

- (id) newObject
{
    _newObject = [super newObject];
	
//	for (NSString* key in _searchableProperties)
//	{
//		[_newObject setValue:key forKey:key];
//	}

    return _newObject;
}

- (NSArray*) arrangeObjects:(NSArray*)inObjects
{
	BOOL hasProxyForObject = _delegate && [_delegate respondsToSelector:@selector(proxyForObject:)];

	// If we have a filterPredicate, then the array is already filtered at this point. All we need 
	// to do is replace the objects with proxies...
	
	if ([self filterPredicate])
	{
		NSArray* arrangedObjects = [super arrangeObjects:inObjects];
		if (!hasProxyForObject) return arrangedObjects;
		NSMutableArray* proxyArray = [NSMutableArray array];
		
		for (id object in arrangedObjects)
		{
			[proxyArray addObject:[_delegate proxyForObject:object]];
		}
		
		return proxyArray;
	}	
	
	
	// Without the predicate, we need to filter the array manually:
	
	else
	{
		BOOL searching = _searchString != nil && 
						 _searchableProperties != nil &&  
						 ![_searchString isEqualToString:@""] &&
						 [_searchableProperties count] > 0;
		
		// Create array of objects that match search string.
		// Also add any newly-created object unconditionally:
		// (a) You'll get an error if a newly-added object isn't added to arrangedObjects.
		// (b) The user will see newly-added objects even if they don't match the search term.
		// (c) The search is not case-sensitive.
		
		NSMutableArray* matchedObjects = [NSMutableArray arrayWithCapacity:[inObjects count]];
		NSString* lowerCaseSearchString = [_searchString lowercaseString];
/*
		// Let's try to use Spotlight to help us if at all possible.  It will be a lot faster on large data sets.
		// The trick is to figure out how to combine what the person searches for and the other constraints that we
		// want the parser object to impose, e.g. restricting to a certain folder, a certain UTI, or matching to some kind of
		// database query.  Anyhow, I'll bang out some ideas here and then we can talk about getting it merged together.
		// Also, we need to specify what properties we are matching against.
		
		// I think that maybe what we can do is to match the hits it returns against the items we are displaying, so that
		// you never can find *more* than what is in the list.
		
		// from PhotoSearch sample code

		NSMetaDataQuery     *query = [[NSMetadataQuery alloc] init];
		// We want the items in the query to automatically be sorted by the file system name; this way, we don't have to do any special sorting
		[query setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:(id)kMDItemFSName ascending:YES] autorelease]]];
		[query setPredicate:searchPredicate];
		// Use KVO to watch the results of the query
		[query addObserver:self forKeyPath:@"results" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
		[query setDelegate:self];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queryNote:) name:nil object:query];
		
		[query startQuery];
		
		
		//For images, put in the predicate: kMDItemContentTypeTree = 'public.image'
		
		//We would be matching on kMDItemKeywords
		
		//we would want to use -[NSMetaDataQuery setSearchScopes:] with the path of the folder we are searching for
*/			
		
		
		for (IMBObject* object in inObjects)
		{
			NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

			// For searching to work properly we should load object metadata if it isn't available yet,
			// because the search might require keypaths like @"metadata.*"...

			if (searching && object.metadata == nil)
			{
				[object.parser loadMetadataForObject:object];
			}

			// Give the delegate a chance to enhance an object or totally replace it with a proxy object.
			// This way an object can be customized or made more rich...
			
			id proxy = hasProxyForObject ? [_delegate proxyForObject:object] : object;
			
			// If the object has just been created, add it unconditionally...
			
			if (object == _newObject)
			{
				[matchedObjects addObject:proxy];
				_newObject = nil;
			}
			
			// Search all properties in the array. Please note that we need to check for the existance of a property 
			// (value!=nil) BEFORE checking rangeOfString: or a nil value will provide us with a positive match. 
			// This would yield way to many false results...
			
			else if (searching)
			{
				NSString* value;
				BOOL foundMatch = NO;
				
				for (NSString* key in _searchableProperties)
				{
					value = [object valueForKeyPath:key];

					if (value != nil)
					{
						if ([value isKindOfClass:[NSString class]])
						{
							NSString* thisString = [(NSString*)value lowercaseString];
							foundMatch = [thisString rangeOfString:lowerCaseSearchString].location != NSNotFound;
						}
						else
						{
							// We don't test for implementation of the search filtering method, because 
							// runtime querying for every object could be expensive. The previous contract was
							// that metadata values had to be NSString. The new contract is that metadata 
							// values have to either be NSString or else implement this filter message.
							//
							// NOTE also that if the client has a custom metadata type. we won't even make assumptions
							// about whether they want the lowercase string or not, we'll just let them dictate
							// the entire matching policy based on the user's input string.
							
							foundMatch = [value matchesSearchFilterString:_searchString];
						}
					}
					
					if (foundMatch)
					{
						[matchedObjects addObject:proxy];
						break;
					}
				}
			}
			else
			{
				[matchedObjects addObject:proxy];
			}
				
			[pool release];
		}
		
		return [super arrangeObjects:matchedObjects];
	}
}


//----------------------------------------------------------------------------------------------------------------------


@end
