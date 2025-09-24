//
//  CMWatermarkCatalog.m
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import "CMWatermarkCatalog.h"
#import "CMWatermarkConfiguration.h"

NSString * const CMWatermarkFrameIdentifierNone = @"frame.none";
NSString * const CMWatermarkFrameIdentifierStudio = @"frame.studio";
NSString * const CMWatermarkFrameIdentifierPolaroid = @"frame.polaroid";
NSString * const CMWatermarkFrameIdentifierMinimal = @"frame.minimal";

NSString * const CMWatermarkLogoIdentifierNone = @"logo.none";

@interface CMWatermarkFrameDescriptor ()

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *overlayAssetName;
@property (nonatomic, copy, nullable) NSString *backgroundAssetName;
@property (nonatomic, copy, nullable) NSString *previewAssetName;
@property (nonatomic, assign) CGFloat bottomExpansionRatio;
@property (nonatomic, assign) CGFloat overlayInsetsRatio;
@property (nonatomic, assign) UIEdgeInsets contentInsetsRatio;
@property (nonatomic, assign) BOOL overlayDrawsAbovePhoto;
@property (nonatomic, assign) CGSize photoContentScale;
@property (nonatomic, assign) CGPoint photoContentOffset;
@property (nonatomic, assign) CGFloat photoCornerRadiusRatio;
@property (nonatomic, assign) BOOL allowsLogoEditing;
@property (nonatomic, assign) BOOL allowsParameterEditing;
@property (nonatomic, assign) BOOL allowsSignatureEditing;
@property (nonatomic, assign) NSInteger enforcedPreferenceRawValue;
@property (nonatomic, assign) CGRect footerContentRect;

@end

@implementation CMWatermarkFrameDescriptor

+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                              displayName:(NSString *)displayName
                         overlayAssetName:(nullable NSString *)overlayAssetName
                      backgroundAssetName:(nullable NSString *)backgroundAssetName
                      bottomExpansionRatio:(CGFloat)bottomExpansionRatio
                          previewAssetName:(nullable NSString *)previewAssetName
                        overlayInsetsRatio:(CGFloat)overlayInsetsRatio
                       contentInsetsRatio:(UIEdgeInsets)contentInsetsRatio
                     photoContentScale:(CGSize)photoContentScale
                    photoContentOffset:(CGPoint)photoContentOffset
                 photoCornerRadiusRatio:(CGFloat)photoCornerRadiusRatio {
    CMWatermarkFrameDescriptor *descriptor = [[self alloc] init];
    descriptor.identifier = identifier;
    descriptor.displayName = displayName;
    descriptor.overlayAssetName = overlayAssetName;
    descriptor.backgroundAssetName = backgroundAssetName;
    descriptor.previewAssetName = previewAssetName;
    descriptor.bottomExpansionRatio = bottomExpansionRatio;
    descriptor.overlayInsetsRatio = overlayInsetsRatio;
    descriptor.contentInsetsRatio = contentInsetsRatio;
    descriptor.overlayDrawsAbovePhoto = YES;
    descriptor.photoContentScale = photoContentScale;
    descriptor.photoContentOffset = photoContentOffset;
    descriptor.photoCornerRadiusRatio = photoCornerRadiusRatio;
    descriptor.allowsLogoEditing = YES;
    descriptor.allowsParameterEditing = YES;
    descriptor.allowsSignatureEditing = YES;
    descriptor.enforcedPreferenceRawValue = NSNotFound;
    descriptor.footerContentRect = CGRectNull;
    return descriptor;
}

@end

@interface CMWatermarkLogoDescriptor ()

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy, nullable) NSString *assetName;
@property (nonatomic, assign) BOOL prefersTemplateRendering;

@end

@implementation CMWatermarkLogoDescriptor

