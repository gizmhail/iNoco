//
//  ConnectionViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 21/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "ConnectionViewController.h"
#import "NLTOAuth.h"

@interface ConnectionViewController ()
@end

@implementation ConnectionViewController

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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//TODO Remove
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if([sender respondsToSelector:@selector(connectedToNoco)]){
        self.sender = sender;
    }
}

- (IBAction)connect:(id)sender {
    __weak ConnectionViewController* weakSelf = self;

    [[NLTOAuth sharedInstance] authenticate:^(NSError *error) {
        if(!error){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf dismissViewControllerAnimated:YES completion:^{
                    if([weakSelf.sender respondsToSelector:@selector(connectedToNoco)]){
                        [weakSelf.sender connectedToNoco];
                    }
                }];
            });
        }else{
            if([error.domain compare:NSURLErrorDomain]==NSOrderedSame && error.code == -1009){
                if([weakSelf.sender respondsToSelector:@selector(noNetwordForAuth)]){
                    [weakSelf.sender noNetwordForAuth];
                }
                [weakSelf dismissViewControllerAnimated:YES completion:^{
                }];
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if([error.domain compare:@"NLTErrorDomain"]==NSOrderedSame && error.code == 666){
                    [[[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Les serveurs d'authentification de noco sont actuellement indisponibles. Veuillez réessayer plus tard, désolé pour ce dérangement." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
                }else{
                    [[[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de se connecter. Veuillez vérifier votre connection." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
                }
            });
        }
    }];
}

- (IBAction)accounCreation:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://noco.tv/login"]];
}

@end
