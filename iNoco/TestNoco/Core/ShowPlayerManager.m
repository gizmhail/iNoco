//
//  ShowPlayerManager.m
//  iNoco
//
//  Created by Sébastien POIVRE on 26/08/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "ShowPlayerManager.h"

@interface ShowPlayerManager (){
    bool userEndedPlay;
}
@property (retain, nonatomic) MPMoviePlayerController* moviePlayer;
@property (retain, nonatomic) NSTimer* progressTimer;
@property (retain, nonatomic) UIAlertView* progressAlert;
@property (retain, nonatomic) NLTShow* currentShow;
@property (retain, nonatomic) NSArray* showList;

@end

@implementation ShowPlayerManager

+ (instancetype)sharedInstance{
    static ShowPlayerManager* _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!_sharedInstance){
            _sharedInstance = [[self alloc] init];
        }
    });
    return _sharedInstance;
}

- (id)init{
    if(self = [super init]){
        [self playerNotificationSubscription];
    }
    return self;
}


#pragma mark UI

- (BOOL)displayAlerts{
    return self.showList && [self.showList count]>1;
}

#pragma mark Playlist logic

- (NLTShow*)nextShow{
    NLTShow* nextShow = nil;
    if(self.currentShow && self.showList){
        NSUInteger index = [self.showList indexOfObject:self.currentShow];
        index++;
        if(index < [self.showList count]){
            nextShow = [self.showList objectAtIndex:index];
        }
    }
    return nextShow;
}

- (void)switchToNextShow{
#warning See if we should keep it in the superview
    [self.moviePlayer.view removeFromSuperview];
    NLTShow* nextShow = [self nextShow];
    if(nextShow == nil){
        //Playlist is finished
        self.showList = nil;
    }else{
        self.currentShow = nextShow;
#warning TODO Add image =>> add UIIMage attribute to NLTShow
        [self play:self.currentShow withProgress:0 withImage:[UIImage imageNamed:@"noco.png"]];
    }
}

#pragma mark Player

- (void)playerNotificationSubscription{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationMPMoviePlayerNowPlayingMovieDidChangeNotification:) name:MPMoviePlayerNowPlayingMovieDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationMPMoviePlayerPlaybackDidFinishNotification:) name:MPMoviePlayerPlaybackDidFinishNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificaitonMPMoviePlayerDidExitFullscreenNotification:) name:MPMoviePlayerDidExitFullscreenNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notificationMPMoviePlayerPlaybackDidFinishNotification:)
                                                 name:MPMoviePlayerWillExitFullscreenNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notificationMPMoviePlayerLoadStateDidChangeNotification:)
                                                 name:MPMoviePlayerLoadStateDidChangeNotification
                                               object:nil];
}


- (void)notificationMPMoviePlayerLoadStateDidChangeNotification:(NSNotification*)notif{
#ifdef DEBUG
    NSLog(@"Load state %li", (long)self.moviePlayer.loadState);
#endif
    if(self.moviePlayer.loadState & MPMovieLoadStatePlayable){
    }
}

- (void)notificaitonMPMoviePlayerDidExitFullscreenNotification:(NSNotification*)notif{
    if([self.delegate respondsToSelector:@selector(moviePlayerDidExitFullscreen)]){
        [self.delegate moviePlayerDidExitFullscreen];
    }
}

