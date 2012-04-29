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

module synd.twang;

import synd.delay;
import synd.filter;

/**
 * enhanced plucked string class.
 *
 * This class implements an enhanced plucked-string physical model, a la 
 * Jaffe-Smith, Smith, Karjalainen and others.  It includes a comb filter 
 * to simulate pluck position.  The tick() function takes an input sample, 
 * which is added to the delayline input.  This can be used to implement 
 * commuted synthesis (if the input samples are derived from the impulse 
 * response of  a body filter) and/or feedback (as in an electric guitar model).
 */
class Twang {
 
    this(double sr, double lowestFrequency = 50.0) {
        sampleRate_ = sr;
        delayLine_ = new DelayA();
        combDelay_ = new DelayL();
        loopFilter_ = new Fir(sr, [2.0, 0.5]);  
           
        this.lowestFrequency = lowestFrequency;
    
        //lastFrame_.resize(1, 1, 0.0);
    
        loopGain_ = 0.995;
        pluckPosition_ = 0.4;
        this.frequency = 220.0;
    }

    void clear() {
        delayLine_.clear();
        combDelay_.clear();
        loopFilter_.clear();
        lastOut_ = 0.0;
    }

    @property void lowestFrequency(double frequency) {
        uint nDelays = cast(uint) (sampleRate_ / frequency);
        delayLine_.maximumDelay = nDelays + 1;
        combDelay_.maximumDelay = nDelays + 1;
    }

    @property void frequency(double frequency) {    
        // Delay = length - filter delay.
        double delay = (sampleRate_ / frequency) - loopFilter_.phaseDelay(frequency);
        delayLine_.delay = delay;
    
        this.loopGain = loopGain_;
    
        // Set the pluck position, which puts zeroes at position * length.
        combDelay_.delay = 0.5 * pluckPosition_ * delay;
    }

    @property void pluckPosition(double position) {    
        pluckPosition_ = position;
    }

    @property void loopGain(double loopGain) {    
        loopGain_ = loopGain;
        double gain = loopGain_ + (frequency_ * 0.000005);
        if (gain >= 1.0) gain = 0.99999;
        loopFilter_.gain = gain;
    }

    //void setLoopFilter(std.vector<double> coefficients);

    //ref const StkFrames  lastFrame() const { return lastFrame_; }

    double tick(double input) {
        lastOut_ = delayLine_.tick(input + loopFilter_.tick(delayLine_.lastOut()));
        lastOut_ -= combDelay_.tick(lastOut_); // comb filtering on output
        return lastOut_ * 0.5;
    }

 protected:  

    DelayA   delayLine_;
    DelayL   combDelay_;
    Fir      loopFilter_;

    //StkFrames lastFrame_;
    double frequency_;
    double loopGain_;
    double pluckPosition_;
    double lastOut_;
    double sampleRate_;
}

