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

#define DEBUG_SIMULATE_MISSING_THUMBNAILS 0

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

- (IMBNode*) unpopulatedTopLevelNode: (NSError**) outError
{
//    // Running in app process or XPC service?
//    NSString *facebookAppId = FACEBOOK_APP_ID_APP_PROCESS;
//    
//    if (outError) *outError = nil;     // Ensure out-parameter is properly initialized
//    
//    // This method must return synchronously with all necessary requests to facebook being already returned.
//    // Use NSCondition and BOOL for that matter.
//    
//    NSCondition *authenticationCond = [[NSCondition alloc] init];
//    __block BOOL authenticationDone = NO;
//    
//    [authenticationCond lock];
//    
//    self.accountStore = [[ACAccountStore alloc] init];
//    
//    NSLog(@"%@", [self.accountStore accounts]);
//
//    ACAccountType *facebookAccountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
//    
//    NSArray *facebookPermissions = [NSArray arrayWithObjects:@"email", nil];
//    
//    NSDictionary *facebookClientAccessInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                                              facebookAppId, ACFacebookAppIdKey,
//                                              //ACFacebookAudienceOnlyMe, ACFacebookAudienceKey,
//                                              facebookPermissions, ACFacebookPermissionsKey, nil];
//    
//    [self.accountStore requestAccessToAccountsWithType:facebookAccountType options:facebookClientAccessInfo completion:^(BOOL granted, NSError *error) {
//        if (granted) {
//            NSLog(@"Facebook access basically granted!!!");
//            
//            NSArray *facebookPermissions = [NSArray arrayWithObjects:
//                                            @"user_photos", @"friends_photos",
//                                            nil];
//            NSDictionary *subseqFacbookClientAccessInfo = [NSDictionary dictionaryWithObjectsAndKeys:
//                                                           facebookAppId, ACFacebookAppIdKey,
//                                                           //ACFacebookAudienceOnlyMe, ACFacebookAudienceKey,
//                                                           facebookPermissions, ACFacebookPermissionsKey, nil];
//            [self.accountStore requestAccessToAccountsWithType:facebookAccountType options:subseqFacbookClientAccessInfo completion:^(BOOL granted, NSError *error) {
//                if (granted) {
//                    NSLog(@"Facebook access totally granted!!!");
//                    NSArray *accounts = [self.accountStore accountsWithAccountType:facebookAccountType];
//                    self.account = [accounts lastObject];
//                } else {
//                    NSLog(@"No total Facebook access granted :-((");
//                    *outError = error;
//                }
//                [authenticationCond lock];
//                authenticationDone = YES;
//                [authenticationCond signal];
//                [authenticationCond unlock];
//            }];
//        } else {
//            NSLog(@"No basic Facebook access granted :-((");
//            *outError = error;
//        }
//    }];
//    
//    while (!authenticationDone) {
//        [authenticationCond wait];
//    }
//    [authenticationCond unlock];
//    
//    if (outError && *outError) {
//        return nil;
//    }
//    
//    // Facebook user name will be part of Node name. Get user name from Facebook.
//    
//    NSURL *meURL = [NSURL URLWithString:@"https://graph.facebook.com/me"];
//    NSDictionary *params = @{ @"fields" : @"id,name"};
//    
//    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook
//                                            requestMethod:SLRequestMethodGET
//                                                      URL:meURL
//                                               parameters:params];
//    request.account = self.account;
//    
//    NSURLResponse *urlResponse = nil;
//    NSError *error = nil;
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:[request preparedURLRequest]
//                                                 returningResponse:&urlResponse
//                                                             error:&error];
//    if (error) {
//        NSLog(@"%@ Access to me failed:%@", [[NSRunningApplication currentApplication] bundleIdentifier], error);
//        *outError = error;
//        return nil;
//    }
//    
//    NSDictionary *me = (NSDictionary *) [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
//    
//    // Account for expired session
//    
//    __block IMBNode *node = nil;
//    if ([self isSessionExpired:me])
//    {
//        NSCondition *condition = [[NSCondition alloc] init];
//        __block BOOL conditionDone = NO;
//        
//        [condition lock];
//        
//        [self.accountStore renewCredentialsForAccount:self.account completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
//            
//            [condition lock];
//            conditionDone = YES;
//            [condition signal];
//            [condition unlock];
//            
//            node = [self unpopulatedTopLevelNode:outError];
//        }];
//        while (!conditionDone) {
//            [condition wait];
//        }
//        [condition unlock];
//        
//        return node;
//    }
//    
//    NSLog(@"Facebook returned me: %@",me);
//    
//    NSString *myName = [me objectForKey:@"name"];
//    NSString *myID = [me objectForKey:@"id"];
    
    //------------------------------------------------------------------
    
    
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

    NSString *myID, *myName = nil;
    if ([self mediaSourceAccessibility] == kIMBResourceIsAccessible)
    {
        // Add a dummy watched path to ensure that file system observer does not trigger unwanted reloads
        // (seems to trigger reloads meant for other pahts when watchedPath is nil)
        node.watchedPath = @"https://graph.facebook.com";
        
        NSError *error = nil;
        NSDictionary *responseDict = [self.facebook sendSynchronousRequest:@"me"];
        error = [self iMediaErrorFromFacebookResponse:responseDict];

//        NSLog(@"%@", responseDict);
        
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
    }
	return node;
}

