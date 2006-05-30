//
//  iMBLibraryNode.h
//  iMediaBrowse
//
//  Created by Greg Hulands on 24/03/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// This is the common data structure used for anything been parsed into the media browser

@interface iMBLibraryNode : NSObject <NSCopying>
{
	iMBLibraryNode		*myParent; //not retained
	NSString			*myName;
	NSMutableArray		*myItems;
	NSMutableDictionary *myAttributes;
	NSImage				*myIcon;
	NSString			*myIconName;
	NSMutableDictionary *myAttributeFilterMap;
	
	NSMutableAttributedString *myCachedNameWithImage;
}

- (id)init;
- (id)initFolderWithName:(NSString*)key withItems:(NSArray*)items;

- (void)setName:(NSString *)name;
- (NSString *)name;
- (void)setIconName:(NSString *)name;
- (NSString *)iconName;
- (void)setIcon:(NSImage *)icon;
- (NSImage *)icon;

- (void)setAttribute:(id)attrib forKey:(NSString *)key;
- (id)attributeForKey:(NSString *)key;
- (void)setAttributes:(NSDictionary *)attributes;
- (NSDictionary *)attributes;

// This allows us to filter out duplicate photos, music, movies etc.
- (void)setFilterDuplicateKey:(NSString *)filterKey forAttributeKey:(NSString *)attributeKey;
- (void)removeFilterDuplicateKeyForAttributeKey:(NSString *)attributeKey;
- (NSString *)filterDuplicateKeyForAttributeKey:(NSString *)attributeKey;

- (NSArray *)recursiveAttributesForKey:(NSString *)key;

- (void)addItem:(iMBLibraryNode *)item;
- (void)removeItem:(iMBLibraryNode *)item;
- (void)insertItem:(iMBLibraryNode *)item atIndex:(unsigned)idx;
- (void)setItems:(NSArray *)items;
- (NSArray *)items;
// this returns the aggregate of items from sub nodes
- (NSArray *)allItems;

- (iMBLibraryNode *)parent;
- (iMBLibraryNode *)root;

// basically a transformer for the outline view
- (NSAttributedString *)nameWithImage;

- (NSIndexPath *)indexPath;

@end
