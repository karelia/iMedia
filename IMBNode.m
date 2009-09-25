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

#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBParser.h"
#import "IMBLibraryController.h"
#import "NSString+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@interface IMBNode ()
- (void) _recursivelyWalkParentsAddingPathIndexTo:(NSMutableArray*)inIndexArray;
@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBNode

// Primary properties...

@synthesize mediaSource = _mediaSource;
@synthesize identifier = _identifier;
@synthesize name = _name;
@synthesize icon = _icon;
@synthesize groupType = _groupType;
@synthesize attributes = _attributes;
@synthesize objects = _objects;

// Accessors for navigating up or down the node tree...

@synthesize subNodes = _subNodes;
@synthesize parentNode = _parentNode;

// State information...

@synthesize group = _group;
@synthesize leaf = _leaf;
@synthesize loading = _loading;
@synthesize wantsRecursiveObjects = _wantsRecursiveObjects;
@synthesize includedInPopup = _includedInPopup;

// Support for live watching...

@synthesize parser = _parser;
@synthesize watcherType = _watcherType;
@synthesize watchedPath = _watchedPath;

// Badge icons...

@synthesize badgeTypeNormal = _badgeTypeNormal;
@synthesize badgeTypeMouseover = _badgeTypeMouseover;
@synthesize badgeTarget = _badgeTarget;
@synthesize badgeSelector = _badgeSelector;

// Custom object view...

@synthesize customObjectView = _customObjectView;


//----------------------------------------------------------------------------------------------------------------------


- (id) init
{
	if (self = [super init])
	{
		self.groupType = kIMBGroupTypeNone;
		self.group = NO;
		self.leaf = NO;
		self.loading = NO;
		self.wantsRecursiveObjects = NO;
		self.includedInPopup = YES;
		
		self.objects = nil;
		self.subNodes = nil;
		
		self.watcherType = kIMBWatcherTypeNone;
		self.badgeTypeNormal = kIMBBadgeTypeNone;
		self.badgeTypeMouseover = kIMBBadgeTypeNone;
		
		self.customObjectView = nil;
	}
	
	return self;
}


- (id) copyWithZone:(NSZone*)inZone
{
	IMBNode* copy = [[[self class] allocWithZone:inZone] init];
	
	copy.mediaSource = self.mediaSource;
	copy.identifier = self.identifier;
	copy.name = self.name;
	copy.icon = self.icon;
	copy.attributes = self.attributes;
	copy.groupType = self.groupType;
	
	copy.group = self.group;
	copy.leaf = self.leaf;
	copy.loading = self.loading;
	copy.wantsRecursiveObjects = self.wantsRecursiveObjects;
	copy.includedInPopup = self.includedInPopup;
	
	copy.parentNode = self.parentNode;
	copy.parser = self.parser;
	copy.watcherType = self.watcherType;
	copy.watchedPath = self.watchedPath;

	copy.badgeTypeNormal = self.badgeTypeNormal;
	copy.badgeTypeMouseover = self.badgeTypeMouseover;
	copy.badgeTarget = self.badgeTarget;
	copy.badgeSelector = self.badgeSelector;
	
	copy.customObjectView = self.customObjectView;
	
	// Create a shallow copy of objects array...
	
	if (self.objects) copy.objects = [NSMutableArray arrayWithArray:self.objects];
	else copy.objects = nil;

	// Create a deep copy of the subnodes. This is essential to make background operations completely threadsafe...
	
	if (self.subNodes)
	{
		copy.subNodes = [NSMutableArray arrayWithCapacity:self.subNodes.count];

		for (IMBNode* subnode in self.subNodes)
		{
			IMBNode* copiedSubnode = [subnode copy];
			copiedSubnode.parentNode = copy;
			[(NSMutableArray*)copy.subNodes addObject:copiedSubnode];
			[copiedSubnode release];
		}
	}
	else 
	{
		copy.subNodes = nil;
	}

	return copy;
}


