/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2008 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
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
	following copyright notice: Copyright (c) 2005-2008 by Karelia Software et al.
 
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

#import "iMBLibraryNode.h"
#import "NSWorkspace+iMedia.h"

static NSMutableDictionary *sImageCache = nil;

@interface iMBLibraryNode (Private)
- (void)setParent:(iMBLibraryNode *)node;
@end

@implementation iMBLibraryNode

+ (void)initialize
{
	if ( self == [iMBLibraryNode class] ) 
	{
		// Only do some work when not called because one of our subclasses does not implement +initialize
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        sImageCache = [[NSMutableDictionary dictionary] retain];
        [pool release];
        
        // make sure nameWithImage is KVC compliant so that the bindings work properly.
        [iMBLibraryNode setKeys:[NSArray arrayWithObjects:@"name", @"icon", nil] triggerChangeNotificationsForDependentKey:@"nameWithImage"];
    }
}

- (id)init
{
	if (self = [super init])
	{
		myItems = [[NSMutableArray array] retain];
		myAttributes = [[NSMutableDictionary dictionary] retain];
		myAttributeFilterMap = [[NSMutableDictionary dictionary] retain];
		myPrioritySortOrder = 0;
	}
	return self;
}

- (id)initFolderWithName:(NSString*)name withItems:(NSArray*)items;
{
	if (self = [super init])
	{
		myItems = [items mutableCopy];
		myAttributes = [[NSMutableDictionary dictionary] retain];
		myPrioritySortOrder = 0;

		[self setName:name];
		[self setIconName:@"folder"];
	}
	return self;
}

- (void)dealloc
{
	[myName release];
	[myItems release];
	[myAttributes release];
	[myIcon release];
	[myIconName release];
	[myCachedNameWithImage release];
	[myAttributeFilterMap release];
	
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	iMBLibraryNode *copy = [[iMBLibraryNode allocWithZone:zone] init];
	[copy setName:[self name]];
	[copy setIcon:[self icon]];
	[copy setIconName:[self iconName]];
	[copy setAllItems:[self allItems]];
	[copy setAttributes:[self attributes]];
	return copy;
}

// BEGIN KVC FOR items

- (unsigned)countOfItems
{
    return [myItems count];
}

- (iMBLibraryNode *)objectInItemsAtIndex:(unsigned)index
{
    return [myItems objectAtIndex:index];
}

- (void)insertObject:(iMBLibraryNode *)item inItemsAtIndex:(unsigned)index
{
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"items"];

    [self willChangeValueForKey:@"isLeaf"];

    [myItems insertObject:item atIndex:index];
	[item setParent:self];

    [self didChangeValueForKey:@"isLeaf"];

    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"items"];
}

- (void)removeObjectFromItemsAtIndex:(unsigned)index
{
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"items"];

    [self willChangeValueForKey:@"isLeaf"];

    [[myItems objectAtIndex:index] setParent:nil];
    [myItems removeObjectAtIndex:index];

    [self didChangeValueForKey:@"isLeaf"];

    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index] forKey:@"items"];
}

- (NSMutableArray *)mutableItems
{
    return [self mutableArrayValueForKey:@"items"];
}

// END KVC FOR items

- (void)setParent:(iMBLibraryNode *)node
{
	myParent = node;
}

- (iMBLibraryNode *)parent
{
	return [[myParent retain] autorelease];
}

- (void)setName:(NSString *)name
{
	if (name && [myName isEqualToString:name])
		return; 
	[myName autorelease];
	myName = [name copy];
	[myCachedNameWithImage autorelease];
	myCachedNameWithImage = nil;
}

- (NSString *)name
{
	return myName;
}

- (BOOL)isNameEditable
{
	return NO;
}

- (void)setIconName:(NSString *)name
{
	[myIconName autorelease];
	myIconName = [name copy];
}

- (NSString *)iconName
{
	return myIconName;
}

- (void)setIcon:(NSImage *)icon
{
	if (icon != myIcon)
	{
		[myIcon release];
		myIcon = [icon retain];
	}
}

