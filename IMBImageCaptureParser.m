/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
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
	following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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


// Author: Thomas Engelmeier

// Known bugs: 
// When the first camera is attached, the device node gets added twice
// The generic folder Icon does not scale correctly until the tableview cell is touched 
// Drag and Drop: Files are copied multiple times
// Drag and Drop: Download destination is in /var/tmp/..


//----------------------------------------------------------------------------------------------------------------------

#import "IMBImageCaptureParser.h"
#import "IMBParserController.h"
#import "IMBNode.h"
#import "IMBObject.h"
#import "IMBConfig.h"
#import "IMBLibraryController.h"
#import "IMBNodeObject.h"
#import "IMBObjectsPromise.h"
#import "IMBOperationQueue.h"
#import "NSFileManager+iMedia.h"
#import "NSImage+iMedia.h"
#import <Carbon/Carbon.h>
#import <Quartz/Quartz.h>
#import "NSWorkspace+iMedia.h"

//----------------------------------------------------------------------------------------------------------------------
// Internal classes:

// Purpose: protocol to keep the user informed of download progress
@class IMBMTPDownloadOperation;
@protocol IMBMTPDownloadOperationDelegate 
- (void) operationDidDownloadFile:(IMBMTPDownloadOperation*)inOperation;
- (void) operationDidFinish:(IMBMTPDownloadOperation*)inOperation;
- (void) operation:(IMBMTPDownloadOperation*)inOperation didReceiveError:(NSError *) anError;
@end

// Purpose: Gets created from drag'n drop. Triggers copying of files to a local destination 
@interface  IMBMTPObjectPromise : IMBRemoteObjectsPromise<IMBMTPDownloadOperationDelegate>
{ 
	long long _bytesTotal;
	long long _bytesDone;	
}
@property (assign,readonly) long long bytesTotal;
@property (assign,readonly) long long bytesDone;
@end

// Purpose: Copy a bunch of files 

@interface  IMBMTPDownloadOperation : NSOperation
{ 
	// input parameters
	id _delegate;
	NSArray  *_objectsToLoad;
	NSString *_downloadFolderPath;
	
	// changed during operation
	NSMutableArray  *_receivedFilePaths;
	long long _receivedBytes;
}
@property (assign)				id<IMBMTPDownloadOperationDelegate> delegate;
@property (copy)				NSArray *objectsToLoad;
@property (copy)				NSString *downloadFolderPath; 
@property (retain)				NSMutableArray *receivedFilePaths;

@property (assign)				long long receivedBytes;
@property (assign, readonly)	long long totalBytes;

@end

// Purpose: proxy thumbnails that get lazily downloaded 
@interface MTPVisualObject: IMBObject
{
}
- (void) _gotThumbnailCallback: (ICACopyObjectThumbnailPB*)pbPtr;
@end

//----------------------------------------------------------------------------------------------------------------------

@interface IMBImageCaptureParser (internal)
- (void) _installNotification;
- (void) _uninstallNotification;
- (BOOL) _isAppropriateICAType:(uint32_t) inType;
- (BOOL) _addICATree:(NSArray *)subItems toNode:(IMBNode *)inNode;
- (void) _addICAObject:(NSDictionary *) anItem toObjectArray:(NSMutableArray *) objectArray;
- (void) _gotICANotification:(NSString *) aNotification withDictionary:(NSDictionary *) aDictionary;
- (IMBNode *) _nodeForDevicelist;
- (IMBNode *) _nodeForDevice:(NSDictionary *) anDevice;
- (IMBNode *) _nodeForTempDevice:(NSDictionary *) anDevice;
- (NSString *) _identifierForICAObject:(id) anObjectID;
- (NSImage *) _getThumbnailSync:(id) anObject;
- (void) _addICADeviceList:(NSArray *) devices toNode:(IMBNode *)inNode;
@end

// Hmm, is this an internal symbol?
//#ifdef __DEBUGGING__
#if 0
#define DEBUGLOG( fmt, ... ) NSLog( fmt, __VA_ARGS__ )
#else
#define DEBUGLOG( fmt, ... ) {}
#endif

//----------------------------------------------------------------------------------------------------------------------

@implementation IMBImageCaptureParser
@synthesize loadingDevices = _loadingDevices;

