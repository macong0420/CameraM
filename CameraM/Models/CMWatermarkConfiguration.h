//
//  CMWatermarkConfiguration.h
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class CMWatermarkConfiguration;

typedef NS_ENUM(NSInteger, CMWatermarkPreference) {
    CMWatermarkPreferenceOff,
    CMWatermarkPreferenceExposure,
    CMWatermarkPreferenceCoordinates,
    CMWatermarkPreferenceDate
};

typedef NS_ENUM(NSInteger, CMWatermarkPlacement) {
    CMWatermarkPlacementBottom,
    CMWatermarkPlacementMiddle
};

@interface CMWatermarkConfiguration : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, copy, nullable) NSString *frameIdentifier;
@property (nonatomic, copy, nullable) NSString *logoIdentifier;
@property (nonatomic, assign) BOOL logoEnabled;
@property (nonatomic, assign, getter=isCaptionEnabled) BOOL captionEnabled;
@property (nonatomic, copy) NSString *captionText;
@property (nonatomic, assign) CMWatermarkPreference preference;
@property (nonatomic, assign) CMWatermarkPlacement placement;
@property (nonatomic, assign, getter=isSignatureEnabled) BOOL signatureEnabled;
@property (nonatomic, copy) NSString *signatureText;
@property (nonatomic, copy) NSString *auxiliaryText;

+ (instancetype)defaultConfiguration;

@end

NS_ASSUME_NONNULL_END
