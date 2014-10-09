//
//  TodayViewController.m
//  iNocoToday
//
//  Created by Sébastien POIVRE on 07/10/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "GroupSettingsManager.h"
#import "NLTAPI.h"
#include "credentials.h"
#import "NLTEPG.h"
#import "UIImageView+WebCache.h"

@interface TodayViewController () <NCWidgetProviding>
@property(retain,nonatomic)NSArray* epgShows;
@property(retain,nonatomic)NSDictionary* currentEPGShow;
@property(retain,nonatomic)NLTShow* latestShow;
@end

@implementation TodayViewController

#pragma mark Interction

- (void)epgTap{
    [[self extensionContext] openURL:[NSURL URLWithString:@"iNoco://?action=now"] completionHandler:^(BOOL success) {
        
    }];
}

- (void)recentTap{
    if(self.latestShow){
        NSString* urlStr = [NSString stringWithFormat:@"iNoco://?showId=%i",self.latestShow.id_show];
        [[self extensionContext] openURL:[NSURL URLWithString:urlStr] completionHandler:^(BOOL success) {
            
        }];
    }
}

#pragma mark View handling
- (void)viewDidLoad {
    [super viewDidLoad];
    
    UITapGestureRecognizer* epgTag = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(epgTap)];
    [self.nowView addGestureRecognizer:epgTag];
    UITapGestureRecognizer* recentTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(recentTap)];
    [self.recentView addGestureRecognizer:recentTap];

    [[GroupSettingsManager sharedInstance] setDefaultSuiteName:INOCO_GROUPNAME];
    [[NLTOAuth sharedInstance] configureWithClientId:nolibtv_client_id withClientSecret:nolibtv_client_secret withRedirectUri:nolibtv_redirect_uri];
    [[NLTAPI sharedInstance] setAutoLaunchAuthentificationView:FALSE];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated{
    self.currentEPGShow = nil;
    [self updateCurrentShow];
    [self updateDisplay];
    [[NLTAPI sharedInstance] showsAtPage:0 withResultBlock:^(NSArray* results, NSError *error) {
        if(results){
            if([results count]>0){
                self.latestShow = [results objectAtIndex:0];
                NSLog(@"Latest show : %@",self.latestShow);
            }else{
                NSLog(@"Extension list show error: %@",[error description]);
            }
        }else{
            NSLog(@"Extension list show error: %@",[error description]);
        }
        [self updateDisplay];
    } withFamilyKey:nil withKey:nil];
/*
 self.latestShow = nil;
    self.infoLabel.text = @"Chargement en cours....";
    [self updateDisplay];

    [[NLTEPG sharedInstance] fetchEPG:^(NSArray *results, NSError *error) {
        if(results&&[results count]>0){
            self.epgShows = results;
            [self updateCurrentShow];
        }
        if(self.currentEPGShow){
            self.infoLabel.text = @"En ce moment sur Nolife";
        }else{
            //self.infoLabel.font = [UIFont systemFontOfSize:5];
            //self.infoLabel.text = [NSString stringWithFormat:@"%lu %@ %@",(unsigned long)[results count],[error description],results];
            NSLog(@"EPG error: %@ (%@)", error, results);
            self.infoLabel.text = @"Impossible de récupérer l'EPG de Nolife pour le moment";
        }
        [self updateDisplay];
 
    } withCacheDuration:3600*5];
 */
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    self.infoLabel.text = @"Chargement en cours....";
    self.currentEPGShow = nil;
    self.latestShow = nil;
    [self updateDisplay];
    
    [[NLTEPG sharedInstance] fetchEPG:^(NSArray *results, NSError *error) {
        if(results&&[results count]>0){
            self.epgShows = results;
            [self updateCurrentShow];
        }
        if(self.currentEPGShow){
            self.infoLabel.text = @"En ce moment sur Nolife";
        }else{
            self.infoLabel.text = @"Impossible de récupérer l'EPG de Nolife pour le moment";
        }
        [self updateDisplay];
        
        [[NLTAPI sharedInstance] showsAtPage:0 withResultBlock:^(NSArray* results, NSError *error) {
            if(results){
                if([results count]>0){
                    self.latestShow = [results objectAtIndex:0];
                }
                completionHandler(NCUpdateResultNewData);
            }else{

                completionHandler(NCUpdateResultFailed);
            }
            [self updateDisplay];
        } withFamilyKey:nil withKey:nil];

    } withCacheDuration:3600*5];
    [self extensionContext];
}