+ (void) load
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[IMBParserController registerParserClass:self forMediaType:kIMBMediaTypeImage];
	[pool drain];
}

#pragma mark 
#pragma mark Parser Methods

- (id) initWithMediaType:(NSString *) anType
{
	self = [super initWithMediaType:anType];
	if (self != nil) {		
		// we prepopulate the root mediasource with the ICA ID of the list of cameras
		ICAGetDeviceListPB deviceListPB;
		memset( &deviceListPB, 0, sizeof( ICAGetDeviceListPB ));		
		OSStatus err = ICAGetDeviceList((ICAGetDeviceListPB *)&deviceListPB, NULL);
		if( err == noErr )
		{
			self.loadingDevices = [NSMutableDictionary dictionary];
			self.mediaSource = [[NSNumber numberWithInt:deviceListPB.object] stringValue];
			
			[self _installNotification];
		}
	}
	return self;
}

- (void) dealloc
{
	[self _uninstallNotification];
	
	self.loadingDevices = nil;
	self.mediaSource = nil;
	[super dealloc];
}

- (IMBObjectsPromise*) objectPromiseWithObjects:(NSArray*)inObjects 
{
	IMBMTPObjectPromise *promise = [([IMBMTPObjectPromise alloc]) initWithIMBObjects:inObjects];
	return [promise autorelease];
}
	  
// copy a given node

- (IMBNode *) nodeCopy:(const IMBNode*)inOldNode
{		
	IMBNode* newNode = [[IMBNode alloc] init];
	
	newNode.mediaSource = inOldNode.mediaSource;
	newNode.identifier = inOldNode.identifier; 
	newNode.name = inOldNode.name;
	newNode.icon = inOldNode.icon;
	newNode.parser = self;
	newNode.leaf = inOldNode.leaf;
	newNode.group = inOldNode.group;
	newNode.groupType = kIMBGroupTypeNone;
	
	// Enable ICA Event watching for all nodes...
	newNode.watcherType = kIMBWatcherTypeFirstCustom;
	newNode.watchedPath = inOldNode.watchedPath;
	
	[self populateNode:newNode options:0 error:nil];
	return newNode;
}

// Scan the given node "folder" for subfolders and add a subnode for each one we find...

- (BOOL) populateNode:(IMBNode*)inNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	DEBUGLOG( @"%s\n inNode %@",__PRETTY_FUNCTION__, inNode );
	
	NSError* error = nil;
	
	if( !inNode.objects ||
	   !inNode.subNodes )
	{ // only populate if empty
		
		ICAObject object = [inNode.mediaSource intValue];
		
		ICACopyObjectPropertyDictionaryPB copyObjectsPB; 
		memset( &copyObjectsPB, 0, sizeof(ICACopyObjectPropertyDictionaryPB));
		
		NSDictionary *propertiesDict = NULL;
		copyObjectsPB.object = object;
		copyObjectsPB.theDict = (CFDictionaryRef *) &propertiesDict; 
		OSStatus err = ICACopyObjectPropertyDictionary(&copyObjectsPB, NULL);
		
		if (err == noErr && noErr == copyObjectsPB.header.err )
		{ 
			// DEBUGLOG( @"%@", propertiesDict );
			NSArray *devices = [propertiesDict valueForKey:(NSString *)kICADevicesArrayKey];
			if( devices ) 
				[self _addICADeviceList:devices toNode:inNode];
			else 
				[self _addICATree:[(NSDictionary *)propertiesDict valueForKey:@"tree"] toNode:inNode];
			
			CFRelease( propertiesDict );
		}	
	}
	
	if (outError) *outError = error;
	return error == nil;
}

- (IMBNode*) nodeWithOldNode:(const IMBNode*)inOldNode options:(IMBOptions)inOptions error:(NSError**)outError
{
	DEBUGLOG( @"%s: old %@",__PRETTY_FUNCTION__, inOldNode );
	
	NSError* error = nil;
	
	// note: if inOldNode is nil, this represents the device list root object
	IMBNode* newNode = nil;
	
	if( inOldNode )
	{
		newNode = [[self nodeCopy:inOldNode] autorelease];
		// already done in copyNode:
		// if ( [inOldNode.subNodes count] || [inOldNode.objects count]  )
		// { 	// If the old node had subnodes, then look for subnodes in the new node...
		// 	[self populateNode:newNode options:inOptions error:&error];
		// }
	}
	else
		newNode = [self _nodeForDevicelist];
	
	if (outError) *outError = error;
	return newNode;
}

