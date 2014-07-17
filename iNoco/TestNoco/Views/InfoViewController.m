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
@property(retain, nonatomic) NSArray* languageSegmentedEntriesValues;
@property(retain, nonatomic) NSArray* subtitleSegmentedEntriesValues;
@property(retain, nonatomic) NSArray* qualitySegmentedEntriesValues;

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
#warning TODO Fetch value from backend and fill segmented controls accordingly
    self.languageSegmentedEntriesValues = @[@"V.O.", @"en", @"fr", @"ja"];
    self.subtitleSegmentedEntriesValues = @[@"none", @"en", @"fr", @"ja"];
    self.qualitySegmentedEntriesValues = @[@"LQ", @"HQ", @"TV", @"HD_720", @"HD_1080"];

    
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

- (IBAction)qualityChanged:(id)sender {
    if([self.qualitySegmentedEntriesValues count]>self.qualitySegmentedControl.selectedSegmentIndex){
        NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
        NSString* value = [self.qualitySegmentedEntriesValues objectAtIndex:self.qualitySegmentedControl.selectedSegmentIndex];
        [NLTAPI sharedInstance].preferedQuality = value;
        [settings setObject:value forKey:@"preferedQuality"];
        [settings synchronize];
    }else{
#ifdef DEBUG
        NSLog(@"Problem with segemented control");
#endif
    }
}

- (IBAction)languageChanged:(id)sender {
    if([self.languageSegmentedEntriesValues count]>self.languageSegementedControl.selectedSegmentIndex){
        NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
        NSString* value = [self.languageSegmentedEntriesValues objectAtIndex:self.languageSegementedControl.selectedSegmentIndex];
        [NLTAPI sharedInstance].preferedLanguage = value;
        [settings setObject:value forKey:@"preferedLanguage"];
        [settings synchronize];
    }else{
#ifdef DEBUG
        NSLog(@"Problem with segemented control");
#endif
    }
}

- (IBAction)subtitleChanged:(id)sender {
    if([self.subtitleSegmentedEntriesValues count]>self.subtitleSegementedControl.selectedSegmentIndex){
        NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
        NSString* value = [self.subtitleSegmentedEntriesValues objectAtIndex:self.subtitleSegementedControl.selectedSegmentIndex];
        [NLTAPI sharedInstance].preferedSubtitleLanguage = value;
        [settings setObject:value forKey:@"preferedSubtitleLanguage"];
        [settings synchronize];
    }else{
#ifdef DEBUG
        NSLog(@"Problem with segemented control");
#endif
    }
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
    self.settingsZone.hidden = TRUE;
    [self.connectionButton setTitle:@"se connecter" forState:UIControlStateNormal];
    [[NLTOAuth sharedInstance] isAuthenticatedAfterRefreshTokenUse:^(BOOL authenticated) {
        if(authenticated){
            self.settingsZone.hidden = FALSE;
            NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
            //Catalog
            NSString* catalog = DEFAULT_CATALOG;
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
            
            //Language
            NSString* preferedLanguage = DEFAULT_LANGUAGE;//Use VO
            if([settings objectForKey:@"preferedLanguage"]){
                preferedLanguage = [settings objectForKey:@"preferedLanguage"];
            }
            self.languageSegementedControl.selectedSegmentIndex = [self.languageSegmentedEntriesValues indexOfObject:preferedLanguage];
            
            //Subtitle
            NSString* preferedSubtitleLanguage = DEFAULT_SUBTITLE_LANGUAGE;
            if([settings objectForKey:@"preferedSubtitleLanguage"]){
                preferedSubtitleLanguage = [settings objectForKey:@"preferedSubtitleLanguage"];
            }
            self.subtitleSegementedControl.selectedSegmentIndex = [self.subtitleSegmentedEntriesValues indexOfObject:preferedSubtitleLanguage];
            
            //Quality
            NSString* preferedQuality = DEFAULT_QUALITY;
            if([settings objectForKey:@"preferedQuality"]){
                preferedQuality = [settings objectForKey:@"preferedQuality"];
            }
            self.qualitySegmentedControl.selectedSegmentIndex = [self.qualitySegmentedEntriesValues indexOfObject:preferedQuality];

            

            self.accountName.text = @"Chargement ...";
            [self.connectionButton setTitle:@"se déconnecter" forState:UIControlStateNormal];
            [[NLTAPI sharedInstance] userAccountInfoWithResultBlock:^(id result, NSError *error) {
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
            } withKey:self];
        }
    }];
}

-(void)dealloc{
    [[NLTAPI sharedInstance] cancelCallsWithKey:self];
}

@end
