//
//  IMBFacebookParser.m
//  iMedia
//
//  Created by Jörg Jacobsen on 12.03.13.
//
//

#import "IMBFacebookParser.h"
#import "IMBFacebookObject.h"
#import "NSImage+iMedia.h"
#import "IMBIconCache.h"
#import "IMBNodeObject.h"

#define DEBUG_SIMULATE_MISSING_THUMBNAILS 0
#define SHOW_FRIENDS_WITH_ALBUMS_ONLY 1

// Limit of Facebook elements to retrieve in one request response
// Note that there is no "Load More" mechanism implemented
//
static NSUInteger sFacebookElementLimit = 5000;

@interface IMBFacebookParser ()


@end

@implementation IMBFacebookParser

@synthesize atomic_facebook=_facebook;

#pragma mark - Objects Lifecycle

- (void)dealloc
{
    IMBRelease(_facebook);
    [super dealloc];
}


#pragma mark - Mandatory overrides from superclass

- (IMBNode *)unpopulatedTopLevelNode:(NSError **)outError
{
    NSError *error = nil;
    
    //	load Facebook icon...
    NSBundle* ourBundle = [NSBundle bundleForClass:[IMBNode class]];
    
    // Use method imageForResource: if available to take advantage of
    // possibly additionally available high res representations
    
    NSString *iconName = @"facebook_logo";
    NSImage *icon;
    if ([ourBundle respondsToSelector:@selector(imageForResource:)])
    {
        icon = [ourBundle imageForResource:iconName];
    } else {
        NSURL *imageURL = [ourBundle URLForImageResource:iconName];
        icon = [[[NSImage alloc] initWithContentsOfURL:imageURL] autorelease];
    }
    
    //  create an empty root node (unpopulated and without subnodes)...
    IMBNode *node = [[[IMBNode alloc] initWithParser:self topLevel:YES] autorelease];
    node.name = @"Facebook";
    node.groupType = kIMBGroupTypeInternet;
    node.icon = icon;
    node.isIncludedInPopup = YES;
    node.isLeafNode = NO;
    node.mediaSource = nil;
    node.accessibility = [self mediaSourceAccessibility];
    node.isAccessRevocable = YES;
	node.identifier = [self identifierForPath:@"/"];
    node.displayedObjectCount = 0;  // me has only albums and friends as objects but only photos are counted

    NSString *myID, *myName = nil;
    
    if ([self mediaSourceAccessibility] == kIMBResourceIsAccessible)
    {
        // Add a dummy watched path to ensure that file system observer does not trigger unwanted reloads
        // (seems to trigger reloads meant for other paths when watchedPath is nil)
        node.watchedPath = @"https://graph.facebook.com";
        
        NSDictionary *responseDict = [self.facebook sendSynchronousRequest:@"me"];
        error = [self iMediaErrorFromFacebookResponse:responseDict];

        if (error) {
            NSLog(@"Facebook: Access to /me failed:%@", error);
            *outError = error;
            return nil;
        }
        myID = [[responseDict objectForKey:@"resultDict"] objectForKey:@"id"];
        myName = [[responseDict objectForKey:@"resultDict"] objectForKey:@"name"];
        if (myID) {
            node.attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                               myID, @"facebookID",
                               [NSNumber numberWithUnsignedInteger:0], @"nestingLevel", nil];
            node.name = [NSString stringWithFormat:@"Facebook (%@)", myName];
        }
    } else {
        *outError = error;
    }
	return node;
}

