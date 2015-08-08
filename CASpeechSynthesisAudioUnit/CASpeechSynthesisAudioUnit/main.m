//
//  main.m
//  CASpeechSynthesisAudioUnit
//
//  Created by Romain SOMMERARD on 07/08/2015.
//  Copyright (c) 2015 Romain SOMMERARD. All rights reserved.
//

#include <AudioToolbox/AudioToolbox.h>
#include <ApplicationServices/ApplicationServices.h>

#define PART_II


#pragma mark user-data struct

typedef struct MyAUGraphPlayer {
    AUGraph graph;
    AudioUnit speechAU;
} MyAUGraphPlayer;


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

void CreateMyAUGraph(MyAUGraphPlayer *player) {
    // Create a new AUGraph
    
    CheckError(NewAUGraph(&player->graph), "NewAUGraph failed");
    
    
    // Generates a description that matches our output device (speakers)
    
    AudioComponentDescription outputcd = {0};
    outputcd.componentType = kAudioUnitType_Output;
    outputcd.componentSubType = kAudioUnitSubType_DefaultOutput;
    outputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    
    // Adds a node with above description to the graph
    
    AUNode outputNode;
    CheckError(AUGraphAddNode(player->graph, &outputcd, &outputNode), "AUGraphAddNode[kAudioUnitSubType_DefaultOutput] failed");
    
    
    // Generates a description that will match a generator AU of type: speech synthesizer
    
    AudioComponentDescription speechcd = {0};
    speechcd.componentType = kAudioUnitType_Generator;
    speechcd.componentSubType = kAudioUnitSubType_SpeechSynthesis;
    speechcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    
    // Adds a node with above description to the graph
    
    AUNode speechNode;
    CheckError(AUGraphAddNode(player->graph, &speechcd, &speechNode), "AUGraphAddNode[kAudioUnitSubType_SpeechSynthesis] failed");
    
    
    // Opening the graph opens all contained audio units, but does not allocate any resources yet
    
    CheckError(AUGraphOpen(player->graph), "AUGraphOpen failed");
    
    
    // Gets the reference to the AudioUnit object for the speech synthesis graph node
    
    CheckError(AUGraphNodeInfo(player->graph, speechNode, NULL, &player->speechAU), "AUGraphNodeInfo failed");
    

#ifdef PART_II
    // Generate a description that matches the reverb effect
    
    AudioComponentDescription reverbcd = {0};
    reverbcd.componentType = kAudioUnitType_Effect;
    reverbcd.componentSubType = kAudioUnitSubType_MatrixReverb;
    reverbcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    
    // Adds a node with the above description to the graph
    
    AUNode reverbNode;
    CheckError(AUGraphAddNode(player->graph, &reverbcd, &reverbNode), "AUGraphAddNode[kAudioUnitSubType_MatrixReverb] failed");
    
    
    // Connect the output source of the speech synthesizer AU to the input source of the reverb node
    
    CheckError(AUGraphConnectNodeInput(player->graph, speechNode, 0, reverbNode, 0), "AUGraphConnectNodeInput (speech to reverb) failed)");
    
    
    // Connect the output source of the reverb AU to the input source of the output node
    
    CheckError(AUGraphConnectNodeInput(player->graph, reverbNode, 0, outputNode, 0), "AUGraphConnectNodeInput (reverb to output) failed");
    
    
    // Get the reference to the AudioUnit object for the reverb graph node
    
    AudioUnit reverbUnit;
    CheckError(AUGraphNodeInfo(player->graph, reverbNode, NULL, &reverbUnit), "AUGraphNodeInfo failed");
    
    
    // Now initialize the graph (this causes the resources to be allocated)
    
    CheckError(AUGraphInitialize(player->graph), "AUGraphInitialize failed");
    
    
    // Set the reverb preset for room size
    UInt32 roomType = kReverbRoomType_LargeHall;
    CheckError(AudioUnitSetProperty(reverbUnit, kAudioUnitProperty_ReverbRoomType, kAudioUnitScope_Global, 0, &roomType, sizeof(UInt32)), "AudioUnitSetProperty[kAudioUnitProperty_ReverbRoomType] failed");
#else
    // Connect the output source of the speech synthesis AU to the input source of the output node
    
    CheckError(AUGraphConnectNodeInput(player->graph, speechNode, 0, outputNode, 0), "AUGraphConnectNodeInput");
    
    
    // Now initialize the graph (causes resources to be allocated)
    
    CheckError(AUGraphInitialize(player->graph), "AUGraphInitialize failed");
    
#endif
    
    CAShow(player->graph);
    
}

void PrepareSpeechAU(MyAUGraphPlayer *player) {
    SpeechChannel chan;
    
    UInt32 propsize = sizeof(SpeechChannel);
    CheckError(AudioUnitGetProperty(player->speechAU, kAudioUnitProperty_SpeechChannel, kAudioUnitScope_Global, 0, &chan, &propsize), "AudioUnitGetProperty[kAudioUnitProperty_SpeechChannel] failed");
    
    SpeakCFString(chan, CFSTR("hello world"), NULL);
}


#pragma mark main function

int main(int argc, const char *argv[]) {
    MyAUGraphPlayer player = {0};
    
    
    // Build a basic speech->speakers graph
    
    CreateMyAUGraph(&player);
    
    
    // Configure the speech synthesizer
    
    PrepareSpeechAU(&player);
    
    
    // Start playing
    
    CheckError(AUGraphStart(player.graph), "AUGraphStart failed");
    
    
    // Sleep a while so the speech can play out
    
    usleep((int)(10 * 1000. * 1000.));
    
    
    // Cleanup
    AUGraphStop(player.graph);
    AUGraphUninitialize(player.graph);
    AUGraphClose(player.graph);
    
    return 0;
}
