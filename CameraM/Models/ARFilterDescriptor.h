/*
 * @Author: 马聪聪 macong0420@126.com
 * @Date: 2025-09-26 15:51:45
 * @LastEditors: 马聪聪 macong0420@126.com
 * @LastEditTime: 2025-09-26 15:51:46
 * @FilePath: /CameraM/CameraM/Models/ARFilterDescriptor.h
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
//
//  ARFilterDescriptor.h
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class ARFilterPipeline;

NS_ASSUME_NONNULL_BEGIN

@interface ARFilterDescriptor : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, strong) ARFilterPipeline *pipeline;
@property (nonatomic, assign) float intensity; // 0..1 全局强度
@property (nonatomic, assign) float grainIntensity; // 0..1 颗粒强度
@property (nonatomic, assign, readonly) BOOL supportsGrainAdjustment;
@property (nonatomic, strong, nullable) UIImage *thumbnail; // 异步生成
@property (nonatomic, assign) BOOL isFavorite;
@property (nonatomic, strong, nullable) UIColor *accentColor;

+ (instancetype)descriptorWithId:(NSString *)identifier
                            name:(NSString *)name
                        pipeline:(ARFilterPipeline *)pipeline;

+ (instancetype)descriptorWithId:(NSString *)identifier
                             name:(NSString *)name
                         pipeline:(ARFilterPipeline *)pipeline
                       accentColor:(nullable UIColor *)accentColor;

@end

NS_ASSUME_NONNULL_END