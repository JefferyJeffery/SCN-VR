//
//  IMUTracker.m
//  scn-vr
//
//  Created by Michael Fuller on 12/26/14.
//  Copyright (c) 2014 M-Gate Labs. All rights reserved.
//

#import "IMUTracker.h"

#define ASENSOR_TYPE_ROTATION_VECTOR 11
#define sampleFreq	128.0f			// sample frequency in Hz
#define twoKpDef	(2.0f * 0.5f)	// 2 * proportional gain
#define twoKiDef	(2.0f * 0.0f)	// 2 * integral gain
#define betaDef		0.1f	    	// 2 * proportional gain

struct Quaternion {
    float x;
    float y;
    float z;
    float w;
};

static float gyr_x,gyr_y,gyr_z;
static long long time_stamp;
static long long gyro_time_stamp;
static float acc_x,acc_y,acc_z;
static float N2S;
static float EPSILON;
static struct Quaternion deltaGyroQuaternion;
static struct Quaternion q;

@interface IMUTracker(){
    GLKQuaternion rotationFix, rotationFix2;
    float beta;
    float twoKp;											// 2 * proportional gain (Kp)
    float twoKi;											// 2 * integral gain (Ki)
    float q0, q1, q2, q3;					// quaternion of sensor frame relative to auxiliary frame
    float integralFBx,  integralFBy, integralFBz;	// integral error terms scaled by Ki
}

-(void) MahonyAHRSupdateIMU:(float) gx gy:(float) gy gz:(float) gz ax:(float) ax ay:(float) ay az:(float) az ev_timestamp:(long long) ev_timestamp;
-(void) MadgwickAHRSupdateIMU:(float) gx gy:(float) gy gz:(float) gz ax:(float) ax ay:(float) ay az:(float) az;
-(float) invSqrt:(float) x;
-(void) multiplyQuat:(struct Quaternion *) qOne q2:(struct Quaternion*) qTwo;
-(GLKQuaternion) get_q;

@end

@implementation IMUTracker

- (instancetype)init
{
    self = [super initWith:@"IMU" identity:@"imu"];
    if (self) {
        
        rotationFix = GLKQuaternionMakeWithAngleAndAxis(-1.57079633f, 0, 0, 1);
        
        rotationFix2 = GLKQuaternionMakeWithAngleAndAxis(M_PI, 0, 0, 1);
        
        beta = betaDef;
        twoKp = twoKpDef;
        twoKi = twoKiDef;
        
        q0 = 1.0f;
        q1 = 0.0f;
        q2 = 0.0f;
        q3 = 0.0f;
        
        integralFBx = 0.0f;
        integralFBy = 0.0f;
        integralFBz = 0.0f;
        
        acc_x=555;
        acc_y=555;
        acc_z=555;
        gyr_x=999;
        gyr_y=999;
        gyr_z=999;
        
        time_stamp = -1;
        gyro_time_stamp = -1;
        
        N2S = 1.0/1000000000.0;
        EPSILON = 0.000000001;
        deltaGyroQuaternion.x = 0;
        deltaGyroQuaternion.y = 0;
        deltaGyroQuaternion.z = 0;
        deltaGyroQuaternion.w = 0;
        q.x = 0;
        q.y = 0;
        q.z = 0;
        q.w = 1;
        
        //rotationFix = GLKQuaternionMakeWithAngleAndAxis(-1.57079633f, 0, 0, 1);
        
        self.motionManager = [[CMMotionManager alloc] init];
        self.motionManager.gyroUpdateInterval = 1.0f / sampleFreq;
        self.motionManager.accelerometerUpdateInterval = 1.0f / sampleFreq;
        self.motionManager.showsDeviceMovementDisplay = NO;
        
    }
    return self;
}

-(GLKQuaternion) get_q {
    q.x = q1;
    q.y = q2;
    q.z = q3;
    q.w = q0;
    [self multiplyQuat:&q q2:&deltaGyroQuaternion];
    
    return GLKQuaternionMake(q.x, q.y, q.z, q.w);
}