#pragma mark -
#pragma mark Internal handling
#pragma mark Populate nodes with data returned from ICA:

- (void) _addICADeviceList:(NSArray *) devices toNode:(IMBNode *)inNode
{
	// we retrieved a device list
	NSMutableArray *subnodes = [NSMutableArray array];
	NSMutableArray *deviceIdentifiers = [NSMutableArray array];
	
	for( NSDictionary *anDevice in devices )
	{
		[deviceIdentifiers addObject:[anDevice valueForKey:@"icao"]];
		
		IMBNode* deviceNode = [self _nodeForDevice:anDevice];
		[subnodes addObject:deviceNode];
	}
	
	inNode.subNodes = subnodes;
	inNode.objects = [NSArray array]; // prevent endless loop
	
	// now add any unlisted devices with an placeholder node
	NSArray *loadingIdentifiers = [self.loadingDevices allKeys];
	for( id anKey in loadingIdentifiers )
	{
		if( ![deviceIdentifiers containsObject:anKey] )
		{
			[subnodes addObject:[self _nodeForTempDevice:[self.loadingDevices objectForKey:anKey]]];
		}
	}
}
// recursive creation of subtree nodes 
// R: object had children

- (BOOL) _addICATree:(NSArray *)subItems toNode:(IMBNode *)inNode
{
	DEBUGLOG( @"%s\n inNode %@",__PRETTY_FUNCTION__, inNode );

	NSMutableArray *subnodes = [NSMutableArray array];
	NSMutableArray *objects = [NSMutableArray array];
	
	for( NSDictionary *anItem in subItems )
	{ // subitems
		uint32_t type = [[anItem valueForKey:@"file"] intValue];
		NSString *name = [anItem valueForKey:@"ifil"];
		
		if( type == kICADirectory )
		{
			if( [name length] )
			{
				NSString *imageCaptureID = [anItem valueForKey:@"icao"];
				
				IMBNode* subnode = [IMBNode new];
				subnode.mediaSource = imageCaptureID;
				subnode.identifier = [self _identifierForICAObject:imageCaptureID];
				subnode.name = name;
				subnode.parser = self;
				subnode.attributes = anItem;	
				
				// retrieve the thumbnail. Fallback is the generic folder icon 
				if( [anItem valueForKey:@"thuP"] )
					subnode.icon = [self _getThumbnailSync:imageCaptureID];
				if( !subnode.icon ) 
					subnode.icon = [NSImage imb_sharedGenericFolderIcon];
					// subnode.icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFileType:@"'fldr'"];
				
				BOOL hasSubnodes = [self _addICATree:[anItem valueForKey:@"tree"] toNode:subnode];
				subnode.leaf = !hasSubnodes;
				subnode.wantsRecursiveObjects = YES;
				
				[subnodes addObject:subnode];
				[subnode release];	
			}
			else 
			{
				// TE: On my Lumix, nameless containers are basically an logical group of related media. 
				// i.e. Movie plus poster image
				
				// options are: 
				// a.) synthesize an name from the top level object
				// b.) strip the top level object and use the UTI filter to insert it in the current node
				// As iMedia is using a filtered rep, option b makes more sense
				
				NSArray *subObjects = [anItem valueForKey:@"tree"];
				NSMutableArray *tmpObjects = [NSMutableArray array];
				
				for( NSDictionary *tmpObject in subObjects )
					[self _addICAObject:tmpObject toObjectArray:tmpObjects];
				
				// TODO: test if really only one object remained
				// TODO: test if an problem occurs with later handled removal notificatons
				[objects addObjectsFromArray:tmpObjects];
			}

		}
		else 
		{
			[self _addICAObject:anItem toObjectArray:objects];			
		}
		
	}
	inNode.subNodes = subnodes;
	inNode.objects = objects;
	return [subnodes count] > 0;
	
}