// Get icon from named cache if possible.  Special case iPhoto app icon.
- (NSImage *)icon
{
	if (!myIcon && myIconName)
	{
		myIcon = [[sImageCache objectForKey:myIconName] retain];
		if (!myIcon)
		{
			NSString *imagePath = nil;
			
			unsigned int whereColon = [myIconName rangeOfString:@":"].location;
			if (whereColon != NSNotFound)		// split into app identifier for bundle, then resource name.
			{
				NSString *identifier = [myIconName substringToIndex:whereColon];
				NSString *resource = [myIconName substringFromIndex:whereColon+1];
				NSString *appPath = [[NSWorkspace sharedWorkspace]
						absolutePathForAppBundleWithIdentifier:identifier];
				
				// No resource specified, e.g. "com.apple.iTunes:" means use app icon
				if ([resource isEqualToString:@""])
				{
					if ([[NSFileManager defaultManager] fileExistsAtPath:appPath])
					{
						myIcon = [[NSWorkspace sharedWorkspace] iconForFile:appPath];
						[myIcon setScalesWhenResized:YES];	// 30.05.2008 PB: fix the size of the icon so that it 
						[myIcon setSize:NSMakeSize(16,16)];	// fits into a menu item of the popup
					}
					else
					{
						myIcon = [NSImage imageNamed:@"NSDefaultApplicationIcon"];	// fallback
					}
					[myIcon retain];
				}
				else	// image resource after app, e.g. "com.apple.iTunes:podcast.png"
				{
					NSBundle *appBundle = [NSBundle bundleWithPath:appPath];
					imagePath = [appBundle pathForImageResource:resource];
				}
			}
			
			// OLD-style backward compatibilty -- make sure there are >= 2 "."s
			else if ([[myIconName componentsSeparatedByString:@"."] count] >= 2)
			{
					myIcon = [[[NSWorkspace sharedWorkspace] iconForAppWithBundleIdentifier:myIconName] retain];
			}
			
			else	// basic image name (w/ or w/o extension): look in iMedia's bundle ONLY
			{
				NSBundle *b = [NSBundle bundleForClass:[self class]];
				imagePath = [b pathForImageResource:myIconName];
			}
			
			if (!myIcon)	// not already set yet?
			{
				if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath])
				{
					myIcon = [[NSImage alloc] initWithContentsOfFile:imagePath];
				}
				if (!myIcon)	// nonexistent path or invalid image file?  FALLBACK
				{
					NSBundle *b = [NSBundle bundleForClass:[self class]];
					imagePath = [b pathForImageResource:@"folder"];
					myIcon = [[NSImage alloc] initWithContentsOfFile:imagePath];
				}
			}
			[sImageCache setObject:myIcon forKey:myIconName];
		}
	}
	return myIcon;
}

- (int)prioritySortOrder
{
	return myPrioritySortOrder;
}

- (void)setPrioritySortOrder:(int)value
{
	myPrioritySortOrder = value;
}

- (void)setAttribute:(id)attrib forKey:(NSString *)key
{
	if (!attrib || !key) return;
	[self willChangeValueForKey:key];
	[myAttributes setObject:attrib forKey:key];
	[self didChangeValueForKey:key];
}

- (id)attributeForKey:(NSString *)key
{
	return [myAttributes objectForKey:key];
}

- (void)setAttributes:(NSDictionary *)attributes
{
	[myAttributes addEntriesFromDictionary:attributes];
}

- (NSDictionary *)attributes
{
	return [NSDictionary dictionaryWithDictionary:myAttributes];
}

- (void)setAttributeForKeyFromArguments:(NSDictionary *)dictionary
{
    id attrib = [dictionary objectForKey:@"attrib"];
    NSString *key = [dictionary objectForKey:@"key"];
    [self setAttribute:attrib forKey:key];
}

- (void)fromThreadSetAttribute:(id)attrib forKey:(NSString *)key
{
    NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:attrib, @"attrib", key, @"key", NULL];
    [self performSelectorOnMainThread:@selector(setAttributeForKeyFromArguments:) withObject:arguments waitUntilDone:YES];
}

- (void)setFilterDuplicateKeyForAttributeKeyFromArguments:(NSDictionary *)dictionary
{
    NSString *filterKey = [dictionary objectForKey:@"filterKey"];
    NSString *attributeKey = [dictionary objectForKey:@"attributeKey"];
    [self setFilterDuplicateKey:filterKey forAttributeKey:attributeKey];
}

- (void)fromThreadSetFilterDuplicateKey:(NSString *)filterKey forAttributeKey:(NSString *)attributeKey
{
    NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:filterKey, @"filterKey", attributeKey, @"attributeKey", NULL];
    [self performSelectorOnMainThread:@selector(setFilterDuplicateKeyForAttributeKeyFromArguments:) withObject:arguments waitUntilDone:YES];
}

- (void)fromThreadAddItem:(iMBLibraryNode *)item
{
    [self performSelectorOnMainThread:@selector(addItem:) withObject:item waitUntilDone:YES];
}

