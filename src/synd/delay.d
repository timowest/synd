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

module synd.delay;

import synd.common;

/**
 * non-interpolating delay line class.
 *
 * This class implements a non-interpolating digital delay-line.  If
 * the delay and maximum length are not specified during
 * instantiation, a fixed maximum length of 4095 and a delay of zero
 * is set.
 *   
 * A non-interpolating delay line is typically used in fixed
 * delay-length applications, such as for reverberation.
 */
class Delay : Filter {
  
    this(uint d = 0, uint max = 4095) {
        buffer_ = new double[max];
        buffer_[0 .. $] = 0.0;
        delay = d;
    }
    
    @property double delay() { return delay_; }
      
    @property void delay(uint d) {   
        if (inPoint_ >= d) outPoint_ = inPoint_ - d;
        else outPoint_ = buffer_.length + inPoint_ - d;
        delay_ = d;
    }
    
    @property void maximumDelay(uint delay) {
        buffer_ = new double[delay];
        clear(); 
    }
      
    void clear() {
        buffer_[0 .. $] = 0.0;
        last_ = 0.0;
    }   
      
    double nextOut() { 
        return buffer_[outPoint_]; 
    }  
    
    @property double lastOut() { return last_; }
      
    double tick(double input) {
        buffer_[inPoint_++] = input;
        if (inPoint_ == buffer_.length) inPoint_ = 0;
        last_ = buffer_[outPoint_++];    
        if (outPoint_ == buffer_.length) outPoint_ = 0;
        return last_;
    }
      
  private:     
    double[] buffer_;
    double last_ = 0.0;
    uint inPoint_, outPoint_, delay_;
}

unittest {
    Delay delay = new Delay(2);
    assert(2 == delay.delay);

    double[] vals = [
      delay.tick(1.0), delay.tick(0.9), delay.tick(0.8), 
      delay.tick(0.7), delay.tick(0.6)];
    assert(0.0 == vals[0]);
    assert(0.0 == vals[1]);
    assert(1.0 == vals[2]);
    assert(0.9 == vals[3]);
    assert(0.8 == vals[4]);
}

/**
 * allpass interpolating delay line class.
 *
 * This class implements a fractional-length digital delay-line using
 * a first-order allpass filter.  If the delay and maximum length are
 * not specified during instantiation, a fixed maximum length of 4095
 * and a delay of 0.5 is set.
 */
class DelayA : Filter {
  
    this(double d = 0.5, uint max = 4095) {
        buffer_ = new double[max];
        buffer_[0 .. $] = 0.0;
        delay = d;
    }

    @property double delay() { return delay_; }
  
    @property void delay(double delay) {   
        uint length = buffer_.length;   
        double outPointer = inPoint_ - delay + 1.0; // outPoint chases inpoint
        delay_ = delay;
        while (outPointer < 0)
          outPointer += length;  // modulo maximum length
        outPoint_ = cast(int) outPointer;         // integer part
        if (outPoint_ == length) outPoint_ = 0;
        alpha_ = 1.0 + outPoint_ - outPointer; // fractional part
        if (alpha_ < 0.5) {
          // The optimal range for alpha is about 0.5 - 1.5 in order to
          // achieve the flattest phase delay response.
          outPoint_ += 1;
          if (outPoint_ >= length) outPoint_ -= length;
          alpha_ += cast(double) 1.0;
        }
        coeff_ = (1.0 - alpha_) / (1.0 + alpha_);  // coefficient for allpass
    }

    @property void maximumDelay(uint delay) {
        buffer_ = new double[delay];
        clear(); 
    }
      
    void clear() {
        buffer_[0 .. $] = 0.0;
        last_ = 0.0;
        apInput_ = 0.0;
    }  
      
    double nextOut() {
        if (doNextOut_) {
          // Do allpass interpolation delay.
          nextOutput_ = -coeff_ * last_;
          nextOutput_ += apInput_ + (coeff_ * buffer_[outPoint_]);
          doNextOut_ = false;
        }
        return nextOutput_;
    }  
    
