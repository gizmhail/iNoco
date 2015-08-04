
//
//  ShowViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 23/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "ShowViewController.h"
#import "NLTOAuth.h"
#import "NLTAPI.h"
#import "UIImageView+WebCache.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "UIView+Toast.h"
#import <AVFoundation/AVFoundation.h>
#import "FavoriteProgramManager.h"
#import "RecentShowViewController.h"
#import "NocoDownloadsManager.h"
#import "ShowCollectionViewCell.h"
#import "ChromecastManager.h"
#import "AppDelegate.h"

@interface ShowViewController (){
    int unreadCalls;
    float progress;
}
@property (retain, nonatomic) NSMutableArray* chapters;
@property (retain, nonatomic) UIView* tooltipView;
@property (retain, nonatomic) UIAlertView* downloadAlert;
@property (retain, nonatomic) UIAlertView* readAlert;
@property (retain, nonatomic) UIAlertView* statusAlert;
@property (retain, nonatomic) UIActionSheet* readSheet;
@property (retain, nonatomic) UIActionSheet* statusSheet;
@property (retain, nonatomic) UIActionSheet* castSheet;
@property (retain, nonatomic) UIActionSheet* playlistSheet;
@property (retain, nonatomic) UIProgressView* downloadProgress;
@property (retain, nonatomic) UIButton* downloadTextButton;
@property (retain, nonatomic) UIButton* downloadImageButton;
@property (retain, nonatomic) UIView* actionsView;
@property (retain, nonatomic) UIView* downloadView;
@property (retain, nonatomic) NSError* readError;
@property (retain, nonatomic) NSDate* playStart;
@property (retain, nonatomic) NSTimer* playStartTimer;
@property (assign, nonatomic) float imageContainerSize;
@property (assign, nonatomic) float imageContainerOrigin;
@end

//TODO MOve this static strings in localisation file
static NSString * const allReadMessage = @"l'émission et ses chapitres";
static NSString * const removeFromWatchlist = @"retirer de la liste de lecture";
static NSString * const playListOlderToNewer = @"de la + ancienne à la + récente";
static NSString * const playListNewerToOlder  = @"de la + récente à la + ancienne";


@implementation ShowViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    //UI customization
    [self.infoBackground.layer setCornerRadius:10.0f];
    [self.durationBackground.layer setCornerRadius:5.0f];
    [self.downloadedVersionBackground.layer setCornerRadius:5.0f];
    [self.readImageButton.layer setCornerRadius:2.0f];
    [self.watchListButton.layer setCornerRadius:2.0f];
    [self.watchListBackground.layer setCornerRadius:5.0f];
    [self.readBackground.layer setCornerRadius:5.0f];
    
    
    self.csaImageView.image = nil;
    if([self.show.rating_fr intValue] == 10){
        self.csaImageView.image = [UIImage imageNamed:@"csa_10_black.png"];
    }
    if([self.show.rating_fr intValue] == 12){
        self.csaImageView.image = [UIImage imageNamed:@"csa_12_black.png"];
    }
    if([self.show.rating_fr intValue] == 16){
        self.csaImageView.image = [UIImage imageNamed:@"csa_16_black.png"];
    }
    if([self.show.rating_fr intValue] == 18){
        self.csaImageView.image = [UIImage imageNamed:@"csa_18_black.png"];
    }

    UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(familyTap)];
    self.famillyLabel.userInteractionEnabled = TRUE;
    [self.famillyLabel addGestureRecognizer:tapRecognizer];
    
    self.famillyLabel.text = @"";
    self.episodeLabel.text = @"";
    self.subtitleLabel.text = @"";
    self.descriptionText.text = @"";
    self.timeLabel.text = @"";
    self.favoriteFamilly.selected = FALSE;
    self.imageView.image = [UIImage imageNamed:@"noco.png"];
    
    
    self.partnerImageView.image = nil;
    [[NLTAPI sharedInstance] partnersWithResultBlock:^(id result, NSError *error) {
        if([[NLTAPI sharedInstance].partnersByKey objectForKey:self.show.partner_key]){
            NSDictionary* partnerInfo = [[NLTAPI sharedInstance].partnersByKey objectForKey:self.show.partner_key];
            if([partnerInfo objectForKey:@"icon_128x72"]){
                [self.partnerImageView sd_setImageWithURL:[NSURL URLWithString:[partnerInfo objectForKey:@"icon_128x72"]] placeholderImage:nil];
            }
        }
        [self.collectionView reloadData];
    } withKey:self];

    
#ifdef DEBUG
    /*
    if(self.contextPlaylist){
        UIView* titleView = [[UIView alloc] initWithFrame:CGRectMake(10, 5, 100, 30)];
        UIButton* playlistButton = [UIButton buttonWithType:UIButtonTypeCustom];
        playlistButton.frame = CGRectMake(0, 0, 100, 30);
        [playlistButton.titleLabel setFont:[UIFont systemFontOfSize:10] ];
        [playlistButton setTitle:@"Lancer la playlist" forState:UIControlStateNormal];
        [playlistButton addTarget:self action:@selector(launchPlaylist) forControlEvents:UIControlEventTouchUpInside];
        [playlistButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        [titleView addSubview:playlistButton];
        self.navigationItem.titleView = titleView;
    }
     */
