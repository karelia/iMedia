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

/* movietool
 * Used as a command line utility or daemon to generate poster images, movie attribute dicts and mini version of movies
 *
 * You typically launch this from another process and to which it connects using distributed objects.
 *
 * When creating mini movies this tool uses archived QuickTime export settings that's specified with the -settings argument.
 *
 * Originally written by Martin Wennerberg (martin@norrrkross.com)
 */

#import <Foundation/Foundation.h>
#import <QuickTime/QuickTime.h>
#import <QTKit/QTKit.h>
#import "iMBMovieCacheDB.h"

#define CONST_SECONDS (32)
#define MAX_IMAGE_SIZE  300.0f

static NSString *settingsPath = nil;

static QTMovie *openMovie(NSString *urlString, NSMutableDictionary *cache)
{
    QTMovie *movie = [cache objectForKey:urlString];
    if (!movie)
    {
        NSURL   *url = [NSURL URLWithString:urlString];
        NSError *error = nil;
        movie = [QTMovie movieWithURL:url error:&error];
        if (error)
        {
            NSLog (@"Error %@ when opening %@", error, urlString);
            return nil;
        }
        
        [cache setObject:movie forKey:urlString];
        
        NSNumber    *loadState = [movie attributeForKey:QTMovieLoadStateAttribute];
        NSDate  *date = [NSDate date];
        while ([loadState longValue] < QTMovieLoadStateLoaded && [[NSDate date] timeIntervalSinceDate:date] < 600)
        {
            MoviesTask([movie quickTimeMovie], 5);
            loadState = [movie attributeForKey:QTMovieLoadStateAttribute];
        }
    }
    return movie;
}

static ComponentInstance openComponentInstanceForExportingMovie(QTMovie *movie)
{
    // Get the export settings
    NSData          *settings = [settingsPath length] > 0 ? [NSData dataWithContentsOfFile:settingsPath] : nil;
    
    if (!settings)
    {
        NSLog (@"Could not read export settings at %@", settingsPath);
        return NULL;
    }

    ComponentInstance ci = OpenDefaultComponent(MovieExportType, kQTFileTypeMovie);
    QTAtomContainer movieExportSettings = NewHandleClear([settings length]);
    memcpy(*movieExportSettings, [settings bytes], GetHandleSize(movieExportSettings));
    MovieExportSetSettingsFromAtomContainer(ci, movieExportSettings);
    QTDisposeAtomContainer(movieExportSettings);
    return ci;
}

static OSErr CreateMiniMovie(QTMovie *movie, DataReferenceRecord dataRefRecord)
{    
    ComponentInstance ci = openComponentInstanceForExportingMovie(movie);
    OSErr err = ConvertMovieToDataRef([movie quickTimeMovie], NULL, dataRefRecord.dataRef, dataRefRecord.dataRefType, kQTFileTypeMovie, 0, createMovieFileDeleteCurFile, ci);
    CloseComponent(ci);  
    return err;
}

