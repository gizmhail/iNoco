//
//  WebViewDetailsViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 07/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "WebViewDetailsViewController.h"

@interface WebViewDetailsViewController ()

@end

@implementation WebViewDetailsViewController

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
    if(!self.localFile){
        if(self.urlStr){
            [self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.urlStr]]];
        }
    }else{
        NSString* content = [NSString stringWithContentsOfFile:self.localFile encoding:NSUTF8StringEncoding error:nil];
        [self.webview loadHTMLString:content baseURL:nil];
    }
    if(!self.hideSafariButton){
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"ouvrir dans Safari" style:UIBarButtonItemStylePlain target:self action:@selector(openInSafari)];
    }
}

-(void)openInSafari{
    NSString *currentURL = self.webview.request.URL.absoluteString;
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:currentURL]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)webViewDidFinishLoad:(UIWebView *)webView{
#warning TODO Add activity
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    NSLog(@"%@", error);
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

@end
