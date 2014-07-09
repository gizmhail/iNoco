//
//  ShowViewController.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 23/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTAPI.h"
#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface ShowViewController : UIViewController<UICollectionViewDataSource,UICollectionViewDelegate,UIActionSheetDelegate,RemoteControlEventHandlerProtocol>
@property (weak, nonatomic) IBOutlet UILabel *famillyLabel;
@property (weak, nonatomic) IBOutlet UILabel *episodeLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UITextView *descriptionText;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIButton *favoriteFamilly;
@property (weak, nonatomic) IBOutlet UIView *durationBackground;
@property (retain, nonatomic) NLTShow* show;
@property (weak, nonatomic) IBOutlet UIButton *readButton;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UIButton *watchListTextButton;
@property (weak, nonatomic) IBOutlet UIButton *watchListButton;
@property (weak, nonatomic) IBOutlet UIButton *readImageButton;
@property (weak, nonatomic) IBOutlet UIView *watchListBackground;
@property (weak, nonatomic) IBOutlet UIView *readBackground;
@property (weak, nonatomic) IBOutlet UIView *watchListZone;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *videoActivity;
@property (weak, nonatomic) IBOutlet UILabel *chapterLabel;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *chapterActivity;
@property (weak, nonatomic) IBOutlet UIView *infoBackground;

- (IBAction)play:(id)sender;
- (IBAction)favoriteFamillyClick:(id)sender;
- (IBAction)toggleRead:(id)sender;
- (IBAction)watchListClick:(id)sender;
@end
