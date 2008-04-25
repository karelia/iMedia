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

/* MovieCacheDB
 * Used to cache MovieReference instances.
 *
 * Originally written by Martin Wennerberg (martin@norrrkross.com)
 */

#import "iMBMovieCacheDB.h"
#import "iMBMovieReference.h"
#include <stdio.h>
#include <sys/param.h>
#include <sys/sysctl.h>

static iMBMovieCacheDB   *sSharedInstance = nil;
static unsigned int sNumberOfProcessors = 2;

NSString * const kMBMovieCacheDBRefreshedURLsNotification = @"MBMovieCacheDBRefreshedURLsNotification";
NSString * const kMBMovieCacheLoadedPosterImageNotification = @"MBMovieCacheLoadedPosterImageNotification";         // Posted when a poster image was generated. notificationObject is an urlString
NSString * const kMBMovieCacheLoadedMiniMovieImageNotification = @"MBMovieCacheLoadedMiniMovieImageNotification";   // Posted when a minimovie was generated. notificationObject is an urlString
NSString * const kMBMovieCacheLoadedAttributesNotification = @"MBMovieCacheLoadedMiniMovieImageNotification";      // Posted when the attributes was generated. notificationObject is an urlString

NSString * const kMBMovieCacheMaxFileSizeInMB = @"MBMovieCacheMaxFileSizeInMB";

static unsigned int numberOfProcessors()
{
	int mib[2];
	size_t len;
	unsigned int maxproc = 1;
	
	mib[0] = CTL_HW;
	mib[1] = HW_NCPU;
	len = sizeof(maxproc);
	if (sysctl(mib, 2, &maxproc, &len, NULL, 0) == -1) {
		perror("could not determine number of cpus available");
	}
	
	return maxproc;
}

static NSString * uuidString()
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);
	return [(NSString *)uuidStr autorelease];    
}

@interface iMBMovieCacheDB (private)
- (NSPersistentStoreCoordinator *) persistentStoreCoordinator;
- (void) runServer;
- (void) launchToolsIfNeeded;
@end

@implementation iMBMovieCacheDB
+ (iMBMovieCacheDB *) sharedMovieCacheDB
{
    @synchronized ([iMBMovieCacheDB class])
    {
        if (!sSharedInstance)
            sSharedInstance = [[self alloc] init];
    }
    return sSharedInstance;
}

+ (void)initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:300.0f] forKey:kMBMovieCacheMaxFileSizeInMB]];
}

