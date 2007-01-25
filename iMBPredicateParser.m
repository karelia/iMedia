//
//  iMBPredicateParser.m
//  iMediaBrowse
//
//  Created by Dan Wood on 11/1/06.
//


// Inspired by Jonathan Wight's spotlight-based media browser code here:
// http://toxicsoftware.com/blog/heres_your_media_browser_right_here/
// (This will be released under a BSD license)

// Largely unfinished!

#import "iMBPredicateParser.h"


@implementation iMBPredicateParser

- (id)init
{
	if (self = [super init])
	{
		
	}
	return self;
}

- (id)initWithPredicateString:(NSString *)predicateString
{
	if (self = [super init])
	{
		NSPredicate *thePredicate = [NSPredicate predicateWithFormat:predicateString];
		thePredicate = [thePredicate predicateWithSubstitutionVariables:[self predicateSubstitutionVariables]];
		[self setPredicate:thePredicate];
	}
	return self;
}

// Some starting substitutions; subclasses can replace or add more
- (NSDictionary *)predicateSubstitutionVariables
{
	NSCalendarDate *now = [NSCalendarDate calendarDate];
	NSDictionary *theDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
		[now dateByAddingYears:0  months:0  days:-1 hours:0 minutes:0 seconds:0], @"YESTERDAY",
		[now dateByAddingYears:0  months:0  days:-7 hours:0 minutes:0 seconds:0], @"LAST_WEEK",
		[now dateByAddingYears:0  months:-1 days:0  hours:0 minutes:0 seconds:0], @"LAST_MONTH",
		[now dateByAddingYears:-1 months:0  days:0  hours:0 minutes:0 seconds:0], @"THIS_YEAR",
		NULL];
	return theDictionary;
}	

- (void)dealloc
{
	[self setPredicate:nil];
	[super dealloc];
}


- (NSPredicate *)predicate
{
    return myPredicate; 
}

- (void)setPredicate:(NSPredicate *)aPredicate
{
	if (aPredicate != myPredicate)
	{
		[aPredicate retain];
		[myPredicate release];
		myPredicate = aPredicate;
		
		NSMetadataQuery *query = [self query];
		[query stopQuery];
		[query setPredicate:myPredicate];
		[query startQuery];
	}
}


- (NSMetadataQuery *)query
{
	if (!myQuery)
	{
		[self setQuery:[[[NSMetadataQuery alloc] init] autorelease]];
	}
    return myQuery; 
}

- (void)setQuery:(NSMetadataQuery *)aQuery
{
	if (myQuery != aQuery)
	{
		[myQuery setDelegate:NULL];
		[myQuery removeObserver:self forKeyPath:@"results"];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NULL object:myQuery];
		[myQuery autorelease];
		
		myQuery = [aQuery retain];
		
		[myQuery setDelegate:self];
		[myQuery addObserver:self forKeyPath:@"results" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataQueryDidStartGatheringNotification:)
													 name:NSMetadataQueryDidStartGatheringNotification object:myQuery];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataQueryGatheringProgressNotification:)
													 name:NSMetadataQueryGatheringProgressNotification object:myQuery];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataQueryDidFinishGatheringNotification:)
													 name:NSMetadataQueryDidFinishGatheringNotification object:myQuery];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataQueryDidUpdateNotification:)
													 name:NSMetadataQueryDidUpdateNotification object:myQuery];
	}
}

- (void)metadataQueryDidStartGatheringNotification:(NSNotification *)inNotification
{
	NSLog(@"metadataQueryDidStartGatheringNotification");
}
- (void)metadataQueryGatheringProgressNotification:(NSNotification *)inNotification
{
	NSLog(@"metadataQueryGatheringProgressNotification");
}
- (void)metadataQueryDidFinishGatheringNotification:(NSNotification *)inNotification
{
	NSLog(@"metadataQueryDidFinishGatheringNotification");
}
- (void)metadataQueryDidUpdateNotification:(NSNotification *)inNotification
{
	NSLog(@"metadataQueryDidUpdateNotification");
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
//	if (object == [self query] && [keyPath isEqual:@"results"])
//	{
//		if ([[change objectForKey:@"kind"] intValue] == 1)
//		{
//			//		NSLog(@"%d", [[change objectForKey:@"new"] count]);
//			NSArray *theItems = [change objectForKey:@"new"];
//			NSArray *theThumbnailerPaths = [[theItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"thumbnailLoaded == NO"]] valueForKey:@"path"];
//			NSLog(@"theThumbnailerPaths = %@", [theThumbnailerPaths description]);
//		}
//	}
}




@end
