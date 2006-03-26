//
//  iMBLibraryNode.m
//  iMediaBrowse
//
//  Created by Greg Hulands on 24/03/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "iMBLibraryNode.h"


@implementation iMBLibraryNode

- (id)init
{
	if (self = [super init])
	{
		myItems = [[NSMutableArray array] retain];
		myAttributes = [[NSMutableDictionary dictionary] retain];
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
	[myIcon autorelease];
	myIcon = [icon retain];
}

- (NSImage *)icon
{
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
}

- (void)removeItem:(iMBLibraryNode *)item
{
	[myItems removeObject:item];
}

- (void)insertItem:(iMBLibraryNode *)item atIndex:(unsigned)idx
{
	[myItems insertObject:item atIndex:idx];
}

- (void)setItems:(NSArray *)items
{
	[myItems removeAllObjects];
	[myItems addObjectsFromArray:items];
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
		
		if (!libraryImage)
		{
			libraryImage = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:[self iconName]]] autorelease];
		}
		
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

- (NSArray *)recursiveAttributesForKey:(NSString *)key
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
		attrib = [cur attributeForKey:key];
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
	}
	return items;
}

- (id)valueForUndefinedKey:(NSString *)key
{
	return [self recursiveAttributesForKey:key];
}

@end