- (void) _addICAObject:(NSDictionary *) anItem toObjectArray:(NSMutableArray *) objectArray
{	
	uint32_t type = [[anItem valueForKey:@"file"] intValue];
	NSUInteger index = 0;
	
	if( [self _isAppropriateICAType:type] )
	{
		MTPVisualObject* object = [MTPVisualObject new];
		object.location = [[anItem valueForKey:@"icao"] stringValue];
		object.name = [anItem valueForKey:@"ifil"];
		object.metadata = anItem;
		object.parser = self;
		object.index = index+1;
		
		[objectArray addObject:object];
		
		[object release];
	}
}

#pragma mark Create nodes prepared for different use cases:
// populate the node for the device list

- (IMBNode *) _nodeForDevicelist
{
	DEBUGLOG( @"%s",__PRETTY_FUNCTION__ );
	
	BOOL showsGroupNodes = [IMBConfig showsGroupNodes];
	
	NSString* path = [self.mediaSource stringByStandardizingPath];
	NSString* name = NSLocalizedStringWithDefaultValue(
													   @"IMBImageCaptureParser.Devices",
													   nil,IMBBundle(),
													   @"Devices",
													   @"Caption for Image Capture Root node");
	
	// Create an empty root node (unpopulated and without subnodes)...
	
	IMBNode* newNode = [[IMBNode alloc] init];
	
	newNode.mediaSource = path;
	newNode.identifier = [self _identifierForICAObject:self.mediaSource];
	
	newNode.name = showsGroupNodes ? [name uppercaseString] : name;
	newNode.parser = self;
	newNode.leaf = NO;
	
	if( !showsGroupNodes ) 
		newNode.icon = [[NSWorkspace imb_threadSafeWorkspace] iconForFile:@"/Applications/Image Capture.app"];
	
	newNode.group = showsGroupNodes;
	newNode.groupType = kIMBGroupTypeNone;
	
	// Enable ICA Event watching for all nodes...
	newNode.watcherType = kIMBWatcherTypeFirstCustom;
	newNode.watchedPath = path;
	
	[self populateNode:newNode options:0 error:nil];
	return [newNode autorelease];
}

// populate the node for an single device

- (IMBNode *) _nodeForDevice:(NSDictionary *) anDevice
{
	DEBUGLOG( @"%s: device %@",__PRETTY_FUNCTION__, anDevice );

	NSString* parserClassName = NSStringFromClass([self class]);
	
	IMBNode* subnode = [IMBNode new];
	
	subnode.mediaSource = [anDevice valueForKey:@"icao"];
	
	subnode.identifier = [NSString stringWithFormat:@"%@:/%@",parserClassName,subnode.mediaSource];
	NSString *name = [anDevice valueForKey:@"ICAUserdefinedName"];
	if( !name || ![name length] )
		name = [anDevice valueForKey:@"ifil"];
	subnode.name = name;
	subnode.icon = [self _getThumbnailSync:subnode.mediaSource]; 
	subnode.parser = self;
	subnode.leaf = NO;
	subnode.wantsRecursiveObjects = YES;
	
	subnode.attributes = anDevice;
	return [subnode autorelease];
}

- (IMBNode *) _nodeForTempDevice:(NSDictionary *) anDevice
{
	DEBUGLOG( @"%s\n temp %@",__PRETTY_FUNCTION__, anDevice );

	NSString* parserClassName = NSStringFromClass([self class]);
	
	IMBNode* subnode = [IMBNode new];
	
	subnode.mediaSource = [anDevice valueForKey:@"icao"];
	
	subnode.identifier = [NSString stringWithFormat:@"%@:/%@",parserClassName,subnode.mediaSource];
	NSString *name = NSLocalizedStringWithDefaultValue(@"IMBImageCaptureParser.loading",nil,IMBBundle(),@"Loading…",@"Caption for loading camera");
	subnode.name = name;
	//	subnode.icon = [self _getThumbnailSync:subnode.mediaSource]; 
	subnode.parser = self;
	subnode.group = NO;
	subnode.leaf = YES;
	subnode.wantsRecursiveObjects = NO;
	subnode.loading = YES;
	
	subnode.attributes = anDevice;
	return [subnode autorelease];
}



//----------------------------------------------------------------------------------------------------------------------

