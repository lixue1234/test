//
//  Requests.m
//  Pods
//
//  Created by Jaffer on 17/1/11.
//
//

#import "Requests.h"
#import "NetworkConfig.h"

@implementation BaseRequest

#pragma mark dealloc
- (void)dealloc {
    NSLog(@"%s",__func__);
}

#pragma mark init
+ (instancetype)request {
    return [[[self class] alloc] init];
}

- (instancetype)init {
    
    if (self = [super init]) {
        
        self.isCallbackOnMainThread = YES;
    }
    
    return self;
}

@end



@implementation UnitRequest

#pragma init
- (instancetype)init {
    if (self = [super init]) {
        [self setDefaultConfig];
    }
    return self;
}

- (void)setDefaultConfig {
    self.requestId = 0;
    
    self.requestTaskType = RequestTaskNormal;
    self.requestMethodType = RequestMethodPost;
    self.requestSerializerType = RequestSerializeRAW;
    self.responseSerializerType = ResponseSerializeJSON;
    
    self.needAppendGlobalParams = YES;
    self.needAppendGlobalHeaders = YES;
    self.needAppendGlobalServerHost = YES;
    
    self.retryTimes = 0;
}

@end




@interface GroupRequest()

@property (nonatomic, strong) NSMutableArray *responsesArray;
@property (nonatomic, strong) NSMutableArray *requestsArray;

@end


@implementation GroupRequest

#pragma mark init
- (instancetype)init {
    if (self = [super init]) {
        self.responsesArray = [NSMutableArray arrayWithCapacity:0];
        self.requestsArray = [NSMutableArray arrayWithCapacity:0];
    }
    return self;
}

#pragma mark getter
- (NSArray *)unitResponsesArray {
    return [self.responsesArray copy];
}

- (NSArray *)unitRequestsArray {
    return [self.requestsArray copy];
}


@end





@interface BatchRequest ()

@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@end

@implementation BatchRequest

#pragma mark init
- (instancetype)init {
    if (self = [super init]) {
        self.errorExists = NO;
        self.semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark public method
- (void)addRequests:(UnitRequest *)request, ... {
    
    if (request == nil) {
        return;
    }
    
    [self.requestsArray addObject:request];
    
    //定义一个指向个数可变的参数列表 指针
    //使参数列表指针arg_ptr指向函数参数列表中的第一个可选参数
    //返回参数列表中指针arg_ptr所指的参数，返回类型为type
    //并使指针arg_ptr指向参数列表中下一个参数
    //清空参数列表，并置参数指针arg_ptr无效。
    //说明：指针arg_ptr被置无效后，可以通过调用va_start()、va_copy()恢复arg_ptr
    
    va_list paramsPtr;
    
    va_start(paramsPtr, request);
    
    UnitRequest *varRequest = nil;
    while ((varRequest = va_arg(paramsPtr, id))) {
        [self.requestsArray addObject:varRequest];
    }
    
    va_end(paramsPtr);
    
    [self fillResponseContainerWithHolderObject];
}

- (void)addRequestsFromArray:(NSArray <UnitRequest *> *)requestArray {
    if (requestArray && requestArray.count > 0) {
        [self.requestsArray addObjectsFromArray:requestArray];
        [self fillResponseContainerWithHolderObject];
    }
}

- (void)finishedUnitRequest:(UnitRequest *)unitRequest resposne:(id)response error:(NSError *)error {
    
    //这个方法执行的线程会由于用户设置的不同的回调队列不同而不同
    //如果是 main queue，这会在主线程执行
    //否则，会在不同的子线程执行，
    //信号量方式限制
    
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    
    NSInteger requestIndex = [self.requestsArray indexOfObject:unitRequest];
    
    if (requestIndex != NSNotFound) {
        id resultObject = nil;
        if (response) {
            resultObject = response;
        } else if (error) {
            resultObject = error;
            self.errorExists = YES;
        }
        
        @try {
            
            [self.responsesArray replaceObjectAtIndex:requestIndex withObject:resultObject];
            
        } @catch (NSException *exception) {
            NSLog(@"%s===exception==%@",__func__, exception);
            self.errorExists = YES;
        }
    } else {
        
        self.errorExists = YES;
    }

    dispatch_semaphore_signal(self.semaphore);
}

#pragma mark tools
- (void)fillResponseContainerWithHolderObject {
    [self.responsesArray removeAllObjects];
    
    [self.requestsArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.responsesArray addObject:[NSNull null]];
    }];
}

