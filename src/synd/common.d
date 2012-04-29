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

module synd.common;

private import std.math;

const TWO_PI = 2 * PI;

// TODO : get this from somewhere else
pure bool isPrime(uint number) { 
    if (number == 2) return true;
    if (number & 1) {
      for (int i=3; i <  sqrt(cast(float)number) + 1; i += 2) {
        if ((number % i) == 0 ) return false;    
      }  
      return true; // prime
    } else {
      return false; // even
    }  
}

class Filter {
    
    abstract double tick(double input);
    
    abstract void clear();    
    
    @property gain() { return gain_; }
    
    @property gain(double g) { gain_ = g; }
    
  protected:
    double gain_ = 1.0;    
    
}

class Generator {
    
    //abstract void reset();
    
    abstract double tick();
    
}

class Effect {
    
    abstract double tick(double input, uint channel = 0);
  
    @property effectMix(double mix) { effectMix_ = mix; }
  
  protected:    
    double effectMix_;
}

/**
 * class to handle vectorized audio data.
 *
 * This class can hold single- or multi-channel audio data.  The data
 * type is always double and the channel format is always
 * interleaved.  
 */
class Frames {

    this(double sr, uint frames, uint channels) {
        dataRate_ = sr;
        frames_ = frames;
        channels_ = channels;
        resize(frames, channels);
    }

    void opIndexAssign(double v, size_t i) { data_[i] = v; }

    void opIndexAssign(double v, size_t frame, size_t channel) {
        data_[frame * channels_ + channel] = v;
    }

    ref double opIndex(size_t i) { return data_[i]; }

    ref double opIndex(size_t frame, size_t channel) { 
        return data_[frame * channels_ + channel]; 
    }

    @property uint channels() { return channels_; }

    @property uint frames() { return frames_; }

    @property uint length() { return data_.length; }

    @property double dataRate() { return dataRate_; }

    void resize(uint frames, uint channels = 1) {
        resize(frames, channels, 0.0);
    }

    void resize(uint frames, uint channels, double value ) {
        // TODO : optimize
        data_ = new double[frames * channels];
        data_[0 .. $] = value;
    }

    double interpolate(double frame, uint channel = 0) {
        return 0.0; //TODO
    }

  protected:
    uint frames_, channels_;
    double[] data_;
    double dataRate_;

}

unittest {
    Frames frames = new Frames(44100.0, 100, 2);
    assert(44100.0 == frames.dataRate);
    assert(100 == frames.frames);
    assert(2 == frames.channels);
    assert(200 == frames.length);	

    assert(0.0 == frames[0]);

    frames[1] = 4.3;
    assert(4.3 == frames[1]);

    frames[1,2] = 2.3;
    assert(2.3 == frames[1,2]);

    frames.resize(100, 2, 0.5);
    assert(0.5 == frames[1]);

    frames.resize(100, 2);
    assert(0.0 == frames[2]);
}
