//
//  FirstViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 12/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "FirstViewController.h"
#import "NLTOAuth.h"
#import "NLTAPI.h"

@interface FirstViewController ()

@end

@implementation FirstViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NLTOAuth sharedInstance] configureWithClientId:nolibtv_client_id withClientSecret:nolibtv_client_secret withRedirectUri:nolibtv_redirect_uri];
        //[[NLTOAuth sharedInstance] disconnect];
        //[[NLTAPI sharedInstance] invalidateCache:@"/shows"];
        [[NLTAPI sharedInstance] callAPI:@"/shows" withResultBlock:^(id result, NSError *error) {
            if(error){
                NSLog(@"Error: %@",error);
            }else{
                NSLog(@"Answer: %@",result);
            }
        } withKey:nil withCacheDuration:3600];
        
    });

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