+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                              displayName:(NSString *)displayName
                                 assetName:(nullable NSString *)assetName
                 prefersTemplateRendering:(BOOL)prefersTemplateRendering {
    CMWatermarkLogoDescriptor *descriptor = [[self alloc] init];
    descriptor.identifier = identifier;
    descriptor.displayName = displayName;
    descriptor.assetName = assetName;
    descriptor.prefersTemplateRendering = prefersTemplateRendering;
    return descriptor;
}

@end

@implementation CMWatermarkCatalog

+ (NSArray<CMWatermarkFrameDescriptor *> *)frameDescriptors {
    static NSArray<CMWatermarkFrameDescriptor *> *frames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CMWatermarkFrameDescriptor *none = [CMWatermarkFrameDescriptor descriptorWithIdentifier:CMWatermarkFrameIdentifierNone
                                                                                      displayName:@"None"
                                                                                 overlayAssetName:nil
                                                                              backgroundAssetName:nil
                                                                              bottomExpansionRatio:0.0
                                                                                  previewAssetName:nil
                                                                                overlayInsetsRatio:0.0
                                                                               contentInsetsRatio:UIEdgeInsetsZero
                                                                             photoContentScale:CGSizeMake(1.0, 1.0)
                                                                            photoContentOffset:CGPointZero
                                                                         photoCornerRadiusRatio:0.0];

        CMWatermarkFrameDescriptor *studio = [CMWatermarkFrameDescriptor descriptorWithIdentifier:CMWatermarkFrameIdentifierStudio
                                                                                      displayName:@"Studio"
                                                                                 overlayAssetName:nil
                                                                              backgroundAssetName:@"sign_b"
                                                                              bottomExpansionRatio:0.35
                                                                                  previewAssetName:@"master_xiangkuang"
                                                                                overlayInsetsRatio:0.0
                                                                               contentInsetsRatio:UIEdgeInsetsMake(0.02, 0.02, 0.37, 0.02)
                                                                             photoContentScale:CGSizeMake(0.96, 0.76)
                                                                            photoContentOffset:CGPointMake(0.02, 0.02)
                                                                         photoCornerRadiusRatio:0.0];
        studio.overlayDrawsAbovePhoto = YES;
        studio.allowsLogoEditing = NO;
        studio.allowsParameterEditing = NO;
        studio.allowsSignatureEditing = NO;
        studio.enforcedPreferenceRawValue = CMWatermarkPreferenceExposure;
        // 参数显示区域：底部15%高度的下半部分，用于显示拍摄参数
        studio.footerContentRect = CGRectMake(0.05, 0.90, 0.90, 0.08);

        CMWatermarkFrameDescriptor *polaroid = [CMWatermarkFrameDescriptor descriptorWithIdentifier:CMWatermarkFrameIdentifierPolaroid
                                                                                        displayName:@"Polaroid"
                                                                                   overlayAssetName:nil
                                                                                backgroundAssetName:nil
                                                                                bottomExpansionRatio:0.16
                                                                                    previewAssetName:@"baolilai"
                                                                                  overlayInsetsRatio:0.0
                                                                               contentInsetsRatio:UIEdgeInsetsMake(0.035, 0.035, 0.195, 0.035)
                                                                             photoContentScale:CGSizeMake(0.93, 0.805)
                                                                            photoContentOffset:CGPointMake(0.035, 0.035)
                                                                         photoCornerRadiusRatio:0.008];

        CMWatermarkFrameDescriptor *minimal = [CMWatermarkFrameDescriptor descriptorWithIdentifier:CMWatermarkFrameIdentifierMinimal
                                                                                        displayName:@"Minimal"
                                                                                   overlayAssetName:nil
                                                                                backgroundAssetName:@"master_bg"
                                                                                bottomExpansionRatio:0.14
                                                                                    previewAssetName:@"master_bg"
                                                                                  overlayInsetsRatio:0.0
                                                                               contentInsetsRatio:UIEdgeInsetsMake(0.02, 0.05, 0.20, 0.05)
                                                                             photoContentScale:CGSizeMake(0.9, 0.78)
                                                                            photoContentOffset:CGPointMake(0.05, 0.06)
                                                                         photoCornerRadiusRatio:0.016];

        frames = @[none, studio, polaroid, minimal];
    });
    return frames;
}