- (id) init
{
    self = [super init];
    if (self)
    {
        urlPosterImageQueue = [[NSMutableArray arrayWithCapacity:100] retain];
        urlMiniMovieQueue = [[NSMutableArray arrayWithCapacity:100] retain];
        miniMovieTasks = [[NSMutableSet setWithCapacity:8] retain];
        posterImageTasks = [[NSMutableSet setWithCapacity:8] retain];
        sNumberOfProcessors = numberOfProcessors();
        [self persistentStoreCoordinator];
        [NSThread detachNewThreadSelector:@selector(backgroundClean:) toTarget:self withObject:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(killTasks:) name:NSApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void) killTasks:sender
{
    NSMutableSet    *tasks = [[miniMovieTasks mutableCopy] autorelease];
    [tasks unionSet:posterImageTasks];
    NSEnumerator    *taskEnum = [tasks objectEnumerator];
    NSTask          *task;
    
    while ((task = [taskEnum nextObject]))
        [task terminate];
}

- (void) dealloc
{    
    [urlPosterImageQueue release]; urlPosterImageQueue = nil;
    [urlMiniMovieQueue release]; urlMiniMovieQueue = nil;
    [alreadyQueuedMiniMovies release]; alreadyQueuedMiniMovies = nil;
    [alreadyQueuedPosters release]; alreadyQueuedPosters = nil;
    [miniMoviesDirPath release]; miniMoviesDirPath = nil;
    [posterImagesDirPath release]; posterImagesDirPath = nil;
    
    [[self class] cancelPreviousPerformRequestsWithTarget:self];    // Delayed save
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self killTasks:nil];
    
    [miniMovieTasks release]; miniMovieTasks = nil;
    [posterImageTasks release]; posterImageTasks = nil;
    
    [persistentStoreCoordinator release]; persistentStoreCoordinator = nil;
    [managedObjectModel release]; managedObjectModel = nil;
    if (mocKey)
    {
        [[[NSThread currentThread] threadDictionary] removeObjectForKey:mocKey];
        [mocKey release];
        mocKey = nil;
    }
    @synchronized ([iMBMovieCacheDB class])
    {
        if ([sSharedInstance isEqual:self])
            sSharedInstance = nil;
    }
    
    [super dealloc];
}

- (NSURL *) databaseURL
{
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDirPath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    NSString *appCacheDirPath = [cacheDirPath stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    
    if ( ![fileManager fileExistsAtPath:appCacheDirPath isDirectory:NULL])
        [fileManager createDirectoryAtPath:appCacheDirPath attributes:nil];
    
    return [NSURL fileURLWithPath: [appCacheDirPath stringByAppendingPathComponent: @"MovieCache.msql"]];
}

- (NSString *) miniMoviesDirPath
{
    @synchronized (self)
    {
        if (!miniMoviesDirPath)
        {
            miniMoviesDirPath = [[[[self databaseURL] path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"MiniMovies"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:miniMoviesDirPath])
                [[NSFileManager defaultManager] createDirectoryAtPath:miniMoviesDirPath attributes:nil];
            miniMoviesDirPath = [[miniMoviesDirPath stringByStandardizingPath] retain];
        }
    }
    return miniMoviesDirPath;
}

- (NSString *) posterImagesDirPath
{
    @synchronized (self)
    {
        if (!posterImagesDirPath)
        {
            posterImagesDirPath = [[[[self databaseURL] path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"PosterImages"];
            if (![[NSFileManager defaultManager] fileExistsAtPath:posterImagesDirPath])
                [[NSFileManager defaultManager] createDirectoryAtPath:posterImagesDirPath attributes:nil];
            posterImagesDirPath = [[posterImagesDirPath stringByStandardizingPath] retain];
        }
    }
    return posterImagesDirPath;
}

- (NSString *) uniqueMiniMovieFilePath
{
	return [[[self miniMoviesDirPath] stringByAppendingPathComponent:uuidString()] stringByAppendingPathExtension:@"mov"];
}

- (NSString *) uniquePosterImageFilePath
{
	return  [[[self posterImagesDirPath] stringByAppendingPathComponent:uuidString()] stringByAppendingPathExtension:@"jp2"];    
}

- (iMBMovieReference *) movieReferenceWithURL:(NSURL *)url
{   // Can be called from thread
    if (url == nil)
        return nil;
    
	NSFetchRequest			*fetchRequest = [[[NSFetchRequest alloc] init] autorelease]; 
	NSError					*fetchError = nil; 
    NSManagedObjectContext  *moc = [self managedObjectContext];
    
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"MovieReference" inManagedObjectContext:moc]]; 
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"urlString LIKE %@", [url absoluteString]]];
    
	NSArray *array = [moc executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchError)
    {
        NSLog ([fetchError description]);
        return nil;
    }
    
    iMBMovieReference *movieCache = [array lastObject];
    
    if (!movieCache)
    {
        movieCache = [NSEntityDescription insertNewObjectForEntityForName:@"MovieReference" inManagedObjectContext:moc];
        [movieCache takeAttributesFromURL:url];
    }

    return movieCache;
}

- (BOOL)save:(NSError **)inOutError
{
    NSError *error = nil;
    BOOL    result = [[self managedObjectContext] save:&error];
    if (!result)
    {
        NSLog (@"Error %@ when saving movie cache", error);
        [alreadyQueuedMiniMovies removeAllObjects];
        [alreadyQueuedPosters removeAllObjects];
        [[self managedObjectContext] reset];
    }
    if (inOutError)
        *inOutError = error;
    return result;
}

- (NSDictionary *) nextQueuedMiniMovieJob
{
    NSURL   *url = nil;
    @synchronized (self)
    {
        if ([urlMiniMovieQueue count] > 0)
        {
            url = [[[urlMiniMovieQueue lastObject] retain] autorelease];
            [urlMiniMovieQueue removeLastObject];
        }
    }
    
    if (!url)
        return nil;
    
    return [NSDictionary dictionaryWithObjectsAndKeys:[url absoluteString], @"sourceURLString", [self uniqueMiniMovieFilePath], @"destinationPath", nil];
}

- (NSDictionary *) nextQueuedPosterAndAttributesJob
{
    NSURL   *url = nil;
    @synchronized (self)
    {
        if ([urlPosterImageQueue count] > 0)
        {
            url = [[[urlPosterImageQueue lastObject] retain] autorelease];
            [urlPosterImageQueue removeLastObject];
        }
    }
    
    if (!url)
        return nil;

    return [NSDictionary dictionaryWithObjectsAndKeys:[url absoluteString], @"sourceURLString", [self uniquePosterImageFilePath], @"destinationPath", nil];
}

- (oneway void) setMiniMovieFilePath:(in NSString *)destinationPath forURLString:(in NSString *)sourceURLString
{ // This might be called from a thread
    [self performSelectorOnMainThread:@selector(addMiniMovieFileNamesInDict:) 
                           withObject:[NSDictionary dictionaryWithObjectsAndKeys:[destinationPath lastPathComponent], sourceURLString, nil] 
                        waitUntilDone:NO
                                modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode,NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];
}

- (oneway void) setPosterImageFilePath:(in NSString *)destinationPath forURLString:(in NSString *)sourceURLString
{ // This might be called from a thread
	
	//NSLog(@"++++++ Got Thumbnail %@ for %@", [destinationPath lastPathComponent], sourceURLString);

    [self performSelectorOnMainThread:@selector(addPosterImageFileNamesInDict:) 
                           withObject:[NSDictionary dictionaryWithObjectsAndKeys:[destinationPath lastPathComponent], sourceURLString, nil] 
                        waitUntilDone:NO
                                modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode,NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];
}

- (oneway void) setMovieAttributes:(in NSDictionary *)dict forURLString:(in NSString *)urlString
{ // This might be called from a thread
    [self performSelectorOnMainThread:@selector(addMovieAttributes:) 
                           withObject:[NSDictionary dictionaryWithObjectsAndKeys:dict, urlString, nil] 
                        waitUntilDone:NO
                                modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode,NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];
}

-(NSManagedObjectContext *)managedObjectContext 
{
    if (!mocKey)
        return nil;
    
    NSManagedObjectContext *moc = [[[NSThread currentThread] threadDictionary] objectForKey:mocKey];
    if (!moc) 
    {
        NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
		moc = [[NSManagedObjectContext alloc] init];
		[moc setPersistentStoreCoordinator: coordinator];
        [moc setStalenessInterval:10];
        [moc setUndoManager:nil];
        [[[NSThread currentThread] threadDictionary] setObject:moc forKey:mocKey];
        [moc release];
    }
    
    return moc;
}

- (void) generateMiniMovieForURLString:(NSString *)s
{
    NSParameterAssert(s != nil);
    NSURL   *url = [NSURL URLWithString:s];
    if ([alreadyQueuedMiniMovies containsObject:url])
        return;
    
    @synchronized (self)
    {
        [urlMiniMovieQueue addObject:url];
        if (!serverIdentifier)
            [self runServer];
    }
    if (!alreadyQueuedMiniMovies)
        alreadyQueuedMiniMovies = [[NSMutableSet setWithCapacity:100] retain];
    [alreadyQueuedMiniMovies addObject:url];
}

- (void) generatePosterImageAndAttributesForURLString:(NSString *)s
{
    NSParameterAssert(s != nil);
    NSURL   *url = [NSURL URLWithString:s];
    if ([alreadyQueuedPosters containsObject:url])
        return;
    
    @synchronized (self)
    {
		//NSLog(@"++++++ Queuing %@", s);
		[urlPosterImageQueue addObject:url];
        if (!serverIdentifier)
            [self runServer];
    }
    if (!alreadyQueuedPosters)
        alreadyQueuedPosters = [[NSMutableSet setWithCapacity:100] retain];
    [alreadyQueuedPosters addObject:url];
}
@end

@implementation iMBMovieCacheDB (private)
- (void) taskDidTerminate:(NSNotification *)notification
{
    @synchronized(self){
        [miniMovieTasks removeObject:[notification object]];
        [posterImageTasks removeObject:[notification object]];
    }
}

- (void) launchToolsIfNeeded
{
    NSString   *launchPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"movietool" ofType:@""];
    if (!launchPath)
    {
        NSLog (@"Could not find path for movietool");
        return;
    }
    int numberOfQueuedMiniMovies = 0;
    int numberOfQueuedPosterImages = 0;
    int numberOfMiniMovieTasks = 0;
    int numberOfPosterImageTasks = 0;
    @synchronized (self) {
        numberOfMiniMovieTasks = [miniMovieTasks count];
        numberOfPosterImageTasks = [posterImageTasks count];
        numberOfQueuedMiniMovies = [urlMiniMovieQueue count];
        numberOfQueuedPosterImages = [urlPosterImageQueue count];
    }
    
    // Launch poster image tasks
    int i = MIN ((int)sNumberOfProcessors - numberOfPosterImageTasks, numberOfQueuedPosterImages);
    while (i > 0)
    {
        NSTask  *task = [[NSTask allocWithZone:[self zone]] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminate:) name:NSTaskDidTerminateNotification object:task];
        
        [task setLaunchPath:launchPath];
        // The movietool needs 2 arguments: First we pass the serverIdentifier so it can connect back to this object and then we pass archived quicktime settings.
        [task setArguments:[NSArray arrayWithObjects:@"-posterImages", @"-server", serverIdentifier, nil]];
        @synchronized (self){
            [posterImageTasks addObject:task];
        }
        [task launch];
        [task release];
        --i;
    }

    // Launch mini movie tasks
    i = MIN ((int)sNumberOfProcessors - numberOfMiniMovieTasks, numberOfQueuedMiniMovies);
    NSString    *settingsPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"minimovie" ofType:@"atomdata"];
    if (!settingsPath)
    {
        NSLog (@"Could not find minimovies settings 'minimovie.atomdata'");
        return;
    }
    
    while (i > 0)
    {
        NSTask  *task = [[NSTask allocWithZone:[self zone]] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminate:) name:NSTaskDidTerminateNotification object:task];
        
        [task setLaunchPath:launchPath];
        // The movietool needs 2 arguments: First we pass the serverIdentifier so it can connect back to this object and then we pass archived quicktime settings.
        [task setArguments:[NSArray arrayWithObjects: @"-server", serverIdentifier, @"-settings", settingsPath, @"-miniMovies", nil]];
        @synchronized (self){
            [miniMovieTasks addObject:task];
        }
        [task launch];
        [task release];
        --i;
    }
}