    @property double lastOut() { return last_; }
  
    double tick(double input) {
        buffer_[inPoint_++] = input * gain_;
        if (inPoint_ == buffer_.length) inPoint_ = 0;
        last_ = nextOut();
        doNextOut_ = true;
        // Save the allpass input and increment modulo length.
        apInput_ = buffer_[outPoint_++];
        if (outPoint_ == buffer_.length) outPoint_ = 0;
        return last_;
    }
    
  private:     
    double[] buffer_;
    uint inPoint_, outPoint_;
    double delay_, alpha_, coeff_, last_ = 0.0;
    double apInput_ = 0.0,  nextOutput_ = 0.0;
    bool doNextOut_ = true;
}

unittest {
    DelayA delay = new DelayA(2.0);
    assert(2.0 == delay.delay);

    double[] vals = [
      delay.tick(1.0), delay.tick(0.9), delay.tick(0.8), 
      delay.tick(0.7), delay.tick(0.6)];
    assert(0.0 == vals[0]);
    assert(0.0 == vals[1]);
    assert(1.0 == vals[2]);
    assert(0.9 == vals[3]);
    assert(0.8 == vals[4]);
}

/**
 * linear interpolating delay line class.
 *
 * This class implements a fractional-length digital delay-line using
 * first-order linear interpolation.  If the delay and maximum length
 * are not specified during instantiation, a fixed maximum length of
 * 4095 and a delay of zero is set.
 */
class DelayL : Filter {
  
    this(uint d = 0, uint max = 4095) {
        buffer_ = new double[max];
        delay = d;
    }

    @property double delay() { return delay_; }
  
    @property void delay(double delay) {   
        double outPointer = inPoint_ - delay;  // read chases write
        delay_ = delay;
        while (outPointer < 0)
          outPointer += buffer_.length; // modulo maximum length
        outPoint_ = cast(int) outPointer;   // integer part
        if (outPoint_ == buffer_.length) outPoint_ = 0;
        alpha_ = outPointer - outPoint_; // fractional part
        omAlpha_ = cast(double) 1.0 - alpha_;
    }
    
    @property void maximumDelay(uint delay) {
        buffer_ = new double[delay];
        clear(); 
    }    
  
    void clear() {
        for (uint i = 0; i < buffer_.length; i++) buffer_[i] = 0.0;
        last_ = 0.0;
    }   
  
    double nextOut() { 
        if (doNextOut_){
          // First 1/2 of interpolation
          nextOutput_ = buffer_[outPoint_] * omAlpha_;
          // Second 1/2 of interpolation
          if (outPoint_+1 < buffer_.length)
            nextOutput_ += buffer_[outPoint_+1] * alpha_;
          else
            nextOutput_ += buffer_[0] * alpha_;
          doNextOut_ = false;
        }
        return nextOutput_;
    }  
    
    @property double lastOut() { return last_; }
  
    double tick(double input) {
        buffer_[inPoint_++] = input * gain_;
        if (inPoint_ == buffer_.length) inPoint_ = 0;
        last_ = nextOut();
        doNextOut_ = true;
        if (++outPoint_ == buffer_.length) outPoint_ = 0;
        return last_;
    }
      
  private:     
    double gain_ = 1.0; // TODO : move into Filter ?!?
    double[] buffer_;
    uint inPoint_, outPoint_ = 0;
    double delay_, alpha_, omAlpha_, nextOutput_, last_ = 0.0;
    bool doNextOut_ = true;
}

unittest {
    DelayA delay = new DelayA(2);
    assert(2.0 == delay.delay);

    double[] vals = [
      delay.tick(1.0), delay.tick(0.9), delay.tick(0.8), 
      delay.tick(0.7), delay.tick(0.6)];
    assert(0.0 == vals[0]);
    assert(0.0 == vals[1]);
    assert(1.0 == vals[2]);
    assert(0.9 == vals[3]);
    assert(0.8 == vals[4]);
}