- (NSString *) _identifierForICAObject:(id) anObjectID
{
	NSString* parserClassName = NSStringFromClass([self class]);
	if( ![anObjectID isKindOfClass:[NSString class]] )
		anObjectID = [anObjectID stringValue];
	NSString *path = [anObjectID stringByStandardizingPath];
	
	return [NSString stringWithFormat:@"%@:/%@",parserClassName,path];	
}

- (BOOL) _isAppropriateICAType:(uint32_t) inType
{
	BOOL isOurType = NO;
	switch( inType )
	{
			//		case kICAList:	
			//		case kICADirectory: 
			//		case kICAFile: 
			//		case kICAFileFirmware:
			//		case kICAFileOther: 
			
		case kICAFileImage:
			isOurType = [self.mediaType isEqualTo:kIMBMediaTypeImage];
			break;
		case kICAFileMovie:
			isOurType = [self.mediaType isEqualTo:kIMBMediaTypeMovie];
			break;
		case kICAFileAudio:
			isOurType = [self.mediaType isEqualTo:kIMBMediaTypeAudio];
			break;
	}
	return isOurType;
}

- (NSImage *) _getThumbnailSync:(id) anObject
{
	NSImage *image = NULL;
	NSData *data = NULL;
    ICACopyObjectThumbnailPB    pb = { 0  };
    
    pb.header.refcon   = 0L; 
    pb.thumbnailFormat = kICAThumbnailFormatTIFF; // gives transparency
    pb.object          = [anObject intValue];
	pb.thumbnailData   = (CFDataRef*) &data;
    
    /*err =*/ ICACopyObjectThumbnail( &pb, NULL );
	if (noErr == pb.header.err)
    {
        // got the thumbnail data, now create an image...
		image = [[NSImage alloc] initWithData:data];
		[image setScalesWhenResized:YES];
		[image setSize:NSMakeSize(16.0,16.0)];
		[data release];
		DEBUGLOG( @"%s -> %@", __PRETTY_FUNCTION__, self );
    }
	return [image autorelease];
}

#pragma mark Image Capture Notification Handling:

// watching:
static void ICANotificationCallback(CFStringRef notificationType, CFDictionaryRef notificationDictionary)
{
	id self_ = [[(NSDictionary *)notificationDictionary valueForKey:@"ICARefconKey"] pointerValue];
	[self_ _gotICANotification:(NSString *)notificationType withDictionary:(NSDictionary *)notificationDictionary];
}

// ———————————————————————————————————————————————————————————————————————————
// - installNotification:
// ———————————————————————————————————————————————————————————————————————————
- (void)_installNotification
{
	NSAssert( sizeof(id) <= sizeof(unsigned long), @"Need enough space to stope an pointer in the ImageCapture Refcon" ); 
    ICARegisterForEventNotificationPB pb;
    OSErr	err;
	
    memset(&pb, 0, sizeof(ICARegisterForEventNotificationPB));
    pb.header.refcon = (unsigned long)self;
    pb.objectOfInterest  = 0;	// all objects
    pb.eventsOfInterest	 = (CFArrayRef)[NSArray arrayWithObjects:
							// object level:
							///	kICANotificationTypeObjectAdded, => when the device is connected, first a flood of those notifications arrives
								(NSString *) kICANotificationTypeObjectRemoved, 
								(NSString *) kICANotificationTypeObjectInfoChanged,
							// memory card level:
								(NSString *) kICANotificationTypeStoreAdded,
								(NSString *) kICANotificationTypeStoreRemoved,
							// device level:
								(NSString *) kICANotificationTypeDeviceAdded, // issued after all object info is retrieved
								(NSString *) kICANotificationTypeDeviceRemoved,  // issued immediately when the device goes off
								(NSString *) kICANotificationTypeDeviceInfoChanged, // issued when another driver takes over 
								(NSString *) kICANotificationTypeDeviceWasReset, 
// the following two constants are tagged as appearing from 10.5 on in the 10.6
// but in reality they appear in the 10.6 SDK 										
//								(NSString *) kICANotificationTypeDeviceStatusInfo, 
//								(NSString *) kICANotificationTypeDeviceStatusError,
							
								(NSString *) kICANotificationTypeUnreportedStatus, 
								(NSString *) kICANotificationTypeDeviceConnectionProgress, 
							nil];
							
							
	pb.notificationProc	 = ICANotificationCallback;
	pb.options = NULL;
    err = ICARegisterForEventNotification(&pb, NULL);
    if (noErr == err) 
    {
        DEBUGLOG(@"@", @"ICA notification callback registered");
    }
}