- (void)notificationMPMoviePlayerPlaybackDidFinishNotification:(NSNotification*)notif{
    [self.progressTimer invalidate];
    int reason = MPMovieFinishReasonUserExited;
    if([notif.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey]){
        reason = [[notif.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    }
    //MPMovieFinishReasonPlaybackEnded will be callend after MPMovieFinishReasonUserExited so we prevent reset the progress when an MPMovieFinishReasonUserExited occured
    if (reason == MPMovieFinishReasonPlaybackEnded && ! userEndedPlay) {
        //movie finished playin
        NSLog(@"Stopped at end");
        if([self displayAlerts]){
            if(!self.progressAlert){
                self.progressAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"Mise à jour de la progression de la lecture..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
                [self.progressAlert show];
            }
        }
        [[NLTAPI sharedInstance] setResumePlay:0 forShow:self.currentShow withResultBlock:^(id result, NSError *error) {
            [self.progressAlert dismissWithClickedButtonIndex:0 animated:YES];
            [self progressChanged:0];
        } withKey:self];
        [self.moviePlayer stop];
    }else if (reason == MPMovieFinishReasonUserExited) {
        //user hit the done button
        if(self.moviePlayer.currentPlaybackTime > 0 && self.moviePlayer.currentPlaybackTime < self.moviePlayer.duration){
            userEndedPlay = TRUE;
            NSLog(@"Stopped before end - %f / %f",self.moviePlayer.currentPlaybackTime, self.moviePlayer.duration);
            [self progressChanged:self.moviePlayer.currentPlaybackTime];
            if([self displayAlerts]){
                if(!self.progressAlert){
                    self.progressAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"Mise à jour de la progression de la lecture..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
                    [self.progressAlert show];
                }
            }
            [[NLTAPI sharedInstance] setResumePlay:1000*self.moviePlayer.currentPlaybackTime forShow:self.currentShow withResultBlock:^(id result, NSError *error) {
                [self.progressAlert dismissWithClickedButtonIndex:0 animated:YES];
            } withKey:self];
        }
        [self.moviePlayer stop];
    }else if (reason == MPMovieFinishReasonPlaybackError) {
        //error
        NSLog(@"Stoped due to error");
        [self.moviePlayer stop];
    }
    [self.moviePlayer setFullscreen:NO animated:YES];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSMutableDictionary dictionary];
    
    [self switchToNextShow];
}

- (void)notificationMPMoviePlayerNowPlayingMovieDidChangeNotification:(NSNotification*)notif{
    [self.delegate endedLookingForMovieUrl];
    if([self.delegate respondsToSelector:@selector(moviePlayerNowPlayingMovieDidChange)]){
        [self.delegate moviePlayerNowPlayingMovieDidChange];
    }
}

//NSTimer
- (void)progressUpdate{
    if(self.moviePlayer && self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying && self.currentShow){
        [[NLTAPI sharedInstance] setResumePlay:1000*self.moviePlayer.currentPlaybackTime forShow:self.currentShow withResultBlock:^(id result, NSError *error) {
        } withKey:self];
    }
}

- (void)tooglePlay{
    if(self.moviePlayer){
        if(self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying){
            //Playing
            [self.moviePlayer pause];
        }else{
            //Not playing
            [self.moviePlayer play];
        }
    }
}

- (IBAction)play:(NLTShow*)show withProgress:(float)progress withImage:(UIImage*)image withPlaylist:(NSArray*)playlist{
    self.showList = [NSArray arrayWithArray:playlist];
    [self play:show withProgress:progress withImage:image];
}

- (IBAction)play:(NLTShow*)show withProgress:(float)progress withImage:(UIImage*)image{
    self.currentShow = show;
    if(self.currentShow.access_show == 0){
        if([self.currentShow.access_error compare:@"subscription_required" options:NSCaseInsensitiveSearch]==NSOrderedSame){
            NSString* urlStr = [NSString stringWithFormat:@"partners/by_key/%@",self.currentShow.partner_key];
            [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(id result, NSError *error) {
                BOOL partnerFound = FALSE;
                if([result isKindOfClass:[NSArray class]]){
                    for (NSDictionary*partner in result) {
                        if([(NSString*)[partner objectForKey:@"partner_key"] compare:self.currentShow.partner_key]==NSOrderedSame){
                            if([self displayAlerts]){
                                [[[UIAlertView alloc] initWithTitle:@"Lecture impossible" message:[NSString stringWithFormat:@"Vous n'êtes pas abonné(e) à %@", [partner objectForKey:@"partner_name"]] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
                                partnerFound = TRUE;
                            }
                            break;
                        }
                    }
                }
                if(!partnerFound){
                    if([self displayAlerts]){
                        [[[UIAlertView alloc] initWithTitle:@"Lecture impossible" message:@"Impossible de lire cette émission" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
                    }
                }
                [self switchToNextShow];
            } withKey:self withCacheDuration:60*10];
        }else{
            if([self displayAlerts]){
                [[[UIAlertView alloc] initWithTitle:@"Lecture impossible" message:@"Impossible de lire cette émission" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
            }
            [self switchToNextShow];
        }
        return;
    }
    
    __weak ShowPlayerManager* weakSelf = self;
    
    if([self.delegate respondsToSelector:@selector(startedLookingForMovieUrl)]){
        [self.delegate startedLookingForMovieUrl];
    }
    
    NSURL* url = nil;
    if([[NocoDownloadsManager sharedInstance] isDownloaded:self.currentShow]){
        NSString* file = [[NocoDownloadsManager sharedInstance] downloadFilePathForShow:self.currentShow];
        if(file){
            url = [NSURL fileURLWithPath:file];
        }
    }
    if(url){
        //Downloaded video
        [self playURL:url withProgress:progress withImage:image];
    }else{
        //Remote video
        [[NLTAPI sharedInstance] videoUrlForShow:self.currentShow withResultBlock:^(id result, NSError *error) {
            if(result){
                userEndedPlay = FALSE;
                NSString* file = [result objectForKey:@"file"];
                NSURL* url = nil;
                if(file){
                    url = [NSURL URLWithString:file];
                }
                [weakSelf playURL:url withProgress:progress withImage:image];
            }else{
                if([self.delegate respondsToSelector:@selector(endedLookingForMovieUrl)]){
                    [self.delegate endedLookingForMovieUrl];
                }
                if([self displayAlerts]){
                    if(error.code == NLTAPI_ERROR_VIDEO_UNAVAILABLE_WITH_POPMESSAGE && [error.userInfo objectForKey:@"popmessage"]&&[[error.userInfo objectForKey:@"popmessage"] objectForKey:@"message"]){
                        [[[UIAlertView alloc] initWithTitle:@"Erreur" message:[[error.userInfo objectForKey:@"popmessage"] objectForKey:@"message"] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
                    }else{
                        [[[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de lire la vidéo" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
                    }
                }
            }
        } withKey:self];
    }
}

- (void)playURL:(NSURL*)url withProgress:(float)progress withImage:(UIImage*)image{
    NSLog(@"Reading url %@",url);
    self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
    self.moviePlayer.view.frame = [self.delegate moviePlayerFrame];
    [[self.delegate moviePlayerSuperview] addSubview:self.moviePlayer.view];
    if([self.delegate respondsToSelector:@selector(moviePlayerPlacedInView)]){
        [self.delegate moviePlayerPlacedInView];
    }
    [self.moviePlayer setInitialPlaybackTime:progress];
    [self.moviePlayer prepareToPlay];
    self.moviePlayer.shouldAutoplay = TRUE;
    [self.moviePlayer setFullscreen:YES animated:YES];
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:PROGRESS_UPDATE_UPLOAD_STEP_TIME target:self selector:@selector(progressUpdate) userInfo:nil repeats:YES];
    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary* info = [NSMutableDictionary dictionaryWithDictionary:infoCenter.nowPlayingInfo];
    if(!info){
        info =  [NSMutableDictionary dictionary];
    }
    if(self.currentShow.show_TT) [info setObject:self.currentShow.show_TT forKey:MPMediaItemPropertyTitle];
    if(self.currentShow.family_TT) [info setObject:self.currentShow.family_TT forKey:MPMediaItemPropertyArtist];
    [info setObject:[NSNumber numberWithInt:self.currentShow.episode_number] forKey:MPMediaItemPropertyAlbumTrackNumber];
    [info setObject:[[MPMediaItemArtwork alloc] initWithImage:image] forKey:MPMediaItemPropertyArtwork];
    infoCenter.nowPlayingInfo = info;
}

#pragma mark Delegate

- (void)progressChanged:(float)progress{
    if([self.delegate respondsToSelector:@selector(progressChanged:)]){
        [self.delegate progressChanged:progress];
    }
}

#pragma mark Memory management

-(void)dealloc{
    [self.progressTimer invalidate];
    [[NLTAPI sharedInstance] cancelCallsWithKey:self];
}

@end
