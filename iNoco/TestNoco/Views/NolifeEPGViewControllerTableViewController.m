//
//  NolifeEPGViewControllerTableViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 07/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NolifeEPGViewControllerTableViewController.h"
#import "NLTEPG.h"
#import "UIView+Toast.h"
#import "UIImageView+WebCache.h"
#import "NLTAPI.h"
#import "ShowViewController.h"
#import "WebViewDetailsViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "EPGTableViewCell.h"

@interface NolifeEPGViewControllerTableViewController (){
    BOOL firstFocusOnNowDone;
    BOOL cellSelected;
}
@property (retain,nonatomic)NSArray* epgDays;
@property (retain,nonatomic)NSDictionary* dayContents;
@end

@implementation NolifeEPGViewControllerTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    long sourceKind = [[[NSUserDefaults standardUserDefaults] objectForKey:@"PlanningSource"] longValue];
    if(sourceKind == 1){
        [[NLTEPG sharedInstance] switchToMugenCatalog];
    }

    [self loadShowsByDay:[NSArray array]];
    [super viewDidLoad];
   
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"maintenant" style:UIBarButtonItemStylePlain target:self action:@selector(scrollToNow)];
    [self.tableView setBackgroundView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"fond02.png"]]];
    self.tableView.backgroundView.contentMode = UIViewContentModeScaleAspectFill;
    self.tableView.backgroundView.alpha = 0.5;
    
    UISegmentedControl* planningSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Nolife",@"Nolife ∞"]];
    self.navigationItem.titleView = planningSegmentedControl;
    [planningSegmentedControl addTarget:self action:@selector(planningSourceChange) forControlEvents:UIControlEventValueChanged];
    planningSegmentedControl.selectedSegmentIndex = sourceKind;
}

-(void)viewDidAppear:(BOOL)animated{
    [self refreshEPG];
    
    if([self isNolifeMugenAvailable]){
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"∞" style:UIBarButtonItemStylePlain target:self action:@selector(launchNolifeMugen)];
    }else{
        self.navigationItem.leftBarButtonItem = nil;
    }

    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Source (Nolife / Nolife mugen)

- (void)refreshEPG{
    __weak NolifeEPGViewControllerTableViewController* weakSelf = self;
    [self.view makeToastActivity];
    
    [NLTAPI sharedInstance].networkActivityCount++;
    if([NLTAPI sharedInstance].handleNetworkActivityIndicator&&![[UIApplication sharedApplication] isNetworkActivityIndicatorVisible]){
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:TRUE];
    }
    
    [[NLTEPG sharedInstance] fetchEPG:^(NSArray *result, NSError *error) {
        [NLTAPI sharedInstance].networkActivityCount--;
        if([NLTAPI sharedInstance].handleNetworkActivityIndicator&&[[UIApplication sharedApplication] isNetworkActivityIndicatorVisible]){
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:FALSE];
        }
        
        [weakSelf.view hideToastActivity];
        if(error){
            [[[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de charger le guide des programmes de Nolife. Veuillez vérifier votre connection." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        }else{
            [self loadShowsByDay:[[NLTEPG sharedInstance] cachedEPG]];
        }
        [self.tableView reloadData];
        if(!firstFocusOnNowDone&&!error){
            firstFocusOnNowDone = TRUE;
            [self scrollToNow];
        }
    } withCacheDuration:60*10];
}

- (void)planningSourceChange{
    UISegmentedControl* planningSegmentedControl = (UISegmentedControl*)self.navigationItem.titleView;
    if(planningSegmentedControl.selectedSegmentIndex == 0){
        [[NLTEPG sharedInstance] switchToNolifeCatalog];
    }else if(planningSegmentedControl.selectedSegmentIndex == 1){
        [[NLTEPG sharedInstance] switchToMugenCatalog];
    }
    firstFocusOnNowDone = FALSE;
    self.epgDays = nil;
    [self.tableView reloadData];
    [self refreshEPG];
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithLong:planningSegmentedControl.selectedSegmentIndex] forKey:@"PlanningSource"];
    [[NSUserDefaults standardUserDefaults] synchronize];

}
#pragma mark Twitch Nolife mugen

- (BOOL)isNolifeMugenAvailable{
    NSURL *twitchURL = [NSURL URLWithString:@"twitch://channel/nolife"];
    if ([[UIApplication sharedApplication] canOpenURL:twitchURL]) {
        return true;
    }
    return false;
}