- (void) _uninstallNotification
{
	ICARegisterForEventNotificationPB pb;
    OSErr	err;
	
    memset(&pb, 0, sizeof(ICARegisterForEventNotificationPB));
    pb.header.refcon = (unsigned long)self;
    pb.objectOfInterest  = 0;	// all objects
    pb.eventsOfInterest	 = NULL;
	pb.notificationProc	 = ICANotificationCallback;
	pb.options = NULL;
    err = ICARegisterForEventNotification(&pb, NULL);
    if (noErr == err) 
    {
        NSLog(@"ICA notification callback unregistered");
    }
}

// ———————————————————————————————————————————————————————————————————————————
// - handleNotification:
// ———————————————————————————————————————————————————————————————————————————
- (void) _gotICANotification:(NSString *) aNotification withDictionary:(NSDictionary *) aDictionary
{
	DEBUGLOG( @"%s: %@",__PRETTY_FUNCTION__, aNotification );
	DEBUGLOG( @"%@", aDictionary );
	id objectID = nil;
	
	// for those hardcoded string constants, probably a == comparison instead of a full isEqualTo: would be sufficient
	
	// trigger node change notifications:
	
	if( [aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceConnectionProgress] ||
		[aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceAdded] ||
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceRemoved] )
	{ 
		// reload the whole device list:
		objectID = [aDictionary valueForKey:(NSString *)kICANotificationDeviceListICAObjectKey];
	}	

	
	if( [aNotification isEqualTo:(NSString *)kICANotificationTypeDeviceConnectionProgress] )
	{ 		
		@synchronized( _loadingDevices ) 
		{
			// it seems the 100% read notification arrives directly AFTER the device added notification.
			// prevent overriding the newly added device:
			
			id percentCompleted = [aDictionary valueForKey:(NSString *) kICANotificationPercentDownloadedKey];
			if( [percentCompleted intValue] < 100 ) 
			{
				// from some point ICAUserdefinedName is also set. reload the node contents?
				id deviceID = [aDictionary objectForKey:(NSString *)kICANotificationDeviceICAObjectKey];
				NSDictionary *deviceDict = 
					[NSDictionary dictionaryWithObjectsAndKeys:
						percentCompleted, kICANotificationPercentDownloadedKey,
						deviceID, @"icao",
					 nil];
				[_loadingDevices setObject:deviceDict forKey:deviceID];
			}
			else 
			{
				[_loadingDevices setObject:nil forKey:objectID];
			}
		}  // end  lock
	}
	
	if( !objectID && 
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeStoreAdded] || 
	    [aNotification isEqualTo:(NSString *)kICANotificationTypeStoreRemoved] )
	{ 
		// Reload the device
		// TODO: test with devices with two card slots
		objectID =  [aDictionary valueForKey:(NSString *)kICANotificationDeviceICAObjectKey];
	} 
	
	if( objectID )
	{
		// find it in the node tree
		IMBLibraryController *libController = [IMBLibraryController sharedLibraryControllerWithMediaType:[self mediaType]];
		
		IMBNode *rootNode = [libController topLevelNodeForParser:self];
		[libController reloadNode:rootNode parser:self];
	}
 
}
@end 

/******************************** Visuals objects for the browser *******************************/
#pragma mark -

@implementation MTPVisualObject

// ---------------------------------------------------------------------------------------------------------------------
static void ICAThumbnailCallback (ICAHeader* pbHeader)
{
    // we use the refcon to get back to the ICAHandler
    MTPVisualObject * handler = (MTPVisualObject *)pbHeader->refcon;
    if (handler)
        [handler _gotThumbnailCallback: (ICACopyObjectThumbnailPB*) pbHeader];
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		// properties of the baseclass -> no need for implementing dealloc
		self.imageRepresentationType = IKImageBrowserNSDataRepresentationType;
		self.imageVersion = 1;
	}
	return self;
}

