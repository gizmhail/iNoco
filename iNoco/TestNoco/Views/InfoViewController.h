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
@property (weak, nonatomic) IBOutlet UISegmentedControl *qualitySegmentedControl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *languageSegementedControl;
@property (weak, nonatomic) IBOutlet UISegmentedControl *subtitleSegementedControl;
@property (weak, nonatomic) IBOutlet UIView *settingsZone;
@property (weak, nonatomic) IBOutlet UIView *iNocoZone;
@property (weak, nonatomic) IBOutlet UIView *accountZone;

- (IBAction)disconnect:(id)sender;
- (IBAction)catalogueChanged:(id)sender;
- (IBAction)accountClick:(id)sender;
- (IBAction)thirdPartyClick:(id)sender;
- (IBAction)qualityChanged:(id)sender;
- (IBAction)languageChanged:(id)sender;
- (IBAction)subtitleChanged:(id)sender;

@end
