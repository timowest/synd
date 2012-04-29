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
module synd.formsweep;

import std.math;
import synd.common;

/**
 * sweepable formant filter class.
 *
 * This class implements a formant (resonance) which can be "swept"
 * over time from one frequency setting to another.  It provides
 * methods for controlling the sweep rate and target frequency.
 */
class FormSwep : Filter {

    this(double sr) {
        sampleRate_ = sr;
        sweepRate_ = 0.002;
        dirty_ = false;
        a_[0] = 1.0;
    }

//    void ignoreSampleRateChange(bool ignore = true) { 
//        ignoreSampleRateChange_ = ignore; 
//    }

    void setResonance(double frequency, double radius) {   
        radius_ = radius;
        frequency_ = frequency;
    
        a_[2] = radius * radius;
        a_[1] = -2.0 * radius * cos(TWO_PI * frequency / sampleRate_);
    
        // Use zeros at +- 1 and normalize the filter peak gain.
        b_[0] = 0.5 - 0.5 * a_[2];
        b_[1] = 0.0;
        b_[2] = -b_[0];
    }

    void setStates(double frequency, double radius, double gain = 1.0) {
        dirty_ = false;
    
        if (frequency_ != frequency || radius_ != radius)
          this.setResonance(frequency, radius);
    
        gain_ = gain;
        targetFrequency_ = frequency;
        targetRadius_ = radius;
        targetGain_ = gain;
    }

    void setTargets(double frequency, double radius, double gain = 1.0) {    
        dirty_ = true;
        startFrequency_ = frequency_;
        startRadius_ = radius_;
        startGain_ = gain_;
        targetFrequency_ = frequency;
        targetRadius_ = radius;
        targetGain_ = gain;
        deltaFrequency_ = frequency - frequency_;
        deltaRadius_ = radius - radius_;
        deltaGain_ = gain - gain_;
        sweepState_ = 0.0;
    }

    @property void sweepRate(double rate) {    
        sweepRate_ = rate;
    }

    @property void sweepTime(double time) {    
        sweepRate_ = 1.0 / (time * sampleRate_);
    }

    @property double lastOut() const { return last_; }

    double tick(double input) {                                     
        if (dirty_)  {
          sweepState_ += sweepRate_;
          if (sweepState_ >= 1.0)   {
            sweepState_ = 1.0;
            dirty_ = false;
            radius_ = targetRadius_;
            frequency_ = targetFrequency_;
            gain_ = targetGain_;
          } else {
            radius_ = startRadius_ + (deltaRadius_ * sweepState_);
            frequency_ = startFrequency_ + (deltaFrequency_ * sweepState_);
            gain_ = startGain_ + (deltaGain_ * sweepState_);
          }
          this.setResonance(frequency_, radius_);
        }
    
        inputs_[0] = gain_ * input;
        last_ = b_[0] * inputs_[0] + b_[1] * inputs_[1] + b_[2] * inputs_[2];
        last_ -= a_[2] * outputs_[2] + a_[1] * outputs_[1];
        inputs_[2] = inputs_[1];
        inputs_[1] = inputs_[0];
        outputs_[2] = outputs_[1];
        outputs_[1] = last_;
        return last_;
    }


 protected:
    double[3] a_, b_, inputs_, outputs_;
    double last_;
    bool dirty_;
    double frequency_;
    double radius_;
    double startFrequency_;
    double startRadius_;
    double startGain_;
    double targetFrequency_;
    double targetRadius_;
    double targetGain_;
    double deltaFrequency_;
    double deltaRadius_;
    double deltaGain_;
    double sweepState_;
    double sweepRate_;
    double sampleRate_;

}
