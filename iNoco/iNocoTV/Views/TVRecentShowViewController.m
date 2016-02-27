//
//  TVRecentShowViewController.m
//  iNoco
//
//  Created by Sébastien POIVRE on 10/10/2015.
//  Copyright © 2015 Sébastien Poivre. All rights reserved.
//

#import "TVRecentShowViewController.h"

@interface TVRecentShowViewController ()

@end

@implementation TVRecentShowViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

-(UIView *)preferredFocusedView{
    return self.collectionView;
}

@end
