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

module synd.effects.jcrev;

import std.math;
import synd.common;
import synd.delay;
import synd.filter;

/**
 * John Chowning's reverberator class.
 *
 * This class takes a monophonic input signal and produces a stereo output signal.  
 * It is derived from the CLM JCRev function, which is based on the use of networks 
 * of simple allpass and comb delay filters.  This class implements three
 * series allpass units, followed by four parallel comb filters, and two decorrelation 
 * delay lines in parallel at the output.
 *
 * Although not in the original JC reverberator, one-pole lowpass filters have been 
 * added inside the feedback comb filters.
 */
class JCRev : Effect {
 
    this(double sr, double T60 = 1.0) {    
        sampleRate = sr;
        //lastFrame_.resize(1, 2, 0.0); // resize lastFrame_ for stereo output
    
        // Delay lengths for 44100 Hz sample rate.
        // {1116, 1188, 1356, 1277, 1422, 1491, 1617, 1557} // FreeVerb comb delays
        int lengths[9] = [1116, 1356, 1422, 1617, 225, 341, 441, 211, 179];
        double scaler = sampleRate / 44100.0;
    
        int delay, i;
        if (scaler != 1.0) {
          for (i = 0; i < 9; i++) {
            delay = cast(int) floor(scaler * lengths[i]);
            if ((delay & 1) == 0) delay++;
            while (!isPrime(delay)) delay += 2;
            lengths[i] = delay;
          }
        }
    
        for (i = 0; i < 3; i++) {
            allpassDelays_[i] = new Delay(lengths[i+4]);
            allpassDelays_[i].delay = lengths[i+4];
        }
    
        for (i = 0; i < 4; i++) {
          combDelays_[i] = new Delay(lengths[i]);
          combDelays_[i].delay = lengths[i];
          combFilters_[i] = new OnePole();
          combFilters_[i].setPole(0.2);
        }
    
        this.setT60(T60);
        outLeftDelay_ = new Delay(lengths[7]);
        outLeftDelay_.delay = lengths[7];
        outRightDelay_ = new Delay(lengths[8]);
        outRightDelay_.delay = lengths[8];
        allpassCoefficient_ = 0.7;
        effectMix_ = 0.3;
        this.clear();
    }

    void clear() {
        allpassDelays_[0].clear();
        allpassDelays_[1].clear();
        allpassDelays_[2].clear();
        combDelays_[0].clear();
        combDelays_[1].clear();
        combDelays_[2].clear();
        combDelays_[3].clear();
        outRightDelay_.clear();
        outLeftDelay_.clear();
        lastFrame_[0] = 0.0;
        lastFrame_[1] = 0.0;
    }

    void setT60(double T60) {    
        for (int i=0; i<4; i++)
          combCoefficient_[i] = pow(10.0, (-3.0 * combDelays_[i].delay / (T60 * sampleRate)));
    }

    double tick(double input, uint channel = 0) {    
        double temp, temp0, temp1, temp2, temp3, temp4, temp5, temp6;
        double filtout;
    
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
        
        temp = allpassDelays_[2].lastOut();
        temp2 = allpassCoefficient_ * temp;
        temp2 += temp1;
        allpassDelays_[2].tick(temp2);
        temp2 = -(allpassCoefficient_ * temp2) + temp;
        
        temp3 = temp2 + (combFilters_[0].tick(combCoefficient_[0] * combDelays_[0].lastOut()));
        temp4 = temp2 + (combFilters_[1].tick(combCoefficient_[1] * combDelays_[1].lastOut()));
        temp5 = temp2 + (combFilters_[2].tick(combCoefficient_[2] * combDelays_[2].lastOut()));
        temp6 = temp2 + (combFilters_[3].tick(combCoefficient_[3] * combDelays_[3].lastOut()));
    
        combDelays_[0].tick(temp3);
        combDelays_[1].tick(temp4);
        combDelays_[2].tick(temp5);
        combDelays_[3].tick(temp6);
    
        filtout = temp3 + temp4 + temp5 + temp6;
    
        lastFrame_[0] = effectMix_ * (outLeftDelay_.tick(filtout));
        lastFrame_[1] = effectMix_ * (outRightDelay_.tick(filtout));
        temp = (1.0 - effectMix_) * input;
        lastFrame_[0] += temp;
        lastFrame_[1] += temp;
        
        return 0.7 * lastFrame_[channel];
    }

 protected:
    Delay allpassDelays_[3];
    Delay combDelays_[4];
    OnePole combFilters_[4];
    Delay outLeftDelay_;
    Delay outRightDelay_;
    double sampleRate;
    double allpassCoefficient_;
    double combCoefficient_[4];
    double lastFrame_[2];
}