- (void) dealloc
{
	IMBRelease(_identifier);
	IMBRelease(_icon);
	IMBRelease(_name);
	IMBRelease(_attributes);
	IMBRelease(_objects);
	IMBRelease(_subNodes);
	IMBRelease(_parser);
	IMBRelease(_watchedPath);
	IMBRelease(_badgeTarget);
	IMBRelease(_customObjectView);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Accessors


// Node accessors. Use these for bindings the NSTreeController...

- (IMBNode*) rootNode
{
	if (_parentNode)
	{
		return [_parentNode rootNode];
	}
		
	return self;
}


- (NSUInteger) countOfSubNodes
{
	return [_subNodes count];
}


- (IMBNode*) objectInSubNodesAtIndex:(NSUInteger)inIndex
{
	return [_subNodes objectAtIndex:inIndex];
}


//----------------------------------------------------------------------------------------------------------------------


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


// Recursive object accessors. Use these for binding the NSArrayController. Please note that these accessors use
// a depth-first algorithm, hoping that most media libraries like iPhoto, iTunes, Aperture, etc do the same thing.

// The expensive filtering of duplicate objects that was done in iMedia 1.x has been eliminated as it has caused 
// substantial performance problems. It is now the responsibility of the parser classes to ensure that parent nodes
// do not contain any objects that are already contained in subnodes...

- (NSUInteger) countOfRecursiveObjects
{
	NSUInteger count = self.countOfShallowObjects;
	
	for (IMBNode* node in _subNodes)
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
	
	for (IMBNode* node in _subNodes)
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

// Nodes are grouped by type, but within a group nodes are sorted alphabetically. Nodes without a group type
// are at the end of the list...

- (NSComparisonResult) compare:(IMBNode*)inNode
{
	NSUInteger selfGroupType = self.groupType;
	NSUInteger otherGroupType = inNode.groupType;

	if (selfGroupType > otherGroupType)
	{
		return NSOrderedDescending;
	}
	else if (selfGroupType < otherGroupType)
	{
		return NSOrderedAscending;
	}
	
	return [self.name finderCompare:inNode.name];
}


//----------------------------------------------------------------------------------------------------------------------


// Check if this node or one of its ancestors is current loading in the background. In this case it will be 
// replaced shortly and is not considered to be eligible for a new background operation...

- (BOOL) isLoading
{
	if (_loading) return YES;
	if (_parentNode) return [_parentNode isLoading];
	return NO;
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
			indexes[i] = [[indexArray objectAtIndex:i] unsignedIntValue];
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
//		NSUInteger index = [_parentNode.subNodes indexOfObjectIdenticalTo:self];
//		[inIndexArray addObject:[NSNumber numberWithUnsignedInt:index]];
		
		NSUInteger index = 0;
		
		for (IMBNode* siblingNode in _parentNode.subNodes)
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
		NSString* mediaType = _parser.mediaType;
		IMBLibraryController* libraryController = [IMBLibraryController sharedLibraryControllerWithMediaType:mediaType];
//		NSUInteger index = [libraryController.rootNodes indexOfObjectIdenticalTo:self];
//		[inIndexArray addObject:[NSNumber numberWithUnsignedInt:index]];

		NSUInteger index = 0;
		
		for (IMBNode* siblingNode in libraryController.rootNodes)
		{
			if ([siblingNode.identifier isEqualToString:self.identifier])
			{
				[inIndexArray addObject:[NSNumber numberWithUnsignedInteger:index]];
				return;
			}
			
			index++;
		}
	}
	
	// Oops, we shouldn't be here...
	
	[inIndexArray addObject:[NSNumber numberWithUnsignedInteger:NSNotFound]];
}


//----------------------------------------------------------------------------------------------------------------------


// A node is considered a root node if it really is a root node (nil parent) or if it is indented by one under 
// a group node...

- (BOOL) isRootNode
{
	return self.parentNode == nil || self.parentNode.isGroup;
}


// A node is pouplated if the subnodes and objects arrays are present. Please note that these arrays may still
// be empty (this is also consider to be pouplated)...

- (BOOL) isPopulated
{
	return self.subNodes != nil && self.objects !=nil;
}


// Look in our node tree for a node with the specified identifier...

- (IMBNode*) subNodeWithIdentifier:(NSString*)inIdentfier
{
	if ([self.identifier isEqualToString:inIdentfier])
	{
		return self;
	}
	
	for (IMBNode* subnode in self.subNodes)
	{
		IMBNode* found = [subnode subNodeWithIdentifier:inIdentfier];
		if (found) return found;
	}

	return nil;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark
#pragma mark Debugging

- (NSString*) description
{
	// Basic info...
	
	NSMutableString* description = [NSMutableString stringWithFormat:@"\tIMBNode (%@) \n\t\tidentifier = %@ \n\t\tattributes = %@",
		self.name,
		self.identifier,
		self.attributes];
	
	// Objects...
	
	if ([_objects count] > 0)
	{
		[description appendFormat:@"\n\t\tobjects = %u",[_objects count]];
		for (IMBObject* object in _objects)
		{
			[description appendFormat:@"\n\t\t\t%@",object.name];
		}
	}
	
	// Subnodes...
	
	if ([_subNodes count] > 0)
	{
		[description appendFormat:@"\n\t\tsubnodes = %u",[_subNodes count]];
		for (IMBNode* subnode in _subNodes)
		{
			[description appendFormat:@"\n\t\t\t%@",subnode.name];
		}
	}
	
	return description;
}


//----------------------------------------------------------------------------------------------------------------------


@end
