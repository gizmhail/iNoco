//
//  ShowCollectionViewCell.m
//  iNoco
//
//  Created by Sébastien POIVRE on 22/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "ShowCollectionViewCell.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImageView+WebCache.h"
#include "commonSettings.h"

@implementation ShowCollectionViewCell

//Lazy may to bind views ;)
- (void)loadOutletWithTags{
    self.imageView = (UIImageView*)[self viewWithTag:100];
    self.title = (UILabel*)[self viewWithTag:110];
    self.subtitle = (UILabel*)[self viewWithTag:120];
    self.time = (UILabel*)[self viewWithTag:130];
    self.durationView = [self viewWithTag:200];
    self.durationBackground = [self viewWithTag:205];
    self.durationLabel = (UILabel*)[self viewWithTag:210];
    
    self.watchListView = [self viewWithTag:300];
    self.watchListBackground = [self viewWithTag:305];
    self.watchListButton = (UIButton*)[self viewWithTag:310];
    self.readView = [self viewWithTag:400];
    self.readBackground = [self viewWithTag:405];
    self.readButton = (UIButton*)[self viewWithTag:410];
    self.partnerImageView = (UIImageView*)[self viewWithTag:600];
}


- (id)initWithCoder:(NSCoder *)aDecoder{
    ShowCollectionViewCell* cell = [super initWithCoder:aDecoder];
    [cell loadOutletWithTags];
    [cell addEffects];
    [cell configureAccessibility];
    return cell;
}

- (id)initWithFrame:(CGRect)frame{
    ShowCollectionViewCell* cell = [super initWithFrame:frame];
    [cell loadOutletWithTags];
    [cell addEffects];
    [cell configureAccessibility];
    return cell;
}

- (void)addEffects{
    self.layer.borderColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.4].CGColor;
    [self.layer setCornerRadius:5.0f];
    self.layer.borderWidth= 1;
    [self.durationBackground.layer setCornerRadius:5.0f];
    [self.watchListBackground.layer setCornerRadius:5.0f];
    [self.readBackground.layer setCornerRadius:5.0f];
    [self.watchListButton.layer setCornerRadius:2.0f];
    [self.readButton.layer setCornerRadius:2.0f];
}

- (void)configureAccessibility{
    self.imageView.isAccessibilityElement = FALSE;
    self.title.isAccessibilityElement = FALSE;
    self.subtitle.isAccessibilityElement = FALSE;
    self.time.isAccessibilityElement = FALSE;
    self.durationView.isAccessibilityElement = FALSE;
    self.durationBackground.isAccessibilityElement = FALSE;
    self.durationLabel.isAccessibilityElement = FALSE;
    self.watchListView.isAccessibilityElement = FALSE;
    self.watchListBackground.isAccessibilityElement = FALSE;
    self.watchListButton.isAccessibilityElement = FALSE;
    self.readView.isAccessibilityElement = FALSE;
    self.readBackground.isAccessibilityElement = FALSE;
    self.readButton.isAccessibilityElement = FALSE;
    
    self.isAccessibilityElement = TRUE;

}

