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

/* With this container class we can store the watcher issuing the FSEventCallback as weel as the file desciptor of the directory at watched path */
@interface FSEventCallbackInfo : NSObject { UKFSEventsWatcher *watcher; int fileDescriptor; }
@property (retain) UKFSEventsWatcher *watcher;
@property (assign) int fileDescriptor;
@end

@implementation FSEventCallbackInfo
@synthesize fileDescriptor, watcher;
@end

static void FSEventCallback(ConstFSEventStreamRef inStreamRef,
							void* inClientCallBackInfo, 
							size_t inNumEvents, 
							void* inEventPaths, 
							const FSEventStreamEventFlags inEventFlags[], 
							const FSEventStreamEventId inEventIds[])
{
    FSEventCallbackInfo *information = (FSEventCallbackInfo *)inClientCallBackInfo;
	UKFSEventsWatcher *watcher = information.watcher;
    int fileDescriptor = information.fileDescriptor;
    
	if (watcher != nil && [watcher delegate] != nil)
	{
		id delegate = [watcher delegate];
		if ([delegate respondsToSelector:@selector(watcher:receivedNotification:forPath:withRenamingInfo:)])
		{
            NSArray *paths = (NSArray*)inEventPaths;
            for (int i = 0; i < inNumEvents; ++i)
            {
                NSString *path = [paths objectAtIndex:i];
                if (inEventFlags[i] & kFSEventStreamEventFlagRootChanged)
                {
                    char newPathChar[MAXPATHLEN];
                    int rc = fcntl(fileDescriptor, F_GETPATH, newPathChar);
                    if (rc != -1 /* No error */)
                    {
                        NSString *newPath = [NSString stringWithUTF8String:newPathChar];
                        NSDictionary *renameInfo = @{path: newPath};
                        
                        [delegate watcher:watcher receivedNotification:UKFileWatcherWriteNotification forPath:path withRenamingInfo:renameInfo];
                        [[[NSWorkspace sharedWorkspace] notificationCenter] postNotificationName:UKFileWatcherWriteNotification
                                                                                          object:watcher userInfo:@{@"path": path}];
                    }
                    else { /* Error */ NSLog(@"%s Unable to locate new path of %@, FSEvent %lld will be ignored", __PRETTY_FUNCTION__, path, inEventIds[i]); }
                }
                else
                {
                    [delegate watcher:watcher receivedNotification:UKFileWatcherWriteNotification forPath:path withRenamingInfo:nil];                    
                    [[[NSWorkspace sharedWorkspace] notificationCenter] postNotificationName:UKFileWatcherWriteNotification
                                                                                      object:watcher userInfo:@{@"path": path}];
                }
			}
		}
	}
}

@implementation UKFSEventsWatcher

// -----------------------------------------------------------------------------
//  sharedFileWatcher:
//		Singleton accessor.
// -----------------------------------------------------------------------------

+ (id) sharedFileWatcher
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

- (id) init
{
    if (self = [super init])
	{
		latency = .7;
		flags = kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot;
		eventStreams = [NSMutableDictionary new];
        eventStreamInfos = [NSMutableDictionary new];
		eventStreamPaths = [NSCountedSet new];
    }
	
    return self;
}

// -----------------------------------------------------------------------------
//  * DESTRUCTOR:
// -----------------------------------------------------------------------------

- (void) dealloc
{
	[self removeAllPaths];
    [eventStreams release];
    [eventStreamInfos release];
	[eventStreamPaths release];
    [super dealloc];
}

- (void) finalize
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

- (void) setDelegate:(id)newDelegate
{
    delegate = newDelegate;
}

// -----------------------------------------------------------------------------
//  delegate:
//		Accessor for file watcher delegate.
// -----------------------------------------------------------------------------

- (id) delegate
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

