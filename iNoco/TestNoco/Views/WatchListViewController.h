//
//  WatchListViewController.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 30/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RecentShowViewController.h"

@interface WatchListViewController : RecentShowViewController
@property (weak, nonatomic) IBOutlet UILabel *emptyMessageLabel;


- (long)downloadsSection;
- (long)watchListSection;
- (long)favoriteFamilySection;
- (long)resumePlaySection;

@end