- (void)loadShow:(NLTShow*)show{
    self.accessibilityLabel = @"Chargement ...";
    self.accessibilityHint = @"";
    
    self.durationView.hidden = true;
    
    self.watchListView.hidden = TRUE;
    self.readView.hidden = TRUE;
    
    
    self.title.text = @"Chargement ...";
    self.subtitle.text = @"";
    self.time.text = @"";
    self.imageView.image = [UIImage imageNamed:@"noco.png"];
    self.imageView.backgroundColor = [UIColor whiteColor];
    
    self.partnerImageView.image = nil;
    
    if(show){
        self.accessibilityLabel = @"";
        self.accessibilityHint = @"";
        
        if([[NLTAPI sharedInstance].partnersByKey objectForKey:show.partner_key]){
            NSDictionary* partnerInfo = [[NLTAPI sharedInstance].partnersByKey objectForKey:show.partner_key];
            if([partnerInfo objectForKey:@"icon_128x72"]){
                [self.partnerImageView sd_setImageWithURL:[NSURL URLWithString:[partnerInfo objectForKey:@"icon_128x72"]] placeholderImage:nil];
            }
        }
        self.readView.hidden = FALSE;
        self.readButton.selected = show.mark_read;
        if(self.readButton.selected){
            self.readButton.backgroundColor = SELECTED_VALID_COLOR;
            self.accessibilityHint = @"Emission déjà vue";
        }else{
            self.readButton.backgroundColor = THEME_COLOR;
            self.accessibilityHint = @"Emission pas encore vue";
        }
        [[NLTAPI sharedInstance] isInQueueList:show withResultBlock:^(id result, NSError *error) {
            if(!error){
                self.watchListView.hidden = FALSE;
                self.watchListButton.selected = [result boolValue];
                if(self.watchListButton.selected){
                    self.accessibilityHint = [self.accessibilityHint stringByAppendingFormat:@". L'émission est dans la liste de lecture"];
                    self.watchListButton.backgroundColor = SELECTED_VALID_COLOR;
                }else{
                    self.accessibilityHint = [self.accessibilityHint stringByAppendingFormat:@". L'émission n'est pas dans la liste de lecture"];
                    self.watchListButton.backgroundColor = THEME_COLOR;
                }
            }
        } withKey:self];
        
        self.durationView.hidden = FALSE;
        self.durationLabel.text = [show durationString];
        if(show.family_TT){
            self.title.text = show.family_TT;
            self.accessibilityLabel = show.family_TT;
            if(show.episode_number && show.episode_number != 0){
                if(show.season_number > 1){
                    self.title.text = [self.title.text stringByAppendingFormat:@" - S%02iE%02i", show.season_number,show.episode_number];
                    self.accessibilityLabel = [self.accessibilityLabel stringByAppendingFormat:@" , saison %i, épisode %i", show.season_number,show.episode_number];
                }else{
                    self.title.text = [self.title.text stringByAppendingFormat:@" - %i", show.episode_number];
                    self.accessibilityLabel = [self.accessibilityLabel stringByAppendingFormat:@" , épisode %i",show.episode_number];
                }
            }
        }
        if(show.show_TT) {
            self.subtitle.text = show.show_TT;
            self.accessibilityLabel = [self.accessibilityLabel stringByAppendingFormat:@" , %@",show.show_TT];
            
        }
        if(show.broadcastDate) {
            NSDateFormatter *formater = [[NSDateFormatter alloc] init];
            [formater setDateFormat:@"dd MMM YYY - HH:mm"];
            self.time.text = [formater stringFromDate:show.broadcastDate];
            self.accessibilityLabel = [self.accessibilityLabel stringByAppendingFormat:@" , du %@", self.time.text];
        }
        if(show.screenshot_512x288){
#warning Find alternative screenshot when not available
            [self.imageView sd_setImageWithURL:[NSURL URLWithString:show.screenshot_512x288] placeholderImage:[UIImage imageNamed:@"noco.png"]];
        }
    }
}

- (void)loadFamily:(NLTFamily*)family{
    self.imageView.image = [UIImage imageNamed:@"noco.png"];
    self.title.text = @"Chargement ...";
    self.subtitle.text = @"";
    self.time.text = @"";
    self.accessibilityLabel = @"Chargement ...";
    self.accessibilityHint = @"";

    self.partnerImageView.image = nil;
    if(family){
        if([[NLTAPI sharedInstance].partnersByKey objectForKey:family.partner_key]){
            NSDictionary* partnerInfo = [[NLTAPI sharedInstance].partnersByKey objectForKey:family.partner_key];
            if([partnerInfo objectForKey:@"icon_128x72"]){
                [self.partnerImageView sd_setImageWithURL:[NSURL URLWithString:[partnerInfo objectForKey:@"icon_128x72"]] placeholderImage:nil];
            }
        }
        self.title.text = family.family_TT;
        self.subtitle.text = family.theme_name;
        self.accessibilityLabel = family.family_TT;
        self.accessibilityHint = family.theme_name;
        if(family.icon_512x288){
#warning Find alternative screenshot when not available
            [self.imageView sd_setImageWithURL:[NSURL URLWithString:family.icon_512x288] placeholderImage:[UIImage imageNamed:@"noco.png"]];
        }
    }
}

-(void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator{
    if(self.focused){
        self.backgroundColor = [UIColor colorWithRed:((float)0x2f)/255.0 green:((float)0xcb)/255. blue:((float)0xff)/255. alpha:1];
    }else{
        self.backgroundColor = [UIColor whiteColor];
    }
}
@end
