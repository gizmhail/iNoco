//
//  ShowPlayerManager.m
//  iNoco
//
//  Created by Sébastien POIVRE on 26/08/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "ShowPlayerManager.h"
#import "ChromecastManager.h"
#import "AppDelegate.h"

@interface ShowPlayerManager (){
    bool userEndedPlay;
    bool playbackDurationSet;
    float initialProgress;
}
@property (retain, nonatomic) MPMoviePlayerController* moviePlayer;
@property (retain, nonatomic) NSTimer* progressTimer;
@property (retain, nonatomic) UIAlertView* progressAlert;
@property (retain, nonatomic) NLTShow* currentShow;
@property (retain, nonatomic) id currentPlaylistItem;
@property (retain, nonatomic) NSMutableArray* showList;
@property (retain, nonatomic) NSMutableArray* chapters;
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
    return !self.showList || [self.showList count] ==1;
}

#pragma mark Playlist logic

- (id)nextShow{
    NLTShow* nextShow = nil;
    if(self.currentPlaylistItem && self.showList){
        NSUInteger index = [self.showList indexOfObject:self.currentPlaylistItem];
        if(index==NSNotFound&&[self.currentPlaylistItem isKindOfClass:[NLTShow class]]){
            //The playlsit is maybe in showId format
            index = [self.showList indexOfObject:[NSNumber numberWithInt:[(NLTShow*)self.currentPlaylistItem id_show]]];
        }
        index++;
        if(index < [self.showList count]){
            nextShow = [self.showList objectAtIndex:index];
        }else{
#ifdef DEBUG
            NSLog(@"No more shows %li %@ %@", index, self.showList,self.currentShow);
#endif
        }
    }else{
#ifdef DEBUG
        NSLog(@"No playlist: nothing more to play");
#endif
    }
    return nextShow;
}

- (id)previousShow{
    NLTShow* previousShow = nil;
    if(self.currentPlaylistItem && self.showList){
        NSUInteger index = [self.showList indexOfObject:self.currentPlaylistItem];
        index--;
        if(index > 0 && index < [self.showList count]){
            previousShow = [self.showList objectAtIndex:index];
        }else{
#ifdef DEBUG
            NSLog(@"No more shows %li %@", index, self.showList);
#endif
        }
    }else{
#ifdef DEBUG
        NSLog(@"No playlist: nothing more to play");
#endif
    }
    return previousShow;
}

- (void)switchToNextShow{
    [self switchToSiblingFollowing:TRUE];
}

