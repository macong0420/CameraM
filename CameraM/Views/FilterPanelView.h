/*
 * @Author: 马聪聪 macong0420@126.com
 * @Date: 2025-09-26 15:54:21
 * @LastEditors: 马聪聪 macong0420@126.com
 * @LastEditTime: 2025-09-26 15:54:22
 * @FilePath: /CameraM/CameraM/Views/FilterPanelView.h
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
//
//  FilterPanelView.h
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import <UIKit/UIKit.h>

@class ARFilterDescriptor;

NS_ASSUME_NONNULL_BEGIN

@protocol FilterPanelDelegate <NSObject>
@optional
- (void)didSelectFilter:(ARFilterDescriptor *)filter;
- (void)didChangeFilterIntensity:(float)intensity;
- (void)didToggleFilterFavorite:(ARFilterDescriptor *)filter;
@end

@interface FilterPanelView : UIView

@property (nonatomic, weak) id<FilterPanelDelegate> delegate;
@property (nonatomic, strong) ARFilterDescriptor *currentFilter;

- (void)updateWithFilters:(NSArray<ARFilterDescriptor *> *)filters;
- (void)setIntensity:(float)intensity;

@end

NS_ASSUME_NONNULL_END