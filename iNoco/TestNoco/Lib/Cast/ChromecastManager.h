//
//  ChromecastManager.h
//  iNoco
//
//  Created by Sébastien POIVRE on 07/04/2015.
//  Copyright (c) 2015 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GoogleCast.h"
#import "NLTAPI.h"

@interface ChromecastManager : NSObject<GCKDeviceScannerListener,GCKDeviceManagerDelegate,GCKMediaControlChannelDelegate>
@property (retain,nonatomic)GCKDeviceScanner*deviceScanner;
@property (retain,nonatomic)GCKDeviceManager* deviceManager;
@property (retain,nonatomic)GCKMediaControlChannel* mediaControlChannel;

- (void)deviceScan;
- (void) selectDefaultDevice;
- (void)selectDevice:(GCKDevice*)selectedDevice;
- (void)playContent:(NSURL*)url withTitle:(NSString*)title withSubtitle:(NSString*)subtitle withThumbnail:(NSURL*)thumbnailURL withContentType:(NSString*)mimeType withDuration:(long)duration withStartime:(long)startTime;
- (void)playShow:(NLTShow*)show withProgress:(float)progress;

@end