- (void)addItem:(iMBLibraryNode *)item
{
    [[self mutableItems] addObject:item];
}

- (void)removeItem:(iMBLibraryNode *)item
{
    [[self mutableItems] removeObject:item];
}

- (void)removeAllItems
{
    [[self mutableItems] removeAllObjects];
}

- (void)insertItem:(iMBLibraryNode *)item atIndex:(unsigned)idx
{
    [[self mutableItems] insertObject:item atIndex:idx];
}

- (void)setAllItems:(NSArray *)items
{
    [[self mutableItems] setArray:items];
}

- (NSArray *)allItems
{
	return [NSArray arrayWithArray:[self mutableItems]];
}

- (NSArray *)flattenedItems
{
	NSMutableArray *items = [NSMutableArray array];
	NSEnumerator *e = [myItems objectEnumerator];
	iMBLibraryNode *cur;
	
	while (cur = [e nextObject])
	{
		[items addObject:cur];
		[items addObjectsFromArray:[cur flattenedItems]];
	}
	return items;
}

- (NSAttributedString *)nameWithImage
{
    // check the cache first... 
    if (myCachedNameWithImage == nil) 
	{
		NSString *rawName = [self name];
		NSImage *libraryImage = [self icon];
		
		rawName = (rawName == nil) ? @"" : rawName;
		
		// start with a mutablestring with the name (padding a space at beginning)
		myCachedNameWithImage = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@",rawName]];
		
		
		if (libraryImage != nil) 
		{
			[libraryImage setScalesWhenResized:YES];
			[libraryImage setSize:NSMakeSize(14, 14)];

			// need a filewrapper to create an NSTextAttachment
			NSFileWrapper *wrapper = [[NSFileWrapper alloc] init];
			
			// set the icon (this is what'll show up in attributed strings)
			[wrapper setIcon:libraryImage];
			
			// you need an attachment to create the attributed string as an RTFd
			NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
			
			// finally, the attributed string for the icon
			NSAttributedString *icon = [NSAttributedString attributedStringWithAttachment:attachment];
			NSMutableAttributedString *iconString
				= [[[NSMutableAttributedString alloc] initWithAttributedString:icon] autorelease];
			[iconString addAttribute:NSBaselineOffsetAttributeName
							   value:[NSNumber numberWithFloat:-2.0]
							   range:NSMakeRange(0,[iconString length])];
			[myCachedNameWithImage insertAttributedString:iconString atIndex:0];
		
			// Make the name truncate nicely if the destination is too narrow
			NSMutableParagraphStyle* paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
			[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
			[myCachedNameWithImage addAttribute:NSParagraphStyleAttributeName value:paraStyle range:NSMakeRange(0,[myCachedNameWithImage length])];
			
			// cleanup
			[wrapper release];
			[attachment release];	
		}
    }
    
    return myCachedNameWithImage;
}

- (void)setNameWithImage:(id)value
{
	// Not yet implemented, but needed if you experiment with isNameEditable returning YES
}


- (BOOL)isLeaf
{
	return [myItems count] == 0;
}

- (id)objectForKey:(id)key
{
	return [self attributeForKey:key];
}

- (NSString *)description
{
	NSMutableString *s = [NSMutableString stringWithFormat:@"iMBLibraryNode: '%@'", [self name]];
	int c = [myItems count];
	if (1 == c)
	{
		[s appendString:@" 1 child"];
	}
	else if (c)
	{
		[s appendFormat:@" %d children", c];
	}
	if ([[self attributes] count])
	{
		[s appendFormat:@"; attributes: %@", [[[self attributes] allKeys] description] ];
	}
	return s;
}

- (void)setFilterDuplicateKey:(NSString *)filterKey forAttributeKey:(NSString *)attributeKey
{
	[myAttributeFilterMap setObject:filterKey forKey:attributeKey];
}

- (void)removeFilterDuplicateKeyForAttributeKey:(NSString *)attributeKey
{
	[myAttributeFilterMap removeObjectForKey:attributeKey];
}

- (NSString *)filterDuplicateKeyForAttributeKey:(NSString *)attributeKey
{
	return [myAttributeFilterMap objectForKey:attributeKey];
}

- (NSArray *)recursiveAttributesForKey:(NSString *)key filterKey:(NSString *)filter excludingSet:(NSMutableSet *)alreadyAdded
{
	NSMutableArray *items = [NSMutableArray array];
	NSEnumerator *e = [myItems objectEnumerator];
	iMBLibraryNode *cur;
	id attrib;
	
	attrib = [self attributeForKey:key];
	if (attrib != nil)
	{
		if (![attrib isKindOfClass:[NSArray class]])
		{
			attrib = [NSArray arrayWithObject:attrib];
		}
		NSEnumerator *g = [attrib objectEnumerator];
		id curAttrib;
		NSString *filterKeyValue;
		
		while (curAttrib = [g nextObject])
		{
			if ([curAttrib isKindOfClass:[NSDictionary class]])
			{
				filterKeyValue = [curAttrib objectForKey:filter];
				if (![alreadyAdded member:filterKeyValue])
				{
					[items addObject:curAttrib];
					[alreadyAdded addObject:filterKeyValue];
				}
			}
		}
	}
	
	while (cur = [e nextObject])
	{
		attrib = [cur recursiveAttributesForKey:key filterKey:filter excludingSet:alreadyAdded];
		[items addObjectsFromArray:attrib];
	}
	return items;
}

- (NSArray *)normalRecursiveAttributesForKey:(NSString *)key
{
	NSMutableArray *items = [NSMutableArray array];
	NSEnumerator *e = [myItems objectEnumerator];
	iMBLibraryNode *cur;
	id attrib;
	
	attrib = [self attributeForKey:key];
	if (attrib != nil)
	{
		if ([attrib isKindOfClass:[NSArray class]])
		{
			[items addObjectsFromArray:attrib];
		}
		else
		{
			[items addObject:attrib];
		}
	}
	
	while (cur = [e nextObject])
	{
		attrib = [cur recursiveAttributesForKey:key];
		[items addObjectsFromArray:attrib];
	}
	return items;
}

- (NSArray *)recursiveAttributesForKey:(NSString *)key
{
	NSString *filter = [self filterDuplicateKeyForAttributeKey:key];
	NSArray *results = nil;
	
	if (filter)
	{
		NSMutableSet *exists = [NSMutableSet set];
		results = [self recursiveAttributesForKey:key filterKey:filter excludingSet:exists];
	}
	else
	{
		results = [self normalRecursiveAttributesForKey:key];
	}
	return results;
}

- (NSArray *)searchAttribute:(NSString *)key withKeys:(NSArray *)keys matching:(id)value
{
	NSMutableArray *results = [NSMutableArray array];
	id attrib = [self recursiveAttributesForKey:key];
	
	if ([attrib isKindOfClass:[NSArray class]])
	{
		NSEnumerator *e = [attrib objectEnumerator];
		id cur;
		
		while (cur = [e nextObject])
		{
			NSEnumerator *g = [keys objectEnumerator];
			NSString *curKey;
			
			while (curKey = [g nextObject])
			{
				id keyAttrib = [cur objectForKey:curKey];
				if ([keyAttrib isKindOfClass:[NSString class]])
				{
					if ([keyAttrib rangeOfString:value options:NSCaseInsensitiveSearch].location != NSNotFound)
					{
						[results addObject:cur];
						break;
					}
				}
				else
				{
					if ([keyAttrib isEqual:value])
					{
						[results addObject:cur];
						break;
					}
				}
			}
		}
	}
	
	return results;
}

- (id)valueForUndefinedKey:(NSString *)key
{
	return [self recursiveAttributesForKey:key];
}

- (void)recursivelyWalkParentsAddingPathIndexTo:(NSMutableArray *)array
{
	if ([self parent])
	{
		[[self parent] recursivelyWalkParentsAddingPathIndexTo:array];
		[array addObject:[NSNumber numberWithUnsignedInt:[[[self parent] allItems] indexOfObject:self]]];
	}
}

- (NSIndexPath *)indexPath
{
	NSMutableArray *indexes = [NSMutableArray array];
	[self recursivelyWalkParentsAddingPathIndexTo:indexes];
	
	if ([indexes count] > 0)
	{
		unsigned int *idxs = (unsigned int *)malloc(sizeof(unsigned int) * ([indexes count] + 1));
		unsigned int i;
		
		for (i = 0; i < [indexes count]; i++)
		{
			idxs[i] = [[indexes objectAtIndex:i] unsignedIntValue];
		}
		NSIndexPath *path = [NSIndexPath indexPathWithIndexes:idxs length:[indexes count]];
		free(idxs);
		return path;
	}
	return nil;
}

- (iMBLibraryNode *)root
{
	if ([self parent] == nil)
		return self;
	return [[self parent] root];
}


@end
