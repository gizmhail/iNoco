//
//  SearchViewController.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 01/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "RecentShowViewController.h"

@interface SearchViewController : RecentShowViewController<UITableViewDelegate>
@property (retain,nonatomic) NSString* search;
@property (weak, nonatomic) IBOutlet UILabel *noResultLabel;
@property (weak, nonatomic) IBOutlet UITableView *familyTableview;

@end
