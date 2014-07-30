//
//  NocoDownloadsManager.m
//  iNoco
//
//  Created by Sébastien POIVRE on 11/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NocoDownloadsManager.h"

@interface NocoDownloadsManager ()
@property (retain,nonatomic) NSMutableDictionary* completionHandlerDictionary;
@property (retain,nonatomic) NSMutableDictionary* tasks;
@property (retain,nonatomic) NSURLSessionConfiguration *backgroundConfigObject;
@property (retain,nonatomic) NSURLSession* backgroundSession;

@end
@implementation NocoDownloadsManager


+ (instancetype)sharedInstance{
    static NocoDownloadsManager* _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!_sharedInstance){
            _sharedInstance = [[self alloc] init];
        }
    });
    return _sharedInstance;
}

-(id)init{
    if(self = [super init]){
        [self loadCache];
        self.completionHandlerDictionary = [NSMutableDictionary dictionary];
        self.tasks = [NSMutableDictionary dictionary];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            self.backgroundConfigObject = [NSURLSessionConfiguration backgroundSessionConfiguration: @"iNocoBackgroundSessionIdentifier"];
            self.backgroundSession = [NSURLSession sessionWithConfiguration: self.backgroundConfigObject delegate: self delegateQueue: [NSOperationQueue mainQueue]];
        });

    }
    return self;
}

- (BOOL)prepareStoreDirectory{
    BOOL ok = TRUE;
    NSString *appSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    //If there isn't an App Support Directory yet ...
    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDir isDirectory:NULL]) {
        NSError *error = nil;
        //Create one
        if (![[NSFileManager defaultManager] createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Unable to create NSApplicationSupportDirectory\n%@", error.localizedDescription);
            ok = false;
#warning TODO Handle error: unable to create NSApplicationSupportDirectory
        }
        else {
            NSURL *url = [NSURL fileURLWithPath:appSupportDir];
            ok = [self addSkipBackupAttributeToItemAtURL:url];
            if(!ok){
                NSLog(@"Unable to exclude from backup");
#warning TODO Handle error: unable to exlude from backup
            }
        }
    }
    return ok;
}