- (void)switchToSiblingFollowing:(BOOL)isNext{
#ifdef DEBUG
    NSLog(@"-- switchToSiblingFollowing %i --",isNext);
#endif
#warning See if we should keep it in the superview
    [self removeCustomUI];
    [self.moviePlayer.view removeFromSuperview];
    id siblingShow = [self nextShow];
    if(!isNext){
        siblingShow = [self previousShow];
    }
    if(siblingShow == nil){
        //Playlist is finished
#ifdef DEBUG
        NSLog(@"Playlist is finished");
#endif
        self.showList = nil;
        self.currentShow = nil;
        self.currentPlaylistItem = nil;
    }else{
        self.currentPlaylistItem = siblingShow;
        if([siblingShow isKindOfClass:[NLTShow class]]){
#warning TODO Add image =>> add UIIMage attribute to NLTShow
            [self play:(NLTShow*)siblingShow withProgress:0 withImage:[UIImage imageNamed:@"noco.png"]];
        }else if([siblingShow isKindOfClass:[NSDictionary class]]){
            NSDictionary* showInfo = (NSDictionary*)siblingShow;
            if([[showInfo objectForKey:@"NolifeOnlineURL"] isKindOfClass:[NSString class]]&&[(NSString*)[showInfo objectForKey:@"NolifeOnlineURL"] compare:@""]!=NSOrderedSame){
                NSString* nocoUrl = (NSString*)[showInfo objectForKey:@"NolifeOnlineURL"];
                long nocoId = [[nocoUrl lastPathComponent] integerValue];
                [[NLTAPI sharedInstance] showWithId:nocoId withResultBlock:^(id result, NSError *error) {
                    if(result){
                        [self play:result withProgress:0 withImage:[UIImage imageNamed:@"noco.png"]];
                    }else if (error){
                        //Skipping unusable show
#ifdef DEBUG
                        NSLog(@"Skipping next show (not known on backend)");
#endif
                        [self switchToSiblingFollowing:isNext];
                    }
                } withKey:self];
            }else{
                //Skipping unusable show
#ifdef DEBUG
                NSLog(@"Skipping next show (not a show or an EPG entrydictionary)");
#endif
                [self switchToSiblingFollowing:isNext];
            }
        }else if([siblingShow isKindOfClass:[NSNumber class]]){
            //Show was a number, a show id (probably from atchlist context)
            [[NLTAPI sharedInstance] showWithId:[(NSNumber*)siblingShow longValue] withResultBlock:^(id result, NSError *error) {
                if(result){
                    [self play:result withProgress:0 withImage:[UIImage imageNamed:@"noco.png"]];
                }else if (error){
                    //Skipping unusable show
#ifdef DEBUG
                    NSLog(@"Skipping next show (not known on backend)");
#endif
                    [self switchToSiblingFollowing:isNext];
                }
            } withKey:self];
        }else{
            //Skipping unusable show
#ifdef DEBUG
            NSLog(@"Skipping next show (not a show or an EPG entrydictionary)");
#endif
            [self switchToSiblingFollowing:isNext];
        }
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
        [self playerCustomUI];
    }
    MPMoviePlayerController* player = (MPMoviePlayerController*)notif.object;
    if ( player.playbackState == MPMoviePlaybackStatePlaying) {
        if(!playbackDurationSet){
            [self.moviePlayer setCurrentPlaybackTime:initialProgress];
            playbackDurationSet=YES;
        }
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
    bool playbackCameToCompletion = self.moviePlayer.currentPlaybackTime == self.moviePlayer.duration;
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
            float progressToSave = self.moviePlayer.currentPlaybackTime;
            [[NLTAPI sharedInstance] setResumePlay:1000*progressToSave forShow:self.currentShow withResultBlock:^(id result, NSError *error) {
                [self.progressAlert dismissWithClickedButtonIndex:0 animated:YES];
            } withKey:self];
        }
        [self.moviePlayer stop];
    }else if (reason == MPMovieFinishReasonPlaybackError) {
        //error
        NSLog(@"Stoped due to error");
        [self.moviePlayer stop];
#warning Add emssage, fix fullscreen exit problems
        if([self displayAlerts]){
            [[[UIAlertView alloc] initWithTitle:@"Lecture impossible" message:@"Impossible de lire cette émission" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
        }
    }

    [self.moviePlayer setFullscreen:NO animated:YES];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSMutableDictionary dictionary];
    
    
    if(playbackCameToCompletion){
        //self.currentShow = nil;
#ifdef DEBUG
        NSLog(@"Skipping next show (playback came to completion)");
#endif
        NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
        [settings removeObjectForKey:@"InterruptedShow" ];
        [settings synchronize];

        [self switchToNextShow];
    }else{
        //User stopped playback before end
        NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
        NSData* cacheData = [NSKeyedArchiver archivedDataWithRootObject:self.currentShow.rawShow];

        [settings setObject:cacheData forKey:@"InterruptedShow" ];
        [settings synchronize];
        [self removeCustomUI];
        [self.moviePlayer.view removeFromSuperview];
    }
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

- (IBAction)play:(NLTShow*)show withProgress:(float)progress withImage:(UIImage*)image withPlaylist:(NSMutableArray*)playlist withCurrentPlaylistItem:(id)currentItem{
#ifdef DEBUG
    NSLog(@"Reading show: %@",show);
#endif
    
    self.showList = [NSMutableArray arrayWithArray:playlist];
    self.currentPlaylistItem = currentItem;
    if(!self.currentPlaylistItem){
        self.currentPlaylistItem = show;
    }
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
#ifdef DEBUG
                                NSLog(@"Unable to read: not subscribed");
#endif
                                [[[UIAlertView alloc] initWithTitle:@"Lecture impossible" message:[NSString stringWithFormat:@"Vous n'êtes pas abonné(e) à %@", [partner objectForKey:@"partner_name"]] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
                                partnerFound = TRUE;
                            }
                            break;
                        }
                    }
                }
                if(!partnerFound){
                    if([self displayAlerts]){
#ifdef DEBUG
                        NSLog(@"Unable to read: partner not found");
#endif

                        [[[UIAlertView alloc] initWithTitle:@"Lecture impossible" message:@"Impossible de lire cette émission" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
                    }
                }
#ifdef DEBUG
                NSLog(@"Skipping next show (you do not have acess to this video, subscription required)");
#endif

                [self switchToNextShow];
            } withKey:self withCacheDuration:60*10];
        }else{
            if([self displayAlerts]){
#ifdef DEBUG
                NSLog(@"Unable to read");
#endif
                [[[UIAlertView alloc] initWithTitle:@"Lecture impossible" message:@"Impossible de lire cette émission" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
            }
#ifdef DEBUG
            NSLog(@"Skipping next show (you do not have acess to this video, unknown reason)");
#endif
            [self switchToNextShow];
        }
        return;
    }
    [self fetchShowChapters];
    __weak ShowPlayerManager* weakSelf = self;
    
    NSURL* url = nil;
    if([[NocoDownloadsManager sharedInstance] isDownloaded:self.currentShow]){
        NSString* file = [[NocoDownloadsManager sharedInstance] downloadFilePathForShow:self.currentShow];
        if(file){
            url = [NSURL fileURLWithPath:file];
            BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:file];
            NSLog(@"%i",fileExists);
            if(!fileExists){
                [[NocoDownloadsManager sharedInstance] eraseDownloadForShow:self.currentShow];
                if([self displayAlerts]){
                    [[[UIAlertView alloc] initWithTitle:@"Emission effacée" message:@"Le fichier téléchargé n'est plus disponible.\nCela peut arriver lors d'une mise-à-jour de l'application.\nVeuillez le retélécharger." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
                }
                [self switchToNextShow];
                return;
            }
       }
    }
    
    if([self.delegate respondsToSelector:@selector(startedLookingForMovieUrl)]){
        [self.delegate startedLookingForMovieUrl];
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
    NSLog(@"Reading url %@ (%@)",url, self.currentShow.show_TT);
    self.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
    self.moviePlayer.view.frame = [self.delegate moviePlayerFrame];
    [[self.delegate moviePlayerSuperview] addSubview:self.moviePlayer.view];
    if([self.delegate respondsToSelector:@selector(moviePlayerPlacedInView)]){
        [self.delegate moviePlayerPlacedInView];
    }
    [self.moviePlayer setInitialPlaybackTime:progress];

    //As of ios8.4, MPMoviePlayer as a bug: http://stackoverflow.com/questions/31166400/mpmovieplayercontroller-initialplaybacktime-property-not-working-in-ios-8-4
    //We'll "manually" set progress when plaback starg
    initialProgress = progress;
    playbackDurationSet = false;

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
    if(image){
        [info setObject:[[MPMediaItemArtwork alloc] initWithImage:image] forKey:MPMediaItemPropertyArtwork];
    }
    infoCenter.nowPlayingInfo = info;}

#pragma mark Custom UI

- (BOOL)browseViewHierarchyFrom:(UIView*)view collectClassPrefix:(NSString*)classPrefix expectedParentClassPrefix:(NSString*)parentExpectedPrefix expectedParentFound:(BOOL)parentOk targetArray:(NSMutableArray*)results debugIndent:(NSString*)indent {
    NSString* className = NSStringFromClass([view class]);
    NSString* subIndent = nil;
#ifdef DEBUG_MOVIEPLAYER_VIEW
    if(indent){
        NSLog(@"%@[%@] %@",indent,className,view);
        subIndent = [NSString stringWithFormat:@"%@ ",indent];
    }
#endif
    if(!parentExpectedPrefix||[className rangeOfString:parentExpectedPrefix].location != NSNotFound){
        parentOk = TRUE;
    }

    if(parentOk&&classPrefix&&[className rangeOfString:classPrefix].location != NSNotFound){
        [results addObject:view];
    }
    
    for (UIView*subview in [view subviews]) {
        NSMutableArray* subviewResults = [NSMutableArray array];
        BOOL expectedParentOk = [self browseViewHierarchyFrom:subview collectClassPrefix:classPrefix expectedParentClassPrefix:parentExpectedPrefix expectedParentFound:parentOk targetArray:subviewResults debugIndent:subIndent];
        if(expectedParentOk){
            [results addObjectsFromArray:subviewResults];
            parentOk = true;
        }
    }
    return parentOk;
}

- (void)playerCustomUI{
    NSArray *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow*window in windows) {
        NSMutableArray* playerButtons = [NSMutableArray array];
        [self browseViewHierarchyFrom:window collectClassPrefix:@"MPKnockoutButton" expectedParentClassPrefix:nil expectedParentFound:NO targetArray:playerButtons debugIndent:@""];
        float maxY = 0;
        NSMutableArray* buttonOnBottomLine = [NSMutableArray array];
        for (UIButton* button in playerButtons) {
            CGPoint position = [button convertPoint:CGPointMake(0, 0) toView:window];
            if(position.y > maxY){
                maxY = position.y;
                buttonOnBottomLine = [NSMutableArray array];
            }
            if(position.y == maxY){
                [buttonOnBottomLine addObject:button];
            }
        }
        [buttonOnBottomLine sortUsingComparator:^NSComparisonResult(UIButton* button1, UIButton* button2) {
            CGPoint position1 = [button1 convertPoint:CGPointMake(0, 0) toView:window];
            CGPoint position2 = [button2 convertPoint:CGPointMake(0, 0) toView:window];
            if(position1.x < position2.x){
                return NSOrderedAscending;
            }
            if(position1.x > position2.x){
                return NSOrderedDescending;
            }
            return NSOrderedSame;
        }];
        if([buttonOnBottomLine count]==3){
            UIButton* prevButton = [buttonOnBottomLine firstObject];
            UIButton* nextButton = [buttonOnBottomLine lastObject];
            [prevButton removeTarget:nil
                              action:NULL
                    forControlEvents:UIControlEventAllEvents];
            [nextButton removeTarget:nil
                              action:NULL
                    forControlEvents:UIControlEventAllEvents];
            [prevButton addTarget:self action:@selector(prev) forControlEvents:UIControlEventTouchUpInside];
            [nextButton addTarget:self action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
        }
    }
}

- (void)next{
    if(!self.chapters||[self.chapters count]==0){
        [self switchToNextShow];
    }else{
        NSDictionary* nextChapter = nil;
        for (NSDictionary* chapter in self.chapters) {
            if(([[chapter objectForKey:@"timecode_ms"] floatValue]/1000.0)>(self.moviePlayer.currentPlaybackTime + 5) ){
                nextChapter = chapter;
                break;
            }
        }
        if(nextChapter){
            [self.moviePlayer setCurrentPlaybackTime:([[nextChapter objectForKey:@"timecode_ms"] floatValue]/1000.0)];
        }else{
            [self switchToNextShow];
        }
    }
}

- (void)prev{
    if(!self.chapters||[self.chapters count]==0){
        [self switchToSiblingFollowing:FALSE];
    }else{
        NSDictionary* prevChapter = nil;
        for (NSDictionary* chapter in self.chapters) {
            if(([[chapter objectForKey:@"timecode_ms"] floatValue]/1000.0)<(self.moviePlayer.currentPlaybackTime - 5) ){
                prevChapter = chapter;
            }else{
                break;
            }
        }
        if(prevChapter){
            [self.moviePlayer setCurrentPlaybackTime:([[prevChapter objectForKey:@"timecode_ms"] floatValue]/1000.0)];
        }else{
            [self switchToSiblingFollowing:FALSE];

        }
    }
}

- (void)removeCustomUI{

}

#pragma mark Chaper

- (void)fetchShowChapters{
    self.chapters = nil;
    NSString* urlStr = [NSString stringWithFormat:@"chapters/id_show/%i",self.currentShow.id_show];
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
        if(result&&[result isKindOfClass:[NSArray class]]){
            self.chapters = [NSMutableArray array];
            for (NSDictionary* chapter in result) {
                [self.chapters addObject:chapter];
            }
        }
    } withKey:self];

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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
