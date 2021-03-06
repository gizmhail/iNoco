//
//  AppDelegate.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 12/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "AppDelegate.h"
#import "NLTOAuth.h"
#import "NLTAPI.h"
#import <AVFoundation/AVFoundation.h>
#import "NocoDownloadsManager.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import "RecentShowViewController.h"
#import "GroupSettingsManager.h"
#import "NolifeEPGViewControllerTableViewController.h"
#import "ShowViewController.h"
#import "WatchListViewController.h"

void uncaughtExceptionHandler(NSException *exception) {
    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", [exception callStackSymbols]);
    // Internal error reporting
}

@interface AppDelegate ()
@property (retain,nonatomic)UIAlertView* interruptedAlertview;
@end
@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
#ifdef DEBUG
    //[[Crashlytics sharedInstance] setDebugMode:YES];
#endif
    [Fabric with:@[CrashlyticsKit]];

    GroupSettingsManager* groupSettings = [GroupSettingsManager sharedInstance];
#ifdef NLT_RECORD_LOGS
    groupSettings.debugKeys = @[@"NLTOAuth_oauthAccessToken",
                                @"NLTOAuth_oauthRefreshToken"];
#endif

#ifdef DEBUG
    //NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
#endif
    NSError *setCategoryError = nil;
    BOOL success = [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback error: &setCategoryError];
    if (!success) {
        NSLog(@"Problem during audio session configuration: %@",[setCategoryError description]);
    }else{
        [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    }
    
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

    [[NocoDownloadsManager sharedInstance] fixDownloadInfoPath];


    //Lock screen audio events
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    //Chromecast
    self.chromecastManager = [[ChromecastManager alloc] init];
    [self.chromecastManager deviceScan];
    
    //Current cast view
    UITabBarController* tabBarController = (UITabBarController*)self.window.rootViewController;
    UIView* view = [[UIView alloc] initWithFrame:CGRectMake(0, tabBarController.view.frame.size.height - tabBarController.tabBar.frame.size.height - 100, [[UIScreen mainScreen] bounds].size.width, 100)];
    view.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
    view.userInteractionEnabled = TRUE;
    view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
    UITapGestureRecognizer* tapR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(testTap)];
    [view addGestureRecognizer:tapR];
    [tabBarController.view addSubview:view];
    view.hidden = TRUE;
    return YES;
}

- (void)testTap{
    NSLog(@"111");
}

- (void)handleInterruptedShow{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    NSData* cacheData = [settings objectForKey:@"InterruptedShow" ];
    NLTShow* interruptedShow = nil;
    if(cacheData){
        interruptedShow = [[NLTShow alloc] initWithDictionnary:[NSKeyedUnarchiver unarchiveObjectWithData:cacheData]];
    }
    
    if(interruptedShow && interruptedShow.id_show){
        // We check that we are not already playing this show
        UITabBarController* tabbarController = (UITabBarController*)self.window.rootViewController;
        if([tabbarController.selectedViewController isKindOfClass:[UINavigationController class]]){
            UINavigationController* currentTab = (UINavigationController*)tabbarController.selectedViewController;
            if([currentTab.topViewController isKindOfClass:[ShowViewController class]]){
                ShowViewController* currentViewController = (ShowViewController*)currentTab.topViewController;
                if(currentViewController.show.id_show == interruptedShow.id_show){
                    // We are already playing this show, no need to display the popup
                    return;
                }
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString* title = [interruptedShow showFullTitle];
            self.interruptedAlertview = [[UIAlertView alloc] initWithTitle:@"Continuer la lecture ?" message:[NSString stringWithFormat:@"Voulez-vous reprendre la lecture de la dernière émission interrompue (%@) ?",title] delegate:self cancelButtonTitle:@"Non" otherButtonTitles:@"Oui", nil];
            [self.interruptedAlertview show];
        });
    }
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    //We reload info coming from the settings, as the extension might have changed them
    [[GroupSettingsManager sharedInstance] synchronize];
    [[NLTOAuth sharedInstance] loadOauthInfo];
    [[NLTAPI sharedInstance] loadCache];
    
    
#ifdef NLT_RECORD_LOGS
    //NSMutableArray* logs = [[GroupSettingsManager sharedInstance] logs];
    //NSLog(@"%@",logs);
    
    [[GroupSettingsManager sharedInstance] logEvent:@"iNoco_DidBecomeActive" withUserInfo:nil];
#endif
    
    [self handleInterruptedShow];


}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark Lock screen control


