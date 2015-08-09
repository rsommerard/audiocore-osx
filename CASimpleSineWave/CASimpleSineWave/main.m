//
//  main.m
//  CASimpleSineWave
//
//  Created by Romain SOMMERARD on 09/08/2015.
//  Copyright (c) 2015 Romain SOMMERARD. All rights reserved.
//

#include <AudioToolbox/AudioToolbox.h>

#define sineFrequency 880.0


#pragma mark user-data struct

typedef struct MySineWavePlayer {
    AudioUnit outputUnit;
    double startingFrameCount;
} MySineWavePlayer;


#pragma mark callback function

OSStatus SineWaveRenderProc(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    printf ("SineWaveRenderProc needs %u frames at %f\n", (unsigned int)inNumberFrames, CFAbsoluteTimeGetCurrent());
    
    MySineWavePlayer *player = (MySineWavePlayer*)inRefCon;
    
    double j = player->startingFrameCount;
    double cycleLength = 44100. / sineFrequency;
    int frame = 0;
    for(frame = 0; frame < inNumberFrames; ++frame) {
        Float32 *data = (Float32*)ioData->mBuffers[0].mData;
        (data)[frame] = (Float32)sin(2 * M_PI * (j / cycleLength));
        // copy to right channel too
        data = (Float32*)ioData->mBuffers[1].mData;
        (data)[frame] = (Float32)sin(2 * M_PI * (j / cycleLength));
        
        j += 1.0;
        if(j > cycleLength)
            j -= cycleLength;
    }
    
    player->startingFrameCount = j;
    return noErr;
}


#pragma mark utility functions

static void CheckError(OSStatus error, const char *operation) {
    if(error == noErr)
        return;
    
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if(isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else {
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
    }
    
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    
    exit(1);
}

void CreateAndConnectOutputUnit(MySineWavePlayer *player) {
    // Generates a description that matches the output device (speakers)
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
    outputcd.componentSubType = kAudioUnitSubType_DefaultOutput;
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    AudioComponent comp = AudioComponentFindNext(NULL, &outputcd);
    if(comp == NULL) {
        printf("Can't get output unit");
        exit(-1);
    }
    CheckError(AudioComponentInstanceNew(comp, &player->outputUnit), "Couldn't open component for outputUnit");
    
    // Register the render callback
    AURenderCallbackStruct input;
    input.inputProc = SineWaveRenderProc;
    input.inputProcRefCon = &player;
    CheckError(AudioUnitSetProperty(player->outputUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &input, sizeof(input)), "AudioUnitSetProperty failed");
    
    // Initialize the unit
    CheckError(AudioUnitInitialize(player->outputUnit), "Couldn't initialize output unit");
}


int main(int argc, const char *argv[]) {
    MySineWavePlayer player = {0};
    
    // Set up output unit and callback
    CreateAndConnectOutputUnit(&player);
    
    // Start playing
    CheckError(AudioOutputUnitStart(player.outputUnit), "Couldn't start output unit");
    
    // Play for 5 seconds
    sleep(5);
    
    // Clean up
    AudioOutputUnitStop(player.outputUnit);
    AudioUnitUninitialize(player.outputUnit);
    AudioComponentInstanceDispose(player.outputUnit);
    
    return 0;
}