#endif
    
    self.actionsView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 40)];
    self.downloadView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 40)];
    [self.actionsView addSubview:self.downloadView];
    self.castButton = [CastIconButton buttonWithFrame:CGRectMake(186, 5, 29, 22)];
    [self.castButton addTarget:self action:@selector(castClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.actionsView addSubview:self.castButton];

    //self.actionsView.backgroundColor = [UIColor blueColor];
    //self.downloadView.backgroundColor = [UIColor redColor];

    if(ALLOW_DOWNLOADS){
        self.downloadTextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.downloadTextButton.frame = CGRectMake(0, 0, 150, 30);
        self.downloadTextButton.titleLabel.font = [UIFont systemFontOfSize:10];
        [self.downloadTextButton setTitle:@"télécharger" forState:UIControlStateNormal];
        [self.downloadTextButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        [self.downloadTextButton addTarget:self action:@selector(downloadClick) forControlEvents:UIControlEventTouchUpInside];
        [self.downloadTextButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentRight];
        [self.downloadView addSubview:self.downloadTextButton];
        self.downloadImageButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.downloadImageButton.isAccessibilityElement = false;
        self.downloadImageButton.frame = CGRectMake(self.downloadView.frame.size.width - 20, 5, 20, 20);
        self.downloadImageButton.contentMode = UIViewContentModeScaleAspectFit;
        [self.downloadImageButton setImage:[UIImage imageNamed:@"download.png"] forState:UIControlStateNormal];
        [self.downloadImageButton addTarget:self action:@selector(downloadClick) forControlEvents:UIControlEventTouchUpInside];
        [self.downloadView addSubview:self.downloadImageButton];
        float progressWidth = 155;
        self.downloadProgress = [[UIProgressView alloc] initWithFrame:CGRectMake(self.downloadView.frame.size.width - progressWidth, self.downloadView.frame.size.height - 12, progressWidth, 5)];
        self.downloadProgress.progress = 0;
        self.downloadProgress.hidden = TRUE;
        [self.downloadView addSubview:self.downloadProgress];
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.actionsView];
    [self updateCastContainer];

    self.durationLabel.text = [self.show durationString];
    
    if(self.show.family_TT){
        self.famillyLabel.text = self.show.family_TT;
    }
    if(self.show.episode_number && self.show.episode_number != 0){
        self.subtitleLabel.text = [NSString stringWithFormat:@"%i\n",self.show.episode_number];
    }
    if(self.show.show_TT) {
        self.subtitleLabel.text = [self.subtitleLabel.text stringByAppendingString:self.show.show_TT];
    }
    if(self.show.broadcastDate) {
        NSDateFormatter *formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"dd MMM YYY - HH:mm"];
        self.timeLabel.text = [formater stringFromDate:self.show.broadcastDate];
    }
    if(self.show.screenshot_512x288){
        //TODO Find alternative screenshot when not available
        [self.imageView sd_setImageWithURL:[NSURL URLWithString:self.show.screenshot_512x288] placeholderImage:[UIImage imageNamed:@"noco.png"]];
    }
    if(self.show.show_resume) {
        self.descriptionText.text = self.show.show_resume;
    }else if(self.show.family_resume) {
        self.descriptionText.text = self.show.family_resume;
    }else{
        [[NLTAPI sharedInstance] familyWithFamilyKey:self.show.family_key withPartnerKey:self.show.partner_key withResultBlock:^(NLTFamily* family, NSError *error) {
            if(family && family.theme_name){
                self.descriptionText.text = family.theme_name;
            }
        } withKey:self];

    }
    self.readButton.selected = self.show.mark_read;
    self.readImageButton.selected = self.show.mark_read;
    [self updateInterctiveUI];
    self.watchListZone.hidden = TRUE;
    __weak ShowViewController* weakSelf = self;
    [[NLTAPI sharedInstance] isInQueueList:self.show withResultBlock:^(NSNumber* result, NSError *error) {
        if(!error){
            weakSelf.watchListZone.hidden = FALSE;
            weakSelf.watchListButton.selected = [result boolValue];
            weakSelf.watchListTextButton.selected = [result boolValue];
            [weakSelf updateInterctiveUI];
        }
    } withKey:self];
    
    progress = 0;
    [[NLTAPI sharedInstance] getResumePlayForShow:self.show withResultBlock:^(NSNumber* progressNumber, NSError *error) {
        if(progressNumber){
            progress = ((float)[progressNumber integerValue])/1000.0;
        }
    } withKey:self];

    //Chapters
    self.chapterLabel.hidden = TRUE;
    self.collectionView.hidden = TRUE;
    NSString* urlStr = [NSString stringWithFormat:@"chapters/id_show/%i",self.show.id_show];
    [self.chapterActivity startAnimating];
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
        [self.chapterActivity stopAnimating];
        if(result&&[result isKindOfClass:[NSArray class]]){
            self.chapters = [NSMutableArray array];
            for (NSDictionary* chapter in result) {
                if([chapter objectForKey:@"id_show_sub"]!=[NSNull null]&&[[chapter objectForKey:@"stand_alone"] intValue]==1){
                    [self.chapters addObject:chapter];
                }
            }
            if([self.chapters count]>0){
                self.chapterLabel.hidden = FALSE;
                self.collectionView.hidden = FALSE;
                [self.collectionView reloadData];
            }
        }
    } withKey:self];
    
    //Favorite
    self.favoriteFamilly.selected = [[FavoriteProgramManager sharedInstance] isFavoriteForFamilyKey:self.show.family_key withPartnerKey:self.show.partner_key];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationNocoDownloadsNotificationFinishDownloading:) name:@"NocoDownloadsNotificationFinishDownloading" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationNocoDownloadsNotificationProgress:) name:@"NocoDownloadsNotificationProgress" object:nil];
    
    //Tooltip animation
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    BOOL contextPlaylistTooltip = true;
    if([settings objectForKey:@"contextPlaylistTooltip"]){
        contextPlaylistTooltip = [settings boolForKey:@"contextPlaylistTooltip"];
    }
    if(self.contextPlaylist && contextPlaylistTooltip){
        float tooltipX = 5;
        float tooltipY = 43;
        float tooltipWidth = 120;
        float tooltipHeight = 95;
        NSString* type = @"émissions";
        if(self.playlistType){
            type = self.playlistType;
        }
        if(UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone){
            tooltipX = 105;
            tooltipY = 103;
        }
        
        self.tooltipView = [[UIView alloc] initWithFrame:CGRectMake(tooltipX, tooltipY, tooltipWidth, tooltipHeight)];
        UITextView* tooltipText = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, tooltipWidth, tooltipHeight)];
        tooltipText.text = [NSString stringWithFormat:@"Restez appuyé sur le bouton lecture pour lire les autre %@ après celle-ci",type];
        tooltipText.backgroundColor = [UIColor clearColor];
        tooltipText.textColor = [UIColor whiteColor];
        self.tooltipView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        self.tooltipView.alpha = 0;
        tooltipText.textAlignment = NSTextAlignmentCenter;
        [self.tooltipView.layer setCornerRadius:5.0f];
        [self.tooltipView addSubview:tooltipText];
        [self.imageView.superview addSubview:self.tooltipView];

        __weak ShowViewController* weakSelf = self;
        
        [UIView animateWithDuration:0.5 animations:^{
            weakSelf.tooltipView.alpha = 1;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:5 animations:^{
                weakSelf.tooltipView.frame = CGRectOffset(weakSelf.tooltipView.frame, 0, 6);
                weakSelf.tooltipView.alpha = 0.8;
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.5 animations:^{
                    weakSelf.tooltipView.alpha = 0;
                } completion:^(BOOL finished) {
                    
                }];
                
            }];
        }];
    }
    
    //Chromecast
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];

    if([chromecastManager.deviceScanner.devices count]>0){
        self.castButton.hidden = FALSE;
        [self.castButton setStatus:CIBCastAvailable];
        [self updateCastContainer];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCastPlayerView) name:@"ChromecastPlayerProgress" object:nil];

}

