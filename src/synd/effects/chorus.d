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

module synd.effects.chorus;

import synd.common;
import synd.delay;
import synd.osc;

/**
 * chorus effect class.
 *
 * This class implements a chorus effect.  It takes a monophonic input signal 
 * and produces a stereo output signal.
 */
class Chorus : Effect {
 
    this(double sr, double baseDelay = 6000) {
        delayLine_[0] = new DelayL(cast(uint) (baseDelay * 1.414 + 2));
        delayLine_[0].delay = baseDelay;
        delayLine_[1] = new DelayL(cast(uint) (baseDelay * 1.414 + 2));
        delayLine_[1].delay = baseDelay;
        baseLength_ = baseDelay;
    
        mods_[0] = new SineWave(sr);
        mods_[0].frequency = 0.2;
        mods_[1] = new SineWave(sr);
        mods_[1].frequency = 0.222222;
        modDepth_ = 0.05;
        effectMix_ = 0.5;
        this.clear();
    }

    void clear() {
        delayLine_[0].clear();
        delayLine_[1].clear();
        lastFrame_[0] = 0.0;
        lastFrame_[1] = 0.0;
    }

    @property void modDepth(double depth) {
        modDepth_ = depth;
    }

    @property void  modFrequency(double frequency) {
        mods_[0].frequency = frequency;
        mods_[1].frequency = frequency * 1.1111;
    }

    double lastOut(uint channel = 0) {   
        return lastFrame_[channel];
    }
  
    double tick(double input, uint channel = 0) {
        delayLine_[0].delay = baseLength_ * 0.707 * (1.0 + modDepth_ * mods_[0].tick());
        delayLine_[1].delay = baseLength_  * 0.5 *  (1.0 - modDepth_ * mods_[1].tick());
        lastFrame_[0] = effectMix_ * (delayLine_[0].tick(input) - input) + input;
        lastFrame_[1] = effectMix_ * (delayLine_[1].tick(input) - input) + input;
        return lastFrame_[channel];
    }

  protected:  
    DelayL delayLine_[2];
    SineWave mods_[2];
    double baseLength_, modDepth_;
    double lastFrame_[2];

}
