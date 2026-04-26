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

- (CMWatermarkMetadataOptions)metadataOptionsFromLegacyPreference {
    CMWatermarkMetadataOptions options = CMWatermarkMetadataOptionsNone;
    if (self.preferenceOptions != CMWatermarkPreferenceOptionsNone) {
        if (self.preferenceOptions & CMWatermarkPreferenceOptionsExposure) {
            options |= (CMWatermarkMetadataOptionsLens |
                        CMWatermarkMetadataOptionsShutter |
                        CMWatermarkMetadataOptionsAperture);
        }
        if (self.preferenceOptions & CMWatermarkPreferenceOptionsCoordinates) {
            options |= CMWatermarkMetadataOptionsLocation;
        }
        if (self.preferenceOptions & CMWatermarkPreferenceOptionsDate) {
            options |= CMWatermarkMetadataOptionsDate;
        }
        return options;
    }

    switch (self.preference) {
        case CMWatermarkPreferenceExposure:
            return (CMWatermarkMetadataOptionsLens |
                    CMWatermarkMetadataOptionsShutter |
                    CMWatermarkMetadataOptionsAperture);
        case CMWatermarkPreferenceCoordinates:
            return CMWatermarkMetadataOptionsLocation;
        case CMWatermarkPreferenceDate:
            return CMWatermarkMetadataOptionsDate;
        case CMWatermarkPreferenceOff:
        default:
            return CMWatermarkMetadataOptionsNone;
    }
}