- (void)notificationNocoDownloadsNotificationFinishDownloading:(NSNotification*)notification{
    if([notification.object intValue] == self.show.id_show){
        [self updateInterctiveUI];
    }
}

- (void)notificationNocoDownloadsNotificationProgress:(NSNotification*)notification{
    if([notification.object intValue] == self.show.id_show){
        self.downloadProgress.progress = [[notification.userInfo objectForKey:@"progress"] floatValue];
        [self updateInterctiveUI];
    }
}


- (void)familyTap{
    [[NLTAPI sharedInstance] familyWithFamilyKey:self.show.family_key withPartnerKey:self.show.partner_key withResultBlock:^(NLTFamily* family, NSError *error) {
        if(family){
            [self performSegueWithIdentifier:@"DisplayFamily" sender:family];
        }
    } withKey:self];

}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
   if([[segue destinationViewController] isKindOfClass:[RecentShowViewController class]]&&[sender isKindOfClass:[NLTFamily class]]){
        [(RecentShowViewController*)[segue destinationViewController] setFamily:(NLTFamily*)sender];
    }
}
-(void)viewWillAppear:(BOOL)animated{
    self.navigationController.navigationBarHidden = FALSE;
    [(AppDelegate*)[[UIApplication sharedApplication] delegate] setRemoteControlDelegate:self];
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Cast

- (void)updateCastContainer{
    float currentWidth = self.actionsView.frame.size.width;
    float targetWidth = currentWidth;
    if(self.castButton.status == CIBCastUnavailable){
        targetWidth = 180.;
    }else{
        targetWidth = 215.;
    }
    if(currentWidth != targetWidth){
        self.actionsView.frame = CGRectMake(0, 0, targetWidth, 40);
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.actionsView];
    }
    [self updateCastPlayerView];
}

