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

module synd.effects.prcrev;

import std.math;
import synd.common;
import synd.delay;

/**
 * Perry's simple reverberator class.
 *
 * This class takes a monophonic input signal and produces a stereo output 
 * signal. It is based on some of the famous Stanford/CCRMA reverbs (NRev, KipRev), 
 * which were based on the Chowning/Moorer/Schroeder reverberators using networks 
 * of simple allpass and comb delay filters.  This class implements two series 
 * allpass units and two parallel comb filters.
 */
class PRCRev : Effect {

    this(double sr, double T60 = 1.0){    
        //lastFrame_.resize(1, 2, 0.0); // resize lastFrame_ for stereo output
        sampleRate_ = sr;
        // Delay lengths for 44100 Hz sample rate.
        int lengths[4]= [341, 613, 1557, 2137];
        double scaler = sampleRate_ / 44100.0;
    
        // Scale the delay lengths if necessary.
        int delay, i;
        if (scaler != 1.0) {
          for (i=0; i<4; i++)    {
            delay = cast(int) floor(scaler * lengths[i]);
            if ((delay & 1) == 0) delay++;
            while (!isPrime(delay)) delay += 2;
            lengths[i] = delay;
          }
        }
    
        for (i=0; i<2; i++)    {
          allpassDelays_[i] = new Delay(lengths[i]);
          allpassDelays_[i].delay = lengths[i];
          combDelays_[i] = new Delay(lengths[i+2]);
          combDelays_[i].delay = lengths[i+2];
        }
    
        this.setT60(T60);
        allpassCoefficient_ = 0.7;
        effectMix_ = 0.5;
        this.clear();
    }

    void clear() {
        allpassDelays_[0].clear();
        allpassDelays_[1].clear();
        combDelays_[0].clear();
        combDelays_[1].clear();
        lastFrame_[0] = 0.0;
        lastFrame_[1] = 0.0;
    }

    void setT60(double T60) {    
        combCoefficient_[0] = pow(10.0, (-3.0 * combDelays_[0].delay / (T60 * sampleRate_)));
        combCoefficient_[1] = pow(10.0, (-3.0 * combDelays_[1].delay / (T60 * sampleRate_)));
    }

    double lastOut(uint channel = 0) {    
        return lastFrame_[channel];
    }

    double tick(double input, uint channel = 0) {    
        double temp, temp0, temp1, temp2, temp3;
    
        temp = allpassDelays_[0].lastOut();
        temp0 = allpassCoefficient_ * temp;
        temp0 += input;
        allpassDelays_[0].tick(temp0);
        temp0 = -(allpassCoefficient_ * temp0) + temp;
        
        temp = allpassDelays_[1].lastOut();
        temp1 = allpassCoefficient_ * temp;
        temp1 += temp0;
        allpassDelays_[1].tick(temp1);
        temp1 = -(allpassCoefficient_ * temp1) + temp;
        
        temp2 = temp1 + (combCoefficient_[0] * combDelays_[0].lastOut());
        temp3 = temp1 + (combCoefficient_[1] * combDelays_[1].lastOut());
    
        lastFrame_[0] = effectMix_ * (combDelays_[0].tick(temp2));
        lastFrame_[1] = effectMix_ * (combDelays_[1].tick(temp3));
        temp = (1.0 - effectMix_) * input;
        lastFrame_[0] += temp;
        lastFrame_[1] += temp;
    
        return lastFrame_[channel];
    }

  protected:
    Delay allpassDelays_[2];
    Delay combDelays_[2];
    double allpassCoefficient_;
    double combCoefficient_[2];
    double lastFrame_[2];
    double sampleRate_;
    
}

