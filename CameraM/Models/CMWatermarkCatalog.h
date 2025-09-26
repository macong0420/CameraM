//
//  CMWatermarkCatalog.h
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const CMWatermarkFrameIdentifierNone;
FOUNDATION_EXPORT NSString * const CMWatermarkFrameIdentifierStudio;
FOUNDATION_EXPORT NSString * const CMWatermarkFrameIdentifierPolaroid;

FOUNDATION_EXPORT NSString * const CMWatermarkLogoIdentifierNone;

@interface CMWatermarkFrameDescriptor : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly, nullable) NSString *overlayAssetName;
@property (nonatomic, copy, readonly, nullable) NSString *backgroundAssetName;
@property (nonatomic, copy, readonly, nullable) NSString *previewAssetName;
@property (nonatomic, assign, readonly) CGFloat bottomExpansionRatio;
@property (nonatomic, assign, readonly) CGFloat overlayInsetsRatio;
@property (nonatomic, assign, readonly) UIEdgeInsets contentInsetsRatio;
@property (nonatomic, assign, readonly) BOOL overlayDrawsAbovePhoto;
@property (nonatomic, assign, readonly) CGSize photoContentScale;
@property (nonatomic, assign, readonly) CGPoint photoContentOffset;
@property (nonatomic, assign, readonly) CGFloat photoCornerRadiusRatio;
@property (nonatomic, assign, readonly) BOOL allowsLogoEditing;
@property (nonatomic, assign, readonly) BOOL allowsParameterEditing;
@property (nonatomic, assign, readonly) BOOL allowsSignatureEditing;
@property (nonatomic, assign, readonly) NSInteger enforcedPreferenceRawValue;
@property (nonatomic, assign, readonly) CGRect footerContentRect;

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
                  photoCornerRadiusRatio:(CGFloat)photoCornerRadiusRatio;

@end

@interface CMWatermarkLogoDescriptor : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly, nullable) NSString *assetName;
@property (nonatomic, assign, readonly) BOOL prefersTemplateRendering;

+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                              displayName:(NSString *)displayName
                                 assetName:(nullable NSString *)assetName
                 prefersTemplateRendering:(BOOL)prefersTemplateRendering;

@end

@interface CMWatermarkCatalog : NSObject

+ (NSArray<CMWatermarkFrameDescriptor *> *)frameDescriptors;
+ (NSArray<CMWatermarkLogoDescriptor *> *)logoDescriptors;
+ (nullable CMWatermarkFrameDescriptor *)frameDescriptorForIdentifier:(NSString *)identifier;
+ (nullable CMWatermarkLogoDescriptor *)logoDescriptorForIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
