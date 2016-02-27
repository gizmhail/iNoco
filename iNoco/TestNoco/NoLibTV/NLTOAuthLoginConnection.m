//
//  NLTOAuthLoginConnection.m
//  iNoco
//
//  Created by Sébastien POIVRE on 11/10/2015.
//  Copyright © 2015 Sébastien Poivre. All rights reserved.
//

#import "NLTOAuthLoginConnection.h"
#import "NLTOAuth.h"

@interface NLTOAuthLoginConnection ()
@property (retain,nonatomic) NSURLConnection* connection;
@property (retain,nonatomic) NSMutableData* data;
@end

@implementation NLTOAuthLoginConnection

-(void)connectWithLogin:(NSString*)username withPassword:(NSString*)password withClientId:(NSString*)clientId{
    NSString* urlStr = [NSString stringWithFormat:@"%@/OAuth2/authorize.php?response_type=code&client_id=%@&state=STATE", NOCO_ENDPOINT, clientId];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setHTTPMethod:@"POST"];
    NSString *postString = [NSString stringWithFormat:@"username=%@&password=%@&login=1",username,password];
    [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];

    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
    if(self.connection){
        [self.connection start];
    }else{
        if([self.delegate respondsToSelector:@selector(loginConnectionFailWithError:)]){
            [self.delegate loginConnectionFailWithError:nil];
        }
    }
}

#pragma mark NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    self.data = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    [self.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
}

- (NSURLRequest *)connection: (NSURLConnection *)connection willSendRequest: (NSURLRequest *)request
            redirectResponse: (NSURLResponse *)redirectResponse{
    if (redirectResponse) {
        NSArray* urlParts = [[[request URL] absoluteString] componentsSeparatedByString:@"?"];
        NSString* params = [urlParts lastObject];
        NSArray* paramStrings = [params componentsSeparatedByString:@"&"];
        BOOL codeFound = false;
        for (NSString* paramString in paramStrings) {
            NSArray* paramInfo = [paramString componentsSeparatedByString:@"="];
            if ([paramInfo count] > 0) {
                NSString* key = [paramInfo objectAtIndex:0];
                NSString* value = ([paramInfo count] == 2) ? [paramInfo lastObject] : nil;
                if([key isEqualToString:@"code"] && value){
                    codeFound = true;
                    if([self.delegate respondsToSelector:@selector(loginConnectionSuccessWithCode:)]){
                        [self.delegate loginConnectionSuccessWithCode:value];
                    }
                }
            }
        }
        if(!codeFound){
            if([self.delegate respondsToSelector:@selector(loginConnectionFailWithError:)]){
                [self.delegate loginConnectionFailWithError:nil];
            }
        }
        
        [self.connection cancel];
        return nil;
    }
    return request;
}


@end