static int runConnectedToServer(NSString * serverName, BOOL shouldDoPosterImages, BOOL shouldDoMiniMovies)
{
    NSArray *attributeKeys = [NSArray arrayWithObjects:QTMovieCopyrightAttribute, QTMovieCreationTimeAttribute, QTMovieModificationTimeAttribute, QTMovieDisplayNameAttribute, 
                              QTMovieFileNameAttribute, QTMovieHasAudioAttribute, QTMovieHasVideoAttribute, QTMovieLoopsAttribute, QTMovieHasDurationAttribute, QTMovieTimeScaleAttribute, QTMovieDurationAttribute, nil];

    // Connect to the server
    NSConnection    *connection= [NSConnection connectionWithRegisteredName:serverName host:nil];
    id <iMBMovieCacheDB> server = (id)[connection rootProxy];
    [(NSDistantObject *)server setProtocolForProxy:@protocol(iMBMovieCacheDB)];
    [connection setRequestTimeout:60];
    [connection setReplyTimeout:60];
    
    // Get the url's from the server and process them until there are no more url's
    NSMutableDictionary  *movieCacheDict = [NSMutableDictionary dictionaryWithCapacity:100];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL    done = NO;
    
    while (!done)
    {
        QTMovie *movie = nil;
        NSDictionary    *jobDict = nil;
        done = YES;
        
        // Sycle through all available url's and get the attributes and poster image for them
        while (shouldDoPosterImages && (jobDict = [server nextQueuedPosterAndAttributesJob]))
        {
            done = NO;
            NSString    *sourceURLString = [jobDict objectForKey:@"sourceURLString"];
            NSString    *destinationPath = [jobDict objectForKey:@"destinationPath"];

            if (!sourceURLString)
            {
                NSLog (@"No sourceURLString in nextQueuedMiniMovieJob %@", jobDict);
                continue;
            }
            
            // Open the movie
            movie = openMovie(sourceURLString, movieCacheDict);
            if (!movie) 
                return -2;
                                                            
            // Get the attributes
            NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:[attributeKeys count]];
            NSEnumerator *keyEnum = [attributeKeys objectEnumerator];
            NSString    *key;
            
            while ((key = [keyEnum nextObject]))
            {
                id value = [movie attributeForKey:key];
                if (value)
                    [attributes setObject:value forKey:key];
            }
            [server setMovieAttributes:attributes forURLString:sourceURLString];
            
            if (destinationPath)
            {
                // Get the frame image
                NSNumber    *loadState = [movie attributeForKey:QTMovieLoadStateAttribute];
                NSDate  *date = [NSDate date];
                while ([loadState longValue] < QTMovieLoadStatePlaythroughOK && [[NSDate date] timeIntervalSinceDate:date] < 600)
                {
                    MoviesTask([movie quickTimeMovie], 10);
                    loadState = [movie attributeForKey:QTMovieLoadStateAttribute];
                }
                
                NSNumber    *hasVideoNumber = [movie attributeForKey:QTMovieHasVideoAttribute];
                if (hasVideoNumber && ![hasVideoNumber boolValue])
                {
                   // NSLog (@"Skipping %@ as it has no video", sourceURLString);
                    continue;
                }
                
                QTTime qttime = QTZeroTime;
                NSValue *posterTimeValue = [movie attributeForKey:QTMoviePosterTimeAttribute];
                if (posterTimeValue)
				{
                    qttime = [posterTimeValue QTTimeValue];	// if zero time, we will find a better frame
				}
                if (NSOrderedSame == QTTimeCompare(qttime, QTZeroTime))	// synthesize poster time if we don't have a time
                {
					// get ~1 minute in, capped at 1/5 movie time.
                    NSValue *durValue = [movie attributeForKey:QTMovieDurationAttribute];
                    if (nil != durValue)
                    {
                        QTTime durTime = [durValue QTTimeValue];
                        if (durTime.timeScale == 0)
                            durTime.timeScale = 60;	// make sure there's a time scale
                        
                        QTTime constTime = durTime;
                        constTime.timeValue = durTime.timeScale * CONST_SECONDS;	// n seconds in -- get past commercials, titles, etc.
                        
                        QTTime capTime = durTime;
                        capTime.timeValue /= 5;							// cap off at one-fifth of length
                        
                        if (NSOrderedDescending == QTTimeCompare(constTime, capTime))	// const seconds > 1/5 total?
                            qttime = capTime;
                        else
                            qttime = constTime;
                    }
                    // Move the time to the next key frame so QT to speed things up a little
                    OSType		whichMediaType = VIDEO_TYPE;
                    TimeValue   newTimeValue = 0;
                    GetMovieNextInterestingTime([movie quickTimeMovie], nextTimeSyncSample, 1, &whichMediaType, qttime.timeValue, 0, &newTimeValue, NULL);
                    if (newTimeValue > 0 && newTimeValue <= qttime.timeValue * 1.5) // stay within a reasonable time
                        qttime.timeValue = newTimeValue;
                }
                NSImage *image = [movie frameImageAtTime:qttime];
                
                if (!image)
				{
                    NSLog (@"Could not get frame image for %@", sourceURLString);
				}
                else
                {
                    NSSize  imageSize = [image size];
                    float scaleFactor = fminf(1.0f, MAX_IMAGE_SIZE / fmaxf(imageSize.width, imageSize.height));
                    NSSize  bitmapSize = NSMakeSize (imageSize.width *scaleFactor, imageSize.height * scaleFactor);
                    NSBitmapImageRep    *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                                          pixelsWide:bitmapSize.width
                                                                                          pixelsHigh:bitmapSize.height
                                                                                       bitsPerSample:8
                                                                                     samplesPerPixel:4
                                                                                            hasAlpha:YES
                                                                                            isPlanar:NO
                                                                                      colorSpaceName:NSCalibratedRGBColorSpace
                                                                                         bytesPerRow:0
                                                                                        bitsPerPixel:0];
                    [bitmap setSize:bitmapSize];
                    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
                    [NSGraphicsContext saveGraphicsState];
                    [NSGraphicsContext setCurrentContext:context];
                    [[NSColor clearColor] set];
                    NSRectFill(NSMakeRect(0, 0, bitmapSize.width, bitmapSize.height));
                    [image drawInRect:NSMakeRect(0,0,bitmapSize.width, bitmapSize.height) fromRect:NSMakeRect(0,0,imageSize.width, imageSize.height) operation:NSCompositeCopy fraction:1.0];
                    [NSGraphicsContext restoreGraphicsState];
                    NSData  *data = [bitmap representationUsingType:NSJPEG2000FileType properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.7] forKey:NSImageCompressionFactor]];
                    
                    NSError *error = nil;
                    if ( [data writeToFile:destinationPath options:0 error:&error] )
                    { // Notify the server
                        [server setPosterImageFilePath:destinationPath forURLString:sourceURLString];
                    }
                    else 
                    {    
						NSLog (@"Could not save image data for %@. Error:%@", jobDict, error);
					}
                    
                    [bitmap release];
                }
            }
            [pool drain];
			[pool release];
            pool = [[NSAutoreleasePool alloc] init];
        }
        
        while (shouldDoMiniMovies && (jobDict = [server nextQueuedMiniMovieJob]))
        {            
            done = NO;

            NSString    *sourceURLString = [jobDict objectForKey:@"sourceURLString"];
            NSString    *destinationPath = [jobDict objectForKey:@"destinationPath"];
            
            if (!sourceURLString || !destinationPath)
            {
                NSLog (@"No sourceURLString or destinationPath in nextQueuedMiniMovieJob %@", jobDict);
                continue;
            }
            movie = openMovie (sourceURLString, movieCacheDict);
            if (!movie)
                return -2;
            
            NSNumber    *hasDurationNumber = [movie attributeForKey:QTMovieHasDurationAttribute];
            if (hasDurationNumber && ![hasDurationNumber boolValue])
            {
                NSLog (@"Not doing minimovie for %@ as it has no duration", sourceURLString);
                continue;
            }
            
            NSNumber    *loadState = [movie attributeForKey:QTMovieLoadStateAttribute];
            NSDate  *date = [NSDate date];
            while ([loadState longValue] < QTMovieLoadStateComplete && [[NSDate date] timeIntervalSinceDate:date] < 600)
            {
                MoviesTask([movie quickTimeMovie], 10);
                loadState = [movie attributeForKey:QTMovieLoadStateAttribute];
            }

            // Create a mini movie
            DataReferenceRecord dataRefRecord;
            OSErr err = QTNewDataReferenceFromCFURL((CFURLRef)[NSURL fileURLWithPath:destinationPath],
                                                    0,
                                                    &dataRefRecord.dataRef,
                                                    &dataRefRecord.dataRefType);
            
            if (err != noErr)
            {
                NSLog (@"Error %d when creating data ref to %@", err, destinationPath);
                return err;
            }
            err = CreateMiniMovie(movie, dataRefRecord);
            if (err != noErr)
            {
                NSLog (@"Error %d when ConvertMovieToDataRef for %@", err, movie);
                return err;
            }
            [server setMiniMovieFilePath:destinationPath forURLString:sourceURLString];
        }

        [pool drain];
		[pool release];
        pool = [[NSAutoreleasePool alloc] init];
    }
        
    [pool drain];
	[pool release];
    return 0;
}

int main (int argc, const char * argv[]) {
    int result = 0;
    NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
    NSApplicationLoad();
    
    BOOL shouldDoPosterImages = NO;
    BOOL shouldDoMiniMovies = NO;
    NSString    *server = nil;
    int i;
    for (i = 1; i < argc; ++i)
    {
        if (strcmp(argv[i], "-posterImages") == 0)
            shouldDoPosterImages = YES;
        else if (strcmp(argv[i], "-miniMovies") == 0)
            shouldDoMiniMovies = YES;
        else if (strcmp(argv[i], "-settings") == 0)
        {
            ++i;
            settingsPath = [[NSString stringWithUTF8String:argv[i]] retain];
        }
        else if (strcmp(argv[i], "-server") == 0)
        {
            ++i;
            server = [NSString stringWithUTF8String:argv[i]];
        }
    }
    
    if (!server)
        server = [[NSUserDefaults standardUserDefaults] stringForKey:@"server"];
        
    if (server)
        result = runConnectedToServer(server, shouldDoPosterImages, shouldDoMiniMovies);

    [pool drain];
 	[pool release];
   
    return result;
}