- (IBAction)castClick:(id)sender {
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];
    NSString* currentDevice = @"iPhone";
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ){
        currentDevice = @"iPad";
    }
    if(!chromecastManager.deviceManager.device){
        currentDevice = [@"√ " stringByAppendingString:currentDevice];
    }
    self.castSheet = [[UIActionSheet alloc] initWithTitle:@"Ecran de lecture" delegate:self cancelButtonTitle:@"annuler" destructiveButtonTitle:nil otherButtonTitles:currentDevice, nil];
    
    for (GCKDevice* device in chromecastManager.deviceScanner.devices) {
        NSString* name = device.friendlyName;
        if(chromecastManager.deviceManager.device && [chromecastManager.deviceManager.device.friendlyName compare:device.friendlyName]==NSOrderedSame){
            name = [@"√ " stringByAppendingString:name];
        }
        [self.castSheet addButtonWithTitle:name];
    }
    [self.castSheet showFromTabBar:self.navigationController.tabBarController.tabBar];
    [self.castButton setStatus:CIBCastConnecting];
    [self updateCastContainer];
}

- (void)castDeviceSelected:(NSString*)deviceName{
    deviceName = [deviceName stringByReplacingOccurrencesOfString:@"√ " withString:@""];
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];

    BOOL deviceFound = FALSE;
    for (GCKDevice* device in chromecastManager.deviceScanner.devices) {
        if([device.friendlyName compare:deviceName]==NSOrderedSame){
            [chromecastManager selectDevice:device];
            deviceFound = TRUE;
        }
    }
    
    if(!deviceFound){
        [chromecastManager.deviceManager disconnect];
        chromecastManager.deviceManager = nil;
        [self.castButton setStatus:CIBCastAvailable];
        [self updateCastContainer];
    }else{
        [self.castButton setStatus:CIBCastConnected];
        [self.castButton setTintColor:self.view.window.tintColor];
        [self updateCastContainer];
    }
}

- (void) updateCastPlayerView{
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];
    self.castPlayerView.hidden = chromecastManager.deviceManager.device == nil;
    self.tooltipView.hidden = !self.castPlayerView.hidden || self.tooltipView.alpha == 0;
    GCKMediaPlayerState playerState = chromecastManager.mediaControlChannel.mediaStatus.playerState;
    if(playerState == GCKMediaPlayerStatePlaying){
        self.castPlayerPauseButton.selected = TRUE;
    }else{
        self.castPlayerPauseButton.selected = FALSE;
    }
    self.castTotalLabel.text = [self.show durationString];
    NSTimeInterval position = chromecastManager.mediaControlChannel.mediaStatus.streamPosition;
    self.castProgressLabel.text = [NLTShow durationString:(int)(position*1000)];
    self.castProgressView.progress = position*1000./(float)self.show.duration_ms;
}

- (IBAction)castBackward{
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];
    [chromecastManager seekToTimeInterval:chromecastManager.mediaControlChannel.mediaStatus.streamPosition - 30.];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateCastContainer];
    });
}

- (IBAction)castForward{
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];
    [chromecastManager seekToTimeInterval:chromecastManager.mediaControlChannel.mediaStatus.streamPosition + 30.];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateCastContainer];
    });
}

- (IBAction)castPause{
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];
    GCKMediaPlayerState playerState = chromecastManager.mediaControlChannel.mediaStatus.playerState;
    if(playerState == GCKMediaPlayerStatePaused){
        [chromecastManager resume];
    }else if(playerState == GCKMediaPlayerStatePlaying){
        [chromecastManager pause];
    }else if(!chromecastManager.mediaControlChannel.mediaStatus || playerState == GCKMediaPlayerStateIdle || playerState == GCKMediaPlayerStateUnknown){
        [chromecastManager playShow:self.show withProgress:progress];
    }
#warning Add progress save (regularly ?)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateCastContainer];
    });
}

- (IBAction)castStop{
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];
    [chromecastManager stop];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateCastContainer];
    });
}

#pragma mark Playlist

- (void)launchPlaylist{
    if(self.contextPlaylist){
        NSString* title = @"l'émission";
        NSString* type = @"émissions";
        if(self.playlistType){
            type = self.playlistType;
        }
        if(self.show.family_TT){
            title = self.show.family_TT;
            self.accessibilityLabel = self.show.family_TT;
            if(self.show.episode_number && self.show.episode_number != 0){
                if(self.show.season_number > 1){
                    title = [title stringByAppendingFormat:@" - S%02iE%02i", self.show.season_number,self.show.episode_number];
                    self.accessibilityLabel = [self.accessibilityLabel stringByAppendingFormat:@" , saison %i, épisode %i", self.show.season_number,self.show.episode_number];
                }else{
                    title = [title stringByAppendingFormat:@" - %i", self.show.episode_number];
                    self.accessibilityLabel = [self.accessibilityLabel stringByAppendingFormat:@" , épisode %i",self.show.episode_number];
                }
            }
        }
        self.playlistSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"Lire \"%@\" puis les autres %@",title,type] delegate:self cancelButtonTitle:@"annuler" destructiveButtonTitle:nil otherButtonTitles:playListOlderToNewer,playListNewerToOlder, nil];
        [self.playlistSheet showFromTabBar:self.tabBarController.tabBar];
    }
}


#pragma mark - Player