+ (NSArray<CMWatermarkLogoDescriptor *> *)logoDescriptors {
    static NSArray<CMWatermarkLogoDescriptor *> *logos = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logos = @[
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:CMWatermarkLogoIdentifierNone
                                                      displayName:@"None"
                                                         assetName:nil
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.apple.black"
                                                      displayName:@"Apple"
                                                         assetName:@"Apple_logo_black"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.apple.white"
                                                      displayName:@"Apple W"
                                                         assetName:@"Apple_logo_white"
                                             prefersTemplateRendering:YES],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.arri"
                                                      displayName:@"ARRI"
                                                         assetName:@"Arri_logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.canon"
                                                      displayName:@"Canon"
                                                         assetName:@"Canon_wordmark"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.dji"
                                                      displayName:@"DJI"
                                                         assetName:@"dji-1"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.fujifilm"
                                                      displayName:@"Fujifilm"
                                                         assetName:@"Fujifilm_logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.hasselblad"
                                                      displayName:@"Hasselblad"
                                                         assetName:@"Hasselblad_logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.hasselblad.white"
                                                      displayName:@"Hasselblad W"
                                                         assetName:@"Hasselblad_logo_w"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.hasu"
                                                      displayName:@"HASU"
                                                         assetName:@"hasu"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.hasu.black"
                                                      displayName:@"HASU Black"
                                                         assetName:@"hasu_black"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.kodak"
                                                      displayName:@"Kodak"
                                                         assetName:@"Eastman_Kodak_Company_logo_(2016)(no_background)"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.leica"
                                                      displayName:@"Leica"
                                                         assetName:@"Leica_Camera_logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.nikon"
                                                      displayName:@"Nikon"
                                                         assetName:@"Nikon_Logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.olympus"
                                                      displayName:@"Olympus"
                                                         assetName:@"Olympus_Corporation_logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.panasonic"
                                                      displayName:@"Panasonic"
                                                         assetName:@"Panasonic_logo_(Blue)"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.panavision"
                                                      displayName:@"Panavision"
                                                         assetName:@"Panavision_logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.polaroid"
                                                      displayName:@"Polaroid"
                                                         assetName:@"Polaroid_logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.ricoh"
                                                      displayName:@"Ricoh"
                                                         assetName:@"Ricoh_logo_2012"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.sony"
                                                      displayName:@"Sony"
                                                         assetName:@"Sony_logo"
                                             prefersTemplateRendering:NO],
            [CMWatermarkLogoDescriptor descriptorWithIdentifier:@"logo.zeiss"
                                                      displayName:@"Zeiss"
                                                         assetName:@"Zeiss_logo"
                                             prefersTemplateRendering:NO]
        ];
    });
    return logos;
}

+ (nullable CMWatermarkFrameDescriptor *)frameDescriptorForIdentifier:(NSString *)identifier {
    if (identifier.length == 0) { return [self frameDescriptors].firstObject; }
    for (CMWatermarkFrameDescriptor *descriptor in [self frameDescriptors]) {
        if ([descriptor.identifier isEqualToString:identifier]) {
            return descriptor;
        }
    }
    return nil;
}

+ (nullable CMWatermarkLogoDescriptor *)logoDescriptorForIdentifier:(NSString *)identifier {
    if (identifier.length == 0 || [identifier isEqualToString:CMWatermarkLogoIdentifierNone]) {
        return [self logoDescriptors].firstObject;
    }
    for (CMWatermarkLogoDescriptor *descriptor in [self logoDescriptors]) {
        if ([descriptor.identifier isEqualToString:identifier]) {
            return descriptor;
        }
    }
    return nil;
}

@end