- (BOOL) populateNode:(IMBNode *)inParentNode error:(NSError **)outError
{
    NSError *error = nil;
    
    // Can't do anything if Facebook object is not set
    
    if (![self facebookWithError:&error]) {
        if (outError) *outError = error;
        return NO;
    }
    
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method,
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];
    
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];
    
    // For nodes below top-level node do not ask for friends
    
    NSUInteger parentNestingLevel = [[inParentNode.attributes objectForKey:@"nestingLevel"] unsignedIntegerValue];
    NSArray *connectionTypes = nil;
    if (parentNestingLevel == 0) {
        connectionTypes = [NSArray arrayWithObjects:@"albums", @"friends", nil];
    } else {
        connectionTypes = [NSArray arrayWithObjects:@"albums", nil];
    }
    
    // Get subnodes for each node type
    
    NSArray *subnodeDicts = nil;
    NSDictionary *params = @{ @"limit" : [NSNumber numberWithUnsignedInteger:sFacebookElementLimit]};
    for (NSString *connectionType in connectionTypes)
    {
        subnodeDicts = [self nodeID:[inParentNode.attributes objectForKey:@"facebookID"]
               connectedNodesByType:connectionType params:params error:&error];
        
        if (error) {
            [inParentNode setSubnodes:nil];
            
            if (outError) {
                // Map error code to one known by the framework
                if (error.code == 190) {      // Session expired
                    *outError = [NSError errorWithDomain:kIMBErrorDomain code:kIMBResourceNoPermission userInfo:(*outError).userInfo];
                } else {
                    *outError = error;
                }
            }
            return NO;
        }
        
        // Parallelize subnode creation since "friend" nodes require sending another request to Facebook
        
        dispatch_group_t subnodeCreationGroup = dispatch_group_create();
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(8);
        
        NSMutableArray *unsortedSubnodes = [NSMutableArray arrayWithCapacity:[subnodeDicts count]];
        
        for (NSDictionary *nodeDict in subnodeDicts)
        {
            NSString *ID, *name;
            IMBNode *subnode;
            ID = [nodeDict objectForKey:@"id"];
            name = [nodeDict objectForKey:@"name"];
            
            // Create node for this album...
            
            subnode = [[[IMBNode alloc] initWithParser:self topLevel:NO] autorelease];
            
            subnode.isLeafNode = [connectionType isEqualToString:@"albums"];
            subnode.icon = [self iconForConnectionType:connectionType highlight:NO];
            subnode.highlightIcon = [self iconForConnectionType:connectionType highlight:YES];
            subnode.name = name;
            subnode.identifier = ID;
            
            // Keep a ref to the type of the subnode – so when later populating it we know how to deal with it
            
            //NSUInteger nestingLevel = [[inParentNode.attributes objectForKey:@"nestingLevel"] unsignedIntegerValue] + 1;
            subnode.attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                  connectionType, @"nodeType",
                                  ID, @"facebookID",
                                  [NSNumber numberWithUnsignedInteger:parentNestingLevel+1], @"nestingLevel", nil];
            
            // Test whether 'friend' subnode has itself albums. If not leave it out because would be empty node.
            // NOTE: Can't afford these time intensive requests unless we parallelize them (think about a
            // Facebook user with 500 friends easily)
            
            if ([connectionType isEqualToString:@"friends"])
            {
                subnode.displayedObjectCount = 0;   // friends have only albums as objects but only photos are counted
                
#if SHOW_FRIENDS_WITH_ALBUMS_ONLY
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                dispatch_group_async(subnodeCreationGroup,
                                     dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),     // Concurrent
                                     //                                     subnodeCreationQueue,                                              // Serial
                                     ^{
                                         NSArray *friendalbums = [self nodeID:ID connectedNodesByType:@"albums" params:params error:outError];
                                         
                                         if ([friendalbums count] > 0) {
                                             @synchronized(unsortedSubnodes) {
                                                 [unsortedSubnodes addObject:subnode];
                                                 //                                                 NSLog(@"Adding friend: %@:", subnode);
                                             }
                                         } else {
                                             @synchronized(self) {
                                                 //                                                 NSLog(@"Friend %@ does not have accessible albums", subnode);
                                             }
                                         }
                                         dispatch_semaphore_signal(semaphore);
                                     });
#else
                @synchronized(unsortedSubnodes) {
                    [unsortedSubnodes addObject:subnode];
                    //                    NSLog(@"Adding friend: %@:", subnode);
                }
#endif
            } else {
                @synchronized(subnodes) {
                    [subnodes addObject:subnode];
                }
            }
        }
        dispatch_group_wait(subnodeCreationGroup, DISPATCH_TIME_FOREVER);
        dispatch_release(subnodeCreationGroup);
        dispatch_release(semaphore);
        
        // Since friend nodes were collected in parallel (i.e. unsorted) we must sort them
        // (and add them to the list of albums already collected)
        
        NSSortDescriptor* nameDescriptor = [[[NSSortDescriptor alloc]
                                             initWithKey:@"name"
                                             ascending:YES] autorelease];
        NSArray* sortDescriptors = [NSArray arrayWithObject:nameDescriptor];
        
        [subnodes addObjectsFromArray:[unsortedSubnodes sortedArrayUsingDescriptors:sortDescriptors]];
    }
    
    // me node, friend nodes, and album nodes treated differently regarding object view:
    // - me node shows albums and friends (so you can search for friends)
    // - friend nodes show photos of all of his albums
    // - album nodes show photos of album
    
    NSString *parentNodeType = [inParentNode.attributes objectForKey:@"nodeType"];
    if (parentNodeType == nil) parentNodeType = @"me";
    
    // *** me node's objects ***
    // *** friend node's objects ***
    
    if ([parentNodeType isEqualTo:@"me"] || [parentNodeType isEqualTo:@"friends"])
    {
        IMBNodeObject *object = nil;
        for (IMBNode *node in subnodes) {
            NSString *nodeType = [node.attributes objectForKey:@"nodeType"];
            object = [[IMBNodeObject alloc] init];
			[objects addObject:object];
			[object release];
            
            object.identifier = node.identifier;
            object.representedNodeIdentifier = node.identifier;
            object.parserIdentifier = self.identifier;
			object.location = [NSURL URLWithString:node.identifier]; // object identifier will be set by IMBParser based on location and others (see: -identifierForObject:)
			object.name = node.name;
			object.metadata = nil;
			object.parserIdentifier = self.identifier;
            object.atomic_imageRepresentation = [self thumbnailForConnectionType:nodeType];
            object.imageRepresentationType = IKImageBrowserNSImageRepresentationType;
            object.needsImageRepresentation = NO;
        }
    }
    
    // *** Album node's objects ***
    
    if ([parentNodeType isEqualTo:@"albums"])
    {
        // Get all photos from this album
        NSDictionary *params = @{ @"fields" : @"id,picture,images,source",
                                  @"limit"  : [NSNumber numberWithUnsignedInteger:sFacebookElementLimit]};
        NSArray *photoDicts = [self nodeID:inParentNode.identifier
                      connectedNodesByType:@"photos"
                                    params:params
                                     error:outError];
        
        IMBFacebookObject *object = nil;
        for (NSDictionary *photoDict in photoDicts)
        {
            object = [[IMBFacebookObject alloc] init];
			[objects addObject:object];
			[object release];
            
            object.parserIdentifier = [self identifier];
            
            NSArray *images = [photoDict objectForKey:@"images"];
            
            object.alternateImageLocations = images;
            // Pick image with highest resolution. This should be the first in images.
            NSString *URLString = nil;
            NSNumber *width, *height = nil;
            if ([images count] > 0) {
                NSDictionary *imageDict = [images objectAtIndex:0];
                width = [imageDict objectForKey:@"width"];
                height = [imageDict objectForKey:@"height"];
                URLString = [imageDict objectForKey:@"source"];
            } else {
                URLString = [photoDict objectForKey:@"source"];
                width = [photoDict objectForKey:@"width"];
                height = [photoDict objectForKey:@"height"];
            }
            NSString *createdTime = [photoDict objectForKey:@"created_time"];
            object.preliminaryMetadata = [NSDictionary dictionaryWithObjectsAndKeys:
                                          width, @"width",
                                          height, @"height",
                                          createdTime, @"dateTime", nil];
            object.name = [photoDict objectForKey:@"id"];
            object.location = [NSURL URLWithString:URLString];
                               
            object.accessibility = [self accessibilityForObject:object];
            object.imageLocation = [NSURL URLWithString:[photoDict objectForKey:@"picture"]];
            object.imageRepresentationType = IKImageBrowserNSDataRepresentationType;
        }
    }
    
    inParentNode.objects = objects;

    return YES;
}