-(void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent{
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        switch (receivedEvent.subtype) {
            case UIEventSubtypeRemoteControlPause:
            case UIEventSubtypeRemoteControlTogglePlayPause:
            case UIEventSubtypeRemoteControlPlay:
                if([self.remoteControlDelegate respondsToSelector:@selector(tooglePlay)]){
                    [self.remoteControlDelegate tooglePlay];
                }
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
            case UIEventSubtypeRemoteControlNextTrack:
            case UIEventSubtypeRemoteControlStop:
            default:
                break;
        }
    }
}

#pragma mark NSURLSession

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler{
    NSURLSessionConfiguration *backgroundConfigObject = [NSURLSessionConfiguration backgroundSessionConfiguration: identifier];
    
    [NSURLSession sessionWithConfiguration: backgroundConfigObject delegate: [NocoDownloadsManager sharedInstance] delegateQueue: [NSOperationQueue mainQueue]];
    
    NSLog(@"Rejoining NSURLSession %@\n", identifier);
    
    [[NocoDownloadsManager sharedInstance] addCompletionHandler: completionHandler forSession: identifier];
}

#pragma mark URL Scheme

-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
    NSString* query = [url query];
    NSArray* params = [query componentsSeparatedByString:@"&"];
    if(params){
        for (NSString* param in params) {
            NSArray* parts = [param componentsSeparatedByString:@"="];
            NSString* key = @"";
            NSString* value = @"";
            if([parts count]>0){
                key = [parts objectAtIndex:0];
            }
            if([parts count]>1){
                value = [parts objectAtIndex:1];
            }
            //Using params
            if([key compare:@"betaTest" options:NSCaseInsensitiveSearch]==NSOrderedSame){
                if([value compare:@"activateFamilyList" options:NSCaseInsensitiveSearch]==NSOrderedSame){
                    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
                    [settings setObject:[NSNumber numberWithBool:true] forKey:@"FamilyList"];
                    [settings synchronize];
                }
                if([value compare:@"desactivateFamilyList" options:NSCaseInsensitiveSearch]==NSOrderedSame){
                    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
                    [settings setObject:[NSNumber numberWithBool:false] forKey:@"FamilyList"];
                    [settings synchronize];
                }
            }
            
            if([key compare:@"showId" options:NSCaseInsensitiveSearch]==NSOrderedSame){
                long showId = [value integerValue];
                [[NLTAPI sharedInstance] showWithId:showId withResultBlock:^(NLTShow* result, NSError *error) {
                    [self openShowPage:result];
                } withKey:self];
            }
            
            if([key compare:@"action" options:NSCaseInsensitiveSearch]==NSOrderedSame){
                NSString* action = value;
                if([action compare:@"now"]==NSOrderedSame){
                    [self openNowOnNolife];
                }
            }
        }
    }
    return YES;
}

#pragma mark Direct actions

- (void)openShowPage:(NLTShow*)show{
    if(!show){
        return;
    }
    UITabBarController* tabbarController = (UITabBarController*)self.window.rootViewController;
    UIViewController* firstTabController = [[tabbarController viewControllers] firstObject];
    if([firstTabController isKindOfClass:[UINavigationController class]]){
        UINavigationController* firstNavigationController = (UINavigationController*)firstTabController;
        [firstNavigationController popToRootViewControllerAnimated:NO];
        RecentShowViewController* recentShowController = (RecentShowViewController*)[(UINavigationController*)firstTabController topViewController];
        if([recentShowController isKindOfClass:[RecentShowViewController class]]){
            [tabbarController setSelectedIndex:0];
            recentShowController.playlistContext = nil;
            recentShowController.playlistType = nil;
            [recentShowController performSegueWithIdentifier:@"DisplayRecentShow" sender:show];
        }
    }
}