#pragma mark ShowPlayerManagerDelegate
- (void)progressChanged:(float)p{
    progress = p;
}

- (void)moviePlayerDidExitFullscreen{
    self.readAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"Récupération de l'état lu/non lu..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
    [self.readAlert show];
    __weak ShowViewController* weakSelf = self;
    [[NLTAPI sharedInstance] showWithId:self.show.id_show withResultBlock:^(NLTShow* result, NSError *error) {
        [weakSelf.readAlert dismissWithClickedButtonIndex:0 animated:YES];
        weakSelf.readAlert = nil;
        BOOL markRead = result.mark_read;
        if(markRead){
            //It has been properly mark as read by the backend
            weakSelf.readButton.selected = TRUE;
            weakSelf.readImageButton.selected = TRUE;
            [weakSelf updateInterctiveUI];
            if(weakSelf.chapters&&[weakSelf.chapters count]>0){
                weakSelf.readSheet = [[UIActionSheet alloc] initWithTitle:@"Marquer comme lu" delegate:weakSelf cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:allReadMessage,@"l'émission seule", nil];
                [weakSelf.readSheet showFromTabBar:weakSelf.navigationController.tabBarController.tabBar];
            }else{
                [self proposeToRemoveFromWatchList];
            }
        }else{
            //Not mark as read by the backend (do not track, or problem): we'll handle it manually
            if(!weakSelf.readButton.selected){
                if(weakSelf.chapters&&[weakSelf.chapters count]>0){
                    weakSelf.readSheet = [[UIActionSheet alloc] initWithTitle:@"Marquer comme lu" delegate:weakSelf cancelButtonTitle:@"Ne pas marquer comme lu" destructiveButtonTitle:nil otherButtonTitles:allReadMessage, @"l'émission seule", nil];
                    [weakSelf.readSheet showFromTabBar:weakSelf.navigationController.tabBarController.tabBar];
                }else{
                    weakSelf.readSheet = [[UIActionSheet alloc] initWithTitle:@"Marquer comme lu" delegate:weakSelf cancelButtonTitle:@"Ne pas marquer comme lu" destructiveButtonTitle:nil otherButtonTitles:@"marquer l'émission comme lu", nil];
                    [weakSelf.readSheet showFromTabBar:weakSelf.navigationController.tabBarController.tabBar];
                }
            }else{
                [self proposeToRemoveFromWatchList];
            }
        }
    } withKey:self noCache:YES];
}

- (void)startedLookingForMovieUrl{
    [self.videoActivity startAnimating];
    
}
- (void)endedLookingForMovieUrl{
    [self.videoActivity stopAnimating];
}

- (CGRect)moviePlayerFrame{
    return self.imageView.frame;
}

- (UIView*)moviePlayerSuperview{
    return self.imageView.superview;
}

- (void)moviePlayerPlacedInView{
    [self.videoActivity.superview bringSubviewToFront:self.videoActivity];
}

- (void)tooglePlay{
    [[ShowPlayerManager sharedInstance] tooglePlay];
}

- (IBAction)cancelPlayStart:(id)sender {
    [self.playStartTimer invalidate];
}

- (IBAction)playStart:(id)sender {
    self.playStart = [NSDate date];
    self.playStartTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(longPlay) userInfo:nil repeats:NO];
}

- (void)longPlay{
    [self launchPlaylist];

}
- (IBAction)play:(id)sender {
    [self.playStartTimer invalidate];
    if(self.playStart && [[NSDate date] timeIntervalSinceDate:self.playStart] > 1 && self.contextPlaylist){
#warning Handle playlist with chromecast
#warning Handle playlist with chromecast
#warning Handle playlist with chromecast
#warning Handle playlist with chromecast
#warning Fix playlist with both orders
        [self longPlay];
        return;
    }
    self.playStart = nil;
    
    ChromecastManager* chromecastManager = [(AppDelegate*)[[UIApplication sharedApplication] delegate] chromecastManager];
    if(chromecastManager.deviceManager.device){
        [chromecastManager playShow:self.show withProgress:progress];
        return;
    }
    
    [[ShowPlayerManager sharedInstance] setDelegate:self];
    [[ShowPlayerManager sharedInstance] play:self.show withProgress:progress withImage:self.imageView.image];
    //We update the UI in case of download error : we need to refresh the download button
    [self updateInterctiveUI];
}

#pragma mark Update UI

