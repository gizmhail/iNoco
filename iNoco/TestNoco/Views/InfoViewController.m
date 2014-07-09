//
//  InfoViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 22/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "InfoViewController.h"
#import "NLTOAuth.h"
#import "NLTAPI.h"
#import "UIImageView+WebCache.h"
#import "WebViewDetailsViewController.h"

@interface InfoViewController ()

@end

@implementation InfoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

-(void)viewDidAppear:(BOOL)animated{
    self.navigationController.navigationBarHidden = TRUE;
    [self updateUI];
}

-(void)viewWillDisappear:(BOOL)animated{
    self.navigationController.navigationBarHidden = FALSE;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)disconnect:(id)sender {
    if([[NLTOAuth sharedInstance] isAuthenticated]){
        [[NLTAPI sharedInstance] invalidateAllCache];
        [[NLTOAuth sharedInstance] disconnect];
        [[[UIAlertView alloc] initWithTitle:@"déconnecté" message:@"Vous n'êtes plus connecté à Noco.tv" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        [self updateUI];
    }else{
        [[NLTOAuth sharedInstance] authenticate:^(NSError *error) {
            [self updateUI];
        }];
    }
}

- (IBAction)catalogueChanged:(id)sender {
    NSLog(@"%i",self.segmentedControl.selectedSegmentIndex);
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    if(self.segmentedControl.selectedSegmentIndex == 0){
        //Only nolife
        [settings setObject:@"NOL" forKey:@"SELECTED_CATALOG"];
        [[NLTAPI sharedInstance] setPartnerKey:@"NOL"];
        [[NLTAPI sharedInstance] setSubscribedOnly:FALSE];
    }else if(self.segmentedControl.selectedSegmentIndex == 1){
        [settings setObject:ALL_NOCO_CATALOG forKey:@"SELECTED_CATALOG"];
        [[NLTAPI sharedInstance] setPartnerKey:nil];
        [[NLTAPI sharedInstance] setSubscribedOnly:FALSE];
    }else if(self.segmentedControl.selectedSegmentIndex == 2){
        [settings setObject:ALL_SUBSCRIPTED_CATALOG forKey:@"SELECTED_CATALOG"];
        [[NLTAPI sharedInstance] setPartnerKey:nil];
        [[NLTAPI sharedInstance] setSubscribedOnly:TRUE];
    }
    [settings synchronize];
}

- (IBAction)accountClick:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://noco.tv/profil/"]];
}

- (IBAction)thirdPartyClick:(id)sender {
    NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"oss" ofType:@"html"];
    WebViewDetailsViewController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"WebViewDetailsViewController"];
    controller.localFile = htmlFile;
    controller.hideSafariButton = TRUE;
    [self.navigationController pushViewController:controller animated:YES];

}

- (void) updateUI{
    self.accountButton.hidden = TRUE;
    self.headerImageView.image = nil;
    self.avatarImageView.image = [UIImage imageNamed:@"noco.png"];
    self.accountName.text = nil;
    self.segmentedControl.hidden = TRUE;
    [self.connectionButton setTitle:@"se connecter" forState:UIControlStateNormal];
    [[NLTOAuth sharedInstance] isAuthenticatedAfterRefreshTokenUse:^(BOOL authenticated) {
        if(authenticated){
            self.segmentedControl.hidden = FALSE;
            
            NSString* catalog = DEFAULT_CATALOG;
            NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
            if([settings objectForKey:@"SELECTED_CATALOG"]){
                catalog = [settings objectForKey:@"SELECTED_CATALOG"];
            }
            
            if([catalog compare:ALL_SUBSCRIPTED_CATALOG]==NSOrderedSame){
                self.segmentedControl.selectedSegmentIndex = 2;
            }else if([catalog compare:ALL_NOCO_CATALOG]==NSOrderedSame){
                self.segmentedControl.selectedSegmentIndex = 1;
            }else if(catalog != nil){
                self.segmentedControl.selectedSegmentIndex = 0;
            }

            self.accountName.text = @"Chargement ...";
            [self.connectionButton setTitle:@"se déconnecter" forState:UIControlStateNormal];
            [[NLTAPI sharedInstance] callAPI:@"users/init" withResultBlock:^(id result, NSError *error) {
                if([result isKindOfClass:[NSDictionary class]]&&[(NSDictionary*)result objectForKey:@"error"]){
                    error = [NSError errorWithDomain:@"NLTAPIDomain" code:500 userInfo:(NSDictionary*)result];
                }
                if(!error){
                    if(result&&[result isKindOfClass:[NSDictionary class]]&&[result objectForKey:@"user"]){
                        self.accountName.text = [[result objectForKey:@"user"] objectForKey:@"username"];
                    }
                    if(result&&[result isKindOfClass:[NSDictionary class]]&&[result objectForKey:@"banner"]){
                        [self.headerImageView sd_setImageWithURL:[NSURL URLWithString:[[result objectForKey:@"banner"] objectForKey:@"banner"]]];
                    }
                    if(result&&[result isKindOfClass:[NSDictionary class]]&&[result objectForKey:@"avatars"]){
                        [self.avatarImageView sd_setImageWithURL:[NSURL URLWithString:[[result objectForKey:@"avatars"] objectForKey:@"avatar_128"]]];
                    }
                }else{
                    [self disconnect:nil];
                }
            } withKey:self withCacheDuration:60*10];
        }
    }];
}

-(void)dealloc{
    [[NLTAPI sharedInstance] cancelCallsWithKey:self];
}

@end
