
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

@interface ShowViewController (){
    int unreadCalls;
    float progress;
    bool userEndedPlay;
}
@property (retain, nonatomic) MPMoviePlayerController* moviePlayer;
@property (retain, nonatomic) NSMutableArray* chapters;
@property (retain, nonatomic) UIAlertView* downloadAlert;
@property (retain, nonatomic) UIAlertView* readAlert;
@property (retain, nonatomic) UIAlertView* statusAlert;
@property (retain, nonatomic) UIAlertView* progressAlert;
@property (retain, nonatomic) UIActionSheet* readSheet;
@property (retain, nonatomic) UIActionSheet* statusSheet;
@property (retain, nonatomic) UIProgressView* downloadProgress;
@property (retain, nonatomic) UIButton* downloadTextButton;
@property (retain, nonatomic) UIButton* downloadImageButton;
@property (retain, nonatomic) UIView* downloadView;
@property (retain, nonatomic) NSError* readError;
@end

//TODO MOve this static strings in localisation file
static NSString * const allReadMessage = @"l'émission et ses chapitres";
static NSString * const removeFromWatchlist = @"retirer de la liste de lecture";


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
    [self playerNotificationSubscription];
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

    
    
    if(ALLOW_DOWNLOADS){
        self.downloadView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 230, 40)];
        self.downloadTextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.downloadTextButton.frame = CGRectMake(0, 0, 200, 30);
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
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.downloadView];
    }

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
        formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"dd MMM YYY - HH:mm"];
        self.timeLabel.text = [formater stringFromDate:self.show.broadcastDate];
    }
    if(self.show.screenshot_512x288){
#warning Find alternative screenshot when not available
        [self.imageView sd_setImageWithURL:[NSURL URLWithString:self.show.screenshot_512x288] placeholderImage:[UIImage imageNamed:@"noco.png"]];
    }
    if(self.show.show_resume) {
        self.descriptionText.text = self.show.show_resume;
        //self.descriptionText.text = [self.descriptionText.text stringByAppendingString:@"\n\n"];
    }
    if(self.show.family_resume) {
        //self.descriptionText.text = [self.descriptionText.text stringByAppendingString:self.show.family_resume];
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
        }else{
#warning Handle error
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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

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
    NSLog(@"Load state %i", self.moviePlayer.loadState);
#endif
    if(self.moviePlayer.loadState & MPMovieLoadStatePlayable){
    }
}

- (void)notificaitonMPMoviePlayerDidExitFullscreenNotification:(NSNotification*)notif{
    if(!self.readButton.selected){
        if(self.chapters&&[self.chapters count]>0){
            self.readSheet = [[UIActionSheet alloc] initWithTitle:@"Marquer comme lu" delegate:self cancelButtonTitle:@"Ne pas marquer comme lu" destructiveButtonTitle:nil otherButtonTitles:allReadMessage, @"l'émission seule", nil];
            [self.readSheet showFromTabBar:self.navigationController.tabBarController.tabBar];
        }else{
            self.readSheet = [[UIActionSheet alloc] initWithTitle:@"Marquer comme lu" delegate:self cancelButtonTitle:@"Ne pas marquer comme lu" destructiveButtonTitle:nil otherButtonTitles:@"marquer l'émission comme lu", nil];
            [self.readSheet showFromTabBar:self.navigationController.tabBarController.tabBar];
        }
    }
}

