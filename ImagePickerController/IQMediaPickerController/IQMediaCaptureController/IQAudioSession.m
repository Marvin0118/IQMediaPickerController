//
//  IQAudioSession.m
//  ImagePickerController
//
//  Created by Iftekhar on 16/08/14.
//  Copyright (c) 2014 Iftekhar. All rights reserved.
//

#import "IQAudioSession.h"
#import "IQFileManager.h"
#import <AVFoundation/AVFoundation.h>

NSString *const IQMediaTypeAudio =   @"IQMediaTypeAudio";

@interface IQAudioSession ()<AVAudioRecorderDelegate>

@end

@implementation IQAudioSession
{
    NSURL *outputURL;
    AVAudioRecorder *audioRecorder;
    
    NSString *_previousSessionCategory;
    
    NSTimer *meteringTimer;
}
@synthesize recording = _recording;
@synthesize isRunning = _isRunning;

+(NSString*)storagePath
{
    return [IQFileManager IQTemporaryDirectory];
}

+(NSURL*)defaultRecordingURL
{
    return [NSURL fileURLWithPath:[[[self class] storagePath] stringByAppendingString:@"audio.m4a"]];
}

-(void)dealloc
{
    [meteringTimer invalidate];
    meteringTimer = nil;
    self.delegate = nil;
    audioRecorder.delegate = nil;
    [audioRecorder stop];
    audioRecorder = nil;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        NSURL *fileURL = [[self class] defaultRecordingURL];
        _isRunning = NO;
        
        // Define the recorder setting
        NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
        
        [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
        [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
        [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
        
        // Initiate and prepare the recorder
        audioRecorder = [[AVAudioRecorder alloc] initWithURL:fileURL settings:recordSetting error:nil];
        audioRecorder.delegate = self;
        audioRecorder.meteringEnabled = YES;
    }
    return self;
}

-(BOOL)isRunning
{
    return _isRunning;
}

-(void)startRunning
{
    _isRunning = YES;
    meteringTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateMeter) userInfo:nil repeats:YES];
}

-(void)stopRunning
{
    [audioRecorder stop];
    _isRunning = NO;

    [meteringTimer invalidate];
    meteringTimer = nil;
}

-(BOOL)isRecording
{
    return audioRecorder.isRecording;
}

- (void)startAudioRecording
{
    if (audioRecorder.recording == NO)
    {
        // Setup audio session
        AVAudioSession *session = [AVAudioSession sharedInstance];
        _previousSessionCategory = session.category;
        [session setCategory:AVAudioSessionCategoryRecord error:nil];
        
        [audioRecorder prepareToRecord];
        // Start recording
        [audioRecorder record];
    }
}

- (void)stopAudioRecording
{
    [audioRecorder stop];
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:_previousSessionCategory error:nil];

    [meteringTimer invalidate];
    meteringTimer = nil;
}

- (CGFloat)recordingDuration
{
    return audioRecorder.currentTime;
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)successful
{
    if (successful)
    {
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:recorder.url,IQMediaURL,IQMediaTypeAudio,IQMediaType, nil];

        if ([self.delegate respondsToSelector:@selector(audioSession:didFinishMediaWithInfo:error:)])
        {
            [self.delegate audioSession:self didFinishMediaWithInfo:dict error:nil];
        }
    }
    else
    {
        NSError *error = [NSError errorWithDomain:NSStringFromClass([self class]) code:1 userInfo:nil];
        
        if ([self.delegate respondsToSelector:@selector(audioSession:didFinishMediaWithInfo:error:)])
        {
            [self.delegate audioSession:self didFinishMediaWithInfo:nil error:error];
        }
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(audioSession:didFinishMediaWithInfo:error:)])
    {
        [self.delegate audioSession:self didFinishMediaWithInfo:nil error:error];
    }
}

- (void)updateMeter
{
    if ([self.delegate respondsToSelector:@selector(audioSession:didUpdateMeterLevel:)])
    {
        [audioRecorder updateMeters];
//        float levelInDb = [audioRecorder averagePowerForChannel:0];
//        levelInDb = levelInDb + 160;
//        
//        //Level will always be between 0 and 160 now
//        //Usually it will sit around 100 in quiet so we need to correct
//        levelInDb = MAX(levelInDb - 100,0);
        float levelInZeroToOne;// = levelInDb / 60;
        
        
        {
            float   minDecibels = -80.0f; // Or use -60dB, which I measured in a silent room.
            float   decibels    = [audioRecorder averagePowerForChannel:0];
            
            if (decibels < minDecibels)
            {
                levelInZeroToOne = 0.0f;
            }
            else if (decibels >= 0.0f)
            {
                levelInZeroToOne = 1.0f;
            }
            else
            {
                float   root            = 2.0f;
                float   minAmp          = powf(10.0f, 0.05f * minDecibels);
                float   inverseAmpRange = 1.0f / (1.0f - minAmp);
                float   amp             = powf(10.0f, 0.05f * decibels);
                float   adjAmp          = (amp - minAmp) * inverseAmpRange;
                
                levelInZeroToOne = powf(adjAmp, 1.0f / root);
            }
        }
        
        [self.delegate audioSession:self didUpdateMeterLevel:levelInZeroToOne];
    }
}

@end
