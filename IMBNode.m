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


//----------------------------------------------------------------------------------------------------------------------


// Author: Peter Baumgartner, Mike Abdullah


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBParserMessenger.h"
#import "IMBLibraryController.h"
#import "NSString+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBNode ()

@property (assign,readwrite) IMBNode* parentNode;
@property (retain) NSArray* atomic_subnodes;				
- (void) _recursivelyWalkParentsAddingPathIndexTo:(NSMutableArray*)inIndexArray;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBNode

// Primary properties...

@synthesize icon = _icon;
@synthesize name = _name;
@synthesize identifier = _identifier;
@synthesize mediaType = _mediaType;
@synthesize mediaSource = _mediaSource;
@synthesize attributes = _attributes;
@synthesize groupType = _groupType;

// Subnodes & Objects...

@synthesize parentNode = _parentNode;
@synthesize atomic_subnodes = _subnodes;
@synthesize objects = _objects;

// Info about our parser...

@synthesize parserIdentifier = _parserIdentifier;
@synthesize parserMessenger = _parserMessenger;
@synthesize error = _error;

// State information...

@synthesize displayPriority = _displayPriority;
@synthesize displayedObjectCount = _displayedObjectCount;
@synthesize isTopLevelNode = _isTopLevelNode;
@synthesize isGroupNode = _isGroupNode;
@synthesize isLeafNode = _isLeafNode;
@synthesize isUserAdded = _isUserAdded;
@synthesize isIncludedInPopup = _isIncludedInPopup;
@synthesize wantsRecursiveObjects = _wantsRecursiveObjects;
@synthesize shouldDisplayObjectView = _shouldDisplayObjectView;

// Observing file system changes...

@synthesize watcherType = _watcherType;
@synthesize watchedPath = _watchedPath;

// Badge icons...

@synthesize badgeTypeNormal = _badgeTypeNormal;
@synthesize badgeTypeMouseover = _badgeTypeMouseover;
@synthesize badgeTarget = _badgeTarget;
@synthesize badgeSelector = _badgeSelector;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark


- (id) init
{
	if (self = [super init])
	{
		self.subnodes = nil;
		self.objects = nil;

		self.groupType = kIMBGroupTypeNone;
		self.displayPriority = 5;					// middle of the pack, default
		self.displayedObjectCount = -1;

		self.isGroupNode = NO;
		self.isTopLevelNode = NO;
		self.isLeafNode = NO;
		self.isLoading = NO;
		self.isUserAdded = NO;
		self.isIncludedInPopup = YES;
		self.wantsRecursiveObjects = NO;
		self.shouldDisplayObjectView = YES;
		
		self.watcherType = kIMBWatcherTypeNone;
		self.badgeTypeNormal = kIMBBadgeTypeNone;
		self.badgeTypeMouseover = kIMBBadgeTypeNone;
	}
	
	return self;
}


