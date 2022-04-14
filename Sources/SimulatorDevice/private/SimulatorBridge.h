//
//  SimulatorBridge.h
//  LocationSimulator
//
//  Created by David Klopp on 13.03.21.
//  Copyright © 2021 David Klopp. All rights reserved.
//

#ifndef SimulatorBridge_h
#define SimulatorBridge_h

@interface SimulatorBridge : NSObject
- (void)setLocationWithLatitude:(double)latitude andLongitude:(double)longitude;
- (void)setLocationScenario:(in bycopy id)arg1;
@end

#endif /* SimulatorBridge_h */