//
//
- (id)thumbnailForObject:(IMBObject *)inObject error:(NSError **)outError
{
    if ([inObject isKindOfClass:[IMBNodeObject class]])
    {
        return [inObject atomic_imageRepresentation];
    }
    
#if DEBUG_SIMULATE_MISSING_THUMBNAILS
    BOOL doNotLoad = arc4random_uniform(9) == 8;      // Will be YES for about 12.5 % of thumbnails
#endif
    
    IMBFacebookObject *object = (IMBFacebookObject *)inObject;
    
    // Prepare a UI-presentable error to be handed back to UI if anything goes wrong
    // (We will log more specific errors to console)
    NSString *presentableErrorString = NSLocalizedStringWithDefaultValue(
                                         @"IMBFacebookParser.ThumbnailLoadError",
                                         nil, IMBBundle(),
                                         @"Could not load thumbnail. You may retry manually using contextual menu",
                                         nil);
    NSDictionary *presentableUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              presentableErrorString, NSLocalizedDescriptionKey, nil];
    NSError *presentableError = [NSError errorWithDomain:kIMBErrorDomain code:1 userInfo:presentableUserInfo];
    NSError *realError = nil;
    
    NSData *responseData = nil;
    for (NSDictionary *imageDict in [object.alternateImageLocations reverseObjectEnumerator])
    {
        NSString *urlString = [imageDict objectForKey:@"source"];
        if (urlString) {
            NSURL* url = [NSURL URLWithString:urlString];
            
            NSURLRequest *imageRequest = [NSURLRequest requestWithURL:url];
            NSHTTPURLResponse *response = nil;
            responseData = [NSURLConnection sendSynchronousRequest:imageRequest returningResponse:&response error:&realError];
            
            if (responseData)
            {
                NSInteger statusCode = [response statusCode];
                NSString *mimeType = [response MIMEType];
                if ( statusCode != 200 || ![[mimeType lowercaseString] hasPrefix:@"image/"])
                {
                    // We got a response but did not receive the expected thumbnail
                    
                    NSString *errorString = [NSString stringWithFormat:@"Error loading thumbnail %@: Server responded with code: %ld, mime type: %@ and response data: %@", url, (long)statusCode, mimeType, responseData];
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                              errorString, NSLocalizedDescriptionKey, nil];
                    realError = [NSError errorWithDomain:kIMBErrorDomain code:statusCode userInfo:userInfo];
                    NSLog(@"%@", realError);
                    
                } else {
                    // Sadly enough, Facebook might return an error page instead of an image despite responding with
                    // a 200 status code and a mime type image/...
                    
                    BOOL responseDataIsImage = NO;
                    static const char *nonImageIndicator = "<html>";
                    static NSUInteger bytesToInspect;
                    bytesToInspect = (NSUInteger)strlen(nonImageIndicator);
                    if ([responseData length] >= bytesToInspect){
                        responseDataIsImage =
#if DEBUG_SIMULATE_MISSING_THUMBNAILS
                        !doNotLoad;
#else
                        strncmp([responseData bytes], nonImageIndicator, bytesToInspect) != 0;
#endif
                    }
                    if (!responseDataIsImage) {
                        // We were told we got an image but this is no image but an html (error) page!
                        
                        NSString *errorString = [NSString stringWithFormat:@"Error loading thumbnail %@: Server responded with data:  %@", url,
#if DEBUG_SIMULATE_MISSING_THUMBNAILS
                            @"Simulating missing thumbnail"];
#else
                            responseData];
#endif
                        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                                  errorString, NSLocalizedDescriptionKey, nil];
                        realError = [NSError errorWithDomain:kIMBErrorDomain code:kIMBResourceDoesNotExist userInfo:userInfo];
                        NSLog(@"%@", realError);
#if DEBUG_SIMULATE_MISSING_THUMBNAILS
                        break;              // Do not try to load alternative image locations if we are simulating
#endif
                    } else {
                        // Response data is ok (should be an image)
                        
//                        NSLog(@"Picked thumbnail of size: %@x%@", [imageDict objectForKey:@"width"], [imageDict objectForKey:@"height"]);
                        if (outError) *outError = nil;
                        inObject.accessibility = kIMBResourceIsAccessible;
                        inObject.error = nil;
                        realError = nil;
                        inObject.imageRepresentationType = IKImageBrowserNSDataRepresentationType;
                        break;
                    }
                }
            } else {
                inObject.accessibility = kIMBResourceDoesNotExist;
                // Server did not respond
                if (realError) {
                    NSLog(@"Error loading thumbnail %@: %@", url, realError);
                } else {
                    NSLog(@"Error loading thumbnail %@: No data received but error unknown", url);
                }
            }
        }
    }
    if (realError) {
        inObject.error = presentableError;
        if (outError) {
            *outError = presentableError;
        }
    }
    return responseData;
}

