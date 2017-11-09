//
//  NetworkReachability.m
//  OneTargetGPad
//
//  Created by Jaffer on 17/4/27.
//  Copyright © 2017年 yitai. All rights reserved.
//

#import "NetworkReachability.h"
#import <AFNetworking/AFNetworking.h>

@interface NetworkReachability ()

@property (nonatomic, strong) AFNetworkReachabilityManager *manager;

@end


@implementation NetworkReachability

#pragma mark dealloc
- (void)dealloc {
    NSLog(@"%s::******NetworkReachability dealloc",__func__);
}

#pragma mark init
+ (instancetype)sharedReachability {
    
    static NetworkReachability *instance = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [[NetworkReachability alloc] initWithDomain:nil];
    });
    
    return instance;
}

+ (instancetype)reachabilityForDomain:(NSString *)domain {
    
    NetworkReachability *instance = [[NetworkReachability alloc] initWithDomain:domain];
    
    return instance;
}

- (instancetype)initWithDomain:(NSString *)domian {
    
    if (self = [super init]) {
        
        if (!domian) {
            
            self.manager = [AFNetworkReachabilityManager sharedManager];
            
        } else {
            
            self.manager = [AFNetworkReachabilityManager managerForDomain:domian];
        }
    }
    
    return self;
}


#pragma mark getter
- (NetworkReachabilityStatus)networkReachabilityStatus {
    
    NetworkReachabilityStatus localStatus;
    switch (self.manager.networkReachabilityStatus) {
            
        case AFNetworkReachabilityStatusUnknown:
            localStatus = NetworkReachabilityStatusUnknown;
            break;
            
        case AFNetworkReachabilityStatusNotReachable:
            localStatus = NetworkReachabilityStatusNotReachable;
            break;
            
        case AFNetworkReachabilityStatusReachableViaWWAN:
            localStatus = NetworkReachabilityStatusReachableViaWWAN;
            break;
            
        case AFNetworkReachabilityStatusReachableViaWiFi:
            localStatus = NetworkReachabilityStatusReachableViaWiFi;
            break;
            
        default:
            break;
    }
    
    return localStatus;
}

- (BOOL)isReachable {
    
    return self.manager.isReachable;
}

- (BOOL)isReachableViaWWAN {

    return self.manager.isReachableViaWWAN;
}

- (BOOL)isReachableViaWiFi {
    
    return self.manager.isReachableViaWiFi;
}


#pragma mark control
- (void)startMonitoring {
    
    [self.manager startMonitoring];
}

- (void)stopMonitoring {
    
    [self.manager stopMonitoring];
}

- (void)setReachabilityStatusChangedBlock:(NetworkReacabilityStatusChangedBlock)changeBlock {
    
    if (changeBlock) {
        
        [self.manager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            
            NetworkReachabilityStatus localStatus;
            switch (status) {
                
                case AFNetworkReachabilityStatusUnknown:
                    localStatus = NetworkReachabilityStatusUnknown;
                    break;
                
                case AFNetworkReachabilityStatusNotReachable:
                    localStatus = NetworkReachabilityStatusNotReachable;
                    break;
                
                case AFNetworkReachabilityStatusReachableViaWWAN:
                    localStatus = NetworkReachabilityStatusReachableViaWWAN;
                    break;
                    
                case AFNetworkReachabilityStatusReachableViaWiFi:
                    localStatus = NetworkReachabilityStatusReachableViaWiFi;
                    break;
                    
                default:
                    break;
            }
            
            changeBlock(localStatus);
            
        }];
    }
}


@end
