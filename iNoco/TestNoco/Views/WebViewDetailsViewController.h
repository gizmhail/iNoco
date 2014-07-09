//
//  WebViewDetailsViewController.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 07/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebViewDetailsViewController : UIViewController<UIWebViewDelegate>
@property (strong, nonatomic) IBOutlet UIWebView *webview;
@property (retain,nonatomic) NSString* urlStr;
@property (retain,nonatomic) NSString* localFile;
@property (assign,nonatomic) BOOL hideSafariButton;
@end