@end






@interface ChainRequest ()

@property (nonatomic, strong) NSMutableArray *continueConfigBlocksArray;

@end


@implementation ChainRequest
#pragma mark init
- (instancetype)init {
    if (self = [super init]) {
        self.continueConfigBlocksArray = [NSMutableArray arrayWithCapacity:0];
    }
    return self;
}

#pragma public method
- (ChainRequest *)startWithRequest:(UnitRequestConfigBlock)configBlock {
    UnitRequest *request = [UnitRequest request];
    
    Block_Call(configBlock, request);
    
    [self addTask:request];
    
    return self;
}

- (ChainRequest *)then:(ChainRequestContinueConfigBlock)continueConfigBlock {
    NSAssert(continueConfigBlock, @"then:invalid !!! chain request continue config block");
    
    [self.continueConfigBlocksArray addObject:continueConfigBlock];
    
    return self;
}

- (UnitRequest *)getNextUnitRequestDependingOnCurrentRequest:(UnitRequest *)request response:(id)respons error:(NSError *)error executeState:(ExecuteState *)state {
    
    UnitRequest *nextRequest = nil;
    *state = ExecuteStateSuccss;

    //更新response
    NSInteger finishedRequestIndex = [self.requestsArray indexOfObject:request];
    if (finishedRequestIndex != NSNotFound) {
        if (respons) {
            [self updateTask:request withResponse:respons];
        } else if (error) {
            [self updateTask:request withResponse:error];
            
            //某个请求失败，直接返回
            *state = ExecuteStateFialure;
            return nil;
        }
    }
    
    ChainRequestContinueConfigBlock continueConfigBlock = [self.continueConfigBlocksArray firstObject];
    
    if (continueConfigBlock) {
        //存在下一个任务
        BOOL stop = NO;
        UnitRequest *newRequest = [UnitRequest request];
        
        continueConfigBlock(newRequest, respons, &stop);
        
        if (stop == NO) {
            nextRequest = newRequest;
            [self addTask:nextRequest];
        } else {
            *state = ExecuteStateFialure;
        }
        
        //移除cofig block
        [self.continueConfigBlocksArray removeObjectAtIndex:0];
    } else {
        //任务都已经完成
        *state = ExecuteStateSuccss;
        NSLog(@"all requests finished");
    }
    
    return nextRequest;
}

#pragma mark tools
- (void)addTask:(id)task {
    [self.requestsArray addObject:task];
    [self.responsesArray addObject:[NSNull null]];
}

- (void)updateTask:(UnitRequest *)request withResponse:(id)response {
    NSInteger taskIndex = [self.requestsArray indexOfObject:request];
    if (response) {
        [self.responsesArray replaceObjectAtIndex:taskIndex withObject:response];
    }
}

@end



@implementation UploadMultipartData

#pragma mark init

+ (instancetype)appendPartWithFileURL:(NSURL *)fileURL
                                 name:(NSString *)name
                             fileName:(NSString *)fileName
                             mimeType:(NSString *)mimeType {
    UploadMultipartData *partData = [UploadMultipartData new];
    
    partData.fileURL = fileURL;
    partData.name = name;
    partData.fileName = fileName;
    partData.mimeType = mimeType;
    
    return partData;
}

+ (instancetype)appendPartWithFileData:(NSData *)data
                                  name:(NSString *)name
                              fileName:(NSString *)fileName
                              mimeType:(NSString *)mimeType {
    UploadMultipartData *partData = [UploadMultipartData new];
    
    partData.fileData = data;
    partData.name = name;
    partData.fileName = fileName;
    partData.mimeType = mimeType;
    
    return partData;
}

@end