//Source: https://developer.apple.com/library/ios/qa/qa1719/_index.html
- (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL {
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    return success;
}

- (NSMutableDictionary*)downloadInfoForShow:(NLTShow*)show{
    NSMutableDictionary* info = nil;
    for (NSMutableDictionary* downloadInfo in self.downloadInfos) {
        NLTShow* downloadShow = [[NLTShow alloc] initWithDictionnary:[downloadInfo objectForKey:@"showInfo"]];
        if(downloadShow.id_show == show.id_show){
            info = downloadInfo;
            break;
        }
    }
    return info;
}

- (NSMutableDictionary*)downloadInfoForTask:(NSURLSessionTask*)task{
    NSMutableDictionary* info = nil;
    for (NSMutableDictionary* downloadInfo in self.downloadInfos) {
        if([downloadInfo objectForKey:@"taskIdentifier"]&&[(NSNumber*)[downloadInfo objectForKey:@"taskIdentifier"] unsignedLongValue] == task.taskIdentifier){
            info = downloadInfo;
            break;
        }
    }
    return info;
}

- (BOOL)isDownloaded:(NLTShow*)show{
    BOOL downloaded = false;
    NSDictionary* downloadInfo = [self downloadInfoForShow:show];
    if(downloadInfo&&[downloadInfo objectForKey:@"filePath"]){
        downloaded = TRUE;
    }
    return downloaded;
}

- (BOOL)isDownloadPending:(NLTShow*)show{
    BOOL downloadPending = false;
    NSDictionary* downloadInfo = [self downloadInfoForShow:show];
    if(downloadInfo&&![downloadInfo objectForKey:@"filePath"]){
        downloadPending = true;
    }
    return downloadPending;
}

- (NSString*)taskDescriptionForShow:(NLTShow*)show{
    return [NSString stringWithFormat:@"%i",show.id_show];
}

- (void)planDownloadForShow:(NLTShow*)show withQuality:(NSString*)quality{
    NSMutableDictionary* downloadInfo = [NSMutableDictionary dictionaryWithDictionary:@{
                               @"showInfo":show.rawShow,
                               @"quality":quality
                               }];
    [self.downloadInfos addObject:downloadInfo];
    [self saveCache];
    
    __weak NocoDownloadsManager* weakSelf = self;
    [[NLTAPI sharedInstance] videoUrlForShow:show withResultBlock:^(id result, NSError *error) {
        if(result){
            weakSelf.completionHandlerDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
            
            
            NSURL *url = [NSURL URLWithString: [result objectForKey:@"file"] ];
            
            NSURLSessionDownloadTask *downloadTask = [self.backgroundSession downloadTaskWithURL: url];
            downloadTask.taskDescription = [self taskDescriptionForShow:show];
            [self.tasks setObject:downloadTask forKey:downloadTask.taskDescription];
            
            [downloadInfo setObject:[result objectForKey:@"file"] forKey:@"urlStr"];
            [downloadInfo setObject:[NSNumber numberWithUnsignedLong:downloadTask.taskIdentifier] forKey:@"taskIdentifier"];
            [downloadInfo setObject:downloadTask.taskDescription forKey:@"taskDescription"];
            [self saveCache];
            NSLog(@"Launching download of %@ (task: %@)", [result objectForKey:@"file"], [NSNumber numberWithUnsignedLong:downloadTask.taskIdentifier]);
            [downloadTask resume];
        }else{
#warning TODO See if we should remove alert view messages (background cases, ...)
            if(error.code == NLTAPI_ERROR_VIDEO_UNAVAILABLE_WITH_POPMESSAGE && [error.userInfo objectForKey:@"popmessage"]&&[[error.userInfo objectForKey:@"popmessage"] objectForKey:@"message"]){
                [[[UIAlertView alloc] initWithTitle:@"Erreur" message:[[error.userInfo objectForKey:@"popmessage"] objectForKey:@"message"] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }else{
                [[[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de télécharger la vidéo" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }
            [self.downloadInfos removeObject:downloadInfo];
#warning TODO Add error notif instead of finished
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NocoDownloadsNotificationFinishDownloading" object:[NSNumber numberWithLong:show.id_show] userInfo:downloadInfo];
        }
    } withKey:self];
}

- (void)cancelDownloadForShow:(NLTShow*)show{
    NSDictionary* downloadInfo = [self downloadInfoForShow:show];
    if(downloadInfo&&[downloadInfo objectForKey:@"filePath"]){
        //Already downloaded
        [self eraseDownloadForShow:show];
    }else{
        [self.downloadInfos removeObject:downloadInfo];
#warning TODO Cancel NSURLSession
        NSURLSessionDownloadTask *downloadTask = [self.tasks objectForKey:[downloadInfo objectForKey:@"taskDescription"]];
        [downloadTask cancel];
    }
    [self saveCache];
}

- (void)eraseDownloadForShow:(NLTShow*)show{
    NSMutableDictionary* downloadInfo = [self downloadInfoForShow:show];
    [self.downloadInfos removeObject:downloadInfo];

#warning TODO Cancel NSURLSession
    if([downloadInfo objectForKey:@"filePath"]){
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *fileURL = [NSURL fileURLWithPath:[downloadInfo objectForKey:@"filePath"]];
        NSError* error = nil;
        [fileManager removeItemAtURL:fileURL error:&error];
        [downloadInfo removeObjectForKey:@"filePath"];
    }
    [self saveCache];
}

- (NSString*)downloadFilePathForShow:(NLTShow*)show{
    NSDictionary* downloadInfo = [self downloadInfoForShow:show];
    NSString* path = nil;
    if(downloadInfo){
        path = [downloadInfo objectForKey:@"filePath"];
    }
    return path;
}


#pragma mark cache

- (void)loadCache{
    self.downloadInfos = [NSMutableArray array];
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    NSData* cacheData = [settings objectForKey:@"NLTDownloadInfos"];
    NSArray* cache = [NSKeyedUnarchiver unarchiveObjectWithData:cacheData];
    if(cache){
        NSMutableArray* infos = [NSMutableArray arrayWithArray:cache];
        self.downloadInfos = [NSMutableArray array];
        for (NSDictionary* info in infos) {
            if([info isKindOfClass:[NSDictionary class]]){
                if([[info objectForKey:@"showInfo"] isKindOfClass:[NSDictionary class]]){
                    [self.downloadInfos addObject:[info mutableCopy] ];
                }else{
                    NSLog(@"Pb with stored info");
                }
            }else{
                NSLog(@"Pb with stored info");
            }
        }
    }
}

- (void) saveCache{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    NSData* cacheData = [NSKeyedArchiver archivedDataWithRootObject:self.downloadInfos];
    [settings setObject:cacheData forKey:@"NLTDownloadInfos"];
    [settings synchronize];
}

#pragma mark NSURLSession delegate
//Source of NSURLSession comments: http://hayageek.com/ios-nsurlsession-example/

/* Sent when a download task that has completed a download.  The delegate should
 * copy or move the file at the given location to a new location as it will be
 * removed when the delegate message returns. URLSession:task:didCompleteWithError: will
 * still be called.
 */
-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    NSLog(@"Session %@ download task %@ finished downloading to URL %@\n",
          session, downloadTask, location);
    
    NSMutableDictionary* downloadInfo = [self downloadInfoForTask:downloadTask];
    if(downloadInfo){
        // Workaround [self callCompletionHandlerForSession:session.configuration.identifier];
        NSError *err = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        BOOL directoryOk = [self prepareStoreDirectory];
#warning TOOD Handle problems with storage dir creation
        if(!directoryOk){
            NSLog(@"Problem with storage directory");
        }
        NSString *appSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
        NSString* fileName = [(NSString*)[downloadInfo objectForKey:@"urlStr"] lastPathComponent];
        fileName = [[fileName componentsSeparatedByString:@"?"] firstObject];
        NSString *targetPath = [appSupportDir stringByAppendingPathComponent:fileName];
        NSURL *targetURL = [NSURL fileURLWithPath:targetPath];

        if ([fileManager moveItemAtURL:location toURL:targetURL error: &err]) {
            [self addSkipBackupAttributeToItemAtURL:targetURL];
            [downloadInfo setObject:[targetURL path] forKey:@"filePath"];
            [self saveCache];
            NLTShow* downloadShow = [[NLTShow alloc] initWithDictionnary:[downloadInfo objectForKey:@"showInfo"]];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"NocoDownloadsNotificationFinishDownloading" object:[NSNumber numberWithLong:downloadShow.id_show] userInfo:downloadInfo];

            /* Store some reference to the new URL */
        } else {
            /* Handle the error. */
        }
    }else{
#warning Handle Error
        NSLog(@"No downloadInfo related to downloadTask");
    }
    [self.tasks removeObjectForKey:downloadTask.taskDescription ];
}

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    NSLog(@"NSURLSession didCompleteWithError error: %@", error);
    [self.tasks removeObjectForKey:task.taskDescription];
}

-(void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error{
    NSLog(@"NSURLSession didBecomeInvalidWithError error: %@", error);
}

/* Sent periodically to notify the delegate of download progress. */
-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    float progress = 0;
    if(totalBytesExpectedToWrite>0){
        progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    }
    NSMutableDictionary* downloadInfo = [self downloadInfoForTask:downloadTask];
    NLTShow* downloadShow = [[NLTShow alloc] initWithDictionnary:[downloadInfo objectForKey:@"showInfo"]];
    //NSLog(@"[Show %i] Session download task wrote (%i%%) an additional %lld bytes (total %lld bytes) out of an expected %lld bytes.\n", downloadShow.id_show,(int)(progress*100), bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
    [downloadInfo setObject:[NSNumber numberWithFloat:progress] forKey:@"progress"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"NocoDownloadsNotificationProgress" object:[NSNumber numberWithLong:downloadShow.id_show] userInfo:downloadInfo];
    if(![self.tasks objectForKey:downloadTask.taskDescription]){
        [self.tasks setObject:downloadTask forKey:downloadTask.taskDescription];
    }
}

/* Sent when a download has been resumed. If a download failed with an
 * error, the -userInfo dictionary of the error will contain an
 * NSURLSessionDownloadTaskResumeData key, whose value is the resume
 * data.
 */-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes{
     NSLog(@"Resuming task for show %@", downloadTask.taskDescription);
     if(![self.tasks objectForKey:downloadTask.taskDescription]){
         [self.tasks setObject:downloadTask forKey:downloadTask.taskDescription];
     }
}

#pragma mark Background session handling


/* If an application has received an
 * -application:handleEventsForBackgroundURLSession:completionHandler:
 * message, the session delegate will receive this message to indicate
 * that all messages previously enqueued for this session have been
 * delivered.  At this time it is safe to invoke the previously stored
 * completion handler, or to begin any internal updates that will
 * result in invoking the completion handler.
 */
-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
    NSLog(@"Background URL session %@ finished events.\n", session);
    
    if (session.configuration.identifier){
        [self callCompletionHandlerForSession: session.configuration.identifier];
    }
}

- (void) addCompletionHandler: (CompletionHandlerType) handler forSession: (NSString *)identifier{
    if ([ self.completionHandlerDictionary objectForKey: identifier]) {
        NSLog(@"Error: Got multiple handlers for a single session identifier.  This should not happen.\n");
    }
    
    [ self.completionHandlerDictionary setObject:handler forKey: identifier];
}

- (void) callCompletionHandlerForSession: (NSString *)identifier{
    CompletionHandlerType handler = [self.completionHandlerDictionary objectForKey: identifier];
    
    if (handler) {
        [self.completionHandlerDictionary removeObjectForKey: identifier];
        NSLog(@"Calling completion handler.\n");
        
        handler();
    }
}
@end