- (void)notificationMPMoviePlayerPlaybackDidFinishNotification:(NSNotification*)notif{
    int reason = MPMovieFinishReasonUserExited;
    if([notif.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey]){
        reason = [[notif.userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
    }
    //MPMovieFinishReasonPlaybackEnded will be callend after MPMovieFinishReasonUserExited so we prevent reset the progress when an MPMovieFinishReasonUserExited occured
    if (reason == MPMovieFinishReasonPlaybackEnded && ! userEndedPlay) {
        //movie finished playin
        NSLog(@"Stopped at end");
        if(!self.progressAlert){
            self.progressAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"Mise à jour de la progression de la lecture..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
            [self.progressAlert show];
        }
        [[NLTAPI sharedInstance] setResumePlay:0 forShow:self.show withResultBlock:^(id result, NSError *error) {
            [self.progressAlert dismissWithClickedButtonIndex:0 animated:YES];
            progress = 0;
        } withKey:self];
        [self.moviePlayer stop];
    }else if (reason == MPMovieFinishReasonUserExited) {
        //user hit the done button
        if(self.moviePlayer.currentPlaybackTime > 0 && self.moviePlayer.currentPlaybackTime < self.moviePlayer.duration){
            userEndedPlay = TRUE;
            NSLog(@"Stopped before end - %f / %f",self.moviePlayer.currentPlaybackTime, self.moviePlayer.duration);
            progress = self.moviePlayer.currentPlaybackTime;
            if(!self.progressAlert){
                self.progressAlert = [[UIAlertView alloc] initWithTitle:@"Connection en cours ..." message:@"Mise à jour de la progression de la lecture..." delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
                [self.progressAlert show];
            }
            [[NLTAPI sharedInstance] setResumePlay:1000*self.moviePlayer.currentPlaybackTime forShow:self.show withResultBlock:^(id result, NSError *error) {
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
    [self.moviePlayer.view removeFromSuperview];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = [NSMutableDictionary dictionary];

}

- (void)notificationMPMoviePlayerNowPlayingMovieDidChangeNotification:(NSNotification*)notif{
    [self.videoActivity stopAnimating];
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

- (IBAction)play:(id)sender {
    if(self.show.access_show == 0){
        if([self.show.access_error compare:@"subscription_required" options:NSCaseInsensitiveSearch]==NSOrderedSame){
            NSString* urlStr = [NSString stringWithFormat:@"partners/by_key/%@",self.show.partner_key];
            [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(id result, NSError *error) {
                BOOL partnerFound = FALSE;
                if([result isKindOfClass:[NSArray class]]){
                    for (NSDictionary*partner in result) {
                        if([(NSString*)[partner objectForKey:@"partner_key"] compare:self.show.partner_key]==NSOrderedSame){
                            [[[UIAlertView alloc] initWithTitle:@"Lecture impossible" message:[NSString stringWithFormat:@"Vous n'êtes pas abonné(e) à %@", [partner objectForKey:@"partner_name"]] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
                            partnerFound = TRUE;
                            break;
                        }
                    }
                }
                if(!partnerFound){
                    [self.tabBarController.view makeToast:@"Cette émission ne fait pas partie de votre abonnement" duration:2 position:@"bottom"];
                }
                
            } withKey:self withCacheDuration:60*10];
        }else{
            [self.tabBarController.view makeToast:@"Impossible de lire cette émission" duration:2 position:@"bottom"];
        }
        return;
    }
#warning TODO Add preference for prefered quality
    __weak ShowViewController* weakSelf = self;
    [self.videoActivity startAnimating];
    [[NLTAPI sharedInstance] videoUrlForShow:self.show withResultBlock:^(id result, NSError *error) {
        if(result){
            userEndedPlay = FALSE;
            NSString* file = [result objectForKey:@"file"];
            NSURL* url = [NSURL URLWithString:file];
            if([[NocoDownloadsManager sharedInstance] isDownloaded:self.show]){
                file = [[NocoDownloadsManager sharedInstance] downloadFilePathForShow:self.show];
                if(file){
                    url = [NSURL fileURLWithPath:file];
                }
                
            }
            weakSelf.moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
            weakSelf.moviePlayer.movieSourceType = MPMovieSourceTypeFile;
            weakSelf.moviePlayer.view.frame = weakSelf.imageView.frame;
            [weakSelf.imageView.superview addSubview:weakSelf.moviePlayer.view];
            [weakSelf.videoActivity.superview bringSubviewToFront:weakSelf.videoActivity];
            [weakSelf.moviePlayer setInitialPlaybackTime:progress];
            [weakSelf.moviePlayer prepareToPlay];
            weakSelf.moviePlayer.shouldAutoplay = TRUE;
            [self.moviePlayer setFullscreen:YES animated:YES];
            MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
            NSMutableDictionary* info = [NSMutableDictionary dictionaryWithDictionary:infoCenter.nowPlayingInfo];
            if(!info){
                info =  [NSMutableDictionary dictionary];
            }
            if(self.show.show_TT) [info setObject:self.show.show_TT forKey:MPMediaItemPropertyTitle];
            if(self.show.family_TT) [info setObject:self.show.family_TT forKey:MPMediaItemPropertyArtist];
            [info setObject:[NSNumber numberWithInt:self.show.episode_number] forKey:MPMediaItemPropertyAlbumTrackNumber];
            [info setObject:[[MPMediaItemArtwork alloc] initWithImage:self.imageView.image] forKey:MPMediaItemPropertyArtwork];
            infoCenter.nowPlayingInfo = info;
        }else{
            [self.videoActivity stopAnimating];
            if(error.code == NLTAPI_ERROR_VIDEO_UNAVAILABLE_WITH_POPMESSAGE && [error.userInfo objectForKey:@"popmessage"]&&[[error.userInfo objectForKey:@"popmessage"] objectForKey:@"message"]){
                [[[UIAlertView alloc] initWithTitle:@"Erreur" message:[[error.userInfo objectForKey:@"popmessage"] objectForKey:@"message"] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }else{
#warning Handle error
            }
        }
    } withKey:self];
}

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
            [self.statusAlert dismissWithClickedButtonIndex:0 animated:YES];
            self.statusAlert = nil;
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
        [self.statusAlert show];        [[NLTAPI sharedInstance] removeFromQueueList:self.show withResultBlock:^(id result, NSError *error) {
            [self.statusAlert dismissWithClickedButtonIndex:0 animated:YES];
            self.statusAlert = nil;
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
#warning TODO Add preference for prefered quality
                    [[NocoDownloadsManager sharedInstance] planDownloadForShow:self.show withQuality:@"LQ"];
                    [self updateInterctiveUI];
                }
            }
        }
    }
}

#pragma mark Action sheet delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    if(actionSheet == self.readSheet){
        if(actionSheet.cancelButtonIndex != buttonIndex){
            [self markRead:self.show];
            if([[actionSheet buttonTitleAtIndex:buttonIndex] compare:allReadMessage]==NSOrderedSame){
                int i = 0;
                while(i<[self.chapters count]){
                    NLTShow* chapterShow = [self showAtIndex:i];
                    [self markRead:chapterShow];
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
    
    [[NLTAPI sharedInstance] setReadStatus:!self.readButton.selected forShow:show withResultBlock:^(id result, NSError *error) {
        unreadCalls--;
        if(error){
            self.readError = error;
        }else{
            if(show==self.show){
                weakSelf.readButton.selected = true;
                weakSelf.readImageButton.selected = true;
            }
        }
        if(unreadCalls == 0){
            [weakSelf.readAlert dismissWithClickedButtonIndex:0 animated:YES];
            if(self.readError){
                [weakSelf.tabBarController.view makeToast:[NSString stringWithFormat:@"Impossible de marquer comme lu"] duration:3 position:@"bottom"];
            }else{
            }
            weakSelf.readAlert = nil;
            weakSelf.readError = nil;
            [weakSelf updateInterctiveUI];
            if(weakSelf.watchListButton.selected){
                //Propose to remove from watchlist, as it is read
                self.statusSheet = [[UIActionSheet alloc] initWithTitle:@"Liste de lecture" delegate:self cancelButtonTitle:@"Ne pas retirer" destructiveButtonTitle:nil otherButtonTitles:removeFromWatchlist, nil];
                [self.statusSheet showFromTabBar:self.navigationController.tabBarController.tabBar];
            }
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
                    NSLog(@"Loading not needed");
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

@end