- (BOOL) populateNode:(IMBNode *)inParentNode error:(NSError **)outError
{
    if (outError) *outError = nil;     // Ensure out-parameter is properly initialized
    
	// Create the subNodes array on demand - even if turns out to be empty after exiting this method,
	// because without creating an array we would cause an endless loop...
	
	NSMutableArray* subnodes = [inParentNode mutableArrayForPopulatingSubnodes];
    
    // For nodes below top-level node do not ask for friends
    
    NSUInteger parentNestingLevel = [[inParentNode.attributes objectForKey:@"nestingLevel"] unsignedIntegerValue];
    NSArray *connectionTypes = nil;
    if (parentNestingLevel == 0) {
        connectionTypes = [NSArray arrayWithObjects:@"albums", @"friends", nil];
    } else {
        connectionTypes = [NSArray arrayWithObjects:@"albums", nil];
    }
    
    NSArray *someSubnodes = nil;
    NSDictionary *params = @{ @"limit" : [NSNumber numberWithUnsignedInteger:sFacebookElementLimit]};
    for (NSString *connectionType in connectionTypes)
    {
        someSubnodes = [self nodeID:[inParentNode.attributes objectForKey:@"facebookID"]
               connectedNodesByType:connectionType params:params error:outError];
        
        if (*outError) {
            [inParentNode setSubnodes:nil];
            
            // Map error code to one known by the framework
            if ((*outError).code == 190) {      // Session expired
                *outError = [NSError errorWithDomain:(*outError).domain code:kIMBResourceNoPermission userInfo:(*outError).userInfo];
            }
            return NO;
        }
        
        NSString *ID, *name;
        IMBNode *subnode;
        for (NSDictionary *nodeDict in someSubnodes)
        {
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
            [subnodes addObject:subnode];
        }
    }
        
	// Create the objects array on demand  - even if turns out to be empty after exiting this method, because
	// without creating an array we would cause an endless loop...
	
	NSMutableArray* objects = [NSMutableArray array];
	
    if (inParentNode.attributes && [[inParentNode.attributes objectForKey:@"nodeType"] isEqual:@"albums"])
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
            NSUInteger width, height = 0;
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
#if DEBUG_SIMULATE_MISSING_THUMBNAILS
    BOOL doNotLoad = arc4random() & 7;      // Will be YES for about 12.5 % of thumbnails
#endif
    
    IMBFacebookObject *object = (IMBFacebookObject *)inObject;
    
//    // Object might currently have an NSImage representation type if its previous thumbnail load failed
//    // and the generic thumbnail placeholder image was set as its image representation. But here we are
//    // returning NSDATA representations
//    object.imageRepresentationType = IKImageBrowserNSDataRepresentationType;
    
    NSData *responseData = nil;
    for (NSDictionary *imageDict in [object.alternateImageLocations reverseObjectEnumerator])
    {
        NSString *urlString = [imageDict objectForKey:@"source"];
        if (urlString) {
            NSURL* url = [NSURL URLWithString:urlString];
            //        NSDate *startTime = [NSDate date];
            //        NSData* data = [NSData dataWithContentsOfURL:url options:0 error:outError];
            
            NSURLRequest *imageRequest = [NSURLRequest requestWithURL:url];
            NSHTTPURLResponse *response = nil;
            responseData = [NSURLConnection sendSynchronousRequest:imageRequest returningResponse:&response error:outError];
            
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
                    NSError *error = [NSError errorWithDomain:kIMBErrorDomain code:statusCode userInfo:userInfo];
                    if (outError) {
                        *outError = error;
                    }
                    NSLog(@"%@", error);
                    
                } else {
                    // Sadly enough, Facebook might return an error page instead of an image despite responding with
                    // a 200 status code and a mime type image/...
                    
                    BOOL responseDataIsImage = NO;
                    static const char *nonImageResponse = "<html>";
                    static NSUInteger bytesToInspect;
                    bytesToInspect = (NSUInteger)strlen(nonImageResponse);
                    if ([responseData length] >= bytesToInspect){
                        responseDataIsImage =
#if DEBUG_SIMULATE_MISSING_THUMBNAILS
                        doNotLoad;
#else
                        strncmp([responseData bytes], nonImageResponse, bytesToInspect) != 0;
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
                        NSError *error = [NSError errorWithDomain:kIMBErrorDomain code:kIMBResourceDoesNotExist userInfo:userInfo];
                        if (outError) {
                            *outError = error;
                        }
                        NSLog(@"%@", error);
                    } else {
                        // Response data is ok (should be an image)
                        
//                        NSLog(@"Picked thumbnail of size: %@x%@", [imageDict objectForKey:@"width"], [imageDict objectForKey:@"height"]);
                        if (outError) *outError = nil;
                        inObject.accessibility = kIMBResourceIsAccessible;
                        inObject.error = nil;
                        inObject.imageRepresentationType = IKImageBrowserNSDataRepresentationType;
                        return responseData;
                        
//                        NSLog(@"%f s to load thumbnail %@", [[NSDate date] timeIntervalSinceDate:startTime], url);
                    }
                }
            } else {
                // Server did not respond
                if (outError && *outError) {
                    NSLog(@"Error loading thumbnail %@: %@", url, *outError);
                } else {
                    NSLog(@"Error loading thumbnail %@: No data received but error unknown", url);
                }
            }
        }
    }
    inObject.accessibility = kIMBResourceDoesNotExist;
    return nil;
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
    [facebook setDelegate:self];
    self.atomic_facebook = facebook;
}

