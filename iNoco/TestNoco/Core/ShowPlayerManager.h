//
//  ShowPlayerManager.h
//  iNoco
//
//  Created by Sébastien POIVRE on 26/08/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "NLTAPI.h"
#import "NocoDownloadsManager.h"

@protocol ShowPlayerManagerDelegate <NSObject>
- (CGRect)moviePlayerFrame;
- (UIView*)moviePlayerSuperview;
@optional
- (void)moviePlayerDidExitFullscreen;
- (void)moviePlayerNowPlayingMovieDidChange;
- (void)progressChanged:(float)progress;
- (void)startedLookingForMovieUrl;
- (void)endedLookingForMovieUrl;
- (void)moviePlayerPlacedInView;
@end

@interface ShowPlayerManager : NSObject
@property (assign,nonatomic) id<ShowPlayerManagerDelegate> delegate;
+ (instancetype)sharedInstance;
- (void)tooglePlay;
- (IBAction)play:(NLTShow*)show withProgress:(float)progress withImage:(UIImage*)image withPlaylist:(NSMutableArray*)playlist withCurrentPlaylistItem:(id)currentItem;
- (IBAction)play:(NLTShow*)show withProgress:(float)progress withImage:(UIImage*)image;
@end