- (void)updateDisplay{
    [self updateNowOnNolife];
    [self updateRecent];
    
    CGSize updatedSize = [self preferredContentSize];
    updatedSize.height = 30.0;
    if(self.currentEPGShow){
        self.nowView.hidden = FALSE;
        updatedSize.height = 100.0;
    }else{
        self.nowView.hidden = TRUE;
    }

    if(self.latestShow){
        self.info2.hidden = FALSE;
        self.recentView.hidden = FALSE;
        updatedSize.height = 205.0;
    }else{
        self.info2.hidden = TRUE;
        self.recentView.hidden = TRUE;
    }

    
    [self setPreferredContentSize:updatedSize];

}

- (void)updateRecent{
    if(!self.latestShow){
        return;
    }
    NLTShow* show = self.latestShow;
    
    UILabel* timeLabel = (UILabel*)[self.recentView viewWithTag:100];
    UILabel* titleLabel = (UILabel*)[self.recentView viewWithTag:110];
    UILabel* subtitleLabel = (UILabel*)[self.recentView viewWithTag:120];
    UIImageView* imageView= (UIImageView*)[self.recentView viewWithTag:130];
    UIImageView* partnerImageView = nil;
    
    titleLabel.text = @"Chargement ...";
    subtitleLabel.text = @"";
    timeLabel.text = @"";
    imageView.image = [UIImage imageNamed:@"noco.png"];
    imageView.backgroundColor = [UIColor whiteColor];
    
    partnerImageView.image = nil;
    
    if(show){
        if([[NLTAPI sharedInstance].partnersByKey objectForKey:show.partner_key]){
            NSDictionary* partnerInfo = [[NLTAPI sharedInstance].partnersByKey objectForKey:show.partner_key];
            if([partnerInfo objectForKey:@"icon_128x72"]){
                [partnerImageView sd_setImageWithURL:[NSURL URLWithString:[partnerInfo objectForKey:@"icon_128x72"]] placeholderImage:nil];
            }
        }
        
        if(show.family_TT){
            titleLabel.text = show.family_TT;
            if(show.episode_number && show.episode_number != 0){
                if(show.season_number > 1){
                    titleLabel.text = [titleLabel.text stringByAppendingFormat:@" - S%02iE%02i", show.season_number,show.episode_number];
                }else{
                    titleLabel.text = [titleLabel.text stringByAppendingFormat:@" - %i", show.episode_number];
                }
            }
        }
        if(show.show_TT) {
            subtitleLabel.text = show.show_TT;
        }
        if(show.broadcastDate) {
            NSDateFormatter *formater = [[NSDateFormatter alloc] init];
            [formater setDateFormat:@"dd MMM YYY - HH:mm"];
            timeLabel.text = [formater stringFromDate:show.broadcastDate];
        }
        if(show.screenshot_512x288){
#warning Find alternative screenshot when not available
            [imageView sd_setImageWithURL:[NSURL URLWithString:show.screenshot_512x288] placeholderImage:[UIImage imageNamed:@"noco.png"]];
        }
    }
    
}