//----------------------------------------------------------------------------------------------------------------------
//
- (NSDictionary*) metadataForObject:(IMBObject*)inObject error:(NSError**)outError
{
	if (outError) *outError = nil;
    
	NSMutableDictionary* metadata = [NSMutableDictionary dictionaryWithDictionary:inObject.preliminaryMetadata];
	
// We can not afford this call since it must download the full image at
//    [metadata addEntriesFromDictionary:[NSImage imb_metadataFromImageAtURL:inObject.URL checkSpotlightComments:NO]];

    return metadata;
}

//
//
- (NSData*) bookmarkForObject:(IMBObject*)inObject error:(NSError**)outError
{
	NSError* error = nil;
	NSURL* URL = inObject.URL;
	NSData* bookmark = nil;
	
    bookmark = [URL
                bookmarkDataWithOptions:0
                includingResourceValuesForKeys:nil
                relativeToURL:nil
                error:&error];
    
	if (outError) *outError = error;
	return bookmark;
}


#pragma mark - Access

- (void) setFacebook:(PhFacebook *)facebook
{
    @synchronized(self) {
        [facebook setDelegate:self];
        self.atomic_facebook = facebook;
    }
}

- (PhFacebook *)facebook
{
    @synchronized(self) {
        if (![self.atomic_facebook delegate]) {
            [self.atomic_facebook setDelegate:self];
        }
    }
    return self.atomic_facebook;
}

