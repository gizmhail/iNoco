//
//  NLTOAuthLoginConnection.h
//  iNoco
//
//  Created by Sébastien POIVRE on 11/10/2015.
//  Copyright © 2015 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NLTOAuthLoginConnectionDelegate <NSObject>
- (void)loginConnectionSuccessWithCode:(NSString*)code;
- (void)loginConnectionFailWithError:(NSError*)error;
@end

@interface NLTOAuthLoginConnection : NSObject<NSURLConnectionDelegate>
@property(assign,nonatomic) id<NLTOAuthLoginConnectionDelegate>delegate;

-(void)connectWithLogin:(NSString*)username withPassword:(NSString*)password  withClientId:(NSString*)clientId;
@end
