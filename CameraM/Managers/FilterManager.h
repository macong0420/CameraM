/*
 * @Author: 马聪聪 macong0420@126.com
 * @Date: 2025-09-26 15:55:25
 * @LastEditors: 马聪聪 macong0420@126.com
 * @LastEditTime: 2025-09-26 15:55:26
 * @FilePath: /CameraM/CameraM/Managers/FilterManager.h
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
//
//  FilterManager.h
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import <Foundation/Foundation.h>
@import CoreImage;

@class ARFilterDescriptor;

NS_ASSUME_NONNULL_BEGIN

@interface FilterManager : NSObject

@property (nonatomic, strong, readonly) NSArray<ARFilterDescriptor *> *availableFilters;
@property (nonatomic, strong, nullable) ARFilterDescriptor *currentFilter;
@property (nonatomic, assign) float intensity;
@property (nonatomic, assign) float grainIntensity;

+ (instancetype)sharedManager;

- (void)loadDefaultFilters;
- (CIImage *)applyCurrentFilterToImage:(CIImage *)image;
- (void)setCurrentFilter:(ARFilterDescriptor *)filter withIntensity:(float)intensity;

@end

NS_ASSUME_NONNULL_END