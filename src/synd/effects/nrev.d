/* 
 * synd - audio synthesis library for D
 *
 * Copyright (C) 2012 Timo Westkämper
 * 
 * based on STK by Perry R. Cook and Gary P. Scavone, 1995-2011.
 *
 * This header is free software; you can redistribute it and/or modify it 
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; either version 2.1 of the License,
 * or (at your option) any later version.
 *
 * This header is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
 * USA.
 */

module synd.effects.nrev;

import std.math;
import synd.common;
import synd.filter;
import synd.delay;

/**
 * CCRMA's NRev reverberator class.
 *
 * This class takes a monophonic input signal and produces a stereo output signal.  
 * It is derived  from the CLM NRev function, which is based on the use of networks 
 * of simple allpass and comb delay filters.  This particular arrangement consists 
 * of 6 comb filters in parallel, followed by 3 allpass filters, a lowpass filter, 
 * and another allpass in series, followed by two allpass filters in parallel with 
 * corresponding right and left outputs.
 */
class NRev : Effect {
 
    this(double sr, double T60 = 1.0) {    
        //lastFrame_.resize(1, 2, 0.0); // resize lastFrame_ for stereo output
        sampleRate_ = sr;
        int lengths[15] = [1433, 1601, 1867, 2053, 2251, 2399, 347, 113, 37, 59, 53, 43, 37, 29, 19];
        double scaler = sampleRate_ / 25641.0;
    
        int delay, i;
        for (i=0; i<15; i++) {
          delay = cast(int) floor(scaler * lengths[i]);
          if ((delay & 1) == 0) delay++;
          while (!isPrime(delay)) delay += 2;
          lengths[i] = delay;
        }
    
        for (i=0; i<6; i++) {
          combDelays_[i] = new Delay(lengths[i]);
          combDelays_[i].delay = lengths[i];
          combCoefficient_[i] = pow(10.0, (-3 * lengths[i] / (T60 * sampleRate_)));
        }
    
        for (i=0; i<8; i++) {
            allpassDelays_[i] = new Delay(lengths[i+6]);
            allpassDelays_[i].delay = lengths[i+6];
        }
    
        this.setT60(T60);
        allpassCoefficient_ = 0.7;
        effectMix_ = 0.3;
        this.clear();
    }

    void clear() {
        int i;
        for (i = 0; i < 6; i++) combDelays_[i].clear();
        for (i = 0; i < 8; i++) allpassDelays_[i].clear();
        lastFrame_[0] = 0.0;
        lastFrame_[1] = 0.0;
        lowpassState_ = 0.0;
    }

    void setT60(double T60) {    
        for (int i=0; i<6; i++)
          combCoefficient_[i] = pow(10.0, (-3.0 * combDelays_[i].delay / (T60 * sampleRate_)));
    }

    double tick(double input, uint channel = 0) {    
        double temp, temp0, temp1, temp2, temp3;
        int i;
    
        temp0 = 0.0;
        for (i=0; i<6; i++) {
          temp = input + (combCoefficient_[i] * combDelays_[i].lastOut());
          temp0 += combDelays_[i].tick(temp);
        }
    
        for (i=0; i<3; i++)    {
          temp = allpassDelays_[i].lastOut();
          temp1 = allpassCoefficient_ * temp;
          temp1 += temp0;
          allpassDelays_[i].tick(temp1);
          temp0 = -(allpassCoefficient_ * temp1) + temp;
        }
    
        // One-pole lowpass filter.
        lowpassState_ = 0.7 * lowpassState_ + 0.3 * temp0;
        temp = allpassDelays_[3].lastOut();
        temp1 = allpassCoefficient_ * temp;
        temp1 += lowpassState_;
        allpassDelays_[3].tick(temp1);
        temp1 = -(allpassCoefficient_ * temp1) + temp;
        
        temp = allpassDelays_[4].lastOut();
        temp2 = allpassCoefficient_ * temp;
        temp2 += temp1;
        allpassDelays_[4].tick(temp2);
        lastFrame_[0] = effectMix_*(-(allpassCoefficient_ * temp2) + temp);
        
        temp = allpassDelays_[5].lastOut();
        temp3 = allpassCoefficient_ * temp;
        temp3 += temp1;
        allpassDelays_[5].tick(temp3);
        lastFrame_[1] = effectMix_*(- (allpassCoefficient_ * temp3) + temp);
    
        temp = (1.0 - effectMix_) * input;
        lastFrame_[0] += temp;
        lastFrame_[1] += temp;
        
        return lastFrame_[channel];
    }

 protected:
    Delay allpassDelays_[8];
    Delay combDelays_[6];
    double sampleRate_;
    double allpassCoefficient_;
    double combCoefficient_[6];  
    double lowpassState_;
    double lastFrame_[2];
}