- (void) runServerThread:sender
{
    NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
    [self retain];

    NSConnection *connection = [[NSConnection defaultConnection] retain];
    
    [connection setRootObject:self];
    
    if ( [connection registerName:serverIdentifier] == YES )
    {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [self launchToolsIfNeeded];
        unsigned int numberOfTasks;
        @synchronized (self){
            numberOfTasks = [miniMovieTasks count] + [posterImageTasks count];
        }
        while (numberOfTasks > 0 && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]])
        {
            [self launchToolsIfNeeded];
            @synchronized (self){
                numberOfTasks = [miniMovieTasks count] + [posterImageTasks count];
            }
            [pool drain];
			[pool release];
            pool = [[NSAutoreleasePool alloc] init];
        }
    }
    [connection registerName:nil];
    [connection setRootObject:nil];
    [connection release];
    [serverIdentifier autorelease];
    serverIdentifier = nil;
    [[[NSThread currentThread] threadDictionary] removeObjectForKey:mocKey];
    [self release];
    [pool release];
}

- (void) delayedSave
{
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(save:) object:nil];
    [self performSelector:@selector(save:) withObject:nil afterDelay:10.0];
}

- (void) delayedClean
{
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(clean:) object:nil];
    [self performSelector:@selector(clean:) withObject:nil afterDelay:300];
}

