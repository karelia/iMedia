/*
 iMedia Browser <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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


#import <Cocoa/Cocoa.h>

// This is the common data structure used for anything been parsed into the media browser

@interface iMBLibraryNode : NSObject <NSCopying>
{
	iMBLibraryNode		*myParent; //not retained
	NSString			*myName;
	NSMutableArray		*myItems;
	NSMutableDictionary *myAttributes;
	NSImage				*myIcon;
	int					myPrioritySortOrder;
	NSString			*myIconName;
	NSMutableDictionary *myAttributeFilterMap;
	id					myParser;	// not retained
	
	NSMutableAttributedString *myCachedNameWithImage;
}

- (id)init;
- (id)initFolderWithName:(NSString*)key withItems:(NSArray*)items;

- (void)setName:(NSString *)name;
- (NSString *)name;
- (void)setIconName:(NSString *)name;	// for the identifier of the app, or an image resource (sans .extention) in imedia bundle only
- (NSString *)iconName;
- (void)setIcon:(NSImage *)icon;
- (NSImage *)icon;

- (int)prioritySortOrder; // The higher the better
- (void)setPrioritySortOrder:(int)value;

- (void)setParser:(id)parser;
- (id)parser;

- (void)setAttribute:(id)attrib forKey:(NSString *)key;
- (id)attributeForKey:(NSString *)key;
- (void)setAttributes:(NSDictionary *)attributes;
- (NSDictionary *)attributes;

// This allows us to filter out duplicate photos, music, movies etc.
- (void)setFilterDuplicateKey:(NSString *)filterKey forAttributeKey:(NSString *)attributeKey;
- (void)removeFilterDuplicateKeyForAttributeKey:(NSString *)attributeKey;
- (NSString *)filterDuplicateKeyForAttributeKey:(NSString *)attributeKey;

- (NSArray *)recursiveAttributesForKey:(NSString *)key;

// search attributes (uses recursiveAttributesForKey:)
- (NSArray *)searchAttribute:(NSString *)key withKeys:(NSArray *)keys matching:(id)value;


// Tree support
- (void)addItem:(iMBLibraryNode *)item;
- (void)removeItem:(iMBLibraryNode *)item;
- (void)removeAllItems;
- (void)insertItem:(iMBLibraryNode *)item atIndex:(unsigned)idx;
// use 'allItems' below instead of 'items' so that we don't conflict with KVC
- (void)setAllItems:(NSArray *)items;
- (NSArray *)allItems;
// this returns the aggregate of items from sub nodes
- (NSArray *)flattenedItems;

- (iMBLibraryNode *)parent;
- (iMBLibraryNode *)root;

// basically a transformer for the outline view
- (NSAttributedString *)nameWithImage;

- (NSIndexPath *)indexPath;

@end
