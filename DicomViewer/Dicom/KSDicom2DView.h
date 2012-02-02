//
//  KSDicom2DView.h
//  DicomViewer
//
//  Created by LuoZhaohui on 11/17/11.
//  Copyright 2011 LuoZhaohui. All rights reserved.
//  Contact:    kesalin@gmail.com
//              http://blog.csdn.net/kesalin
//
// DicomDecoder is provided by LuoZhaohui on an "AS IS" basis. LuoZhaohui MAKES NO
// WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
// WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
// COMBINATION WITH YOUR PRODUCTS. 
//


#import <UIKit/UIKit.h>

@interface KSDicom2DView : UIView
{
    NSInteger hOffset;
    NSInteger vOffset;
    NSInteger hMax;
    NSInteger vMax;
    NSInteger imgWidth;
    NSInteger imgHeight;
    NSInteger panWidth;
    NSInteger panHeight;
    BOOL newImage;
    
    // For Window Level
    //
    NSInteger winMin;
    NSInteger winMax;
    NSInteger winCenter;
    NSInteger winWidth;
    NSInteger winShr1;
    NSInteger deltaX;
    NSInteger deltaY;
    
    double changeValWidth;
    double changeValCentre;
    BOOL signed16Image;
    BOOL imageAvailable;
    
    Byte * pix8;
    ushort * pix16;
    Byte * pix24;
    
    Byte * lut8;
    Byte * lut16;
    
    CGColorSpaceRef colorspace;
    CGContextRef bitmapContext;
    CGImageRef bitmapImage;
}

@property (nonatomic, assign) BOOL signed16Image;
@property (nonatomic, assign) NSInteger winCenter;
@property (nonatomic, assign) NSInteger winWidth;
@property (nonatomic, assign) double changeValWidth;
@property (nonatomic, assign) double changeValCentre;

- (void)setPixels8:(Byte *)pixel
             width:(NSInteger)width
            height:(NSInteger)height
       windowWidth:(double)winW 
      windowCenter:(double)winC 
   samplesPerPixel:(NSInteger)spp
       resetScroll:(BOOL)reset;

- (void)setPixels16:(ushort *)pixel
              width:(NSInteger)width
             height:(NSInteger)height
        windowWidth:(double)winW 
       windowCenter:(double)winC 
    samplesPerPixel:(NSInteger)spp
        resetScroll:(BOOL)reset;

- (UIImage *)dicomImage;

@end
