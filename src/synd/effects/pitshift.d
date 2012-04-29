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

module synd.effects.pitshift;

import std.math;
import synd.common;
import synd.delay;

private immutable maxDelay = 5024;

/**
 * simple pitch shifter effect class.
 *
 * This class implements a simple pitch shifter using delay lines.
 */
class PitShift : Effect {
 
    this() {
        delayLength_ = maxDelay - 24;
        halfLength_ = delayLength_ / 2;
        delay_[0] = 12;
        delay_[1] = maxDelay / 2;
    
        delayLine_[0] = new DelayL(maxDelay);
        delayLine_[0].delay = delay_[0];
        delayLine_[1] = new DelayL(maxDelay);
        delayLine_[1].delay = delay_[1];
        effectMix_ = 0.5;
        rate_ = 1.0;
    }

    void clear() {
        delayLine_[0].clear();
        delayLine_[1].clear();
        lastOut_ = 0.0;
    }

    void setShift(double shift) {
      if (shift < 1.0) {
        rate_ = 1.0 - shift; 
      }  else if (shift > 1.0) {
        rate_ = 1.0 - shift;
      } else {
        rate_ = 0.0;
        delay_[0] = halfLength_ + 12;
      }
    }

    double tick(double input, uint channel = 0) {
        // Calculate the two delay length values, keeping them within the
        // range 12 to maxDelay-12.
        delay_[0] += rate_;
        while (delay_[0] > maxDelay-12) delay_[0] -= delayLength_;
        while (delay_[0] < 12) delay_[0] += delayLength_;
    
        delay_[1] = delay_[0] + halfLength_;
        while (delay_[1] > maxDelay-12) delay_[1] -= delayLength_;
        while (delay_[1] < 12) delay_[1] += delayLength_;
    
        // Set the new delay line lengths.
        delayLine_[0].delay = delay_[0];
        delayLine_[1].delay = delay_[1];
    
        // Calculate a triangular envelope.
        env_[1] = fabs((delay_[0] - halfLength_ + 12) * (1.0 / (halfLength_ + 12)));
        env_[0] = 1.0 - env_[1];
    
        // Delay input and apply envelope.
        lastOut_ =  env_[0] * delayLine_[0].tick(input);
        lastOut_ += env_[1] * delayLine_[1].tick(input);
    
        // Compute effect mix and output.
        lastOut_ *= effectMix_;
        lastOut_ += (1.0 - effectMix_) * input;
    
        return lastOut_;
    }

  protected:
    DelayL delayLine_[2];
    double delay_[2];
    double env_[2];
    double rate_;
    double lastOut_;
    uint delayLength_;
    uint halfLength_;

}