- (void)updateInterctiveUI{
    if(self.readImageButton.selected){
        self.readImageButton.backgroundColor = SELECTED_VALID_COLOR;
    }else{
        self.readImageButton.backgroundColor = THEME_COLOR;
    }
    if(self.watchListButton.selected){
        self.watchListButton.backgroundColor = SELECTED_VALID_COLOR;
    }else{
        self.watchListButton.backgroundColor = THEME_COLOR;
    }
    [self.collectionView reloadData];
    
    //Download zone
    self.downloadedVersionLabel.hidden = TRUE;
    self.downloadedVersionBackground.hidden = TRUE;
    if([[NocoDownloadsManager sharedInstance] isDownloaded:self.show]){
        [self.downloadTextButton setTitle:@"téléchargé" forState:UIControlStateNormal];
        [self.downloadImageButton setImage:[UIImage imageNamed:@"ok.png"] forState:UIControlStateNormal];
        self.downloadImageButton.frame = CGRectMake(self.downloadView.frame.size.width - 20, 5, 15, 20);
        self.downloadProgress.hidden = TRUE;
        if([[NocoDownloadsManager sharedInstance] downloadFilePathForShow:self.show]){
            self.downloadedVersionLabel.hidden = FALSE;
            self.downloadedVersionBackground.hidden = FALSE;
        }
#warning TODO
    }else{
            if([[NocoDownloadsManager sharedInstance] isDownloadPending:self.show]){
                [self.downloadTextButton setTitle:@"téléchargement en cours..." forState:UIControlStateNormal];
                [self.downloadImageButton setImage:[UIImage imageNamed:@"downloadPending.png"] forState:UIControlStateNormal];
                self.downloadImageButton.frame = CGRectMake(self.downloadView.frame.size.width - 20, 5, 16, 20);
                self.downloadProgress.hidden = FALSE;
#warning TODO
            }else{
                [self.downloadTextButton setTitle:@"télécharger" forState:UIControlStateNormal];
                [self.downloadImageButton setImage:[UIImage imageNamed:@"download.png"] forState:UIControlStateNormal];
                self.downloadImageButton.frame = CGRectMake(self.downloadView.frame.size.width - 20, 5, 20, 20);
                self.downloadProgress.hidden = TRUE;
            }
    }
}

#pragma mark Interactions

- (void)downloadClick{
    if([[NocoDownloadsManager sharedInstance] isDownloaded:self.show]){
        self.downloadAlert = [[UIAlertView alloc] initWithTitle:@"Mode hors ligne" message:@"Effacer la vidéo téléchargée ?" delegate:self cancelButtonTitle:@"Non" otherButtonTitles:@"Oui", nil];
        [self.downloadAlert show];
    }else{
        if([[NocoDownloadsManager sharedInstance] isDownloadPending:self.show]){
            self.downloadAlert = [[UIAlertView alloc] initWithTitle:@"Mode hors ligne" message:@"Annuler le téléchargement en cours ?" delegate:self cancelButtonTitle:@"Non" otherButtonTitles:@"Oui", nil];
            [self.downloadAlert show];

        }else{
            self.downloadAlert = [[UIAlertView alloc] initWithTitle:@"Mode hors ligne" message:@"Lancer le téléchargement de cette vidéo ?" delegate:self cancelButtonTitle:@"Non" otherButtonTitles:@"Oui", nil];
            [self.downloadAlert show];
        }
    }
}

- (IBAction)favoriteFamillyClick:(id)sender {
    self.favoriteFamilly.selected = !self.favoriteFamilly.selected;
    [[FavoriteProgramManager sharedInstance] setFavorite:self.favoriteFamilly.selected forFamilyKey:self.show.family_key withPartnerKey:self.show.partner_key];
    if(self.favoriteFamilly.selected){
        [self.tabBarController.view makeToast:[NSString stringWithFormat:@"Programme %@ ajouté aux favoris", self.show.family_TT] duration:2 position:@"bottom"];
    }else{
        [self.tabBarController.view makeToast:[NSString stringWithFormat:@"Programme %@ retiré des favoris", self.show.family_TT] duration:2 position:@"bottom"];
    }
    [self updateInterctiveUI];
}

- (IBAction)toggleRead:(id)sender {
    if(!self.readButton.selected){
        if(self.chapters&&[self.chapters count]>0){
            self.readSheet = [[UIActionSheet alloc] initWithTitle:@"Marquer comme lu" delegate:self cancelButtonTitle:@"Ne pas marquer comme lu" destructiveButtonTitle:nil otherButtonTitles:allReadMessage, @"l'émission seule", nil];
            [self.readSheet showFromTabBar:self.navigationController.tabBarController.tabBar];
        }else{
            [self markRead:self.show];
        }
    }else{
        [self markUnread:self.show];
    }

}

- (IBAction)watchListClick:(id)sender {
    __weak ShowViewController* weakSelf = self;
    if(!self.watchListButton.selected){
        if(!self.statusAlert){
            self.statusAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"L'émision est en train d'être ajoutée à la liste de lecture..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
            [self.statusAlert show];
        }
        [[NLTAPI sharedInstance] addToQueueList:self.show withResultBlock:^(id result, NSError *error) {
            [weakSelf.statusAlert dismissWithClickedButtonIndex:0 animated:YES];
            weakSelf.statusAlert = nil;
            if(error){
                [weakSelf.tabBarController.view makeToast:[NSString stringWithFormat:@"Impossible de rajouter l'émission à la liste de lecture"] duration:2 position:@"bottom"];
            }else{
                weakSelf.watchListButton.selected = TRUE;
                weakSelf.watchListTextButton.selected = TRUE;
                [weakSelf updateInterctiveUI];
            }
        } withKey:self];
    }else{
        self.statusAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"L'émision est en train d'être retirée de la liste de lecture..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
        [self.statusAlert show];
        [[NLTAPI sharedInstance] removeFromQueueList:self.show withResultBlock:^(id result, NSError *error) {
            [weakSelf.statusAlert dismissWithClickedButtonIndex:0 animated:YES];
            weakSelf.statusAlert = nil;
            if(error){
                [weakSelf.tabBarController.view makeToast:[NSString stringWithFormat:@"Impossible d'enlever l'émission de la liste de lecture"] duration:2 position:@"bottom"];
            }else{
                weakSelf.watchListButton.selected = FALSE;
                weakSelf.watchListTextButton.selected = FALSE;
                [weakSelf updateInterctiveUI];
            }
        } withKey:self];
    }
}

