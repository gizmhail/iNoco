//
//  AppDelegate.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 12/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChromecastManager.h"

@protocol RemoteControlEventHandlerProtocol <NSObject>
- (void)tooglePlay;
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate,UIAlertViewDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (assign, nonatomic) id<RemoteControlEventHandlerProtocol> remoteControlDelegate;
@property (retain,nonatomic) ChromecastManager* chromecastManager;
@end