- (void) addMiniMovieFileNamesInDict:(NSDictionary *)d
{   // Always run in the main thread
    NSEnumerator    *keyEnum = [d keyEnumerator];
    NSString        *key;
    
    while ((key = [keyEnum nextObject]))
    {
        iMBMovieReference    *movieRef = [self movieReferenceWithURL:[NSURL URLWithString:key]];
        [movieRef setMiniMovieFileName:[d objectForKey:key]];
        [[NSNotificationCenter defaultCenter] postNotificationName:kMBMovieCacheLoadedMiniMovieImageNotification object:key userInfo:nil];
    }
    [self delayedSave];
    [self delayedClean];
}

- (void) addPosterImageFileNamesInDict:(NSDictionary *)d
{   // Always run in the main thread
    NSEnumerator    *keyEnum = [d keyEnumerator];
    NSString        *key;
    
    while ((key = [keyEnum nextObject]))
    {
        iMBMovieReference    *movieRef = [self movieReferenceWithURL:[NSURL URLWithString:key]];
        [movieRef setPosterImageFileName:[d objectForKey:key]];
        [[NSNotificationCenter defaultCenter] postNotificationName:kMBMovieCacheLoadedPosterImageNotification object:key userInfo:nil];
    }
    [self delayedSave];
}

- (void) addMovieAttributes:(NSDictionary *)d
{   // Always run in the main thread
    NSEnumerator    *keyEnum = [d keyEnumerator];
    NSString        *key;
    
    while ((key = [keyEnum nextObject]))
    {
        [[self movieReferenceWithURL:[NSURL URLWithString:key]] setMovieAttributes:[d objectForKey:key]];
        [[NSNotificationCenter defaultCenter] postNotificationName:kMBMovieCacheLoadedAttributesNotification object:key userInfo:nil];
    }
    [self delayedSave];
}