-(void)dealloc{
    [self.playStartTimer invalidate];
    [[ShowPlayerManager sharedInstance] setDelegate:nil];
    [[NLTAPI sharedInstance] cancelCallsWithKey:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [(AppDelegate*)[[UIApplication sharedApplication] delegate] setRemoteControlDelegate:nil];
}

#pragma mark - Status messages

#pragma mark Alert view delegate

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(buttonIndex != alertView.cancelButtonIndex){
        if(alertView == self.downloadAlert){
            if([[NocoDownloadsManager sharedInstance] isDownloaded:self.show]){
                [[NocoDownloadsManager sharedInstance] eraseDownloadForShow:self.show];
                [self updateInterctiveUI];
            }else{
                if([[NocoDownloadsManager sharedInstance] isDownloadPending:self.show]){
                    [[NocoDownloadsManager sharedInstance] cancelDownloadForShow:self.show];
                    [self updateInterctiveUI];
                }else{
                    [[NocoDownloadsManager sharedInstance] planDownloadForShow:self.show withQuality:@"LQ"];
                    [self updateInterctiveUI];
                }
            }
        }
    }
}

#pragma mark Action sheet delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(actionSheet == self.castSheet){
        if(actionSheet.cancelButtonIndex != buttonIndex){
            [self castDeviceSelected:[actionSheet buttonTitleAtIndex:buttonIndex]];
        }else{
            [self.castButton setStatus:CIBCastAvailable];
        }
    }
    if(actionSheet == self.readSheet){
        if(actionSheet.cancelButtonIndex != buttonIndex){
            [self markRead:self.show];
            if([[actionSheet buttonTitleAtIndex:buttonIndex] compare:allReadMessage]==NSOrderedSame){
                int i = 0;
                while(i<[self.chapters count]){
                    
                    NSDictionary* chapter = [self.chapters objectAtIndex:i];
                    NSNumber* idNumber =  [chapter objectForKey:@"id_show_sub"];
                    if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
                        NLTShow* chapterShow = [[NLTAPI sharedInstance].showsById objectForKey:idNumber];
                        [self markRead:chapterShow];
                    }else{
                        __weak ShowViewController* weakSelf = self;
                        [[NLTAPI sharedInstance] showWithId:[idNumber integerValue] withResultBlock:^(NLTShow* chapterShow, NSError *error) {
                            if(chapterShow){
                                [weakSelf markRead:chapterShow];
                            }
                        } withKey:self];
                    }
                    i++;
                }
            }
        }
    }
    
    if(actionSheet == self.statusSheet){
        if(actionSheet.cancelButtonIndex != buttonIndex){
            [self watchListClick:nil];
        }
    }
    
    if(actionSheet == self.playlistSheet){
        if(actionSheet.cancelButtonIndex != buttonIndex){
            bool fromShow = false;
            if([[actionSheet buttonTitleAtIndex:buttonIndex] compare:playListOlderToNewer]==NSOrderedSame){
                fromShow = true;
            }
            if(self.contextPlaylist){
                [[ShowPlayerManager sharedInstance] setDelegate:self];
                NSMutableArray* playlist = self.contextPlaylist;
                if(fromShow){
                    playlist = [NSMutableArray arrayWithCapacity:[self.contextPlaylist count]];
                    NSEnumerator*   reverseEnumerator = [self.contextPlaylist reverseObjectEnumerator];
                    for (id playlistItem in reverseEnumerator){
                        [playlist addObject:playlistItem];
                    }
                }
                [[ShowPlayerManager sharedInstance] play:self.show withProgress:progress withImage:self.imageView.image withPlaylist:playlist withCurrentPlaylistItem:self.contextPlaylistCurrentItem];
            }
        }
    
    }
}

#pragma mark Watchlist


- (void)proposeToRemoveFromWatchList{
    if(self.watchListButton.selected){
        //Propose to remove from watchlist, as it is read
        self.statusSheet = [[UIActionSheet alloc] initWithTitle:@"Liste de lecture" delegate:self cancelButtonTitle:@"Ne pas retirer" destructiveButtonTitle:nil otherButtonTitles:removeFromWatchlist, nil];
        [self.statusSheet showFromTabBar:self.navigationController.tabBarController.tabBar];
    }
    
}

#pragma mark  Read status

