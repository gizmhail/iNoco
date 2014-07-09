//
//  WatchListHeaderReusableView.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 05/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WatchListHeaderReusableView : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *label;

@end