- (void) runServer
{
    serverIdentifier = [[[NSProcessInfo processInfo] globallyUniqueString] retain];
    [NSThread detachNewThreadSelector:@selector(runServerThread:) toTarget:self withObject:self];
}

- (BOOL) isCachedMovieReferenceValid:(iMBMovieReference *)movieRef
{
    NSURL   *url = [NSURL URLWithString:[movieRef urlString]];
    if ([url isFileURL])
    {
        NSDictionary    *attributes = [[NSFileManager defaultManager] fileAttributesAtPath:[url path] traverseLink:YES];
        return (attributes != nil
                && [[attributes objectForKey:NSFileModificationDate] isEqual:[movieRef modificationDate]]
                && [[attributes objectForKey:NSFileCreationDate] isEqual:[movieRef creationDate]]);
    }
    return YES;
}

- (float) maxFileSize
{
    return [[NSUserDefaults standardUserDefaults] floatForKey:kMBMovieCacheMaxFileSizeInMB];
}

- (void) cleanUpdatedMovies
{
	NSFetchRequest			*fetchRequest = [[[NSFetchRequest alloc] init] autorelease]; 
	NSError					*fetchError = nil; 
    NSManagedObjectContext  *moc = [self managedObjectContext];
    NSError *error = nil;
    
	[fetchRequest setEntity:[NSEntityDescription entityForName:@"MovieReference" inManagedObjectContext:moc]]; 
    
	NSArray *array = [moc executeFetchRequest:fetchRequest error:&fetchError];
    if (fetchError)
    {
        NSLog ([fetchError description]);
        return;
    }
        
    NSEnumerator        *movieRefEnum = [array objectEnumerator];
    iMBMovieReference    *movieRef;
    NSMutableSet        *urlStrings = [NSMutableSet setWithCapacity:10];
    
    while ((movieRef = [movieRefEnum nextObject]))
    {
        NSAutoreleasePool       *pool = [[NSAutoreleasePool alloc] init];
        if (![self isCachedMovieReferenceValid:movieRef]) 
        {
            [urlStrings addObject:[movieRef urlString]];
            [alreadyQueuedMiniMovies removeObject:[movieRef urlString]];
            [alreadyQueuedPosters removeObject:[movieRef urlString]];
            [movieRef deleteExternalFiles];
            [moc deleteObject:movieRef]; // We could be smart and only update the entry, but this is simpler
        }
        [pool drain];
		[pool release];
    }

    if ([urlStrings count] > 0)
    {
        if (![moc save:&error])
        {
            NSLog (@"Error %@ when saving after cleaning movie cache", error);
            [alreadyQueuedMiniMovies removeAllObjects];
            [alreadyQueuedPosters removeAllObjects];
            [moc reset];
        }
    }
    
    if ([urlStrings count] > 0)
    {
        [self performSelectorOnMainThread:@selector(cleanedMovieURLs:) withObject:urlStrings waitUntilDone:NO];
    }
}

- (void) cleanUnusedFilesInDirectory:(NSString *) dirPath attribute:(NSString *) attribute
{
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    NSFetchRequest			*fetchRequest = [[[NSFetchRequest alloc] init] autorelease]; 
    NSError					*fetchError = nil; 
    NSManagedObjectContext  *moc = [self managedObjectContext];
    NSError *error = nil;
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"MovieReference" inManagedObjectContext:moc]];
    NSArray *files = [fileManager directoryContentsAtPath:dirPath];
    NSEnumerator    *fileEnum = [files objectEnumerator];
    NSString        *fileName;
  
    while ((fileName = [fileEnum nextObject]))
    {
        NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
        
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"%K LIKE %@", attribute, fileName]];
        NSArray *array = [moc executeFetchRequest:fetchRequest error:&fetchError];
        if (fetchError)
        {
            NSLog (@"Fetch error %@ when looking for %@", fetchError, fetchRequest);
            return;
        }
        if ([array count] == 0)
        {
            NSString    *fullPath = [dirPath stringByAppendingPathComponent:fileName];
            if (![fileManager removeFileAtPath:fullPath handler:nil])
            {
                NSLog (@"Error %@ when deleting unused file %@", error, fullPath);
                return;
            }
        }
        
        [pool drain];
		[pool release];
    }
}

