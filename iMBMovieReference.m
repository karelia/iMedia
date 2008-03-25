/*
 iMedia Browser <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
 Redistributions of source code must retain the original terms stated here,
 including this list of conditions, the disclaimer noted below, and the
 following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
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

#import "iMBMovieReference.h"
#import "iMBMovieCacheDB.h"
#import <QTKit/QTKit.h>

@implementation iMBMovieReference
+ (void) initialize
{
    [self setKeys:[NSArray arrayWithObject:@"posterImageFileName"] triggerChangeNotificationsForDependentKey:@"posterImage"];
    [self setKeys:[NSArray arrayWithObject:@"miniMovieFileName"] triggerChangeNotificationsForDependentKey:@"miniMovie"];
    [self setKeys:[NSArray arrayWithObject:@"urlString"] triggerChangeNotificationsForDependentKey:@"movie"];
}

- (void) takeAttributesFromURL:(NSURL *)url
{
    [self setURLString:[url absoluteString]];
    if ([url isFileURL])
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDictionary *attributes = [fm fileAttributesAtPath:[url path] traverseLink:YES];

        [self setCreationDate:[attributes objectForKey:NSFileCreationDate]];
        [self setModificationDate:[attributes objectForKey:NSFileModificationDate]];
    }
}

- (NSDate *)modificationDate 
{
    NSDate * tmpValue;
    
    [self willAccessValueForKey:@"modificationDate"];
    tmpValue = [self primitiveValueForKey:@"modificationDate"];
    [self didAccessValueForKey:@"modificationDate"];
    
    return tmpValue;
}

- (void)setModificationDate:(NSDate *)value 
{
    [self willChangeValueForKey:@"modificationDate"];
    [self setPrimitiveValue:value forKey:@"modificationDate"];
    [self didChangeValueForKey:@"modificationDate"];
}

- (NSString *)urlString 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"urlString"];
    tmpValue = [self primitiveValueForKey:@"urlString"];
    [self didAccessValueForKey:@"urlString"];
    
    return tmpValue;
}

- (void)setURLString:(NSString *)value 
{
    [self willChangeValueForKey:@"urlString"];
    [self setPrimitiveValue:value forKey:@"urlString"];
    [self didChangeValueForKey:@"urlString"];
}

- (NSDate *)creationDate 
{
    NSDate * tmpValue;
    
    [self willAccessValueForKey:@"creationDate"];
    tmpValue = [self primitiveValueForKey:@"creationDate"];
    [self didAccessValueForKey:@"creationDate"];
    
    return tmpValue;
}

- (void)setCreationDate:(NSDate *)value 
{
    [self willChangeValueForKey:@"creationDate"];
    [self setPrimitiveValue:value forKey:@"creationDate"];
    [self didChangeValueForKey:@"creationDate"];
}

- (QTMovie *)movie 
{
    QTMovie    *qtMovie = nil;
    NSString  *urlString = [self urlString];
    if (!urlString)
        return nil;
    
    NSError	*error = nil;
    @try{
        QTDataReference *dataRef = [QTDataReference dataReferenceWithReferenceToURL:[NSURL URLWithString:urlString]];
        NSDictionary    *attributes = [NSDictionary dictionaryWithObjectsAndKeys:dataRef, QTMovieDataReferenceAttribute, 
                                       [NSNumber numberWithBool:YES], QTMovieOpenAsyncOKAttribute, 
                                       [NSNumber numberWithBool:NO], QTMovieAskUnresolvedDataRefsAttribute, nil, nil];
        qtMovie = [[QTMovie movieWithAttributes:attributes error:&error] retain];
        if ([qtMovie respondsToSelector:@selector(setIdling:)])
            [qtMovie setIdling:NO];
    }
    @catch (NSException *e) {
        NSLog (@"Exception %@ when creating movie for %@", e, urlString);
    }
    if (error)
        NSLog (@"Error %@ when creating movie for %@", error, urlString);
    return qtMovie;
}

- (QTMovie *) miniMovie
{
    NSString    *miniMovieFileName = [self miniMovieFileName];
 
    if (!miniMovieFileName)
    {
        NSNumber    *hasVideoNumber = [[self movieAttributes] objectForKey:QTMovieHasVideoAttribute];
        if (!hasVideoNumber || [hasVideoNumber boolValue])
            [[iMBMovieCacheDB sharedMovieCacheDB] generateMiniMovieForURLString: [self urlString]];
        return nil;
    }
    
    NSString    *path = [[[iMBMovieCacheDB sharedMovieCacheDB] miniMoviesDirPath] stringByAppendingPathComponent:miniMovieFileName];

    if (![[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSDate date] forKey:NSFileModificationDate] atPath:path]
        && ![[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        [self setMiniMovieFileName:nil];
        [[iMBMovieCacheDB sharedMovieCacheDB] generateMiniMovieForURLString: [self urlString]];
        return nil;
    }
    
    NSError *error = nil;
    QTMovie *movie = [QTMovie movieWithFile:path error:&error];
    if ([movie respondsToSelector:@selector(setIdling:)])
        [movie setIdling:NO];
    if (!movie)
        [self setMiniMovieFileName:nil];
    
    return movie;
}

- (NSImage *) posterImage
{
    NSString    *posterImageFileName = [self posterImageFileName];
    
    if (!posterImageFileName)
    {
        [[iMBMovieCacheDB sharedMovieCacheDB] generatePosterImageAndAttributesForURLString: [self urlString]];
        NSDictionary    *attributes = [self movieAttributes];
        if (attributes && ![[attributes objectForKey:QTMovieHasVideoAttribute] boolValue] && [[attributes objectForKey:QTMovieHasAudioAttribute] boolValue])
            return [NSImage imageNamed:@"music"];
        return nil;
    }
    
    NSString    *path = nil;
    
    if ([posterImageFileName isEqual:@"DRM"])
        path = [[NSBundle bundleForClass:[self class]] pathForResource:@"drm_movie" ofType:@"png"];
    else
    {
        path = [[[iMBMovieCacheDB sharedMovieCacheDB] posterImagesDirPath] stringByAppendingPathComponent:posterImageFileName];
        
        if (![[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSDate date] forKey:NSFileModificationDate] atPath:path]
            && ![[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            [self setPosterImageFileName:nil];
            [[iMBMovieCacheDB sharedMovieCacheDB] generatePosterImageAndAttributesForURLString: [self urlString]];
            return nil;
        }
    }
    
    NSImage *image = [[NSImage alloc] initByReferencingFile:path];
    if (!image)
        [self setPosterImageFileName:nil];
    
    return [image autorelease];
}

- (NSString *) miniMovieFileName
{
    [self willAccessValueForKey:@"miniMovieFileName"];
    NSString *name = [self primitiveValueForKey:@"miniMovieFileName"];
    [self didAccessValueForKey:@"miniMovieFileName"];
    return name;
}

- (void) setMiniMovieFileName:(NSString *) s
{
    [self willChangeValueForKey:@"miniMovieFileName"];
    [self setPrimitiveValue:s forKey:@"miniMovieFileName"];
    [self didChangeValueForKey:@"miniMovieFileName"];
}

- (NSString *) posterImageFileName
{
    [self willAccessValueForKey:@"posterImageFileName"];
    NSString *name = [self primitiveValueForKey:@"posterImageFileName"];
    [self didAccessValueForKey:@"posterImageFileName"];
    return name;
}

- (void) setPosterImageFileName:(NSString *) s
{
    [self willChangeValueForKey:@"posterImageFileName"];
    [self setPrimitiveValue:s forKey:@"posterImageFileName"];
    [self didChangeValueForKey:@"posterImageFileName"];
}

- (NSDictionary *) movieAttributes
{   // The attributes are stored archived to NSData
    NSData  *data = [self valueForKey:@"movieAttributesData"];
    if (!data)
    {
        [[iMBMovieCacheDB sharedMovieCacheDB] generatePosterImageAndAttributesForURLString: [self urlString]];
        return nil;
    }
    NSDictionary *d = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSNumber    *durationNumber = [d objectForKey:@"durationNumber"];
    if (durationNumber)
    {
        NSNumber    *timeScaleNumber = [d objectForKey:QTMovieTimeScaleAttribute];
        long timeScale = timeScaleNumber ? [timeScaleNumber longValue] : 60;
        QTTime      qtTime = QTMakeTime([durationNumber doubleValue] * timeScale, timeScale);
        NSMutableDictionary *md = [d mutableCopy];
        [md setObject:[NSValue valueWithQTTime:qtTime] forKey:QTMovieDurationAttribute];
        d = [md autorelease];
    }
    return d;
}

- (void) setMovieAttributes:(NSDictionary *)d
{   // The attributes are stored archived to NSData
    [self willChangeValueForKey:@"movieAttributes"];
    NSData  *data = nil;
    if (d)
    {
        NSValue *durationValue = [d objectForKey:QTMovieDurationAttribute];
        if (durationValue)
        {   // We can't archibe NSValue
            QTTime  t = [durationValue QTTimeValue];
            NSMutableDictionary *md = [d mutableCopy];
            [md removeObjectForKey:QTMovieDurationAttribute];
            [md setObject:[NSNumber numberWithDouble:(NSTimeInterval)t.timeValue / (NSTimeInterval)t.timeScale] forKey:@"durationNumber"];
            data = [NSKeyedArchiver archivedDataWithRootObject:md];
            [md release];
        }
        else
            data = [NSKeyedArchiver archivedDataWithRootObject:d];
    }
    [self setValue:data forKey:@"movieAttributesData"];
    [self didChangeValueForKey:@"movieAttributes"];
}

- (void) deleteExternalFiles
{
    NSString *fileName = [self miniMovieFileName];
    NSError *error = nil;

    if (fileName)
    {
        NSString    *path = [[[iMBMovieCacheDB sharedMovieCacheDB] miniMoviesDirPath] stringByAppendingPathComponent:fileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            if ([[NSFileManager defaultManager] removeFileAtPath:path handler:nil])
                [self setMiniMovieFileName:nil];
            else
                NSLog (@"Error %@ when deleting %@", error);
        }
    }
    fileName = [self posterImageFileName];
    if (fileName)
    {
        NSString    *path = [[[iMBMovieCacheDB sharedMovieCacheDB] posterImagesDirPath] stringByAppendingPathComponent:fileName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path])
        {
            if ([[NSFileManager defaultManager] removeFileAtPath:path handler:nil])
                [self setPosterImageFileName:nil];
            else
                NSLog (@"Error %@ when deleting %@", error);
        }
    }
}

@end
