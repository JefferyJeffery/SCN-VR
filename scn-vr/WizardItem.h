/************************************************************************
	
 
	Copyright (C) 2015  Michael Glen Fuller Jr.
 
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
 
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
 
	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 ************************************************************************/

#import <Foundation/Foundation.h>
#import "ProfileInstance.h"

#define WIZARD_ITEM_HEADTRACKER 0
#define WIZARD_ITEM_DEVICE 1
#define WIZARD_ITEM_VIRTUAL_DEVICE 2
#define WIZARD_ITEM_HMD 3
#define WIZARD_ITEM_IPD 4
#define WIZARD_ITEM_IPD_VALUE1 5
#define WIZARD_ITEM_IPD_VALUE2 6
#define WIZARD_ITEM_COLOR 7
#define WIZARD_ITEM_COLOR_VALUE 8
#define WIZARD_ITEM_DISTORTION 9
#define WIZARD_ITEM_DISTORTION_VALUE1 10
#define WIZARD_ITEM_DISTORTION_VALUE2 11
#define WIZARD_ITEM_VIRTUAL_DEVICE_WIDTH 12
#define WIZARD_ITEM_VIRTUAL_DEVICE_HEIGHT 13
#define WIZARD_ITEM_DEVICE_DPI 14

#define WIZARD_ITEM_FOV 15
#define WIZARD_ITEM_FOV_H 16
#define WIZARD_ITEM_FOV_V 17

#define WIZARD_ITEM_DISTORTION_QUALITY 18

#define WIZARD_ITEM_SUPER_SAMPLING 19

typedef NS_ENUM(NSInteger, WizardItemChangeAction)
{
    WizardItemChangeActionNone = 0,
    WizardItemChangeActionCascade = 1
};

typedef NS_ENUM(NSInteger, WizardItemDataType)
{
    WizardItemDataTypeInt = 0,
    WizardItemDataTypeString = 1
};

typedef NS_ENUM(NSInteger, WizardItemNotReadyAction)
{
    WizardItemNotReadyActionBreak = 0,
    WizardItemNotReadyActionContinue = 1
};

@interface WizardItem : NSObject

@property (strong, nonatomic, readonly) NSString * title;
@property (strong, nonatomic, readonly) NSString * info;
@property (assign, nonatomic, readonly) WizardItemDataType type;
@property (assign, nonatomic) int count;
@property (assign, nonatomic, readonly) int itemId;
@property (strong, nonatomic) NSString * valueId;
@property (assign, nonatomic) int valueIndex;

@property (assign, nonatomic) int sectionIndex;
@property (assign, nonatomic) int visibleIndex;

- (instancetype)initWith:(NSString *) title info:(NSString *) info itemId:(int) itemId type:(WizardItemDataType) type;

-(WizardItemChangeAction) changeAction;
-(WizardItemNotReadyAction) notReadyAction;

-(void) chainUpdated;
-(void) reset;
-(BOOL) ready;
-(BOOL) endpoint;
-(BOOL) available;
-(void) loadForInt:(int) value;
-(void) loadForIdentity:(NSString *) identity;
-(NSString *) stringForIndex:(int) index;
-(NSString *) valueForIndex:(int) index;
-(void) selectedIndex:(int) index;

-(int) prepValueToSave;

-(void) updateProfileInstance:(ProfileInstance *) instance;

@end
