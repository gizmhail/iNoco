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
#import <Crashlytics/Crashlytics.h>

void uncaughtExceptionHandler(NSException *exception) {
    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", [exception callStackSymbols]);
    // Internal error reporting
}

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
#ifdef DEBUG
    //[[Crashlytics sharedInstance] setDebugMode:YES];
#endif
    [Crashlytics startWithAPIKey:CRASHLITICS_KEY afterDelay:5];

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
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    if([settings objectForKey:@"SELECTED_CATALOG"]){
        catalog = [settings objectForKey:@"SELECTED_CATALOG"];
    }
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


    //Lock screen audio events
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];


    return YES;
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

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
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

@end