- (PhFacebook *)facebook
{
    if (![self.atomic_facebook delegate]) {
        [self.atomic_facebook setDelegate:self];
    }
    return self.atomic_facebook;
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

- (NSArray *) nodeID:(NSString *)nodeID
connectedNodesByType:(NSString *)nodeType
              params:(NSDictionary *)params
               error:(NSError **)outError
{
    if (!params) params = @{ @"fields" : @"id,name"};
    NSArray *nodes = nil;

    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", nodeID, nodeType]];

    NSLog(@"Graph URL: %@", URL);

    NSError *error = nil;

    if (self.facebook) {
        NSDictionary *responseDict = [self.facebook sendSynchronousRequest:[URL absoluteString] params:params];
        error = [self iMediaErrorFromFacebookResponse:responseDict];
        
        if (error) {
            NSLog(@"Access to %@ failed:%@", nodeType, error);
            *outError = error;
            return nil;
        }

//        NSLog(@"Facebook returned %@: %@", nodeType, responseDict);

        nodes = [[responseDict objectForKey:@"resultDict"] objectForKey:@"data"];
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
    NSDictionary *iconTypeMapping = @{@"albums": @"album",
                                      @"friends": @"person"};
    
	return [[IMBIconCache sharedIconCache] iconForType:[iconTypeMapping objectForKey:inConnectionType]
                                             highlight:inHighlight];
}

- (NSError *) iMediaErrorFromFacebookError:(NSDictionary *)facebookError
{
    if (!facebookError) return nil;

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
