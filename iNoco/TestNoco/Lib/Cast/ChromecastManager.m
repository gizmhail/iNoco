//
//  ChromecastManager.m
//  iNoco
//
//  Created by Sébastien POIVRE on 07/04/2015.
//  Copyright (c) 2015 Sébastien Poivre. All rights reserved.
//

#import "ChromecastManager.h"

@interface ChromecastManager (){
    BOOL finishProgressionSynched;
}
@property (retain,nonatomic)NSTimer* progressTimer;
@property (retain, nonatomic) UIAlertView* progressAlert;
@end

@implementation ChromecastManager

- (void)deviceScan{
    
    GCKFilterCriteria *filterCriteria = [[GCKFilterCriteria alloc] init];
    filterCriteria = [GCKFilterCriteria criteriaForAvailableApplicationWithID:kGCKMediaDefaultReceiverApplicationID];
    
    self.deviceScanner = [[GCKDeviceScanner alloc] initWithFilterCriteria:filterCriteria];
    
    [self.deviceScanner addListener:self];
    [self.deviceScanner startScan];
}

- (void)selectDevice:(GCKDevice*)selectedDevice{
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *appIdentifier = [info objectForKey:@"CFBundleIdentifier"];
        self.deviceManager = [[GCKDeviceManager alloc] initWithDevice:selectedDevice clientPackageName:appIdentifier];
    self.deviceManager.delegate = self;
    [self.deviceManager connect];
}

- (void)playContent:(NSURL*)url withTitle:(NSString*)title withSubtitle:(NSString*)subtitle withThumbnail:(NSURL*)thumbnailURL withContentType:(NSString*)mimeType withDuration:(long)duration withStartime:(long)startTime{
    BOOL autoPlay = TRUE;
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
    [metadata setString:title forKey:kGCKMetadataKeyTitle];
    [metadata setString:subtitle forKey:kGCKMetadataKeySubtitle];
    if(thumbnailURL)[metadata addImage:[[GCKImage alloc] initWithURL:thumbnailURL width:200 height:100]];
    GCKMediaInformation *mediaInformation =
    [[GCKMediaInformation alloc] initWithContentID:[url absoluteString]
                                        streamType:GCKMediaStreamTypeLive
                                       contentType:mimeType
                                          metadata:metadata
                                    streamDuration:duration
                                        customData:nil];
    
    self.progress = startTime;
    [self.progressTimer invalidate];
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(progressCheck) userInfo:nil repeats:YES];
    finishProgressionSynched = FALSE;
    [self.mediaControlChannel loadMedia:mediaInformation autoplay:autoPlay playPosition:startTime];
}