-(void) getQuaternionFromGyro:(float) ev_x ev_y:(float) ev_y ev_z:(float) ev_z ev_timestamp:(long long) ev_timestamp {
    if(gyro_time_stamp != -1){
        float dT = (ev_timestamp - gyro_time_stamp) * N2S;
        //Calculate the angular speed of the sample
        float omegaMagnitude = sqrt(ev_x*ev_x + ev_y*ev_y + ev_z*ev_z);
        
        //Normalize the rotation vector
        if(omegaMagnitude > EPSILON){
            ev_x /= omegaMagnitude;
            ev_y /= omegaMagnitude;
            ev_z /= omegaMagnitude;
        }
        
        //NSLog(@"I %2.6f %2.6f %2.6f", ev_x, ev_y, ev_z);
        
        float thetaOverTwo = omegaMagnitude * dT / 2.0f;
        float sinThetaOverTwo = sin(thetaOverTwo);
        float cosThetaOverTwo = cos(thetaOverTwo);
        NSLog(@"sinThetaOverTwo: %2.6f", sinThetaOverTwo);
        deltaGyroQuaternion.x = sinThetaOverTwo * ev_x;
        deltaGyroQuaternion.y = sinThetaOverTwo * ev_y;
        deltaGyroQuaternion.z = sinThetaOverTwo * ev_z;
        deltaGyroQuaternion.w = cosThetaOverTwo;
        
        NSLog(@"%2.4f %2.4f %2.4f", deltaGyroQuaternion.x, deltaGyroQuaternion.y, deltaGyroQuaternion.z);
        
        [self multiplyQuat:&deltaGyroQuaternion q2:&deltaGyroQuaternion];
        [self multiplyQuat:&deltaGyroQuaternion q2:&deltaGyroQuaternion];
        [self multiplyQuat:&deltaGyroQuaternion q2:&deltaGyroQuaternion];
        
        NSLog(@"%2.4f %2.4f %2.4f", deltaGyroQuaternion.x, deltaGyroQuaternion.y, deltaGyroQuaternion.z);
    }
    gyro_time_stamp = ev_timestamp;
    
}

-(void) MahonyAHRSupdateIMU:(float) gx gy:(float) gy gz:(float) gz ax:(float) ax ay:(float) ay az:(float) az ev_timestamp:(long long) ev_timestamp {
    if(time_stamp != -1){
        float dT = (ev_timestamp - time_stamp) * N2S;
        float recipNorm;
        float halfvx, halfvy, halfvz;
        float halfex, halfey, halfez;
        float qa, qb, qc;
        
        // Compute feedback only if accelerometer measurement valid (avoids NaN in accelerometer normalisation)
        if(!((ax == 0.0f) && (ay == 0.0f) && (az == 0.0f))) {
            
            // Normalise accelerometer measurement
            recipNorm = [self invSqrt:ax * ax + ay * ay + az * az];
            ax *= recipNorm;
            ay *= recipNorm;
            az *= recipNorm;
            
            // Estimated direction of gravity and vector perpendicular to magnetic flux
            halfvx = q1 * q3 - q0 * q2;
            halfvy = q0 * q1 + q2 * q3;
            halfvz = q0 * q0 - 0.5f + q3 * q3;
            
            // Error is sum of cross product between estimated and measured direction of gravity
            halfex = (ay * halfvz - az * halfvy);
            halfey = (az * halfvx - ax * halfvz);
            halfez = (ax * halfvy - ay * halfvx);
            
            // Compute and apply integral feedback if enabled
            if(twoKi > 0.0f) {
                integralFBx += twoKi * halfex * dT/*(1.0f / sampleFreq)*/;	// integral error scaled by Ki
                integralFBy += twoKi * halfey * dT/*(1.0f / sampleFreq)*/;
                integralFBz += twoKi * halfez * dT/*(1.0f / sampleFreq)*/;
                gx += integralFBx;	// apply integral feedback
                gy += integralFBy;
                gz += integralFBz;
            }
            else {
                integralFBx = 0.0f;	// prevent integral windup
                integralFBy = 0.0f;
                integralFBz = 0.0f;
            }
            
            // Apply proportional feedback
            gx += twoKp * halfex;
            gy += twoKp * halfey;
            gz += twoKp * halfez;
        }
        
        // Integrate rate of change of quaternion
        gx *= (0.5f * dT/*(1.0f / sampleFreq)*/);		// pre-multiply common factors
        gy *= (0.5f * dT/*(1.0f / sampleFreq)*/);
        gz *= (0.5f * dT/*(1.0f / sampleFreq)*/);
        qa = q0;
        qb = q1;
        qc = q2;
        q0 += (-qb * gx - qc * gy - q3 * gz);
        q1 += (qa * gx + qc * gz - q3 * gy);
        q2 += (qa * gy - qb * gz + q3 * gx);
        q3 += (qa * gz + qb * gy - qc * gx);
        
        // Normalise quaternion
        recipNorm = [self invSqrt:q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3];
        q0 *= recipNorm;
        q1 *= recipNorm;
        q2 *= recipNorm;
        q3 *= recipNorm;
    }
    time_stamp=ev_timestamp;
}

