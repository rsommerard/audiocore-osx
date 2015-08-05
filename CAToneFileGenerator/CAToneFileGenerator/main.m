//
//  main.m
//  CAToneFileGenerator
//
//  Created by Romain SOMMERARD on 05/08/2015.
//  Copyright (c) 2015 Romain SOMMERARD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define SAMPLE_RATE 44100
#define DURATION 5.0
#define FILENAME_FORMAT @"%0.3f-square.aif"

int main(int argc, const char * argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if(argc < 2) {
        printf("Usage: CAToneFileGenerator n\n(where n is tone in Hz)");
        return -1;
    }
    
    double hz = atof(argv[1]);
    assert(hz > 0);
    NSLog(@"generating %f hz tone", hz);
    
    NSString *fileName = [NSString stringWithFormat: FILENAME_FORMAT, hz];
    NSString *filePath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent: fileName];
    NSURL *fileURL = [NSURL fileURLWithPath: filePath];
    
    // Prepare the format
    AudioStreamBasicDescription asdb;
    memset(&asdb, 0, sizeof(asdb));
    
    asdb.mSampleRate = SAMPLE_RATE;
    asdb.mFormatID = kAudioFormatLinearPCM;
    asdb.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asdb.mBitsPerChannel = 16;
    asdb.mChannelsPerFrame = 1;
    asdb.mFramesPerPacket = 1;
    asdb.mBytesPerFrame = 2;
    asdb.mBytesPerPacket = 2;
    
    // Set up the file
    AudioFileID audioFile;
    OSStatus audioErr = noErr;
    audioErr = AudioFileCreateWithURL((CFURLRef)fileURL, kAudioFileAIFFType, &asdb, kAudioFileFlags_EraseFile, &audioFile);
    assert(audioErr == noErr);
    
    // Start writing samples
    long maxSampleCount = SAMPLE_RATE * DURATION;
    long sampleCount = 0;
    UInt32 bytesToWrite = 2;
    double wavelengthInSamples = SAMPLE_RATE / hz;
    
    while(sampleCount < maxSampleCount) {
        for(int i = 0; i < wavelengthInSamples; i++) {
            // Square wave
            SInt16 sample;
            if(i < wavelengthInSamples/2) {
                sample = CFSwapInt16HostToBig(SHRT_MAX);
            } else {
                sample = CFSwapInt16HostToBig(SHRT_MIN);
            }
            
            audioErr = AudioFileWriteBytes(audioFile, false, sampleCount*2, &bytesToWrite, &sample);
            assert(audioErr == noErr);
            sampleCount++;
        }
    }
    
    audioErr = AudioFileClose(audioFile);
    assert(audioErr == noErr);
    NSLog(@"wrote %ld samples", sampleCount);
    
    [pool drain];
    return 0;
}
