//
//  TodayViewController.h
//  iNocoToday
//
//  Created by Sébastien POIVRE on 07/10/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "commonSettings.h"

@interface TodayViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;
@property (weak, nonatomic) IBOutlet UIView *nowView;
@property (weak, nonatomic) IBOutlet UILabel *info2;
@property (weak, nonatomic) IBOutlet UIView *recentView;

@end