/* IMU algorithm update. Madgwick implementation.
 */
-(void) MadgwickAHRSupdateIMU:(float) gx gy:(float) gy gz:(float) gz ax:(float) ax ay:(float) ay az:(float) az {
    float recipNorm;
    float s0, s1, s2, s3;
    float qDot1, qDot2, qDot3, qDot4;
    float _2q0, _2q1, _2q2, _2q3, _4q0, _4q1, _4q2 ,_8q1, _8q2, q0q0, q1q1, q2q2, q3q3;
    
    // Rate of change of quaternion from gyroscope
    qDot1 = 0.5f * (-q1 * gx - q2 * gy - q3 * gz);
    qDot2 = 0.5f * (q0 * gx + q2 * gz - q3 * gy);
    qDot3 = 0.5f * (q0 * gy - q1 * gz + q3 * gx);
    qDot4 = 0.5f * (q0 * gz + q1 * gy - q2 * gx);
    
    // Compute feedback only if accelerometer measurement valid (avoids NaN in accelerometer normalisation)
    if(!((ax == 0.0f) && (ay == 0.0f) && (az == 0.0f))) {
        
        // Normalise accelerometer measurement
        recipNorm = [self invSqrt:ax * ax + ay * ay + az * az];
        ax *= recipNorm;
        ay *= recipNorm;
        az *= recipNorm;
        
        // Auxiliary variables to avoid repeated arithmetic
        _2q0 = 2.0f * q0;
        _2q1 = 2.0f * q1;
        _2q2 = 2.0f * q2;
        _2q3 = 2.0f * q3;
        _4q0 = 4.0f * q0;
        _4q1 = 4.0f * q1;
        _4q2 = 4.0f * q2;
        _8q1 = 8.0f * q1;
        _8q2 = 8.0f * q2;
        q0q0 = q0 * q0;
        q1q1 = q1 * q1;
        q2q2 = q2 * q2;
        q3q3 = q3 * q3;
        
        // Gradient decent algorithm corrective step
        s0 = _4q0 * q2q2 + _2q2 * ax + _4q0 * q1q1 - _2q1 * ay;
        s1 = _4q1 * q3q3 - _2q3 * ax + 4.0f * q0q0 * q1 - _2q0 * ay - _4q1 + _8q1 * q1q1 + _8q1 * q2q2 + _4q1 * az;
        s2 = 4.0f * q0q0 * q2 + _2q0 * ax + _4q2 * q3q3 - _2q3 * ay - _4q2 + _8q2 * q1q1 + _8q2 * q2q2 + _4q2 * az;
        s3 = 4.0f * q1q1 * q3 - _2q1 * ax + 4.0f * q2q2 * q3 - _2q2 * ay;
        recipNorm = [self invSqrt:s0 * s0 + s1 * s1 + s2 * s2 + s3 * s3]; // normalise step magnitude
        s0 *= recipNorm;
        s1 *= recipNorm;
        s2 *= recipNorm;
        s3 *= recipNorm;
        
        // Apply feedback step
        qDot1 -= beta * s0;
        qDot2 -= beta * s1;
        qDot3 -= beta * s2;
        qDot4 -= beta * s3;
    }
    
    // Integrate rate of change of quaternion to yield quaternion
    q0 += qDot1 * (1.0f / sampleFreq);
    q1 += qDot2 * (1.0f / sampleFreq);
    q2 += qDot3 * (1.0f / sampleFreq);
    q3 += qDot4 * (1.0f / sampleFreq);
    
    // Normalise quaternion
    recipNorm = [self invSqrt:q0 * q0 + q1 * q1 + q2 * q2 + q3 * q3];
    q0 *= recipNorm;
    q1 *= recipNorm;
    q2 *= recipNorm;
    q3 *= recipNorm;
}

