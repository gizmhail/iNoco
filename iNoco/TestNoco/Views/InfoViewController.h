//
//  InfoViewController.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 22/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface InfoViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIImageView *headerImageView;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *accountName;
@property (weak, nonatomic) IBOutlet UIButton *connectionButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (weak, nonatomic) IBOutlet UIButton *accountButton;

- (IBAction)disconnect:(id)sender;
- (IBAction)catalogueChanged:(id)sender;
- (IBAction)accountClick:(id)sender;
- (IBAction)thirdPartyClick:(id)sender;

@end
