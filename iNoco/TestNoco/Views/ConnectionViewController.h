//
//  ConnectionViewController.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 21/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ConnectionViewControllerDelegate <NSObject>
@optional
- (void)connectedToNoco;
- (void)noNetwordForAuth;
@end

@interface ConnectionViewController : UIViewController
@property (assign, nonatomic) id<ConnectionViewControllerDelegate> sender;
- (IBAction)connect:(id)sender;
- (IBAction)accounCreation:(id)sender;

@end
