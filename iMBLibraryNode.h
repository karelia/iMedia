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
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>  

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
