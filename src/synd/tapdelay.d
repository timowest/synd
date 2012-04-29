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
module synd.tapdelay;

import synd.common;

/**
 * non-interpolating tapped delay line class.
 *
 * This class implements a non-interpolating digital delay-line with an 
 * arbitrary number of output "taps".  If the maximum length and tap 
 * delays are not specified during instantiation, a fixed maximum length 
 * of 4095 and a single tap delay of zero is set.
 */  
class TapDelay : Filter {
 
    //TapDelay(long *taps = std::vector<unsigned long>(1, 0), unsigned long maxDelay = 4095);
    
    this(int[] taps, uint maxDelay) {
        inputs_ = new double[maxDelay + 1];
        inPoint_ = 0;
        this.tapDelays = taps;
    }
    

    @property void maximumDelay(uint delay) {
        if (delay < inputs_.length) return;
        inputs_ = new double[delay + 1];
    }

    @property void tapDelays(int[] taps) {
        if (taps.length != outPoint_.length) {
          outPoint_ = new int[taps.length];
          delays_ = new int[taps.length];
          lastFrame_ = new double[taps.length];
        }
        for (uint i = 0; i < taps.length; i++) {
          // read chases write
          if (inPoint_ >= taps[i]) outPoint_[i] = inPoint_ - taps[i];
          else outPoint_[i] = inputs_.length + inPoint_ - taps[i];
          delays_[i] = taps[i];
        }
    }

    @property int[] tapDelays() { return delays_; }

    double lastOut(uint tap = 0) {
      return lastFrame_[tap];
    }

    ref double[] tick(double input, ref double[] outputs) {    
      inputs_[inPoint_++] = input * gain_;
    
      // Check for end condition
      if (inPoint_ == inputs_.length) {
        inPoint_ = 0;
      }
    
      // Read out next values
      double *outs = &outputs[0];
      for (uint i = 0; i < outPoint_.length; i++) {
        *outs++ = inputs_[outPoint_[i]];
        lastFrame_[i] = *outs;
        if (++outPoint_[i] == inputs_.length) { 
          outPoint_[i] = 0;
        }  
      }
    
      return outputs;
    }

  protected:

    uint inPoint_;
    int[] outPoint_;
    int[] delays_;
    double[] inputs_;
    double[] lastFrame_;

};


