//
//  KSDicom2DView.m
//  DicomViewer
//
//  Created by LuoZhaohui on 11/17/11.
//  Copyright 2011 kesalin@gmail.com. All rights reserved.
//

#import "KSDicom2DView.h"

// KSDicom2DView - PrivateMethods
//
@interface KSDicom2DView(PirvateMethods)

- (void) computeLookUpTable8;
- (void) computeLookUpTable16;

- (void) resetValues;
- (void) createImage8;
- (void) createImage16;
- (void) createImage24;
- (void) resetImage;
@end

// KSDicom2DView implementation
//
@implementation KSDicom2DView

@synthesize signed16Image;
@synthesize winCenter;
@synthesize winWidth;
@synthesize changeValWidth;
@synthesize changeValCentre;

#pragma mark -
#pragma mark Lifecycle

- (id) initWithFrame:(CGRect)frame;
{
    self = [super initWithFrame:frame];
    if (self) {
        winMin = 0;
        winMax = 65535;
        
        changeValWidth = 0.5;
        changeValCentre = 0.5;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) 
    {
    }
    
    return self;
}

- (void) dealloc
{
    [self resetImage];
    
    SAFE_FREE(lut8);
    SAFE_FREE(lut16);
    
    [super dealloc];
}

- (void)drawRect:(CGRect)rect
{
    if (!bitmapImage) {
        return;
    }
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(ctx);
    float height = rect.size.height;
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -height);
    CGContextDrawImage(ctx, rect, bitmapImage);
    CGContextRestoreGState(ctx);
}

#pragma mark -
#pragma mark Image related

- (void) resetValues
{
    winMax = (winCenter + 0.5 * winWidth);
    winMin = winMax - winWidth;
}

- (void) resetImage
{
    if (colorspace) {
        CGColorSpaceRelease(colorspace);
        colorspace = NULL;
    }
    if (bitmapImage) {
        CGImageRelease(bitmapImage);
        bitmapImage = NULL;
    }
    
    if (bitmapContext) {
        CGContextRelease(bitmapContext);
        bitmapContext = NULL;
    }
}

// Create a bitmap on the fly, using 8-bit grayscale pixel data
//
- (void) createImage8
{
    if (!pix8) {
        return;
    }
    
    NSInteger numBytes = imgWidth * imgHeight;
    Byte * imageData = (Byte *)calloc(numBytes, sizeof(Byte));
    if (!imageData) {
        return;
    }
    
    NSInteger k = 0;
    for (NSInteger i = 0; i < imgHeight; ++i) {
        k = i * imgWidth;
        for (NSInteger j = 0; j < imgWidth; ++j) {
            imageData[k + j] = lut8[pix8[k + j]]; 
        }
    }
    
    [self resetImage];
    
    colorspace = CGColorSpaceCreateDeviceGray();
    bitmapContext = CGBitmapContextCreate(imageData, imgWidth, imgHeight, 8, imgWidth, colorspace, kCGImageAlphaNone);
    bitmapImage = CGBitmapContextCreateImage(bitmapContext);
    
    SAFE_FREE(imageData);
}

// Create a bitmap on the fly, using 16-bit grayscale pixel data
//
- (void) createImage16
{
    if (!pix16) {
        return;
    }
    
    NSInteger numBytes = imgWidth * imgHeight;
    Byte * imageData = (Byte *)calloc(numBytes, sizeof(Byte));
    if (!imageData) {
        return;
    }
    
    NSInteger k = 0;
    for (NSInteger i = 0; i < imgHeight; ++i) {
        k = i * imgWidth;
        for (NSInteger j = 0; j < imgWidth; ++j) {
            imageData[k + j] = lut16[pix16[k + j]]; 
        }
    }
    
    [self resetImage];
    
    colorspace = CGColorSpaceCreateDeviceGray();
    bitmapContext = CGBitmapContextCreate(imageData, imgWidth, imgHeight, 8, imgWidth, colorspace, kCGImageAlphaNone);
    bitmapImage = CGBitmapContextCreateImage(bitmapContext);
    
    SAFE_FREE(imageData);
}

