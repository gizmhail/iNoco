//
//  NLTOAuthController.h
//  NoLibTV
//
//  Created by Sébastien POIVRE on 18/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifndef TVOS_NOCO
@interface NLTOAuthController : UIViewController <UIWebViewDelegate>
#else
@interface NLTOAuthController : UIViewController
#endif

@end
