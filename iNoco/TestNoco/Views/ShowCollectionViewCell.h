//
//  ShowCollectionViewCell.h
//  iNoco
//
//  Created by Sébastien POIVRE on 22/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NLTAPI.h"

@interface ShowCollectionViewCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView* imageView;
@property (weak, nonatomic) IBOutlet UILabel* title;
@property (weak, nonatomic) IBOutlet UILabel* subtitle;
@property (weak, nonatomic) IBOutlet UILabel* time;
@property (weak, nonatomic) IBOutlet UIView* durationView;
@property (weak, nonatomic) IBOutlet UIView* durationBackground;
@property (weak, nonatomic) IBOutlet UILabel* durationLabel;

@property (weak, nonatomic) IBOutlet UIView* watchListView;
@property (weak, nonatomic) IBOutlet UIView* watchListBackground;
@property (weak, nonatomic) IBOutlet UIButton* watchListButton;
@property (weak, nonatomic) IBOutlet UIView* readView;
@property (weak, nonatomic) IBOutlet UIView* readBackground;
@property (weak, nonatomic) IBOutlet UIButton* readButton;
@property (weak, nonatomic) IBOutlet UIImageView* partnerImageView;

- (void)loadShow:(NLTShow*)show;
- (void)loadFamily:(NLTFamily*)family;

@end
