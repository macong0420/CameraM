/*
 * @Author: 马聪聪 macong0420@126.com
 * @Date: 2025-09-26 15:53:43
 * @LastEditors: 马聪聪 macong0420@126.com
 * @LastEditTime: 2025-09-26 15:53:44
 * @FilePath: /CameraM/CameraM/Models/ARFilterFactory.h
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
//
//  ARFilterFactory.h
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import <Foundation/Foundation.h>

@class ARFilterDescriptor;

NS_ASSUME_NONNULL_BEGIN

@interface ARFilterFactory : NSObject

+ (NSArray<ARFilterDescriptor *> *)defaultFilters;

@end

NS_ASSUME_NONNULL_END