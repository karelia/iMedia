/* =============================================================================
	FILE:		UKFSEventsWatcher.h
    
    COPYRIGHT:  (c) 2008 Peter Baumgartner, all rights reserved.
    
	AUTHORS:	Peter Baumgartner
    
    LICENSES:   MIT License

	REVISIONS:
		2008-06-09	PB Created.
   ========================================================================== */

// -----------------------------------------------------------------------------
//  Headers:
// -----------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "UKFileWatcher.h"
#import <Carbon/Carbon.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4

// -----------------------------------------------------------------------------
//  Class declaration:
// -----------------------------------------------------------------------------

@interface UKFSEventsWatcher : NSObject <UKFileWatcher>
{
    id							delegate;           // Delegate must respond to UKFileWatcherDelegate protocol.
	CFTimeInterval				latency;			// Time that must pass before events are being sent.
	FSEventStreamCreateFlags	flags;				// See FSEvents.h
    NSMutableDictionary*		eventStreams;		// List of FSEventStreamRef pointers in NSValues, with the pathnames as their keys.
	dispatch_queue_t			dispatchQueue;
	NSCountedSet*				eventStreamPaths;	// To support a client adding the same path multiple times, we 
													// count the number of times it's been added, and only remove when 
													// the number goes to zero...
}

+ (id) sharedFileWatcher;

- (void) setDispatchQueue:(dispatch_queue_t)queue;
- (dispatch_queue_t) dispatchQueue;

- (void) setLatency:(CFTimeInterval)latency;
- (CFTimeInterval) latency;

- (void) setFSEventStreamCreateFlags:(FSEventStreamCreateFlags)flags;
- (FSEventStreamCreateFlags) fsEventStreamCreateFlags;

// UKFileWatcher defines the methods: addPath: removePath: removeAllPaths: and delegate accessors.
//
// Our implementation differs from the basic UKFileWatcher protocol in that calls to 
// addPath and removePath are expected to be balanced so that if for example addPath:
// is called twice with the same path, it should be called twice with removePath: to 
// effect the actual ending of the FSEvent observation.
//
// removeAllPaths ensures that every watched path is no longer watched, regardless
// of the number of times addPath: has been called on a given path.
//

- (void) addPath: (NSString*)path;
- (void) removePath: (NSString*)path;
- (void)	removeAllPaths;

@end

#endif
