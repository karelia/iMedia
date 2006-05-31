/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 Please send fixes to
	<ghulands@framedphotographics.com>
	<ben@scriptsoftware.com>
 
 */
#import "iMBLibraryNode.h"
#import "NSWorkspace+iMedia.h"

static NSMutableDictionary *imageCache = nil;

@interface iMBLibraryNode (Private)
- (void)setParent:(iMBLibraryNode *)node;
@end

@implementation iMBLibraryNode

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	imageCache = [[NSMutableDictionary dictionary] retain];
	[pool release];
}

- (id)init
{
	if (self = [super init])
	{
		myItems = [[NSMutableArray array] retain];
		myAttributes = [[NSMutableDictionary dictionary] retain];
		myAttributeFilterMap = [[NSMutableDictionary dictionary] retain];
	}
	return self;
}

- (id)initFolderWithName:(NSString*)name withItems:(NSArray*)items;
{
	if (self = [super init])
	{
		myItems = [items mutableCopy];
		myAttributes = [[NSMutableDictionary dictionary] retain];
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
	[copy setItems:[self items]];
	[copy setAttributes:[self attributes]];
	return copy;
}

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
	[myName autorelease];
	myName = [name copy];
}

- (NSString *)name
{
	return myName;
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
	[myIcon release];
	myIcon = [icon retain];
}

// Get icon from named cache if possible.  Special case iPhoto app icon.
- (NSImage *)icon
{
	if (!myIcon && myIconName)
	{
		myIcon = [[imageCache objectForKey:myIconName] retain];
		if (!myIcon)
		{
			if ([myIconName rangeOfString:@"."].location != NSNotFound)
			{
				myIcon = [[[NSWorkspace sharedWorkspace]
					iconForAppWithBundleIdentifier:myIconName] retain];
			}
			else
			{
				NSBundle *b = [NSBundle bundleForClass:[self class]];
				NSString *p = [b pathForImageResource:myIconName];
				myIcon = [[NSImage alloc] initWithContentsOfFile:p];
			}
			[imageCache setObject:myIcon forKey:myIconName];
		}
	}
	return myIcon;
}

- (void)setAttribute:(id)attrib forKey:(NSString *)key
{
	[myAttributes setObject:attrib forKey:key];
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

- (void)addItem:(iMBLibraryNode *)item
{
	[myItems addObject:item];
	[item setParent:self];
}

- (void)removeItem:(iMBLibraryNode *)item
{
	[myItems removeObject:item];
	[item setParent:nil];
}

- (void)insertItem:(iMBLibraryNode *)item atIndex:(unsigned)idx
{
	[myItems insertObject:item atIndex:idx];
	[item setParent:self];
}

- (void)setItems:(NSArray *)items
{
	[myItems removeAllObjects];
	[myItems addObjectsFromArray:items];
	[items makeObjectsPerformSelector:@selector(setParent:) withObject:self];
}

- (NSArray *)items
{
	return [NSArray arrayWithArray:myItems];
}

- (NSArray *)allItems
{
	NSMutableArray *items = [NSMutableArray array];
	NSEnumerator *e = [myItems objectEnumerator];
	iMBLibraryNode *cur;
	
	while (cur = [e nextObject])
	{
		[items addObject:cur];
		[items addObjectsFromArray:[cur items]];
	}
	return items;
}

- (NSAttributedString *)nameWithImage
{
    // check the cache first... 
    if (myCachedNameWithImage == nil) 
	{
		NSString *tmpValue = [self name];
		NSImage *libraryImage = [self icon];
		
		tmpValue = (tmpValue == nil) ? @"" : tmpValue;
		
		// start with a mutablestring with the name (padding a space at beginning)
		myCachedNameWithImage = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@",tmpValue]];
		
		[libraryImage setScalesWhenResized:YES];
		[libraryImage setSize:NSMakeSize(14, 14)];
		
		if (libraryImage != nil) 
		{
			
			NSFileWrapper *wrapper = nil;
			NSTextAttachment *attachment = nil;
			NSAttributedString *icon = nil;
			
			// need a filewrapper to create an NSTextAttachment
			wrapper = [[NSFileWrapper alloc] init];
			
			// set the icon (this is what'll show up in attributed strings)
			[wrapper setIcon:libraryImage];
			
			// you need an attachment to create the attributed string as an RTFd
			attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
			
			// finally, the attributed string for the icon
			icon = [NSAttributedString attributedStringWithAttachment:attachment];
			[myCachedNameWithImage insertAttributedString:icon atIndex:0];
			
			// cleanup
			[wrapper release];
			[attachment release];	
		}
    }
    
    return myCachedNameWithImage;
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
	return [NSString stringWithFormat:@"iMBLibraryNode: %@ (%@)", [self name], [[self attributes] allKeys]];
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

- (id)valueForUndefinedKey:(NSString *)key
{
	return [self recursiveAttributesForKey:key];
}

- (void)recursivelyWalkParentsAddingPathIndexTo:(NSMutableArray *)array
{
	if ([self parent])
	{
		[[self parent] recursivelyWalkParentsAddingPathIndexTo:array];
		[array addObject:[NSNumber numberWithUnsignedInt:[[[self parent] items] indexOfObject:self]]];
	}
}

- (NSIndexPath *)indexPath
{
	NSMutableArray *indexes = [NSMutableArray array];
	[self recursivelyWalkParentsAddingPathIndexTo:indexes];
	
	if ([indexes count] > 0)
	{
		unsigned int *idxs = (unsigned int *)malloc(sizeof(unsigned int) * ([indexes count] + 1));
		int i;
		
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
