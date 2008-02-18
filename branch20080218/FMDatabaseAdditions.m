// FMDATABASE SQLITE WRAPPER HAS BEEN INTO THE PUBLIC DOMAIN BY GUS MUELLER,
// ACCORDING TO EMAIL CORRESPONDENCE WITH PIERRE BERNARD DATED DECEMBER 17, 2007

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation FMDatabase (FMDatabaseAdditions)

- (NSString*) stringForQuery:(NSString*)objs, ...; {
    
    FMResultSet *rs = [self executeQuery:objs];
    
    if (![rs next]) {
        return nil;
    }
    
    NSString *ret = [rs stringForColumnIndex:0];
    
    // clear it out.
    [rs close];
    
    return ret;
}

- (int) intForQuery:(NSString*)objs, ...; {
    
    FMResultSet *rs = [self executeQuery:objs];
    
    if (![rs next]) {
        return NO;
    }
    
    long ret = [rs longForColumnIndex:0];
    
    // clear it out.
    [rs close];
    
    return ret;
}

- (long) longForQuery:(NSString*)objs, ...; {
    
    FMResultSet *rs = [self executeQuery:objs];
    
    if (![rs next]) {
        return NO;
    }
    
    int ret = [rs intForColumnIndex:0];
    
    // clear it out.
    [rs close];
    
    return ret;
}

- (BOOL) boolForQuery:(NSString*)objs, ...; {
    
    FMResultSet *rs = [self executeQuery:objs];
    
    if (![rs next]) {
        return NO;
    }
    
    BOOL ret = [rs boolForColumnIndex:0];
    
    // clear it out.
    [rs close];
    
    return ret;
}

- (double) doubleForQuery:(NSString*)objs, ...; {
    
    FMResultSet *rs = [self executeQuery:objs];
    
    if (![rs next]) {
        return 0.0;
    }
    
    double ret = [rs doubleForColumnIndex:0];
    
    // clear it out.
    [rs close];
    
    return ret;
}

- (NSData*) dataForQuery:(NSString*)objs, ...; {
    
    FMResultSet *rs = [self executeQuery:objs];
    
    if (![rs next]) {
        return nil;
    }
    
    NSData *data = [rs dataForColumnIndex:0];
    
    // clear it out.
    [rs close];
    
    return data;
}

@end