- (void) dealloc
{
    [self setSubnodes:nil];		// Sub-nodes have a weak reference to self, so break that
	
	IMBRelease(_icon);
	IMBRelease(_name);
	IMBRelease(_identifier);
	IMBRelease(_mediaType);
	IMBRelease(_mediaSource);
	IMBRelease(_attributes);
	IMBRelease(_subnodes);
	IMBRelease(_objects);
	IMBRelease(_parserMessenger);
	IMBRelease(_parserIdentifier);
	IMBRelease(_error);
	IMBRelease(_watchedPath);
	IMBRelease(_badgeTarget);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (id) copyWithZone:(NSZone*)inZone
{
	IMBNode* copy = [[[self class] allocWithZone:inZone] init];

	copy.icon = self.icon;
	copy.name = self.name;
	copy.identifier = self.identifier;
	copy.mediaType = self.mediaType;
	copy.mediaSource = self.mediaSource;
	copy.attributes = self.attributes;
	copy.groupType = self.groupType;
	copy.parserMessenger = self.parserMessenger;
	copy.parserIdentifier = self.parserIdentifier;
	copy.error = self.error;
	
	copy.displayPriority = self.displayPriority;
	copy.displayedObjectCount = self.displayedObjectCount;
	copy.isGroupNode = self.isGroupNode;
	copy.isTopLevelNode = self.isTopLevelNode;
	copy.isLeafNode = self.isLeafNode;
	copy.isLoading = self.isLoading;
	copy.isUserAdded = self.isUserAdded;
	copy.isIncludedInPopup = self.isIncludedInPopup;
	copy.wantsRecursiveObjects = self.wantsRecursiveObjects;
	copy.shouldDisplayObjectView = self.shouldDisplayObjectView;
	
	copy.watcherType = self.watcherType;
	copy.watchedPath = self.watchedPath;

	copy.badgeTypeNormal = self.badgeTypeNormal;
	copy.badgeTypeMouseover = self.badgeTypeMouseover;
	copy.badgeTarget = self.badgeTarget;
	copy.badgeSelector = self.badgeSelector;

	
	// Create a shallow copy of objects array...
	
	if (self.objects)
    {
        copy.objects = [NSMutableArray arrayWithArray:self.objects];
    }
	else
    {
        copy.objects = nil;
    }
	
	// Create a deep copy of the subnodes. This is essential to make background operations completely threadsafe...
	
	if (self.subnodes)
	{
		NSMutableArray* subnodes = [NSMutableArray arrayWithCapacity:self.subnodes.count];

		for (IMBNode* subnode in self.subnodes)
		{
			IMBNode* copiedSubnode = [subnode copy];
			[subnodes addObject:copiedSubnode];
			[copiedSubnode release];
		}
		
		copy.subnodes = subnodes;
	}
	else 
	{
		copy.subnodes = nil;
	}

	return copy;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithCoder:(NSCoder*)inCoder
{
	if ((self = [super init]))
	{
		self.name = [inCoder decodeObjectForKey:@"name"];
		self.identifier = [inCoder decodeObjectForKey:@"identifier"];
		self.mediaType = [inCoder decodeObjectForKey:@"mediaType"];
		self.mediaSource = [inCoder decodeObjectForKey:@"mediaSource"];
		self.attributes = [inCoder decodeObjectForKey:@"attributes"];
		self.groupType = [inCoder decodeIntegerForKey:@"groupType"];
		self.parserIdentifier = [inCoder decodeObjectForKey:@"parserIdentifier"];
		self.error = [inCoder decodeObjectForKey:@"error"];

		self.displayPriority = [inCoder decodeIntegerForKey:@"displayPriority"];
		self.displayedObjectCount = [inCoder decodeIntegerForKey:@"displayedObjectCount"];
		self.isGroupNode = [inCoder decodeBoolForKey:@"isGroupNode"];
		self.isTopLevelNode = [inCoder decodeBoolForKey:@"isTopLevelNode"];
		self.isLeafNode = [inCoder decodeBoolForKey:@"isLeafNode"];
		self.isLoading = [inCoder decodeBoolForKey:@"isLoading"];
		self.isUserAdded = [inCoder decodeBoolForKey:@"isUserAdded"];
		self.isIncludedInPopup = [inCoder decodeBoolForKey:@"isIncludedInPopup"];
		self.wantsRecursiveObjects = [inCoder decodeBoolForKey:@"wantsRecursiveObjects"];
		self.shouldDisplayObjectView = [inCoder decodeBoolForKey:@"shouldDisplayObjectView"];

		self.watcherType = [inCoder decodeIntegerForKey:@"watcherType"];
		self.watchedPath = [inCoder decodeObjectForKey:@"watchedPath"];

		NSMutableArray* subnodes = [inCoder decodeObjectForKey:@"subnodes"];
		if (subnodes) self.subnodes = subnodes;
		
		NSMutableArray* objects = [inCoder decodeObjectForKey:@"objects"];
		if (objects) self.objects = objects;
		
#warning TODO Peter, to account for retina displays I returned to keeping all image representations. We may have to cash icons in the app now. Did not notice any performance decrease though
        
		// Optimization: The icon is built from a single (small) image representation. See comments in method below...
		
		self.icon = [inCoder decodeObjectForKey:@"icon"];

//		NSImageRep* iconRepresentation = [inCoder decodeObjectForKey:@"iconRepresentation"];
//		
//		if (iconRepresentation)
//		{
//			NSImage* icon = [[[NSImage alloc] init] autorelease];
//			[icon addRepresentation:iconRepresentation];
//			self.icon = icon;
//		}
	}
	
	return self;
}


- (void) encodeWithCoder:(NSCoder*)inCoder
{
	[inCoder encodeObject:self.name forKey:@"name"];
	[inCoder encodeObject:self.identifier forKey:@"identifier"];
	[inCoder encodeObject:self.mediaType forKey:@"mediaType"];
	[inCoder encodeObject:self.mediaSource forKey:@"mediaSource"];
	[inCoder encodeObject:self.attributes forKey:@"attributes"];
	[inCoder encodeInteger:self.groupType forKey:@"groupType"];
	[inCoder encodeObject:self.parserIdentifier forKey:@"parserIdentifier"];
	[inCoder encodeObject:self.error forKey:@"error"];
	
	[inCoder encodeInteger:self.displayPriority forKey:@"displayPriority"];
	[inCoder encodeInteger:self.displayedObjectCount forKey:@"displayedObjectCount"];
	[inCoder encodeBool:self.isGroupNode forKey:@"isGroupNode"];
	[inCoder encodeBool:self.isTopLevelNode forKey:@"isTopLevelNode"];
	[inCoder encodeBool:self.isLeafNode forKey:@"isLeafNode"];
	[inCoder encodeBool:self.isLoading forKey:@"isLoading"];
	[inCoder encodeBool:self.isUserAdded forKey:@"isUserAdded"];
	[inCoder encodeBool:self.isIncludedInPopup forKey:@"isIncludedInPopup"];
	[inCoder encodeBool:self.wantsRecursiveObjects forKey:@"wantsRecursiveObjects"];
	[inCoder encodeBool:self.shouldDisplayObjectView forKey:@"shouldDisplayObjectView"];

	[inCoder encodeInteger:self.watcherType forKey:@"watcherType"];
	[inCoder encodeObject:self.watchedPath forKey:@"watchedPath"];
	
	if (self.subnodes) [inCoder encodeObject:self.subnodes forKey:@"subnodes"];
	if (self.objects) [inCoder encodeObject:self.objects forKey:@"objects"];
	
#warning TODO Peter, to account for retina displays I returned to keeping all image representations. We may have to cash icons in the app now. Did not notice any performance decrease though
    
	// Encoding the icon needs special attention. We only need 16x16 pixels, but the NSImage contains multiple
	// high resolution representations. Instead of encoding them all, we'll simply encode the smallest one...
	
	[inCoder encodeObject:self.icon forKey:@"icon"];

//	NSImage* icon = self.icon;
//	NSArray* reps = [icon representations];
//	NSImageRep* smallestRep = nil;
//	CGFloat smallestWidth = HUGE_VALF;
//	
//	for (NSImageRep* rep in reps)
//	{
//		NSSize size = rep.size;
//		
//		if (size.width < smallestWidth)
//		{
//			smallestWidth = size.width;
//			smallestRep = rep;
//		}
//	}
//	
//	if (smallestRep) [inCoder encodeObject:smallestRep forKey:@"iconRepresentation"];
}


//----------------------------------------------------------------------------------------------------------------------


// Set loading status for self and complete subtree...

- (void) setIsLoading:(BOOL)inLoading
{
	_isLoading = inLoading;
	
	for (IMBNode* subnode in self.subnodes)
	{
		subnode.isLoading = inLoading;
	}
}


// Check if this node or one of its ancestors is current loading in the background. In this case it will be 
// replaced shortly and is not considered to be eligible for a new background operation...

- (BOOL) isLoading
{
	if (_isLoading) return YES;
	if (_parentNode) return [_parentNode isLoading];
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Subnodes


- (void) setSubnodes:(NSArray*)inNodes
{
    [_subnodes makeObjectsPerformSelector:@selector(setParentNode:) withObject:nil];
    self.atomic_subnodes = inNodes;
    [_subnodes makeObjectsPerformSelector:@selector(setParentNode:) withObject:self];
}


- (NSArray*) subnodes
{
	return self.atomic_subnodes;
}


//----------------------------------------------------------------------------------------------------------------------


// Node accessors. Use these for bindings the NSTreeController...

- (NSUInteger) countOfSubnodes
{
	return [_subnodes count];
}


- (IMBNode*) objectInSubnodesAtIndex:(NSUInteger)inIndex
{
	return [_subnodes objectAtIndex:inIndex];
}


- (void) insertObject:(IMBNode*)inNode inSubnodesAtIndex:(NSUInteger)inIndex
{
	if (_subnodes == nil)
	{
		self.atomic_subnodes = [NSMutableArray arrayWithCapacity:1];
	}
	
	if (inIndex <= _subnodes.count)
	{
		[_subnodes insertObject:inNode atIndex:inIndex];
		inNode.parentNode = self;
	}
	else 
	{
		NSLog(@"%s ERROR trying to insert node at illegal index!",__FUNCTION__);
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: trying to insert node at illegal index" userInfo:nil] raise];
	}
}


- (void) removeObjectFromSubnodesAtIndex:(NSUInteger)inIndex
{
	if (inIndex < _subnodes.count)
	{
		IMBNode* node = [_subnodes objectAtIndex:inIndex];
		node.parentNode = nil;
		[_subnodes removeObjectAtIndex:inIndex];
	}
	else 
	{
		NSLog(@"%s ERROR trying to remove node at illegal index!",__FUNCTION__);
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: trying to remove node at illegal index" userInfo:nil] raise];
	}
}


- (void) replaceObject:(IMBNode*)inNode inSubnodesAtIndex:(NSUInteger)inIndex
{
	if (inIndex < _subnodes.count)
	{
		IMBNode* node = [_subnodes objectAtIndex:inIndex];
		node.parentNode = nil;
		[_subnodes replaceObjectAtIndex:inIndex withObject:inNode];
		inNode.parentNode = self;
	}
	else 
	{
		NSLog(@"%s ERROR trying to replace node at illegal index!",__FUNCTION__);
		[[NSException exceptionWithName:@"IMBProgrammerError" reason:@"Error: trying to replace node at illegal index" userInfo:nil] raise];
	}
}


//----------------------------------------------------------------------------------------------------------------------


// This accessor is only to be used by parser classes and IMBLibraryController, i.e. those participants that
// are offically allowed to mutate IMBNodes...

- (NSMutableArray*) mutableArrayForPopulatingSubnodes
{
	if (_subnodes == nil)
	{
		self.atomic_subnodes = [NSMutableArray arrayWithCapacity:1];
	}
	
	return [self mutableArrayValueForKey:@"subnodes"];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Objects


// Shallow object accessors. Use these for binding the NSArrayController. This only returns the objects that are
// contained directly by this node, but not those contained by any subnodes...

- (NSUInteger) countOfShallowObjects
{
	if (_objects)
	{
		return [_objects count];
	}
	
	return 0;	
}


- (IMBObject*) objectInShallowObjectsAtIndex:(NSUInteger)inIndex
{
	if (_objects)
	{
		return [_objects objectAtIndex:inIndex];
	}
	
	return nil;	
}


//----------------------------------------------------------------------------------------------------------------------


// Recursive object accessors. Please note that these accessors use a depth-first algorithm, hoping that most media 
// libraries like iPhoto, iTunes, Aperture, etc do the same thing.

// The expensive filtering of duplicate objects that was done in iMedia 1.x has been eliminated as it has caused 
// substantial performance problems. It is now the responsibility of the parser classes to ensure that parent nodes
// do not contain any objects that are already contained in subnodes...

- (NSUInteger) countOfRecursiveObjects
{
	NSUInteger count = self.countOfShallowObjects;
	
	for (IMBNode* node in _subnodes)
	{
		count += node.countOfRecursiveObjects;
	}
	
	return count;
}


- (IMBObject*) objectInRecursiveObjectsAtIndex:(NSUInteger)inIndex
{
	// If the index is smaller that number of objects at this node level, then the object must be right  
	// here in this node...
	
	NSUInteger count = self.countOfShallowObjects;
	
	if (inIndex < count)
	{
		return [self objectInShallowObjectsAtIndex:inIndex];
	}
	
	// If the index is larger, then it must be in one of the subnodes...
	
	NSUInteger index = inIndex - count;
	
	for (IMBNode* node in _subnodes)
	{
		IMBObject* object = [node objectInRecursiveObjectsAtIndex:index];
		if (object) return object;
		else index -= node.countOfRecursiveObjects;
	}
	
	// Couldn't find a object with this index (index to large). Return nil...
	
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// The bindableObjects property is used to bind the contentArray of IMBObjectArrayController. In this property 
// the node can select whether it wants to display shallow or deep (recursive) objects...

- (NSUInteger) countOfBindableObjects
{
	if (self.wantsRecursiveObjects)
	{
		return self.countOfRecursiveObjects;
	}
	else
	{
		return self.countOfShallowObjects;
	}
}


- (IMBObject*) objectInBindableObjectsAtIndex:(NSUInteger)inIndex
{
	if (self.wantsRecursiveObjects)
	{
		return [self objectInRecursiveObjectsAtIndex:inIndex];
	}
	else
	{
		return [self objectInShallowObjectsAtIndex:inIndex];
	}
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Helpers


// Nodes are considered to be equal if their identifiers match - even if we are looking at different 
// instances. This is necessary as nodes are relatively short-lived objects that are replaced with   
// new instances often - a necessity in our multithreaded environment...

- (BOOL) isEqual:(id)inNode
{
    if (self == inNode)
    {
        return YES; // fast path
    }
    else if ([inNode isKindOfClass:[IMBNode class]]) // ImageKit sometimes compares us to strings
    {
        return [[self identifier] isEqualToString:[inNode identifier]];
    }
    
    return NO;
}


- (NSUInteger) hash;
{
    return [[self identifier] hash];
}


// Nodes are grouped by type, but within a group nodes are sorted first by priority (1=top, 9=last),
// then alphabetically.  (The default value is 5.  The idea is to be able to push things UP or DOWN.)
// Nodes without a group type are at the end of the list...

- (NSComparisonResult) compare:(IMBNode*)inNode
{
	NSUInteger selfGroupType = self.groupType;
	NSUInteger selfDisplayPriority = self.displayPriority;
	NSUInteger otherGroupType = inNode.groupType;
	NSUInteger otherDisplayPriority = inNode.displayPriority;

	if (selfGroupType > otherGroupType)
	{
		return NSOrderedDescending;
	}
	else if (selfGroupType < otherGroupType)
	{
		return NSOrderedAscending;
	}
	
	if (selfDisplayPriority > otherDisplayPriority)
	{
		return NSOrderedDescending;
	}
	else if (selfDisplayPriority < otherDisplayPriority)
	{
		return NSOrderedAscending;
	}
		
	return [self.name localizedStandardCompare:inNode.name];
}


// This method find the correction insertion index for a new subnode, so that the resulting array of 
// subnodes is correctly ordered...

+ (NSUInteger) insertionIndexForNode:(IMBNode*)inSubnode inSubnodes:(NSArray*)inSubnodes
{
	NSUInteger i = 0;
	
	for (IMBNode* subnode in inSubnodes)
	{
		NSComparisonResult order = [subnode compare:inSubnode];
		if (order < 0) i++;
	}
	
	return i;
}


//----------------------------------------------------------------------------------------------------------------------


// Returns the path to this node as a NSIndexSet. Useful for working with NSTreeController and NSOutlineView...

- (NSIndexPath*) indexPath
{
	// First build the path as a array of numbers...
	
	NSMutableArray* indexArray = [NSMutableArray array];
	[self _recursivelyWalkParentsAddingPathIndexTo:indexArray];
	NSUInteger n = [indexArray count];
	
	// Then convert the NSArray into a NSIndexPath...
	
	if (n > 0)
	{
		NSUInteger* indexes = (NSUInteger*) malloc(n*sizeof(NSUInteger));
		
		for (NSUInteger i=0; i<n; i++)
		{
			indexes[i] = [[indexArray objectAtIndex:i] unsignedIntegerValue];
		}
		
		NSIndexPath* path = [NSIndexPath indexPathWithIndexes:indexes length:n];
		free(indexes);
		
		return path;
	}
	
	return nil;
}


// This helper method creates an array of numbers containing the indexes to this node...

- (void) _recursivelyWalkParentsAddingPathIndexTo:(NSMutableArray*)inIndexArray
{
	// If we have a parent then get the our index in the parents subnodes...
	
	if (_parentNode)
	{
		[_parentNode _recursivelyWalkParentsAddingPathIndexTo:inIndexArray];
		NSUInteger index = 0;
		
		for (IMBNode* siblingNode in _parentNode.subnodes)
		{
			if ([siblingNode.identifier isEqualToString:self.identifier])
			{
				[inIndexArray addObject:[NSNumber numberWithUnsignedInteger:index]];
				return;
			}
			
			index++;
		}
	}
	
	// If we are at the root the get the node index in the controllers nodes array...
	
	else
	{
		IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:self.mediaType];
		NSUInteger index = 0;
		
		for (IMBNode* node in libraryController.subnodes)
		{
			if ([node.identifier isEqualToString:self.identifier])
			{
				[inIndexArray addObject:[NSNumber numberWithUnsignedInteger:index]];
				return;
			}
			
			index++;
		}
	}
	
	// Oops, we shouldn't be here...
	
	NSLog(@"Unable to find '%@' in the source list", self.name);
	[inIndexArray addObject:[NSNumber numberWithUnsignedInteger:NSNotFound]];
}


//----------------------------------------------------------------------------------------------------------------------


// A node is pouplated if the subnodes and objects arrays are present. Please note that these arrays may still
// be empty (this is also consider to be pouplated)...

- (BOOL) isPopulated
{
	return self.subnodes != nil && self.objects !=nil;
}


// Look in our node tree for a node with the specified identifier...

- (IMBNode*) subnodeWithIdentifier:(NSString*)inIdentifier
{
	if ([self.identifier isEqualToString:inIdentifier])
	{
		return self;
	}
	
	for (IMBNode* subnode in self.subnodes)
	{
		IMBNode* found = [subnode subnodeWithIdentifier:inIdentifier];
		if (found) return found;
	}

	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


// Check if self is an ancestor of the specified node. Please note that we are using isEqual: instead of just
// comparing object pointers because nodes are short lived objects that are replaced often in our multithreaded
// environment...

- (BOOL) isAncestorOfNode:(IMBNode*)inNode
{
	IMBNode* node = inNode.parentNode;
	
	while (node)
	{
		if ([self isEqual:node]) return YES;
		node = node.parentNode;
	}
	
	return NO;
}


// Check if self is a descendant of the specified node...

- (BOOL) isDescendantOfNode:(IMBNode*)inNode
{
	for (IMBNode* node in inNode.subnodes)
	{
		if ([self isEqual:node])
		{
			return YES;
		}
		else
		{
			BOOL found = [self isDescendantOfNode:node];
			if (found) return YES;
		}
	}
	
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


// Walk towards the root of the tree until we find the top-level node. Please note that this may not be the 
// root of the tree itself, since top-level nodes may be subnodes of a group node...

- (IMBNode*) topLevelNode
{
	if (self.isTopLevelNode)
	{
		return self;
	}
	
	if (_parentNode)
	{
		return [_parentNode topLevelNode];
	}
		
	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Debugging

// Subnodes are indented by one tab...
	
- (NSString*) indentString
{
	if (_parentNode)
	{
		return [[_parentNode indentString] stringByAppendingString:@"\t"];
	}
	
	return @"";
}


- (NSString*) description
{
	// Basic info...
	
	NSMutableString* description = [NSMutableString stringWithFormat:@"%@%@ \"%@\" (%@)",
		self.indentString,
		NSStringFromClass([self class]),
		self.name,
		self.identifier];
	
	// Objects...
	
	if (_objects.count > 0)
	{
		[description appendFormat:@" - %u",_objects.count];
			
		for (IMBObject* object in _objects)
		{
			[description appendFormat:@"\n%@\t%@ \"%@\" (%@)",self.indentString,NSStringFromClass([object class]),object.name,object.identifier];
		}
	}
	
	// Subnodes...
	
	if (_subnodes.count > 0)
	{
		for (IMBNode* subnode in _subnodes)
		{
			[description appendFormat:@"\n%@",subnode.description];
		}
	}
	
	return description;
}


//----------------------------------------------------------------------------------------------------------------------


@end


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBNode (Private)

// Clear the subnodes and objects array. The node is now unpopulated again. Only to be called by parsers 
// that are about to re-populate a node...

- (void) unpopulate
{
	self.subnodes = nil;
	self.objects = nil;
}

@end


//----------------------------------------------------------------------------------------------------------------------

