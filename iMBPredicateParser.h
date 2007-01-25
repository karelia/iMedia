//
//  iMBPredicateParser.h
//  iMediaBrowse
//
//  Created by Dan Wood on 11/1/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "iMBAbstractParser.h"


@interface iMBPredicateParser : iMBAbstractParser {

	NSPredicate *myPredicate;
	NSMetadataQuery *myQuery;
}

- (id)initWithPredicateString:(NSString *)predicateString;

- (NSDictionary *)predicateSubstitutionVariables;

- (NSPredicate *)predicate;
- (void)setPredicate:(NSPredicate *)aPredicate;

- (NSMetadataQuery *)query;
- (void)setQuery:(NSMetadataQuery *)aQuery;


@end