// ---------------------------------------------------------------------------------------------------------------------
- (void) _gotThumbnailCallback: (ICACopyObjectThumbnailPB*)pbPtr
{
	self.isLoadingThumbnail = NO;
    if (noErr == pbPtr->header.err)
    {
        // got the thumbnail data, now create an image...
        NSData * data  = (NSData*)*(pbPtr->thumbnailData);		
 		self.imageRepresentation = data;
		[data release];
		
		self.imageVersion = self.imageVersion + 1;
		
		DEBUGLOG( @"Received Thumbnail %@", self );
    }
}

- (void) _getThumbnail
{
	self.isLoadingThumbnail = YES;
    ICACopyObjectThumbnailPB    pb = { 0 };
    
    pb.header.refcon   = (unsigned long) self;
    pb.thumbnailFormat = kICAThumbnailFormatJPEG;
    pb.object          = (ICAObject)[self.location integerValue];
    
    ICACopyObjectThumbnail(&pb, ICAThumbnailCallback );
	
	DEBUGLOG( @"Loading Thumbnail %@", self );
}

// ---------------------------------------------------------------------------------------------------------------------
- (NSImage *) imageRepresentation
{
	if ( !_imageRepresentation && !self.isLoadingThumbnail  ) {
		[self _getThumbnail];
	}
	return _imageRepresentation;
}

// UNEXPECTED behavior of the baseclass
- (NSString*) imageRepresentationType
{
	return _imageRepresentationType;
}

@end

/***************************** Drag and drop support ***********************************/

#pragma mark -

@implementation IMBMTPDownloadOperation
@synthesize delegate = _delegate;
@synthesize objectsToLoad =		_objectsToLoad;
@synthesize downloadFolderPath = _downloadFolderPath;
@synthesize receivedBytes =		_receivedBytes;
@synthesize receivedFilePaths = _receivedFilePaths;

- (id) initWithArrayOfObjects:(NSArray *) anArray delegate:(id<IMBMTPDownloadOperationDelegate>) aDelegate
{
	self = [super init];
	if (self != nil) {
		self.delegate = aDelegate;
		self.objectsToLoad = anArray;
		self.receivedFilePaths = [NSMutableArray arrayWithCapacity:[anArray count]];
	}
	return self;
}

- (void) dealloc 
{
	self.objectsToLoad = nil;
	self.downloadFolderPath = nil;
	self.receivedFilePaths = nil;
	[super dealloc];
}

- (void) main
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	FSRef downloadFolder, fileFSRef; 
	ICADownloadFilePB pb = { 0 };
	
	if( !CFURLGetFSRef ( (CFURLRef)[NSURL fileURLWithPath:self.downloadFolderPath], &downloadFolder ) ) 
	{
		NSLog( @"IMBMTPDownloadOperation: Can not download without dastination folder" );
		return;
	}
	
	for( IMBObject *anObject in self.objectsToLoad )
	{
		if( [anObject isKindOfClass:[IMBNodeObject class]] )
			 continue;
			 
		if( [self isCancelled] )
			 break;
			 
		OSStatus err;
		pb.header.refcon   = 0L; // not necessary - sync version;

		pb.object			= [anObject.location intValue];
		pb.dirFSRef			= &downloadFolder;		// FSRef of destination directiory
		pb.fileType			= pb.fileCreator = 0;	// not used any more
		pb.rotationAngle	= 0;					// Rotation angle in steps of 90 degress.
		pb.fileFSRef		= &fileFSRef;			// we want to know where the file ends up
		
		DEBUGLOG( @"Downloading file %x", pb.object );
	
		err = ICADownloadFile(&pb, nil);
		if( !err ) 
		{
			NSURL *fileURL = NSMakeCollectable(CFURLCreateFromFSRef( kCFAllocatorDefault, &fileFSRef ));
			if( fileURL )
			{
				[self.receivedFilePaths addObject:[fileURL path]];
				[fileURL release];
			}
			
			self.receivedBytes += [[anObject.metadata valueForKey:@"isiz"] longLongValue];
			
			if( [(id)self.delegate respondsToSelector:@selector( operationDidDownloadFile: )] )
				[self.delegate operationDidDownloadFile:self];
			
			DEBUGLOG( @"Did download file %x to %@", pb.object, [self.receivedFilePaths lastObject] );
		}
		
		if( err )
		{
			DEBUGLOG( @"Failed to download file %x: Error %i", pb.object, err );

			if( [(id)self.delegate respondsToSelector:@selector( operation:didReceiveError: )])
				[self.delegate operation:self didReceiveError:[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]];
		}
	}
	
	if( [(id)self.delegate respondsToSelector:@selector( operationDidFinish: )] )
		[self.delegate operationDidFinish:self];
	
	[pool drain];
}