/* Fast inverse square-root
 * See: http://en.wikipedia.org/wiki/Fast_inverse_square_root
 */
-(float) invSqrt:(float) x {
    float halfx = 0.5f * x;
    float y = x;
    long i = *(long*)&y;
    i = 0x5f3759df - (i>>1);
    y = *(float*)&i;
    y = y * (1.5f - (halfx * y * y));
    return y;
}

/* Multiplies quaternions q1 and q2. Result goes in q1.
 */
-(void) multiplyQuat:(struct Quaternion *) qOne q2:(struct Quaternion*) qTwo {
    float nx = (qOne->w)*(qTwo->x) + (qOne->x)*(qTwo->w) + (qOne->y)*(qTwo->z) - (qOne->z)*(qTwo->y);
    float ny = (qOne->w*qTwo->y - qOne->x*qTwo->z + qOne->y*qTwo->w + qOne->z*qTwo->x);
    float nz = (qOne->w*qTwo->z + qOne->x*qTwo->y - qOne->y*qTwo->x + qOne->z*qTwo->w);
    float nw = (qOne->w*qTwo->w - qOne->x*qTwo->x - qOne->y*qTwo->y - qOne->z*qTwo->z);
    qOne->x = nx;
    qOne->y = ny;
    qOne->z = nz;
    qOne->w = nw;
}

-(void) start {
    
    [self.motionManager startAccelerometerUpdatesToQueue:[[NSOperationQueue alloc] init] withHandler:
     ^(CMAccelerometerData *accelerometerData, NSError *error) {
         acc_x = accelerometerData.acceleration.x;
         acc_y = accelerometerData.acceleration.y;
         acc_z = accelerometerData.acceleration.z;
         [self MahonyAHRSupdateIMU:gyr_x gy:gyr_y gz:gyr_z ax:acc_x ay:acc_y az:acc_z ev_timestamp:accelerometerData.timestamp * 1000000000.0];
     }];
    
    [self.motionManager startGyroUpdatesToQueue:[[NSOperationQueue alloc] init] withHandler:^(CMGyroData *gyroData, NSError *error) {
        gyr_x = gyroData.rotationRate.x;
        gyr_y = gyroData.rotationRate.y;
        gyr_z = gyroData.rotationRate.z;
        [self getQuaternionFromGyro:gyr_x ev_y:gyr_y ev_z:gyr_z ev_timestamp:gyroData.timestamp * 1000000000.0];
    }];
}

-(void) stop {
    [self.motionManager stopAccelerometerUpdates];
    [self.motionManager stopGyroUpdates];
}

-(void) capture {
#if !(TARGET_IPHONE_SIMULATOR)
    
    
    
    //CMQuaternion currentAttitude_noQ = self.motionManager.deviceMotion.attitude.quaternion;
    
    GLKQuaternion baseRotation = [self get_q];// GLKQuaternionMake(currentAttitude_noQ.x, currentAttitude_noQ.y, currentAttitude_noQ.z, currentAttitude_noQ.w);
    
    
    self.orientation = baseRotation;// GLKQuaternionMultiply(GLKQuaternionMultiply(baseRotation, rotationFix), rotationFix2);
    
#else
    self.orientation = GLKQuaternionMultiply(rotationFix, GLKQuaternionMakeWithAngleAndAxis(90 * 0.0174532925f, 1, 0, 0));
#endif
}

@end