/**
 Returns the facebook object of this parser. If the object is not set
 will also return an error with code kIMBResourceNoPermission (without localized description).
 */
- (PhFacebook *)facebookWithError:(NSError **)pError
{
    PhFacebook *facebook = self.facebook;
    
    if (!facebook && pError) {
        *pError = [NSError errorWithDomain:kIMBErrorDomain code:kIMBResourceNoPermission userInfo:nil];
    }
    return facebook;
}

#pragma mark - Access Control

- (IMBResourceAccessibility) mediaSourceAccessibility
{
    // JJ/TODO: access token may be expired?
    return (self.facebook == nil ? kIMBResourceNoPermission : kIMBResourceIsAccessible);
}

// Always returns nil (must match signature required by XPCKit)
//
- (id) revokeAccessToNode:(IMBNode *)node error:(NSError **)pError
{
    NSString *facebookID = [node.attributes objectForKey:@"facebookID"];
    if (self.facebook && facebookID)
    {        
        NSDictionary *responseDict = [self.facebook sendSynchronousRequest:[NSString stringWithFormat:@"%@/permissions", facebookID] HTTPMethod:@"DELETE" params:nil];
        
//        NSLog(@"Response from logging out: %@", responseDict);

        NSError *error = [self iMediaErrorFromFacebookResponse:responseDict];
        if (pError && error) {
            *pError = error;
        }
        if (!error) {
            self.facebook = nil;
        }
    }
    return nil;
}

#pragma mark - Utility Methods


/**
 This method currently unused and currently not meant for use
 */
- (NSDictionary *)friendIDsWithAlbumsWithError:(NSError **)pError
{
    static NSString *FQLFriendsAlbumsQuery = @"SELECT uid, name, first_name, last_name FROM user WHERE uid IN (SELECT owner FROM album WHERE owner IN (SELECT uid1 FROM friend WHERE uid2 = me()))";
    
    NSMutableDictionary *friendsIDs = nil;
    
    NSError *error = nil;
    PhFacebook *facebook = [self facebookWithError:&error];
    if (facebook) {
        NSDictionary *responseDict = [facebook sendSynchronousFQLRequest:FQLFriendsAlbumsQuery];
        
        error = [self iMediaErrorFromFacebookResponse:responseDict];
        
        if (error) {
            NSLog(@"Execution of %@ failed:%@", FQLFriendsAlbumsQuery, error);
            *pError = error;
            return nil;
        }
        
        NSArray *friends = [responseDict objectForKey:@"resultDict"];
        
        NSLog(@"Our %lu friends have albums: %@", (unsigned long)[friends count], friends);
        
        friendsIDs = [NSMutableDictionary dictionary];
        id friendID = nil;
        
        for (NSDictionary *friend in friends)
        {
            friendID = [[friend objectForKey:@"uid"] stringValue];
            NSLog(@"String value: %@", friend);
            if (![friendsIDs objectForKey:friend]) {
                [friendsIDs setObject:friendID forKey:friend];
            }
        }
    } else {
        *pError = error;
    }
    
    NSLog(@"We got %lu friends that have albums: %@", (unsigned long)[friendsIDs count], friendsIDs);
    
    return [NSDictionary dictionaryWithDictionary:friendsIDs];
}