- (void)openNowOnNolife{
    UITabBarController* tabbarController = (UITabBarController*)self.window.rootViewController;
    if([[tabbarController viewControllers] count]<4){
        return;
    }
    UIViewController* epgTabController = [[tabbarController viewControllers] objectAtIndex:3];
    if([epgTabController isKindOfClass:[UINavigationController class]]){
        UINavigationController* epgNavigationController = (UINavigationController*)epgTabController;
        [epgNavigationController popToRootViewControllerAnimated:NO];
        NolifeEPGViewControllerTableViewController* epgController = (NolifeEPGViewControllerTableViewController*)[(UINavigationController*)epgNavigationController topViewController];
        if([epgController isKindOfClass:[NolifeEPGViewControllerTableViewController class]]){
            [tabbarController setSelectedIndex:3];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [epgController scrollToNow];
            });
        }
    }
}

#pragma mark UIAlertviewDelegate

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    if(alertView==self.interruptedAlertview){
        self.interruptedAlertview = nil;
        NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
        NSData* cacheData = [settings objectForKey:@"InterruptedShow" ];
        NLTShow* interruptedShow = nil;
        if(cacheData){
            interruptedShow = [[NLTShow alloc] initWithDictionnary:[NSKeyedUnarchiver unarchiveObjectWithData:cacheData]];
        }
        [settings removeObjectForKey:@"InterruptedShow"];
        [settings synchronize];
        
        if(buttonIndex == alertView.cancelButtonIndex){
            return;
        }
        
        [self openShowPage:interruptedShow];
    }
}

#pragma mark - 3D Touch

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler{
    long watchListSection = -1;
    
    UITabBarController* tabbarController = (UITabBarController*)self.window.rootViewController;
    for (UINavigationController* navController in tabbarController.viewControllers) {
        if([navController isKindOfClass:[UINavigationController class]]){
            if([[navController.viewControllers firstObject] isKindOfClass:[WatchListViewController class]]){
                WatchListViewController* watchListViewController = (WatchListViewController*)[navController.viewControllers firstObject];
                
                if([shortcutItem.type isEqualToString:@"name.poivre.iNoco.watchlist"]){
                    watchListSection = [watchListViewController watchListSection];
                }
                if([shortcutItem.type isEqualToString:@"name.poivre.iNoco.downloads"]){
                    watchListSection = [watchListViewController downloadsSection];
                }
                if([shortcutItem.type isEqualToString:@"name.poivre.iNoco.favorites"]){
                    watchListSection = [watchListViewController favoriteFamilySection];
                }
                if([shortcutItem.type isEqualToString:@"name.poivre.iNoco.started"]){
                    watchListSection = [watchListViewController resumePlaySection];
                }
                if(watchListSection >= 0){
                    tabbarController.selectedViewController = navController;
                    [navController popToRootViewControllerAnimated:NO];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [watchListViewController.collectionView.collectionViewLayout prepareLayout];
                        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:0 inSection:watchListSection];
                        
                        CGFloat offsetY = [watchListViewController.collectionView layoutAttributesForSupplementaryElementOfKind:UICollectionElementKindSectionHeader atIndexPath:indexPath].frame.origin.y;
                        CGFloat sectionInsetY = ((UICollectionViewFlowLayout *)watchListViewController.collectionView.collectionViewLayout).sectionInset.top;
                        [watchListViewController.collectionView setContentOffset:CGPointMake(watchListViewController.collectionView.contentOffset.x, offsetY - sectionInsetY) animated:YES];                        
                    });
                }

            }
        }
    }

}

@end