- (void)launchNolifeMugen{
    NSURL *twitchURL = [NSURL URLWithString:@"twitch://channel/nolife"];
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ){
        //Channel url seem to have a problem on iPad: we switch to stream url
        twitchURL = [NSURL URLWithString:@"twitch://open?stream=nolife"];
    }
    if ([[UIApplication sharedApplication] canOpenURL:twitchURL]) {
        [[UIApplication sharedApplication] openURL:twitchURL];
    }
    
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return [self.epgDays count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if([self.epgDays count]>section){
        NSString* header = [self.epgDays objectAtIndex:section];
        NSArray* dayContents = [self.dayContents objectForKey:header];
        return [dayContents count];
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NSDictionary* show = [self showAtIndexPath:indexPath];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EPGCell" forIndexPath:indexPath];
    UILabel* timeLabel = (UILabel*)[cell viewWithTag:100];
    UILabel* titleLabel = (UILabel*)[cell viewWithTag:110];
    UILabel* subtitleLabel = (UILabel*)[cell viewWithTag:120];
    UIImageView* imageView= (UIImageView*)[cell viewWithTag:130];
    
    /*
    UIView* backgroundView = [cell viewWithTag:300];
    backgroundView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    backgroundView.layer.borderWidth = 1;
    
    [backgroundView.layer setShadowColor:[UIColor lightGrayColor].CGColor];
    [backgroundView.layer setShadowOpacity:0.5];
    [backgroundView.layer setShadowRadius:0.2];
    [backgroundView.layer setShadowOffset:CGSizeMake(1, 1)];
    */

    NSString* imageUrl = nil;
    if([show objectForKey:@"screenshot"] && [show objectForKey:@"screenshot"] != [NSNull null] && [(NSString*)[show objectForKey:@"screenshot"] compare:@""] != NSOrderedSame){
        imageUrl = [show objectForKey:@"screenshot"];
    }
    if([show objectForKey:@"AdditionalScreenshot"] && [show objectForKey:@"AdditionalScreenshot"] != [NSNull null] && [(NSString*)[show objectForKey:@"AdditionalScreenshot"] compare:@""] != NSOrderedSame){
        imageUrl = [show objectForKey:@"AdditionalScreenshot"];
    }
    imageView.contentMode = UIViewContentModeScaleAspectFit;

    if(imageUrl){
        [imageView sd_setImageWithURL:[NSURL URLWithString:imageUrl] placeholderImage:[UIImage imageNamed:@"nolife.png"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            imageView.contentMode = UIViewContentModeScaleAspectFill;
        }];
    }

    if([show objectForKey:@"dateUTC"] && [show objectForKey:@"dateUTC"] != [NSNull null]){
        NSDateFormatter *formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        [formater setTimeZone:timeZone];
        NSDate* broadcastDate = [formater dateFromString:[show objectForKey:@"dateUTC"]];
        formater = [[NSDateFormatter alloc] init];
        [formater setDateFormat:@"dd MMM YYY - HH:mm"];
        timeLabel.text = [formater stringFromDate:broadcastDate];
    }
    
    if([show objectForKey:@"description"] && [show objectForKey:@"description"] != [NSNull null]){
        titleLabel.text = [show objectForKey:@"description"];
    }

    if([show objectForKey:@"detail"] && [show objectForKey:@"detail"] != [NSNull null]){
        subtitleLabel.text = [show objectForKey:@"detail"];
    }
    
    if(show && [[show objectForKey:@"NolifeOnlineURL"] isKindOfClass:[NSString class]]&&[(NSString*)[show objectForKey:@"NolifeOnlineURL"] compare:@""]!=NSOrderedSame){
        titleLabel.textColor = THEME_COLOR;
    }else{
        titleLabel.textColor = [UIColor lightGrayColor];
    }

    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
   [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
    if(cellSelected){
        //Call already pending
        return;
    }
    self.playlistContext = [self allEPGShowInfos];
    if(self.playlistType == nil){
        self.playlistType = @"émissions diffusées sur Nolife";
    }

    NSDictionary* show = [self showAtIndexPath:indexPath];
    self.playlistCurrentItem = show;
    if(show && [[show objectForKey:@"NolifeOnlineURL"] isKindOfClass:[NSString class]]&&[(NSString*)[show objectForKey:@"NolifeOnlineURL"] compare:@""]!=NSOrderedSame){
        NSString* nocoUrl = (NSString*)[show objectForKey:@"NolifeOnlineURL"];
        NSInteger nocoId = [[nocoUrl lastPathComponent] integerValue];
        cellSelected = true;
        [[NLTAPI sharedInstance] showWithId:nocoId withResultBlock:^(id result, NSError *error) {
            cellSelected = false;
            if(result){
                [self performSegueWithIdentifier:@"DisplayRecentShow" sender:result];
            }else if (error){
                [[[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de charger l'émission. Veuillez vérifier votre connection." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }
        } withKey:self];
    }else if([[show objectForKey:@"type"]isKindOfClass:[NSString class]]&&[(NSString*)[show objectForKey:@"type"] compare:@"Clip"]==NSOrderedSame){
        [self performSegueWithIdentifier:@"WebViewDetails" sender:show];
    
    }
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if([self.epgDays count]>section){
        NSString* header = [self.epgDays objectAtIndex:section];
        return header;
    }
    return @"";
}


- (NSMutableArray*)allEPGShowInfos{
    NSMutableArray* shows = [NSMutableArray array];
    for (NSString* header in self.epgDays) {
        NSArray* dayContents = [self.dayContents objectForKey:header];
        [shows addObjectsFromArray:dayContents];
    }
    //We reverse the array to have the most recent element first (like in other views : defualt playlist format espected)
    NSMutableArray* reversedShows = [NSMutableArray arrayWithCapacity:[shows count]];
    NSEnumerator*   reverseEnumerator = [shows reverseObjectEnumerator];
    for (id playlistItem in reverseEnumerator){
        [reversedShows addObject:playlistItem];
    }

    return reversedShows;
}


- (NSDictionary*)showAtIndexPath:(NSIndexPath *)indexPath{
    NSDictionary* show = nil;
    if([self.epgDays count]>indexPath.section){
        NSString* header = [self.epgDays objectAtIndex:indexPath.section];
        NSArray* dayContents = [self.dayContents objectForKey:header];
        if(dayContents&&[dayContents count]>indexPath.row){
            show = [dayContents objectAtIndex:indexPath.row];
        }
    }
    return show;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([[segue destinationViewController] isKindOfClass:[ShowViewController class]]&&[sender isKindOfClass:[NLTShow class]]){
        [(ShowViewController*)[segue destinationViewController] setShow:sender];
        if(self.playlistContext){
            [(ShowViewController*)[segue destinationViewController] setContextPlaylist:self.playlistContext];
            [(ShowViewController*)[segue destinationViewController] setPlaylistType:self.playlistType];
            [(ShowViewController*)[segue destinationViewController] setContextPlaylistCurrentItem:self.playlistCurrentItem];
            self.playlistContext = nil;
            self.playlistType = nil;
        }

    }else if([[segue destinationViewController] isKindOfClass:[WebViewDetailsViewController class]]){
        NSDictionary* show = (NSDictionary*)sender;
        NSString* urlStr = nil;
        /*
        if([[show objectForKey:@"url"] isKindOfClass:[NSString class]]&&[(NSString*)[show objectForKey:@"url"] compare:@""]!=NSOrderedSame){
            urlStr = [show objectForKey:@"url"];
            
        }else 
         */
        if([[show objectForKey:@"sub-title"] isKindOfClass:[NSString class]]&&[(NSString*)[show objectForKey:@"sub-title"] compare:@""]!=NSOrderedSame){
            urlStr = [@"http://google.fr/search?tbm=vid&q=" stringByAppendingString:[[show objectForKey:@"sub-title"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];

        }
        if(urlStr){
            [(WebViewDetailsViewController*)[segue destinationViewController] setUrlStr:urlStr];
        }
    }
}

-(void)dealloc{
    [[NLTAPI sharedInstance] cancelCallsWithKey:self];
}

#pragma mark 

- (void)loadShowsByDay:(NSArray*)epg{
    NSDateFormatter *formater = [[NSDateFormatter alloc] init];
    [formater setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [formater setTimeZone:timeZone];
    NSMutableArray* sections = [NSMutableArray array];
    NSMutableDictionary* sectionContents = [NSMutableDictionary dictionary];
    NSCalendar* calendar = [NSCalendar currentCalendar];
    for (NSDictionary* show in epg) {
        NSDate* broadcastDate = [formater dateFromString:[show objectForKey:@"dateUTC"]];
        NSDateComponents* components = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:broadcastDate];
        NSString* headerLabel = [NSString stringWithFormat:@"%02li/%02li/%li",(long)[components day], (long)[components month], (long)[components year]];
        if(![sections containsObject:headerLabel]){
            [sections addObject:headerLabel];
        }
        if(![sectionContents objectForKey:headerLabel]){
            [sectionContents setObject:[NSMutableArray array] forKey:headerLabel];
        }
        NSMutableArray* sectionContent = [sectionContents objectForKey:headerLabel];
        [sectionContent addObject:show];
    }
    self.epgDays = sections;
    self.dayContents = sectionContents;
}

- (void)scrollToNow{
    NSDate* now = [NSDate date];
    NSDateFormatter *formater = [[NSDateFormatter alloc] init];
    [formater setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [formater setTimeZone:timeZone];
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDateComponents* components = [calendar components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:now];
    NSString* header = [NSString stringWithFormat:@"%02li/%02li/%li",(long)[components day], (long)[components month], (long)[components year]];
    long section = 0;
    long row = 0;
    if([self.epgDays containsObject:header]){
        section = [self.epgDays indexOfObject:header];
        NSArray* dayContents = [self.dayContents objectForKey:header];
        long currentIndex = 0;
        long closestDistance = 10*3600;
        NSDictionary* bestShow = nil;
        for (NSDictionary* show in dayContents) {
            NSDate* broadcastDate = [formater dateFromString:[show objectForKey:@"dateUTC"]];
            if([broadcastDate timeIntervalSinceDate:now]<0 && ABS([broadcastDate timeIntervalSinceDate:now])<closestDistance){
                row = currentIndex;
                bestShow = show;
                closestDistance = ABS([broadcastDate timeIntervalSinceDate:now]);
            }
            currentIndex++;
        }
        NSLog(@"%@",bestShow);
    }
    if([self numberOfSectionsInTableView:self.tableView]>section && [self tableView:self.tableView numberOfRowsInSection:section]>row){
        NSIndexPath* indexPath = [NSIndexPath indexPathForRow:row inSection:section];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}


@end
