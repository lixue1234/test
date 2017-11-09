//
//  NetworkReachability.h
//  OneTargetGPad
//
//  Created by Jaffer on 17/4/27.
//  Copyright © 2017年 yitai. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, NetworkReachabilityStatus) {
    NetworkReachabilityStatusUnknown          = -1,
    NetworkReachabilityStatusNotReachable     = 0,
    NetworkReachabilityStatusReachableViaWWAN = 1,
    NetworkReachabilityStatusReachableViaWiFi = 2,
};

typedef void(^NetworkReacabilityStatusChangedBlock)(NetworkReachabilityStatus status);


@interface NetworkReachability : NSObject

+ (instancetype)sharedReachability;

+ (instancetype)reachabilityForDomain:(NSString *)domain;


- (void)startMonitoring;

- (void)stopMonitoring;

- (void)setReachabilityStatusChangedBlock:(NetworkReacabilityStatusChangedBlock)changeBlock;


@property (nonatomic, assign, readonly) NetworkReachabilityStatus networkReachabilityStatus;

@property (nonatomic, assign, readonly) BOOL isReachable;

@property (nonatomic, assign, readonly) BOOL isReachableViaWWAN;

@property (nonatomic, assign, readonly) BOOL isReachableViaWiFi;

@end
