/*
 * @Author: 马聪聪 macong0420@126.com
 * @Date: 2025-09-26 15:51:15
 * @LastEditors: 马聪聪 macong0420@126.com
 * @LastEditTime: 2025-09-26 15:51:16
 * @FilePath: /CameraM/CameraM/Models/ARFilterPipeline.h
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
//
//  ARFilterPipeline.h
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import <Foundation/Foundation.h>
@import CoreImage;
#import "ARFilterOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARFilterPipeline : NSObject

@property (nonatomic, strong, readonly) NSArray<id<ARFilterOperation>> *operations;
@property (nonatomic, assign) float intensity; // 0..1
@property (nonatomic, assign) float grainIntensity; // 0..1, 当存在胶片颗粒操作时有效
@property (nonatomic, assign, readonly) BOOL supportsGrainAdjustment;

- (instancetype)initWithOperations:(NSArray<id<ARFilterOperation>> *)ops;
- (CIImage *)process:(CIImage *)image;

@end

NS_ASSUME_NONNULL_END