- (void)playShow:(NLTShow*)show withProgress:(float)progress{
    [[NLTAPI sharedInstance] videoUrlForShow:show withResultBlock:^(id result, NSError *error) {
        if(result){
            NSString* file = [result objectForKey:@"file"];
            NSURL* url = nil;
            if(file){
                url = [NSURL URLWithString:file];
                
            }
            NSURL* thumbnailURL = nil;
            NSString* subtitle = @"";
            NSString* title = @"iNoco";
            long duration = 0;
            if(show.duration_ms){
                duration = show.duration_ms/1000;
            }
            if(show.family_TT){
                title = show.family_TT;
            }
            
            if(show.episode_number && show.episode_number != 0){
                subtitle = [NSString stringWithFormat:@"%i\n",show.episode_number];
            }
            if(show.show_TT) {
                subtitle = [subtitle stringByAppendingString:show.show_TT];
            }
            
            if(show.screenshot_512x288){
                thumbnailURL = [NSURL URLWithString:show.screenshot_512x288];
            }
            self.currentShow = show;
            [self playContent:url withTitle:title withSubtitle:subtitle withThumbnail:thumbnailURL withContentType:@"video/mp4" withDuration:duration withStartime:progress];
            
        }else{
            if(error.code == NLTAPI_ERROR_VIDEO_UNAVAILABLE_WITH_POPMESSAGE && [error.userInfo objectForKey:@"popmessage"]&&[[error.userInfo objectForKey:@"popmessage"] objectForKey:@"message"]){
                [[[UIAlertView alloc] initWithTitle:@"Erreur" message:[[error.userInfo objectForKey:@"popmessage"] objectForKey:@"message"] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }else{
                [[[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de lire la vidéo" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }
        }
    } withKey:self];
}

#pragma mark - GCKDeviceScannerListener
- (void)deviceDidComeOnline:(GCKDevice *)device {
    NSLog(@"%@ device found!!!", device.friendlyName);
}

- (void)deviceDidGoOffline:(GCKDevice *)device {
    NSLog(@"device disappeared!!!");
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

#pragma mark - GCKDeviceManagerDelegate
- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {
    NSLog(@"connected!!");
    
    [self.deviceManager launchApplication:kGCKMediaDefaultReceiverApplicationID];
    //self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(progressCheck) userInfo:nil repeats:YES];
    [self.mediaControlChannel requestStatus];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
didConnectToCastApplication:(GCKApplicationMetadata *)applicationMetadata
            sessionID:(NSString *)sessionID
  launchedApplication:(BOOL)launchedApp {
    
    self.mediaControlChannel = [[GCKMediaControlChannel alloc] init];
    self.mediaControlChannel.delegate = self;
    [self.deviceManager addChannel:self.mediaControlChannel];
}

#pragma mark Progression

- (void)syncProgression{
    if (ABS(1000*self.progress-self.currentShow.duration_ms)<10000) {
        //Was probably finished (less than 10s remaining)
        self.progress = 0;
    }
    if(self.currentShow){
#ifdef DEBUG
        NSLog(@" >> sync progress from cast: %f",self.progress);
#endif
        self.progressAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"Mise à jour de la progression de la lecture..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
        [self.progressAlert show];
        [[NLTAPI sharedInstance] setResumePlay:self.progress*1000 forShow:self.currentShow withResultBlock:^(id result, NSError *error) {
            [self.progressAlert dismissWithClickedButtonIndex:0 animated:YES];
        } withKey:self];
    }
}
#pragma mark - Controls

- (void)resume{
    [self.progressTimer invalidate];
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(progressCheck) userInfo:nil repeats:YES];
    [self.mediaControlChannel play];
}

- (void)pause{
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    [self.mediaControlChannel pause];
}

- (void)stop{
    self.progress = self.mediaControlChannel.mediaStatus.streamPosition;
    [self notifyFinish];
    [self.mediaControlChannel stop];
}

- (void)seekToTimeInterval:(NSTimeInterval)timeInterval{
    [self.mediaControlChannel seekToTimeInterval:timeInterval];
}


#pragma mark - Progress


- (void)progressCheck{
    [self.mediaControlChannel requestStatus];
    [self notifyProgress];
}

- (void)notifyFinish{
    finishProgressionSynched = TRUE;
    [self syncProgression];
    [self.progressTimer invalidate];
    self.progressTimer = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ChromecastPlayerFinished" object:nil];
}

- (void)notifyProgress{
#ifdef DEBUG
    //NSLog(@"%li %f",(long)self.mediaControlChannel.mediaStatus.playerState,self.mediaControlChannel.mediaStatus.streamPosition);
#endif
    if(self.mediaControlChannel.mediaStatus.streamPosition != self.progress && self.mediaControlChannel.mediaStatus.playerState == GCKMediaPlayerStatePlaying){
        self.progress = self.mediaControlChannel.mediaStatus.streamPosition;
    }
    [[NSNotificationCenter defaultCenter]postNotificationName:@"ChromecastPlayerProgress" object:nil];
}

#pragma mark - GCKMediaControlChannelDelegate

- (void)mediaControlChannelDidUpdateStatus:(GCKMediaControlChannel *)mediaControlChannel{
#ifdef DEBUG
    /*
    NSLog(@"mediaControlChannelDidUpdateStatus: %@ %li %li %f",
          mediaControlChannel.mediaStatus,
          mediaControlChannel.mediaStatus.playerState,
          mediaControlChannel.mediaStatus.idleReason,
          mediaControlChannel.mediaStatus.streamPosition);
     */
#endif
    if(!finishProgressionSynched&&mediaControlChannel.mediaStatus.playerState == GCKMediaPlayerStateIdle&&mediaControlChannel.mediaStatus.idleReason == GCKMediaPlayerIdleReasonFinished){
        //Reading is finished
        self.progress = 0;
        [self notifyFinish];
    }
    [self notifyProgress];
    if(!self.progressTimer && mediaControlChannel.mediaStatus.playerState == GCKMediaPlayerStatePlaying){
        //Playing from another session: we start observing status
        self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(progressCheck) userInfo:nil repeats:YES];
    }
}


@end