- (BOOL) _registerFSEventsObserverForPath:(NSString*)path
{
	BOOL succeeded = YES;
    
    FSEventCallbackInfo *directoryInformation = [FSEventCallbackInfo new];
    directoryInformation.fileDescriptor = open([path UTF8String], O_RDONLY);
    directoryInformation.watcher = self;
    
	FSEventStreamContext context;
	context.info = (void*)directoryInformation;
	context.version = 0;
	context.retain = NULL;
	context.release = NULL;
	context.copyDescription = NULL;

	NSArray* pathArray = [NSArray arrayWithObject:path];
	FSEventStreamRef stream = FSEventStreamCreate(NULL,&FSEventCallback,&context,(CFArrayRef)pathArray,kFSEventStreamEventIdSinceNow,latency,flags);

	if (stream)
	{
		FSEventStreamScheduleWithRunLoop(stream,CFRunLoopGetMain(),kCFRunLoopCommonModes);
		FSEventStreamStart(stream);

		[eventStreams setObject:[NSValue valueWithPointer:stream] forKey:path];
        [eventStreamInfos setObject:directoryInformation forKey:path];
	}	
	else
	{
		NSLog( @"UKFSEventsWatcher _registerFSEventObserverForPath:%@ failed",path);
		succeeded = NO;
	}
	
	return succeeded;
}

// -----------------------------------------------------------------------------
//  addPath:
//		Start watching the folder at the specified path, or if we are already watching
//		the path, increase its count in eventStreamPaths
// -----------------------------------------------------------------------------

- (void) addPath:(NSString*)path
{
	path = [self pathToParentFolderOfFile:path];

	// Do we already have a stream scheduled for this path?
	// NOTE: Synchronize the whole thing so we don't run the risk of the current count changing while 
	// we're busy updating it with our new addition.
	@synchronized (self)
	{
		BOOL succeeded = YES;
		
		NSUInteger currentRegistrationCount = [eventStreamPaths countForObject:path];
		if (currentRegistrationCount == 0)
		{
			succeeded = [self _registerFSEventsObserverForPath:path];
		}		
		
		if (succeeded)
		{
			[eventStreamPaths addObject:path];
		}
	}
}

- (void) _unregisterFSEventStream:(FSEventStreamRef)stream
{
	FSEventStreamStop(stream);
	FSEventStreamInvalidate(stream);
	FSEventStreamRelease(stream);
}

// -----------------------------------------------------------------------------
//  removePath:
//		Decrease the watch count for the given path, and if the count has gone 
//		to zero, stop watching the given path.
// -----------------------------------------------------------------------------

- (void) removePath:(NSString*)path
{
	// Ensure we are removing a folder, not a file inside the desired folder. This matches
	// the normalization done in addPath to make sure removePath for the same path will succeed.
	path = [self pathToParentFolderOfFile:path];

    NSValue* valueToRemove = nil;
		
    @synchronized (self)
    {
		// We are sometimes asked to removePath on a path that we were never asked to add. That's 
		// OK - it just means they are being extra-certain before (probably) adding it for the 
		// first time...
		NSUInteger currentRegistrationCount = [eventStreamPaths countForObject:path];
		if (currentRegistrationCount > 0)
		{
			[eventStreamPaths removeObject:path];
			
			NSUInteger newRegistrationCount = [eventStreamPaths countForObject:path];
			
			// Clear everything out if we've gone to zero
			if (newRegistrationCount == 0)
			{
				valueToRemove = [[[eventStreams objectForKey:path] retain] autorelease];
				[eventStreams removeObjectForKey:path];				
			}
		}
    }
    
	if (valueToRemove)
	{
		FSEventStreamRef stream = [valueToRemove pointerValue];
		
		if (stream)
		{
            [[eventStreamInfos objectForKey:path] release];
            [eventStreamInfos removeObjectForKey:path];
            
			[self _unregisterFSEventStream:stream];
		}
	}
}

// -----------------------------------------------------------------------------
//  removeAllPaths:
//		Stop watching all known paths.
// -----------------------------------------------------------------------------

- (void) removeAllPaths
{
	@synchronized (self)
	{
		// We don't really need the paths, we just need the open FSEventStreamRefs.
		// Unregister them all indiscriminately, then remove all objects from 
		// our tracking collections.
		
		for (NSString *path in [eventStreams allKeys])
		{
            NSValue* thisEventStreamPointer = [eventStreams objectForKey:path];
			FSEventStreamRef stream = [thisEventStreamPointer pointerValue];

			if (stream)
			{
                
				[self _unregisterFSEventStream:stream];				
			}
		}
        
		for (NSString *path in [eventStreamInfos allKeys])
		{
            [[eventStreamInfos objectForKey:path] release];
            [eventStreamInfos removeObjectForKey:path];
        }
		
		[eventStreams removeAllObjects];
		[eventStreamPaths removeAllObjects];
	}
}

@end

#endif