- (void)updateNowOnNolife{
    NSDictionary*show = self.currentEPGShow;
    if(!self.currentEPGShow){
        return;
    }
    
    UILabel* timeLabel = (UILabel*)[self.nowView viewWithTag:100];
    UILabel* titleLabel = (UILabel*)[self.nowView viewWithTag:110];
    UILabel* subtitleLabel = (UILabel*)[self.nowView viewWithTag:120];
    UIImageView* imageView= (UIImageView*)[self.nowView viewWithTag:130];
    
    NSString* imageUrl = nil;
    if([show objectForKey:@"screenshot"] && [show objectForKey:@"screenshot"] != [NSNull null] && [(NSString*)[show objectForKey:@"screenshot"] compare:@""] != NSOrderedSame){
        imageUrl = [show objectForKey:@"screenshot"];
    }
    if([show objectForKey:@"AdditionalScreenshot"] && [show objectForKey:@"AdditionalScreenshot"] != [NSNull null] && [(NSString*)[show objectForKey:@"AdditionalScreenshot"] compare:@""] != NSOrderedSame){
        imageUrl = [show objectForKey:@"AdditionalScreenshot"];
    }
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    if(imageUrl){
        [imageView sd_setImageWithURL:[NSURL URLWithString:imageUrl] placeholderImage:[UIImage imageNamed:@"nolife.png"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            imageView.image = image;
            if(error){
                imageView.image = [UIImage imageNamed:@"nolife.png"];
            }
            imageView.contentMode = UIViewContentModeScaleAspectFit;
        }];
    }
    
    timeLabel.text = @"";
    NSDate* broadcastDate = nil;
    if([show objectForKey:@"dateUTC"] && [show objectForKey:@"dateUTC"] != [NSNull null]){
        NSDateFormatter *formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        [formater setTimeZone:timeZone];
        broadcastDate = [formater dateFromString:[show objectForKey:@"dateUTC"]];
        formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"HH:mm"];
        timeLabel.text = [formater stringFromDate:broadcastDate];
    }
    NSUInteger indexOfCurrent = [self.epgShows indexOfObject:self.currentEPGShow];
    
    if(broadcastDate && ((indexOfCurrent+1)  < [self.epgShows count]) ){
        NSDictionary* nextShow = [self.epgShows objectAtIndex:(indexOfCurrent+1)];
        if([nextShow objectForKey:@"dateUTC"] && [nextShow objectForKey:@"dateUTC"] != [NSNull null]){
            NSDateFormatter *formater = [[NSDateFormatter alloc] init];
            [formater setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
            NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
            [formater setTimeZone:timeZone];
            NSDate* nextBroadcastDate = [formater dateFromString:[nextShow objectForKey:@"dateUTC"]];
            formater = [[NSDateFormatter alloc] init];
            [formater setDateFormat:@"HH:mm"];
            NSString* enDate = [formater stringFromDate:nextBroadcastDate];
            timeLabel.text = [NSString stringWithFormat:@"%@ - %@",timeLabel.text,enDate];
        }
        
    }
    
    if([show objectForKey:@"description"] && [show objectForKey:@"description"] != [NSNull null]){
        titleLabel.text = [show objectForKey:@"description"];
    }
    
    if([show objectForKey:@"detail"] && [show objectForKey:@"detail"] != [NSNull null]){
        subtitleLabel.text = [show objectForKey:@"detail"];
    }
    
    if(show && [[show objectForKey:@"NolifeOnlineURL"] isKindOfClass:[NSString class]]&&[(NSString*)[show objectForKey:@"NolifeOnlineURL"] compare:@""]!=NSOrderedSame){
        titleLabel.textColor = THEME_COLOR;
    }else{
        titleLabel.textColor = [UIColor lightGrayColor];
    }
}

- (void)updateCurrentShow{
    NSDateFormatter *formater = [[NSDateFormatter alloc] init];
    [formater setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [formater setTimeZone:timeZone];

    long currentIndex = 0;
    long closestDistance = 2*3600;
    NSDate* now = [NSDate date];
    NSDictionary* bestShow = nil;
    for (NSDictionary* show in self.epgShows) {
        NSDate* broadcastDate = [formater dateFromString:[show objectForKey:@"dateUTC"]];
        if([broadcastDate timeIntervalSinceDate:now]<0 && ABS([broadcastDate timeIntervalSinceDate:now])<closestDistance){
            bestShow = show;
            closestDistance = ABS([broadcastDate timeIntervalSinceDate:now]);
        }
        currentIndex++;
    }
    if(!bestShow){
        NSLog(@"Unable to find best show among %i shows (best distance %i)",[self.epgShows count], closestDistance);
    }
    self.currentEPGShow = bestShow;
}
@end
