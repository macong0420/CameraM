//
//  CMCameraLensOption.h
//  CameraM
//
//  Created by 自动生成 on 2025/9/23.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CMCameraLensOption : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, assign, readonly) CGFloat zoomFactor;
@property (nonatomic, copy, readonly) NSString *deviceUniqueID;

+ (instancetype)optionWithIdentifier:(NSString *)identifier
                          displayName:(NSString *)displayName
                            zoomFactor:(CGFloat)zoomFactor
                        deviceUniqueID:(NSString *)deviceUniqueID;

@end

NS_ASSUME_NONNULL_END
