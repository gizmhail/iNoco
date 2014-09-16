//
//  NolifeEPGViewControllerTableViewController.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 07/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NolifeEPGViewControllerTableViewController : UITableViewController
@property (retain,nonatomic)NSMutableArray* playlistContext;
@property (retain,nonatomic)NSString* playlistType;
@property (retain,nonatomic)id playlistCurrentItem;

@end