- (long long) totalBytes 
{
	long long resultSize = 0LL;
	for( IMBObject *anObject in self.objectsToLoad )
		resultSize += [[anObject.metadata valueForKey:@"isiz"] longLongValue];
	return resultSize;
}

@end

//----------------------------------------------------------------------------------------------------------------------

#pragma mark -

@implementation IMBMTPObjectPromise
@synthesize bytesTotal = _bytesTotal;
@synthesize bytesDone = _bytesDone;

- (void) loadObjects:(NSArray*)inObjects
{	
	// Retain self until all download operations have finished. We are going to release self in the   
	// didFinish: and didReceiveError: delegate messages...
	
	[self retain];
	
	// Show the progress, which is indeterminate for now as we do not know the file sizes yet...
	
	[self prepareProgress];
	
	// Create ONE download operations...

	IMBMTPDownloadOperation* op = [[[IMBMTPDownloadOperation alloc] initWithArrayOfObjects:inObjects delegate:self] autorelease];
	op.downloadFolderPath = self.destinationDirectoryPath;
	[self.downloadOperations addObject:op]; 
	
	// Get combined file sizes so that the progress bar can be configured...
	
	_totalBytes = [op totalBytes];
	
	// Start downloading...
	[[IMBOperationQueue sharedQueue] addOperation:op];
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) cancel:(id)inSender
{
	NSArray *receivedFiles = nil;
	// Cancel outstanding operations...
	for (IMBMTPDownloadOperation* op in self.downloadOperations)
	{
		[op cancel];
		receivedFiles = op.receivedFilePaths; // We have only one operation ;-)
	}

	// Trash any files that we already have...
	
	NSFileManager* mgr = [NSFileManager imb_threadSafeManager];
	for (NSString *path in receivedFiles)
	{
		NSError* error = nil;
		[mgr removeItemAtPath:path error:&error];
	}
	
	// Cleanup...
	
	[self performSelectorOnMainThread:@selector(_didFinish) 
						   withObject:nil 
						waitUntilDone:YES 
								modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	[self release];
}


//----------------------------------------------------------------------------------------------------------------------

// We received some data, so display the current progress... 
- (void) operationDidDownloadFile:(IMBMTPDownloadOperation*)inOperation
{
	double fraction = (double)inOperation.receivedBytes / (double)_totalBytes;
	[self displayProgress:fraction];
}
 

// A download has finished. Store the path to the downloaded file. Once all downloads are complete, we can hide 
// the progress UI, Notify the delegate and release self...

- (void) operationDidFinish:(IMBMTPDownloadOperation*)inOperation
{
	// [self.localFiles addObject:inOperation.localPath];
	_objectCountLoaded++;
	
	if (_objectCountLoaded >= _objectCountTotal)
	{
		NSLog(@"%s",__FUNCTION__);
		[self performSelectorOnMainThread:@selector(_didFinish) 
							   withObject:nil 
							waitUntilDone:YES 
									modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		
		[self release];
	}	  
}


// If an error has occured in one of the downloads, then store the error instead of the file path, but everything 
// else is the same as in the previous method...

- (void) operation:(IMBMTPDownloadOperation*)inOperation didReceiveError:(NSError *) anError
{
	// [self.localFiles addObject:anError];
	self.error = anError;
	_objectCountLoaded++;
	
	if (_objectCountLoaded >= _objectCountTotal)
	{
		NSLog(@"%s",__FUNCTION__);
		[self performSelectorOnMainThread:@selector(_didFinish) 
							   withObject:nil 
							waitUntilDone:YES 
									modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		
		[self release];
	}	  
}

@end