- (void) cleanUnusedFiles
{
    [self cleanUnusedFilesInDirectory:[self miniMoviesDirPath] attribute:@"miniMovieFileName"];
    [self cleanUnusedFilesInDirectory:[self posterImagesDirPath] attribute:@"posterImageFileName"];
}

static NSComparisonResult compareFileModificationDate (NSString *key1, NSString *key2, void *context)
{
    NSDictionary *fileDict = context;
    NSDate  *date1 = [[fileDict objectForKey:key1] fileModificationDate];
    NSDate  *date2 = [[fileDict objectForKey:key2] fileModificationDate];
    
    return [date1 compare:date2];
}

- (void) shrinkUntilValidSize
{
    NSString        *dirPath = [self miniMoviesDirPath];
    NSFileManager   *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager directoryContentsAtPath:dirPath];
    NSEnumerator    *fileEnum = [files objectEnumerator];
    NSString        *fileName;
    NSMutableDictionary *fileDict = [NSMutableDictionary dictionaryWithCapacity:100];
    unsigned long long totSize = 0;
    
    while ((fileName = [fileEnum nextObject]))
    { 
        NSString    *fullPath = [dirPath stringByAppendingPathComponent:fileName];
        NSDictionary *attributes = [fileManager fileAttributesAtPath:fullPath traverseLink:NO];
        if (attributes)
            [fileDict setObject:attributes forKey:fileName];
        totSize += [attributes fileSize];
    }
    if (totSize < [self maxFileSize] * 1024 * 1024)
        return;
    
    NSArray *fileNames = [[fileDict allKeys] sortedArrayUsingFunction:compareFileModificationDate context:fileDict];
    fileEnum = [fileNames objectEnumerator];
    while ((fileName = [fileEnum nextObject]) && totSize > [self maxFileSize] * 1024 * 900)
    {
        NSString        *fullPath = [dirPath stringByAppendingPathComponent:fileName];
        NSDictionary    *attributes = [fileDict objectForKey:fileName];
        [fileManager removeFileAtPath:fullPath handler:nil];
        totSize -= [attributes fileSize];
    }
}

- (void) clean:sender
{
    [NSThread detachNewThreadSelector:@selector(backgroundClean:) toTarget:self withObject:self];
}

- (void) backgroundClean:sender
{
    NSAutoreleasePool       *pool = [[NSAutoreleasePool alloc] init];
    [[self managedObjectContext] reset];
    [self cleanUpdatedMovies];
    [self cleanUnusedFiles];
    [self shrinkUntilValidSize];
    [pool drain];
	[pool release];
}

- (void) cleanedMovieURLs:(NSSet *)urlStrings
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMBMovieCacheDBRefreshedURLsNotification object:urlStrings userInfo:nil];
}

- (NSManagedObjectModel *) managedObjectModel
{
    if (!managedObjectModel)
    {
        NSString    *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"MovieCache" ofType:@"mom"];
        NSAssert(path != nil, @"Could not find MovieCache.mom");
        managedObjectModel = [[NSManagedObjectModel allocWithZone:[self zone]] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
    }
    return managedObjectModel;
}

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator 
{
    if (!persistentStoreCoordinator) 
    {        
        
        persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
        NSURL   *url = [self databaseURL];
        
        NSError *error = nil;
        if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:&error])
        {
            NSLog (@"Error %@ when opening movie cache file at %@. Deleting file and trying again.", error, [url path]);
            // Delete the cache and try again
            [[NSFileManager defaultManager] removeFileAtPath:[url path] handler:nil];
            if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:nil error:&error])
                [[NSApplication sharedApplication] presentError:error];
            else
                NSLog (@"New database at %@ opened OK.", [url path]);
        }
        mocKey = [[NSValue valueWithNonretainedObject:[self persistentStoreCoordinator]] retain];
    }
    return persistentStoreCoordinator;
}
@end
