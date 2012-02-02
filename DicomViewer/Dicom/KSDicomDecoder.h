//
//  KSDicomDecoder.h
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

#import <Foundation/Foundation.h>
#import "KSDicomDictionary.h"

#define PIXEL_REPRESENTATION        0X00280103  
#define TRANSFER_SYNTAX_UID         0X00020010
#define SLICE_THICKNESS             0x00180050  
#define SLICE_SPACING               0x00180088  
#define SAMPLES_PER_PIXEL           0x00280002  
#define PHOTOMETRIC_INTERPRETATION  0x00280004  
#define PLANAR_CONFIGURATION        0x00280006  
#define NUMBER_OF_FRAMES            0x00280008  
#define ROWS                        0x00280010  
#define COLUMNS                     0x00280011  
#define PIXEL_SPACING               0x00280030  
#define BITS_ALLOCATED              0x00280100  
#define WINDOW_CENTER               0x00281050  
#define WINDOW_WIDTH                0x00281051  
#define RESCALE_INTERCEPT           0x00281052  
#define RESCALE_SLOPE               0x00281053  
#define RED_PALETTE                 0x00281201  
#define GREEN_PALETTE               0x00281202  
#define BLUE_PALETTE                0x00281203  
#define ICON_IMAGE_SEQUENCE         0x00880200  
#define PIXEL_DATA                  0x7FE00010

#define PATIENT_ID                  0X00100020
#define PATIENT_NAME                0X00100010
#define PATIENT_SEX                 0X00100040
#define PATIENT_AGE                 0X00101010

#define STUDY_INSTANCE_UID          0x0020000d
#define STUDY_ID                    0X00200010
#define STUDY_DATE                  0X00080020
#define STUDY_TIME                  0x00080030
#define STUDY_DESCRIPTION           0x00081030
#define NUMBER_OF_STUDY_RELATED_SERIES  0x00201206
#define MODALITIES_IN_STUDY         0x00080061
#define REFERRING_PHYSICIAN_NAME    0x00080090

#define SERIES_INSTANCE_UID         0x0020000e
#define SERIES_NUMBER               0x00200011
#define SERIES_DATE                 0x00080021
#define SERIES_TIME                 0x00080031
#define SERIES_DESCRIPTION          0x0008103E
#define NUMBER_OF_SERIES_RELATED_INSTANCES  0x00201209
#define MODALITY                    0x00080060

#define SOP_INSTANCE_UID            0x00080018
#define ACQUISITION_DATE            0x00080022
#define CONTENT_DATE                0x00080023
#define ACQUISITION_TIME            0x00080032
#define CONTENT_TIME                0x00080033
#define PATIENT_POSITION            0x00185100


@interface KSDicomDecoder : NSObject
{
@private

    KSDicomDictionary * dict;
    
    NSString * dicomFileName;
    NSData * dicomData;
    
    NSInteger location;
    NSInteger pixelRepresentation;
    NSInteger elementLength;
    NSInteger vr;  // Value Representation
    
    NSInteger min8;
    NSInteger min16;
    
    BOOL oddLocations;  // one or more tags at odd locations
    BOOL inSequence;
    BOOL bigEndianTransferSyntax;
    BOOL littleEndian;
    
    double rescaleIntercept;
    double rescaleSlope;
    
    Byte * reds;
    Byte * greens;
    Byte * blues;
    
    Byte *  pixels8;
    ushort * pixels16;
    Byte * pixels24; // 30 July 2010, 8 bits bit depth, 3 samples per pixel

@public
    NSInteger bitDepth;
    NSInteger width;
    NSInteger height;
    NSInteger offset;
    NSInteger nImages;
    NSInteger samplesPerPixel;  // 30 July 2010
    
    double pixelDepth;
    double pixelWidth;
    double pixelHeight;
    double windowCenter;
    double windowWidth;
    
    BOOL dicomFound;          // "DICM" found at offset 128
    BOOL dicomFileReadSuccess;
    BOOL compressedImage;    // True if the image data is compressed, false otherwise.
    BOOL dicomDir;
    BOOL signedImage;

    NSMutableDictionary * dicomInfoDict;
}

@property (nonatomic, assign, readonly) NSInteger bitDepth;
@property (nonatomic, assign, readonly) NSInteger width;
@property (nonatomic, assign, readonly) NSInteger height;
@property (nonatomic, assign, readonly) NSInteger offset;
@property (nonatomic, assign, readonly) NSInteger nImages;
@property (nonatomic, assign, readonly) NSInteger samplesPerPixel;

@property (nonatomic, assign, readonly) double pixelDepth;
@property (nonatomic, assign, readonly) double pixelWidth;
@property (nonatomic, assign, readonly) double pixelHeight;
@property (nonatomic, assign, readonly) double windowCenter;
@property (nonatomic, assign, readonly) double windowWidth;

@property (nonatomic, assign, readonly) BOOL dicomFileReadSuccess;
@property (nonatomic, assign, readonly) BOOL dicomFound;
@property (nonatomic, assign, readonly) BOOL compressedImage;
@property (nonatomic, assign, readonly) BOOL dicomDir;
@property (nonatomic, assign, readonly) BOOL signedImage;

- (void) setDicomFilename:(NSString *)filename;
- (Byte *) getPixels8;
- (ushort *) getPixels16;
- (Byte *) getPixels24;
- (NSString *)infoFor:(NSInteger) tag;

@end