- (void)syncLegacyPreferenceFromMetadataOptions {
    BOOL hasExposureGroup = ((self.metadataOptions &
                             (CMWatermarkMetadataOptionsLens |
                              CMWatermarkMetadataOptionsShutter |
                              CMWatermarkMetadataOptionsAperture)) != 0);
    BOOL hasLocation = (self.metadataOptions & CMWatermarkMetadataOptionsLocation) != 0;
    BOOL hasDate = (self.metadataOptions & CMWatermarkMetadataOptionsDate) != 0;

    CMWatermarkPreferenceOptions legacyOptions = CMWatermarkPreferenceOptionsNone;
    if (hasExposureGroup) {
        legacyOptions |= CMWatermarkPreferenceOptionsExposure;
    }
    if (hasLocation) {
        legacyOptions |= CMWatermarkPreferenceOptionsCoordinates;
    }
    if (hasDate) {
        legacyOptions |= CMWatermarkPreferenceOptionsDate;
    }

    self.preferenceOptions = legacyOptions;
    if (legacyOptions == CMWatermarkPreferenceOptionsNone) {
        self.preference = CMWatermarkPreferenceOff;
    } else if (hasExposureGroup) {
        self.preference = CMWatermarkPreferenceExposure;
    } else if (hasLocation) {
        self.preference = CMWatermarkPreferenceCoordinates;
    } else if (hasDate) {
        self.preference = CMWatermarkPreferenceDate;
    }
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
        _preferenceOptions = CMWatermarkPreferenceOptionsExposure;
        _placement = CMWatermarkPlacementBottom;
        _signatureEnabled = NO;
        _signatureText = @"";
        _auxiliaryText = @"";
        _metadataOptions = (CMWatermarkMetadataOptionsLens |
                            CMWatermarkMetadataOptionsShutter |
                            CMWatermarkMetadataOptionsAperture);
        _watermarkAnchor = CMWatermarkAnchorBottomLeft;
        _textFontName = @"Garamond Premier Pro";
        [self syncLegacyPreferenceFromMetadataOptions];
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
    copy.preferenceOptions = self.preferenceOptions;
    copy.placement = self.placement;
    copy.signatureEnabled = self.signatureEnabled;
    copy.signatureText = [self.signatureText copy];
    copy.auxiliaryText = [self.auxiliaryText copy];
    copy.metadataOptions = self.metadataOptions;
    copy.watermarkAnchor = self.watermarkAnchor;
    copy.textFontName = [self.textFontName copy];
    [copy syncLegacyPreferenceFromMetadataOptions];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [self syncLegacyPreferenceFromMetadataOptions];
    [coder encodeBool:self.enabled forKey:@"enabled"];
    [coder encodeObject:self.frameIdentifier forKey:@"frameIdentifier"];
    [coder encodeObject:self.logoIdentifier forKey:@"logoIdentifier"];
    [coder encodeBool:self.logoEnabled forKey:@"logoEnabled"];
    [coder encodeBool:self.captionEnabled forKey:@"captionEnabled"];
    [coder encodeObject:self.captionText forKey:@"captionText"];
    [coder encodeInteger:self.preference forKey:@"preference"];
    [coder encodeInteger:self.preferenceOptions forKey:@"preferenceOptions"];
    [coder encodeInteger:self.placement forKey:@"placement"];
    [coder encodeBool:self.signatureEnabled forKey:@"signatureEnabled"];
    [coder encodeObject:self.signatureText forKey:@"signatureText"];
    [coder encodeObject:self.auxiliaryText forKey:@"auxiliaryText"];
    [coder encodeInteger:self.metadataOptions forKey:@"metadataOptions"];
    [coder encodeInteger:self.watermarkAnchor forKey:@"watermarkAnchor"];
    [coder encodeObject:self.textFontName forKey:@"textFontName"];
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
        NSString *decodedFontName = [coder decodeObjectOfClass:[NSString class] forKey:@"textFontName"];

        _frameIdentifier = decodedFrame.length ? [decodedFrame copy] : CMWatermarkFrameIdentifierStudio;
        _logoIdentifier = decodedLogo.length ? [decodedLogo copy] : @"logo.canon";
        _logoEnabled = [coder decodeBoolForKey:@"logoEnabled"];
        BOOL hasCaptionFlag = [coder containsValueForKey:@"captionEnabled"];
        _captionEnabled = hasCaptionFlag ? [coder decodeBoolForKey:@"captionEnabled"] : YES;
        _captionText = decodedCaption.length ? [decodedCaption copy] : @"Mr.C | PHOTOGRAPHY 2025";
        _preference = (CMWatermarkPreference)[coder decodeIntegerForKey:@"preference"];
        _preferenceOptions = (CMWatermarkPreferenceOptions)[coder decodeIntegerForKey:@"preferenceOptions"];
        if (_preferenceOptions == 0) {
            _preferenceOptions = CMWatermarkPreferenceOptionsExposure; // 默认值兼容旧版本
        }
        _placement = (CMWatermarkPlacement)[coder decodeIntegerForKey:@"placement"];
        _signatureEnabled = [coder decodeBoolForKey:@"signatureEnabled"];
        _signatureText = decodedSignature.length ? [decodedSignature copy] : @"";
        _auxiliaryText = decodedAux.length ? [decodedAux copy] : @"";
        _watermarkAnchor = [coder containsValueForKey:@"watermarkAnchor"]
                               ? (CMWatermarkAnchor)[coder decodeIntegerForKey:@"watermarkAnchor"]
                               : CMWatermarkAnchorBottomLeft;
        if (_watermarkAnchor < CMWatermarkAnchorBottomLeft ||
            _watermarkAnchor > CMWatermarkAnchorBottomCenter) {
            _watermarkAnchor = CMWatermarkAnchorBottomLeft;
        }
        _textFontName = decodedFontName.length ? [decodedFontName copy] : @"Garamond Premier Pro";

        if ([coder containsValueForKey:@"metadataOptions"]) {
            _metadataOptions = (CMWatermarkMetadataOptions)[coder decodeIntegerForKey:@"metadataOptions"];
        } else {
            _metadataOptions = [self metadataOptionsFromLegacyPreference];
        }
        [self syncLegacyPreferenceFromMetadataOptions];
    }
    return self;
}

@end
