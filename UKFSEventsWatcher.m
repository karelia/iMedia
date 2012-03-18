/* =============================================================================
	FILE:		UKFSEventsWatcher.m
    
    COPYRIGHT:  (c) 2008 Peter Baumgartner, all rights reserved.
    
	AUTHORS:	Peter Baumgartner
    
    LICENSES:   MIT License

	REVISIONS:
		2008-06-09	PB Created.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import "UKFSEventsWatcher.h"
#import <CoreServices/CoreServices.h>

// -----------------------------------------------------------------------------
//  FSEventCallback
//		Private callback that is called by the FSEvents framework
// -----------------------------------------------------------------------------

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4

static void FSEventCallback(ConstFSEventStreamRef inStreamRef, 
							void* inClientCallBackInfo, 
							size_t inNumEvents, 
							void* inEventPaths, 
							const FSEventStreamEventFlags inEventFlags[], 
							const FSEventStreamEventId inEventIds[])
{
	UKFSEventsWatcher* watcher = (UKFSEventsWatcher*)inClientCallBackInfo;
	
	if (watcher != nil && [watcher delegate] != nil)
	{
		id delegate = [watcher delegate];
		
		if ([delegate respondsToSelector:@selector(watcher:receivedNotification:forPath:)])
		{
			NSEnumerator* paths = [(NSArray*)inEventPaths objectEnumerator];
			NSString* path;
			
			while (path = [paths nextObject])
			{
				[delegate watcher:watcher receivedNotification:UKFileWatcherWriteNotification forPath:path];
				
				[[[NSWorkspace sharedWorkspace] notificationCenter] 
					postNotificationName: UKFileWatcherWriteNotification
					object:watcher
					userInfo:[NSDictionary dictionaryWithObjectsAndKeys:path,@"path",nil]];
			}	
		}
	}
}

@implementation UKFSEventsWatcher

// -----------------------------------------------------------------------------
//  sharedFileWatcher:
//		Singleton accessor.
// -----------------------------------------------------------------------------

+(id) sharedFileWatcher
{
	static UKFSEventsWatcher* sSharedFileWatcher = nil;
	static NSString* sSharedFileWatcherMutex = @"UKFSEventsWatcher";
	
	@synchronized(sSharedFileWatcherMutex)
	{
		if (sSharedFileWatcher == nil)
		{
			sSharedFileWatcher = [[UKFSEventsWatcher alloc] init];	// This is a singleton, and thus an intentional "leak".
		}	
    }
	
    return sSharedFileWatcher;
}

// -----------------------------------------------------------------------------
//  * CONSTRUCTOR:
// -----------------------------------------------------------------------------

-(id) init
{
    if (self = [super init])
	{
		latency = 1.0;
		flags = kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot;
		eventStreams = [[NSMutableDictionary alloc] init];
    }
	
    return self;
}

// -----------------------------------------------------------------------------
//  * DESTRUCTOR:
// -----------------------------------------------------------------------------

-(void) dealloc
{
	[self removeAllPaths];
    [eventStreams release];
    [super dealloc];
}

-(void) finalize
{
	[self removeAllPaths];
    [super finalize];
}

// -----------------------------------------------------------------------------
//  setLatency:
//		Time that must pass before events are being sent.
// -----------------------------------------------------------------------------

- (void) setLatency:(CFTimeInterval)inLatency
{
	latency = inLatency;
}

// -----------------------------------------------------------------------------
//  latency
//		Time that must pass before events are being sent.
// -----------------------------------------------------------------------------

- (CFTimeInterval) latency
{
	return latency;
}

// -----------------------------------------------------------------------------
//  setFSEventStreamCreateFlags:
//		See FSEvents.h for meaning of these flags.
// -----------------------------------------------------------------------------

- (void) setFSEventStreamCreateFlags:(FSEventStreamCreateFlags)inFlags
{
	flags = inFlags;
}

// -----------------------------------------------------------------------------
//  fsEventStreamCreateFlags
//		See FSEvents.h for meaning of these flags.
// -----------------------------------------------------------------------------

- (FSEventStreamCreateFlags) fsEventStreamCreateFlags
{
	return flags;
}

// -----------------------------------------------------------------------------
//  setDelegate:
//		Mutator for file watcher delegate.
// -----------------------------------------------------------------------------

-(void) setDelegate: (id)newDelegate
{
    delegate = newDelegate;
}

// -----------------------------------------------------------------------------
//  delegate:
//		Accessor for file watcher delegate.
// -----------------------------------------------------------------------------

-(id)   delegate
{
    return delegate;
}

// -----------------------------------------------------------------------------
//  parentFolderForFilePath:
//		We need to supply a folder to FSEvents, so if we were passed a path  
//		to a file, then convert it to the parent folder path...
// -----------------------------------------------------------------------------

- (NSString*) pathToParentFolderOfFile:(NSString*)inPath
{
	BOOL directory;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:inPath isDirectory:&directory];
	BOOL package = [[NSWorkspace sharedWorkspace] isFilePackageAtPath:inPath];
	
	if (exists && directory==NO && package==NO)
	{
		inPath = [inPath stringByDeletingLastPathComponent];
	}
	
	return inPath;		
}

// -----------------------------------------------------------------------------
//  addPath:
//		Start watching the folder at the specified path. 
// -----------------------------------------------------------------------------

-(void) addPath: (NSString*)path
{
	path = [self pathToParentFolderOfFile:path];
	NSArray* paths = [NSArray arrayWithObject:path];
				
	FSEventStreamContext context;
	context.version = 0;
	context.info = (void*) self;
	context.retain = NULL;
	context.release = NULL;
	context.copyDescription = NULL;
				
	FSEventStreamRef stream = FSEventStreamCreate(NULL,&FSEventCallback,&context,(CFArrayRef)paths,kFSEventStreamEventIdSinceNow,latency,flags);

	if (stream)
	{
		FSEventStreamScheduleWithRunLoop(stream,CFRunLoopGetMain(),kCFRunLoopCommonModes);
		FSEventStreamStart(stream);

		@synchronized (self)
		{
			// eventStreams should not already contain the given path. If it does, it implies
			// the client has inappropriately added the same path twice, leading to redundant
			// abuse of FSEvents.
			NSAssert([eventStreams objectForKey:path] == nil, @"Attempted to add a path to UKFSEventsWatcher that is already registered: %@", path);
			[eventStreams setObject:[NSValue valueWithPointer:stream] forKey:path];
		}	
	}	
	else
	{
        NSLog( @"UKFSEventsWatcher addPath:%@ failed",path);
	}
}

// -----------------------------------------------------------------------------
//  removePath:
//		Stop watching the folder at the specified path.
// -----------------------------------------------------------------------------

-(void) removePath: (NSString*)path
{
    NSValue* value = nil;
	
    @synchronized (self)
    {
        value = [[[eventStreams objectForKey:path] retain] autorelease];
        [eventStreams removeObjectForKey:path];
    }
    
	if (value)
	{
		FSEventStreamRef stream = [value pointerValue];
		
		if (stream)
		{
			FSEventStreamStop(stream);
			FSEventStreamInvalidate(stream);
			FSEventStreamRelease(stream);
		}
	}
}

// -----------------------------------------------------------------------------
//  removeAllPaths:
//		Stop watching all known folders.
// -----------------------------------------------------------------------------

-(void) removeAllPaths
{
    NSEnumerator* paths = [[eventStreams allKeys] objectEnumerator];
	NSString* path;
	
	while (path = [paths nextObject])
	{
		[self removePath:path];
	}
}

@end

#endif