// Create a RGBA bitmap on the fly, using 8-bit RGB pixel data
//
- (void) createImage24
{
    if (!pix24) {
        return;
    }
    
    NSInteger numBytes = imgWidth * imgHeight * 4;
    Byte * imageData = (Byte *)calloc(numBytes, sizeof(Byte));
    if (!imageData) {
        return;
    }

    NSInteger width4 = imgWidth * 4;
    NSInteger width3 = imgWidth * 3;
    NSInteger k, l;
    for (NSInteger i = 0; i < imgHeight; ++i) {
        l = i * width3;
        k = i * width4;

        for (NSInteger j = 0, m = 0; j < width4; j += 4, m += 3) {
            // System uses little-endian, so the RGB data is actually stored as BGR
            //
            imageData[k + j + 3]  = 0;
            imageData[k + j + 2]  = lut8[pix24[l + m]];     // Blue
            imageData[k + j + 1]  = lut8[pix24[l + m + 1]]; // Green
            imageData[k + j]      = lut8[pix24[l + m + 2]]; // Red
        }
    }
    
    [self resetImage];
    
    colorspace = CGColorSpaceCreateDeviceRGB();
    bitmapContext = CGBitmapContextCreate(imageData, imgWidth, imgHeight, 8, width4, colorspace, kCGImageAlphaNoneSkipLast);
    bitmapImage = CGBitmapContextCreateImage(bitmapContext);
    
    SAFE_FREE(imageData);
}

- (UIImage *)dicomImage
{
    if (bitmapImage)
    {
        UIImage * image = [[UIImage alloc] initWithCGImage:bitmapImage];
        return [image autorelease];
    }
    
    return nil;
}

- (void)setPixels8:(Byte *)pixel
             width:(NSInteger)width
            height:(NSInteger)height
       windowWidth:(double)winW 
      windowCenter:(double)winC 
   samplesPerPixel:(NSInteger)spp
       resetScroll:(BOOL)reset
{
    if (spp == 1)
    {
        imgWidth    = width;
        imgHeight   = height;
        winWidth    = winW;
        winCenter   = winC;
        changeValWidth  = 0.1;
        changeValCentre = 0.1;
        
        pix8        = pixel;
        
        imageAvailable = YES;
        
        [self resetValues];
        
        [self computeLookUpTable8];
        
        [self createImage8];
    }
    
    if (spp == 3)
    {
        imgWidth    = width;
        imgHeight   = height;
        winWidth    = winW;
        winCenter   = winC;
        changeValWidth  = 0.1;
        changeValCentre = 0.1;
        
        pix24       = pixel;
        
        imageAvailable = YES;
        
        [self resetValues];
        
        [self computeLookUpTable8];
        
        [self createImage24];
    }
}

- (void)setPixels16:(ushort *)pixel
              width:(NSInteger)width
             height:(NSInteger)height
        windowWidth:(double)winW 
       windowCenter:(double)winC 
    samplesPerPixel:(NSInteger)spp
        resetScroll:(BOOL)reset
{
    winMin = 0;
    winMax = 65535;
    changeValWidth = 0.5;
    changeValCentre = 0.5;
    
    imgWidth    = width;
    imgHeight   = height;
    winWidth    = winW;
    winCenter   = winC;
    
    if (signed16Image == YES) {
        winCenter -= SHRT_MIN;
    }
    
    // Modify the 'sensitivity' of the mouse based on the original window width
    //
    if (winWidth < 5000) {
        changeValWidth = 2;
        changeValCentre = 2;
    }
    
    else if (winWidth > 40000) {
        changeValWidth = 50;
        changeValCentre = 50;
    }
    else {
        changeValWidth = 25;
        changeValCentre = 25;
    }
    
    pix16       = pixel;
    
    imageAvailable = YES;
    
    [self resetValues];
    
    [self computeLookUpTable16];
    
    [self createImage16];
}


#pragma mark -
#pragma Compute inear interpolation Lookup Tables

- (void) computeLookUpTable8
{
    if (lut8 == NULL) {
        lut8 = (Byte *)calloc(256, sizeof(Byte));
    }
    
    if (winMax == 0)
        winMax = 255;
    
    int range = winMax - winMin;
    if (range < 1)
        range = 1;
    
    double factor = 255.0 / range;
    for (NSInteger i = 0; i < 256; ++i)
    {
        if (i <= winMin)
            lut8[i] = 0;
        else if (i >= winMax)
            lut8[i] = 255;
        else
            lut8[i] = (Byte)((i - winMin) * factor);
    }
}

- (void) computeLookUpTable16
{
    if (lut16 == NULL) {
        lut16 = (Byte *)calloc(65536, sizeof(Byte));
    }
    
    if (winMax == 0)
        winMax = 65535;
    
    long range = winMax - winMin;
    if (range < 1)
        range = 1;
    
    double factor = 255.0 / range;
    for (NSInteger i = 0; i < 65536; ++i)
    {
        if (i <= winMin)
            lut16[i] = 0;
        else if (i >= winMax)
            lut16[i] = 255;
        else
            lut16[i] = (Byte)((i - winMin) * factor);
    }
}

@end
