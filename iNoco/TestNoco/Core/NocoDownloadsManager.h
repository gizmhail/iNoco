//
//  NocoDownloadsManager.h
//  iNoco
//
//  Created by Sébastien POIVRE on 11/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NLTAPI.h"

typedef void (^CompletionHandlerType)();

@interface NocoDownloadsManager : NSObject<NSURLSessionDelegate,NSURLSessionDownloadDelegate>
@property (retain,nonatomic) NSMutableArray* downloadInfos;

+ (instancetype)sharedInstance;

- (BOOL)isDownloaded:(NLTShow*)show;
- (BOOL)isDownloadPending:(NLTShow*)show;

- (void)planDownloadForShow:(NLTShow*)show withQuality:(NSString*)quality;
- (void)cancelDownloadForShow:(NLTShow*)show;
- (void)eraseDownloadForShow:(NLTShow*)show;
- (NSString*)downloadFilePathForShow:(NLTShow*)show;

- (void) addCompletionHandler: (CompletionHandlerType) handler forSession: (NSString *)identifier;
@end