/**
 */
- (NSArray *) nodeID:(NSString *)nodeID
connectedNodesByType:(NSString *)nodeType
              params:(NSDictionary *)params
               error:(NSError **)outError
{
    if (!params) params = @{ @"fields" : @"id,name"};
    NSArray *nodes = nil;

    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", nodeID, nodeType]];

//    NSLog(@"Graph URL: %@", URL);

    NSError *error = nil;
    PhFacebook *facebook = [self facebookWithError:&error];
    if (facebook) {
        NSDictionary *responseDict = [facebook sendSynchronousRequest:[URL absoluteString] params:params];
        error = [self iMediaErrorFromFacebookResponse:responseDict];
        
        if (error) {
            NSLog(@"Access to %@ failed:%@", nodeType, error);
            *outError = error;
            return nil;
        }

//        NSLog(@"Facebook returned %@: %@", nodeType, responseDict);

        nodes = [[responseDict objectForKey:@"resultDict"] objectForKey:@"data"];
    } else {
        *outError = error;
    }

    return nodes;
}


// Get albums for facebook node (node is supposedly me or any of my friends)
//
- (NSArray *)albumsForNodeWithID:(NSString *)nodeID error:(NSError **)outError
{
    return [self nodeID:nodeID connectedNodesByType:@"albums" params:nil error:outError];
}


// Get friends for facebook node (node is supposedly me)
//
- (NSArray *)friendsForNodeWithID:(NSString *)nodeID error:(NSError **)outError
{
    return [self nodeID:nodeID connectedNodesByType:@"friends" params:nil error:outError];
}


- (BOOL) isSessionExpired:(NSDictionary *)responseDict
{
    NSDictionary *error = [responseDict objectForKey:@"error"];
    if (error) {
        return [((NSNumber *)[error objectForKey:@"code"]) integerValue] == 190;
    }
    return NO;
}

- (NSImage *)iconForConnectionType:(NSString *)inConnectionType highlight:(BOOL)inHighlight
{
    NSDictionary *iconTypeMapping = @{@"me"     : @"person",
                                      @"albums" : @"album",
                                      @"friends": @"person"};
    
	return [[IMBIconCache sharedIconCache] iconForType:[iconTypeMapping objectForKey:inConnectionType]
                                             highlight:inHighlight];
}


- (NSImage *)thumbnailForConnectionType:(NSString *)inConnectionType
{
    NSDictionary *typeMapping = @{@"me"     : @"person_512x512",
                                  @"albums" : @"album_512x512",
                                  @"friends": @"person_512x512"};
    
	return [[IMBIconCache sharedIconCache] iconForType:[typeMapping objectForKey:inConnectionType]
                                             highlight:NO];
}


- (NSError *) iMediaErrorFromFacebookError:(NSDictionary *)facebookError
{
    if (!facebookError) return nil;

    NSLog(@"%@", facebookError);
    
    IMBResourceAccessibility iMediaErrorCode;
    NSUInteger errorCode = [[facebookError valueForKey:@"code"] unsignedIntegerValue];
    switch (errorCode) {
        case 190:
            iMediaErrorCode = kIMBResourceNoPermission;
            break;
            
        default:
            iMediaErrorCode = kIMBResourceNoPermission;
    }
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: [facebookError valueForKey:@"message"]};
    return [NSError errorWithDomain:@"IMBAccessibilityError" code:iMediaErrorCode userInfo:userInfo];
}

- (NSError *)iMediaErrorFromFacebookResponse:(NSDictionary *)facebookResponse
{
    return [self iMediaErrorFromFacebookError:[facebookResponse valueForKey:@"error"]];
}
@end
