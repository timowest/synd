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

module synd.blit;

import std.math;
import synd.common;

/**
 * band-limited impulse train class.
 *
 * This class generates a band-limited impulse train using a
 * closed-form algorithm reported by Stilson and Smith in "Alias-Free
 * Digital Synthesis of Classic Analog Waveforms", 1996.  The user
 * can specify both the fundamental frequency of the impulse train
 * and the number of harmonics contained in the resulting signal.
 */
class Blit : Generator {
 
    this(double sr, double freq = 220.0) {
        sampleRate_ = sr;    
        nHarmonics_ = 0;
        frequency = freq;
        reset();
    }

    void reset() {
        phase_ = 0.0;
        last_ = 0.0;
    }
   
    @property void phase(double phase) { phase_ = PI * phase; }

    @property double phase() { return phase_ / PI; }

    @property void frequency(double frequency) {      
        p_ = sampleRate_ / frequency;
        rate_ = PI / p_;
        this.updateHarmonics();
    }

    @property void harmonics(uint nHarmonics = 0) {
        nHarmonics_ = nHarmonics;
        this.updateHarmonics();
    }

    double tick() {
        double tmp, denominator = sin(phase_);
        if (denominator <= double.epsilon) {
          tmp = 1.0;
        } else {
          tmp =  sin(m_ * phase_);
          tmp /= m_ * denominator;
        }
    
        phase_ += rate_;
        if (phase_ >= PI) phase_ -= PI;
    
        last_ = tmp;
        return last_;
    }

 protected:
    
    void updateHarmonics() {
        if (nHarmonics_ <= 0) {
          uint maxHarmonics = cast(uint) floor(0.5 * p_);
          m_ = 2 * maxHarmonics + 1;
        } else {
          m_ = 2 * nHarmonics_ + 1;
        }  
    }
    
    uint nHarmonics_, m_ = 0;
    double sampleRate_;
    double rate_, phase_,  p_, last_ = 0.0;

}

unittest {
    Blit blit = new Blit(44100.0);
    blit.harmonics = 10;
    double acc = 0.0;
    //for (int i = 0; i < 100; i++) acc += fabs(blit.tick());
    foreach (i; 0..100) acc += fabs(blit.tick());
    assert(acc > 0.0);
}

/**
 * band-limited sawtooth wave class.
 *
 * This class generates a band-limited sawtooth waveform using a
 * closed-form algorithm reported by Stilson and Smith in "Alias-Free
 * Digital Synthesis of Classic Analog Waveforms", 1996.  The user
 * can specify both the fundamental frequency of the sawtooth and the
 * number of harmonics contained in the resulting signal.
 */
class BlitSaw : Generator {
    
    this(double sr, double freq = 220.0) {
        sampleRate_ = sr;
        nHarmonics_ = 0;
        reset();
        frequency = freq;
    }

    void reset() {
        phase_ = 0.0f;
        state_ = 0.0;
        last_ = 0.0;
    }

    @property void frequency(double frequency) {
        p_ = sampleRate_ / frequency;
        C2_ = 1 / p_;
        rate_ = PI * C2_;
        this.updateHarmonics();
    }

    @property void harmonics(uint nHarmonics = 0) {
        nHarmonics_ = nHarmonics;
        this.updateHarmonics();
        state_ = -0.5 * a_;
    }

    double tick() {
        double tmp, denominator = sin(phase_);
        if (fabs(denominator) <= double.epsilon)
          tmp = a_;
        else {
          tmp =  sin(m_ * phase_);
          tmp /= p_ * denominator;
        }
        tmp += state_ - C2_;
        state_ = tmp * 0.995;
    
        phase_ += rate_;
        if (phase_ >= PI) phase_ -= PI;
        
        last_ = tmp;
        return last_;
    }

 protected:
    
    void updateHarmonics() {
        if (nHarmonics_ <= 0) {
          uint maxHarmonics = cast(uint) floor(0.5 * p_);
          m_ = 2 * maxHarmonics + 1;
        } else {
          m_ = 2 * nHarmonics_ + 1;
        }
        a_ = m_ / p_;
    }

    uint nHarmonics_, m_ = 0;
    double sampleRate_;
    double rate_, phase_, p_, C2_, a_, state_, last_ = 0.0;

}

unittest {
    BlitSaw blit = new BlitSaw(44100.0);
    blit.harmonics = 10;
    double acc = 0.0;
    //for (int i = 0; i < 100; i++) acc += fabs(blit.tick());
    foreach (i; 0..100) acc += fabs(blit.tick());
    assert(acc > 0.0);
}

/**
 * band-limited square wave class.
 *
 * This class generates a band-limited square wave signal.  It is
 * derived in part from the approach reported by Stilson and Smith in
 * "Alias-Free Digital Synthesis of Classic Analog Waveforms", 1996.
 * The algorithm implemented in this class uses a SincM function with
 * an even M value to achieve a bipolar bandlimited impulse train.
 * This signal is then integrated to achieve a square waveform.  The
 * integration process has an associated DC offset so a DC blocking
 * filter is applied at the output.
 */
class BlitSquare : Generator {
    
    this(double sr, double freq = 220.0) {
        sampleRate_ = sr;
        nHarmonics_ = 0;
        frequency = freq;
        this.reset();
    }
    
    void reset() {
        phase_ = 0.0;
        last_ = 0.0;
        dcbState_ = 0.0;
        lastBlitOutput_ = 0;
    }

    @property void phase(double phase)  { 
        phase_ = PI * phase;
    }

    @property double phase() {  return phase_ / PI; }

    @property void frequency(double frequency) {
        p_ = 0.5 * sampleRate_ / frequency;
        rate_ = PI / p_;
        this.updateHarmonics();
    }

    @property void harmonics(uint nHarmonics = 0) {
        nHarmonics_ = nHarmonics;
        this.updateHarmonics();
    }

    double tick() {
        double temp = lastBlitOutput_;
        double denominator = sin(phase_);
        if (fabs(denominator)  < double.epsilon) {
          // Inexact comparison safely distinguishes betwen *close to zero*, and *close to PI*.
          if (phase_ < 0.1f || phase_ > TWO_PI - 0.1f)
            lastBlitOutput_ = a_;
          else
            lastBlitOutput_ = -a_;
        } else {
          lastBlitOutput_ =  sin(m_ * phase_);
          lastBlitOutput_ /= p_ * denominator;
        }
    
        lastBlitOutput_ += temp;
    
        // Now apply DC blocker.
        last_ = lastBlitOutput_ - dcbState_ + 0.999 * last_;
        dcbState_ = lastBlitOutput_;
    
        phase_ += rate_;
        if (phase_ >= TWO_PI) phase_ -= TWO_PI;
    
        return last_;
    }

 protected:
    
    void updateHarmonics() {
        // Make sure we end up with an even value of the parameter M here.
        if (nHarmonics_ <= 0) {
            uint maxHarmonics = cast(uint) floor(0.5 * p_);
            m_ = 2 * (maxHarmonics + 1);
        } else {
            m_ = 2 * (nHarmonics_ + 1);
        }
        a_ = m_ / p_;
    }

    double sampleRate_;
    uint nHarmonics_, m_ = 0;
    double rate_, phase_, p_, a_, lastBlitOutput_, dcbState_, last_ = 0.0;
}

unittest {
    BlitSquare blit = new BlitSquare(44100.0);
    blit.harmonics = 10;
    double acc = 0.0;
    //for (int i = 0; i < 100; i++) acc += fabs(blit.tick());
    foreach (i; 0..100) acc += fabs(blit.tick());
    assert(acc > 0.0);
}
