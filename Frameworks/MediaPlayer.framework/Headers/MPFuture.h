//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Oct 15 2018 10:31:50).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

#import <objc/NSObject.h>

@class NSMapTable, NSString;
@protocol OS_dispatch_queue;

@interface MPFuture : NSObject
{
    NSObject *_accessQueue;
    _Bool _finalized;
    id _result;
    id _error;
    NSObject *_lazyBlockQueue;
    id _lazySyncBlock;
    id _lazyAsyncBlock;
    NSMapTable *_successBlocks;
    NSMapTable *_failureBlocks;
    NSMapTable *_completionBlocks;
    _Bool _finished;
    NSString *_name;
}

+ (id)futureWithName:(id)arg1 asyncBlock:(id)arg2 queue:(id)arg3;
+ (id)futureWithName:(id)arg1 asyncBlock:(id)arg2;
+ (id)futureWithName:(id)arg1 block:(id)arg2 queue:(id)arg3;
+ (id)futureWithName:(id)arg1 block:(id)arg2;
+ (id)futureWithName:(id)arg1 error:(id)arg2;
+ (id)futureWithName:(id)arg1 result:(id)arg2;
+ (id)calloutQueue;

@property(readonly, nonatomic, getter=isFinished) _Bool finished; // @synthesize finished=_finished;
@property(readonly, copy, nonatomic) NSString *name; // @synthesize name=_name;
- (void)_onQueue_finalizeWithResult:(id)arg1 error:(id)arg2;
- (void)_loadResultIfNeeded;
- (id)result:(id )arg1;
- (id)onCompletion:(id)arg1 queue:(id)arg2;
- (id)onCompletion:(id)arg1;
- (id)onFailure:(id)arg1 queue:(id)arg2;
- (id)onFailure:(id)arg1;
- (id)onSuccess:(id)arg1 queue:(id)arg2;
- (id)onSuccess:(id)arg1;
- (id)description;
- (id)initWithName:(id)arg1;

@end
