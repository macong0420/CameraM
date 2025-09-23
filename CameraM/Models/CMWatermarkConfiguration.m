//
//  CMWatermarkConfiguration.m
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import "CMWatermarkConfiguration.h"
#import "CMWatermarkCatalog.h"

@implementation CMWatermarkConfiguration

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = YES;
        _frameIdentifier = CMWatermarkFrameIdentifierStudio;
        _logoIdentifier = @"logo.canon";
        _logoEnabled = YES;
        _captionEnabled = YES;
        _captionText = @"Mr.C | PHOTOGRAPHY 2025";
        _preference = CMWatermarkPreferenceExposure;
        _placement = CMWatermarkPlacementBottom;
        _signatureEnabled = NO;
        _signatureText = @"";
        _auxiliaryText = @"";
    }
    return self;
}

+ (instancetype)defaultConfiguration {
    return [[self alloc] init];
}

- (id)copyWithZone:(NSZone *)zone {
    CMWatermarkConfiguration *copy = [[[self class] allocWithZone:zone] init];
    copy.enabled = self.enabled;
    copy.frameIdentifier = [self.frameIdentifier copy];
    copy.logoIdentifier = [self.logoIdentifier copy];
    copy.logoEnabled = self.logoEnabled;
    copy.captionEnabled = self.captionEnabled;
    copy.captionText = [self.captionText copy];
    copy.preference = self.preference;
    copy.placement = self.placement;
    copy.signatureEnabled = self.signatureEnabled;
    copy.signatureText = [self.signatureText copy];
    copy.auxiliaryText = [self.auxiliaryText copy];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeBool:self.enabled forKey:@"enabled"];
    [coder encodeObject:self.frameIdentifier forKey:@"frameIdentifier"];
    [coder encodeObject:self.logoIdentifier forKey:@"logoIdentifier"];
    [coder encodeBool:self.logoEnabled forKey:@"logoEnabled"];
    [coder encodeBool:self.captionEnabled forKey:@"captionEnabled"];
    [coder encodeObject:self.captionText forKey:@"captionText"];
    [coder encodeInteger:self.preference forKey:@"preference"];
    [coder encodeInteger:self.placement forKey:@"placement"];
    [coder encodeBool:self.signatureEnabled forKey:@"signatureEnabled"];
    [coder encodeObject:self.signatureText forKey:@"signatureText"];
    [coder encodeObject:self.auxiliaryText forKey:@"auxiliaryText"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _enabled = [coder decodeBoolForKey:@"enabled"];
        NSString *decodedFrame = [coder decodeObjectOfClass:[NSString class] forKey:@"frameIdentifier"];
        NSString *decodedLogo = [coder decodeObjectOfClass:[NSString class] forKey:@"logoIdentifier"];
        NSString *decodedCaption = [coder decodeObjectOfClass:[NSString class] forKey:@"captionText"];
        NSString *decodedSignature = [coder decodeObjectOfClass:[NSString class] forKey:@"signatureText"];
        NSString *decodedAux = [coder decodeObjectOfClass:[NSString class] forKey:@"auxiliaryText"];

        _frameIdentifier = decodedFrame.length ? [decodedFrame copy] : CMWatermarkFrameIdentifierStudio;
        _logoIdentifier = decodedLogo.length ? [decodedLogo copy] : @"logo.canon";
        _logoEnabled = [coder decodeBoolForKey:@"logoEnabled"];
        BOOL hasCaptionFlag = [coder containsValueForKey:@"captionEnabled"];
        _captionEnabled = hasCaptionFlag ? [coder decodeBoolForKey:@"captionEnabled"] : YES;
        _captionText = decodedCaption.length ? [decodedCaption copy] : @"Mr.C | PHOTOGRAPHY 2025";
        _preference = (CMWatermarkPreference)[coder decodeIntegerForKey:@"preference"];
        _placement = (CMWatermarkPlacement)[coder decodeIntegerForKey:@"placement"];
        _signatureEnabled = [coder decodeBoolForKey:@"signatureEnabled"];
        _signatureText = decodedSignature.length ? [decodedSignature copy] : @"";
        _auxiliaryText = decodedAux.length ? [decodedAux copy] : @"";
    }
    return self;
}

@end
