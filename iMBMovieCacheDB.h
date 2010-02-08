/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
 following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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

/* MovieCacheDB
 * Used to cache MovieReference instances.
 *
 * Originally written by Martin Wennerberg (martin@norrkross.com)
 */

#import <Cocoa/Cocoa.h>

@class iMBMovieReference;

@protocol iMBMovieCacheDB
- (NSDictionary *) nextQueuedPosterAndAttributesJob; // keys are @"sourceURLString" and @"destinationPath"
- (NSDictionary *) nextQueuedMiniMovieJob;           // keys are @"sourceURLString" and @"destinationPath"
- (oneway void) setMiniMovieFilePath:(in NSString *)filename forURLString:(in NSString *)urlString;
- (oneway void) setPosterImageFilePath:(in NSString *)filename forURLString:(in NSString *)urlString;
- (oneway void) setMovieAttributes:(in NSDictionary *)dict forURLString:(in NSString *)urlString;
@end

extern NSString * const kMBMovieCacheDBRefreshedURLsNotification;   // Posted when files have changed. notificationObject is an NSSet or urlStrings
extern NSString * const kMBMovieCacheLoadedPosterImageNotification;         // Posted when a poster image was generated. notificationObject is an urlString
extern NSString * const kMBMovieCacheLoadedMiniMovieImageNotification;   // Posted when a minimovie was generated. notificationObject is an urlString
extern NSString * const kMBMovieCacheLoadedAttributesNotification;      // Posted when the attributes was generated. notificationObject is an urlString

extern NSString * const kMBMovieCacheMaxFileSizeInMB; // @"MBMovieCacheMaxFileSizeInMB" userdefaults key for max allowed size. value is NSNumber

@interface iMBMovieCacheDB : NSObject <iMBMovieCacheDB>
{
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSValue *mocKey; // used to store the managed object context in the thread dictionary.
    
    NSString        *serverIdentifier;
    NSString        *miniMoviesDirPath;
    NSString        *posterImagesDirPath;
    NSMutableSet    *posterImageTasks;
    NSMutableSet    *miniMovieTasks;
    NSMutableArray  *urlPosterImageQueue;
    NSMutableArray  *urlMiniMovieQueue;
    NSMutableSet    *alreadyQueuedPosters;
    NSMutableSet    *alreadyQueuedMiniMovies;
}

+ (iMBMovieCacheDB *) sharedMovieCacheDB;
    // Returns the shared instance

- (iMBMovieReference *) movieReferenceWithURL:(NSURL *)url;
    // Returns a movie reference for the url. If needed it's created, otherwise fetched from the cache database.

- (NSManagedObjectContext *)managedObjectContext;
    // Allows cocoa bindings access to the cached movies

// iMBMovieReference support
- (void) generateMiniMovieForURLString:(NSString *)url;                
- (void) generatePosterImageAndAttributesForURLString:(NSString *)url; 
- (NSString *) posterImagesDirPath;
- (NSString *) miniMoviesDirPath;
@end
