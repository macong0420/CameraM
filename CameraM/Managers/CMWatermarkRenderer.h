//
//  CMWatermarkRenderer.h
//  CameraM
//
//  Created by Generated on 2025/9/18.
//

#import <UIKit/UIKit.h>

@class CMWatermarkConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface CMWatermarkRenderer : NSObject

- (UIImage *)renderImage:(UIImage *)image
     withConfiguration:(CMWatermarkConfiguration *)configuration
              metadata:(nullable NSDictionary *)metadata;

@end

NS_ASSUME_NONNULL_END