- (void)markUnread:(NLTShow*)show{
    if(!self.readAlert){
        self.readAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"L'émision est en train d'être marquée comme non lue..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
        [self.readAlert show];
    }
    __weak ShowViewController* weakSelf = self;
    
    [[NLTAPI sharedInstance] setReadStatus:false forShow:show withResultBlock:^(id result, NSError *error) {
        [weakSelf.readAlert dismissWithClickedButtonIndex:0 animated:YES];
        weakSelf.readAlert = nil;
        weakSelf.readError = nil;
        if(error){
            [weakSelf.tabBarController.view makeToast:[NSString stringWithFormat:@"Impossible de marquer comme non lu"] duration:3 position:@"bottom"];
        }else{
            if(show==self.show){
                weakSelf.readButton.selected = false;
                weakSelf.readImageButton.selected = false;
            }
            [weakSelf updateInterctiveUI];
        }
    } withKey:self];
}

- (void)markRead:(NLTShow*)show{
    unreadCalls++;
    if(!self.readAlert){
        self.readAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"L'émision est en train d'être marquée comme lue..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
        [self.readAlert show];
    }
    __weak ShowViewController* weakSelf = self;
    
    [[NLTAPI sharedInstance] setReadStatus:true forShow:show withResultBlock:^(id result, NSError *error) {
        unreadCalls--;
        if(error){
            weakSelf.readError = error;
        }else{
            if(show==self.show){
                weakSelf.readButton.selected = true;
                weakSelf.readImageButton.selected = true;
            }
        }
        if(unreadCalls == 0){
            [weakSelf.readAlert dismissWithClickedButtonIndex:0 animated:YES];
            if(weakSelf.readError){
                [weakSelf.tabBarController.view makeToast:[NSString stringWithFormat:@"Impossible de marquer comme lu"] duration:3 position:@"bottom"];
            }else{
            }
            weakSelf.readAlert = nil;
            weakSelf.readError = nil;
            [weakSelf updateInterctiveUI];
            [weakSelf proposeToRemoveFromWatchList];
        }

    } withKey:self];
}

#pragma mark - Chapters
#pragma mark UICollectionViewDataSource,UICollectionViewDelegate

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if(self.chapters){
        return [self.chapters count];
    }
    return 0;
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    NLTShow* show = [self showAtIndex:indexPath.row];
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ShowsCell" forIndexPath:indexPath];
    if([cell isKindOfClass:[ShowCollectionViewCell class]]){
        [(ShowCollectionViewCell*)cell loadShow:show];
    }else{
        NSLog(@"PB with cell loading");
    }
    return cell;
}

- (NLTShow*)showAtIndex:(long)showIndex{
    NLTShow* show = nil;
    if(self.chapters&&showIndex < [self.chapters count]){
        NSDictionary* chapter = [self.chapters objectAtIndex:showIndex];
        NSNumber* idNumber =  [chapter objectForKey:@"id_show_sub"];
        if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
            show = [[NLTAPI sharedInstance].showsById objectForKey:idNumber];
        }else{
            //We want a bit to be sure the call call is still needed
            __weak ShowViewController* weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:showIndex inSection:0]];
                if([[weakSelf.collectionView visibleCells] containsObject:cell]){
                    [[NLTAPI sharedInstance] showWithId:[idNumber integerValue] withResultBlock:^(id result, NSError *error) {
                        BOOL valid = TRUE;
                        if(error&&error.domain == NSCocoaErrorDomain){
                            //Parsing error
                            valid = FALSE;
                        }
                        if(!error){
                            if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
                                [weakSelf.collectionView reloadData];
                            }else{
                                //Problem with this id: ignoring it
                                valid = FALSE;
                            }
                        }
                        if(!valid){
                            NSDictionary* entryToRemove = nil;
                            for (NSDictionary* chap in weakSelf.chapters) {
                                if([chapter objectForKey:@"id_show_sub"]==[chap objectForKey:@"id_show_sub"]){
                                    entryToRemove = chap;
                                }
                            }
                            [weakSelf.chapters removeObject:entryToRemove];
                            if([weakSelf.chapters count]==0){
                                weakSelf.chapterLabel.hidden = TRUE;
                                weakSelf.collectionView.hidden = TRUE;
                            }
                            [weakSelf.collectionView reloadData];
                        }
                    } withKey:weakSelf];
                }else{
                    //Loading not needed anymore
                    //NSLog(@"Loading not needed");
                }
            });
        }
    }
    return show;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    NLTShow* show = [self showAtIndex:indexPath.row];
    if(show){
        ShowViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"ShowViewController"];
        controller.show = show;
        [self.navigationController pushViewController:controller animated:YES];
    }
}

#pragma mark UIScrollViewDelegate

- (void) scrollViewDidScroll:(UIScrollView *)scrollView{
    if(scrollView == self.collectionView){
        return;
    }
    if (scrollView.contentOffset.y <=0){
        UIView*container = self.imageView.superview;
        if(self.imageContainerSize == 0){
            self.imageContainerSize = container.frame.size.height;
            self.imageContainerOrigin = container.frame.origin.y;
            container.backgroundColor = [UIColor redColor];
        }
        container.frame = CGRectMake(
                                     container.frame.origin.x,
                                     self.imageContainerOrigin + scrollView.contentOffset.y,
                                     container.frame.size.width,
                                     self.imageContainerSize - scrollView.contentOffset.y
        );
    }

}

@end
