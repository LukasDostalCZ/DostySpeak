#include "IosTts.h"

#import <AVFoundation/AVFoundation.h>

namespace {
    AVSpeechSynthesizer *synthesizer()
    {
        static AVSpeechSynthesizer *synth = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            synth = [[AVSpeechSynthesizer alloc] init];
        });
        return synth;
    }
}

void IosTts::speak(const QString &text, const QString &language, float rate, float pitch)
{
    NSString *nsText = text.toNSString();
    NSString *nsLanguage = language.toNSString();

    AVSpeechSynthesizer *synth = synthesizer();
    if ([synth isSpeaking]) [synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];

    AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:nsText];
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:nsLanguage];
    utterance.rate = rate;
    utterance.pitchMultiplier = pitch;
    [synth speakUtterance:utterance];
}

void IosTts::stop()
{
    AVSpeechSynthesizer *synth = synthesizer();
    if ([synth isSpeaking]) [synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}
