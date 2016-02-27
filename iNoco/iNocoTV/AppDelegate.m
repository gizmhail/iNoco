//
//  AppDelegate.m
//  iNocoTV
//
//  Created by Sébastien POIVRE on 10/10/2015.
//  Copyright © 2015 Sébastien Poivre. All rights reserved.
//

#import "AppDelegate.h"
#import "NLTOAuth.h"
#import "NLTAPI.h"
#import <AVFoundation/AVFoundation.h>
#import "NocoDownloadsManager.h"
#import "RecentShowViewController.h"
#import "GroupSettingsManager.h"
#include "commonSettings.h"
#include "credentials.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [self gsmInit];
    [self audioInit];
    [self nocoInit];

    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


#pragma mark Initial settings
- (void)gsmInit{
    GroupSettingsManager* groupSettings = [GroupSettingsManager sharedInstance];
#ifdef NLT_RECORD_LOGS
    groupSettings.debugKeys = @[@"NLTOAuth_oauthAccessToken",
                                @"NLTOAuth_oauthRefreshToken"];
#endif
}

- (void)audioInit{
    NSError *setCategoryError = nil;
    BOOL success = [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: &setCategoryError];
    if (!success) {
        NSLog(@"Problem during audio session configuration: %@",[setCategoryError description]);
    }else{
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    }
}

- (void)nocoInit{
    GroupSettingsManager* groupSettings = [GroupSettingsManager sharedInstance];
    [[NLTOAuth sharedInstance] configureWithClientId:nolibtv_client_id withClientSecret:nolibtv_client_secret withRedirectUri:nolibtv_redirect_uri];
    
    //NLTAPI conf
    
    NSString* catalog = DEFAULT_CATALOG;
    //Migration of shared keys (between app and extension when first having extension update
    [groupSettings copyIfNeededFromLocalKeys:@[
                                               @"NLTAPI_cachedResults",
                                               @"NLTOAuth_oauthAccessToken",
                                               @"NLTOAuth_oauthRefreshToken",
                                               @"NLTOAuth_oauthExpirationDate",
                                               @"NLTOAuth_oauthTokenType",
                                               @"NLTAPI_cachedResults",
                                               @"SELECTED_CATALOG"
                                               ]];
    
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    if([groupSettings objectForKey:@"SELECTED_CATALOG"]){
        catalog = [groupSettings objectForKey:@"SELECTED_CATALOG"];
    }
    
#ifdef DEBUG
    //NSLog(@"Disabling auto authent");
    //[[NLTAPI sharedInstance] setAutoLaunchAuthentificationView:FALSE];
#endif
    
    [[NLTAPI sharedInstance] setSubscribedOnly:false];
    [[NLTAPI sharedInstance] setPartnerKey:nil];
    if([catalog compare:ALL_SUBSCRIPTED_CATALOG]==NSOrderedSame){
        [[NLTAPI sharedInstance] setSubscribedOnly:TRUE];
    }else if([catalog compare:ALL_NOCO_CATALOG]==NSOrderedSame){
        [[NLTAPI sharedInstance] setSubscribedOnly:false];
        [[NLTAPI sharedInstance] setPartnerKey:nil];
    }else if(catalog != nil){
        [[NLTAPI sharedInstance] setSubscribedOnly:false];
        [[NLTAPI sharedInstance] setPartnerKey:catalog];
    }
    
    [[NLTAPI sharedInstance] setHandleNetworkActivityIndicator:TRUE];
    
    [NLTAPI sharedInstance].preferedLanguage = DEFAULT_LANGUAGE;//Use VO
    if([settings objectForKey:@"preferedLanguage"]){
        [NLTAPI sharedInstance].preferedLanguage = [settings objectForKey:@"preferedLanguage"];
    }
    [NLTAPI sharedInstance].preferedSubtitleLanguage = DEFAULT_SUBTITLE_LANGUAGE;
    if([settings objectForKey:@"preferedSubtitleLanguage"]){
        [NLTAPI sharedInstance].preferedSubtitleLanguage = [settings objectForKey:@"preferedSubtitleLanguage"];
    }
    [NLTAPI sharedInstance].preferedQuality = DEFAULT_QUALITY;
    if([settings objectForKey:@"preferedQuality"]){
        [NLTAPI sharedInstance].preferedQuality = [settings objectForKey:@"preferedQuality"];
    }
    
#ifdef TRUST_BACKEND_QUALITY_ADAPTATION
    [NLTAPI sharedInstance].trustBackendQualityAdaptation = TRUST_BACKEND_QUALITY_ADAPTATION;
#endif
    if([settings objectForKey:@"trustBackendQualityAdaptation" ]){
        [NLTAPI sharedInstance].trustBackendQualityAdaptation = [settings boolForKey:@"trustBackendQualityAdaptation"];
    }
    
}


@end
