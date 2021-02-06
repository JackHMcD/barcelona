//
//     Generated by class-dump 3.5 (64 bit) (Debug version compiled Oct 15 2018 10:31:50).
//
//     class-dump is Copyright (C) 1997-1998, 2000-2001, 2004-2015 by Steve Nygard.
//

#import <MediaPlayer/MPMusicPlayerController.h>

@class NSXPCConnection;

@interface MPMusicPlayerApplicationController : MPMusicPlayerController
{
    NSXPCConnection *_serviceConnection;
}


@property(readonly, nonatomic) NSXPCConnection *serviceConnection; // @synthesize serviceConnection=_serviceConnection;
- (id)_applicationAsyncServer;
- (void)_establishConnectionIfNeeded;
- (void)_clearConnection;
- (void)performQueueTransaction:(id)arg1 completionHandler:(id)arg2;
- (void)endGeneratingPlaybackNotifications;
- (void)beginGeneratingPlaybackNotifications;
- (void)dealloc;

@end
