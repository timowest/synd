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

module synd.filter;

import std.math;
import synd.common;

// TODO : fix filter gains

/**
 * one-pole filter class.
 *
 * This class implements a one-pole digital filter.  A method is
 * provided for setting the pole position along the real axis of the
 * z-plane while maintaining a constant peak filter gain.
 */
class OnePole : Filter {

    void clear() {
        last_ = 0.0;
    }

    void setCoefficients(double b0, double a1) {    
        b0_ = b0;
        a1_ = a1;
    }

    void setPole(double p) {    
        b0_ = (p > 0.0) ? (1.0 - p) : (1.0 + p);
        a1_ = -p;
    }

    double tick(double input) {
        last_ = b0_ * input - a1_ * last_;
        return last_;
    }
    
  protected:
    double b0_, a1_, last_;      

}

/**
 * one-zero filter class.
 *
 * This class implements a one-zero digital filter.  A method is
 * provided for setting the zero position along the real axis of the
 * z-plane while maintaining a constant filter gain.
 */
class OneZero : Filter {
    
    void clear() {
        last_ = prevIn_ = 0.0;
    }    

    void setCoefficients(double b0, double b1) {
        b0_ = b0;
        b1_ = b1;
    }

    void setZero(double z) {
        b0_ = (z > 0.0) ? (1.0 + z) : (1.0 - z);
        b1_ = -z * b0_;
    }

    double tick(double input) {
      last_ = b0_ * input + b1_ * prevIn_;
      prevIn_ = input;
      return last_;
    }

  protected:
    double b0_, b1_, last_, prevIn_;   
       
}

/**
 * one-pole, one-zero filter class.
 *
 * This class implements a one-pole, one-zero digital filter.  A
 * method is provided for creating an allpass filter with a given
 * coefficient.  Another method is provided to create a DC blocking
 * filter. 
 */
class PoleZero : Filter {
    
    void clear() {
        last_ = prevIn_ = 0.0;
    }        
 
    void setCoefficients(double b0, double b1, double a1) {    
        b0_ = b0;
        b1_ = b1;
        a1_ = a1;
    }

    void setAllpass(double coefficient) {    
        b0_ = coefficient;
        b1_ = 1.0;
        a0_ = 1.0; // just in case
        a1_ = coefficient;
    }

    void setBlockZero(double thePole = 0.99) {    
        b0_ = 1.0;
        b1_ = -1.0;
        a0_ = 1.0; // just in case
        a1_ = -thePole;
    }

    double tick(double input) {
        last_ = b0_ * input + b1_ * prevIn_ - a1_ * last_;
        prevIn_ = input;
        return last_;
    }

protected:
    double a0_, a1_, b0_, b1_, last_, prevIn_;

}

/**
 * two-pole filter class.
 *
 * This class implements a two-pole digital filter.  A method is
 * provided for creating a resonance in the frequency response while
 * maintaining a nearly constant filter gain.
 */
class TwoPole : Filter {
    
    void clear() {
        last_ = last__ = 0.0;
    }        

    void setCoefficients(double b0, double a1, double a2) {
        b0_ = b0;
        a1_ = a1;
        a2_ = a2;
    }

    double tick(double input) {
        double temp = last_;
        last_ = b0_ * input - a1_ * last_ - a2_ * last__;
        last__ = temp;
        return last_;
    }

 protected:
    double b0_, a1_, a2_, last_, last__;
    
}

/**
 * two-zero filter class.
 *
 * This class implements a two-zero digital filter.  A method is
 * provided for creating a "notch" in the frequency response while
 * maintaining a constant filter gain.
 */
class TwoZero : Filter {
    
    void clear() {
        last_ = prevIn_ = prevIn__ = 0.0;
    }       

    void setCoefficients(double b0, double b1, double b2) {
        b0_ = b0;
        b1_ = b1;
        b2_ = b2;
    }

    double tick(double input) {
        last_ = b0_ * input + b1_ * prevIn_ + b2_ * prevIn__;
        prevIn__ = prevIn_;
        prevIn_ = input;
        return last_;
    }

 protected:
    double b0_, b1_, b2_, last_, prevIn_, prevIn__;
    
}

/**
 * biquad (two-pole, two-zero) filter class.
 *
 * This class implements a two-pole, two-zero digital filter.
 * Methods are provided for creating a resonance or notch in the
 * frequency response while maintaining a constant filter gain.
 */
class BiQuad : Filter {
    
    void clear() {
        last_ = last__ = prevIn_ = prevIn__ = 0.0;
    }           

    void setCoefficients(double b0, double b1, double b2, double a1, double a2) {
        b0_ = b0;
        b1_ = b1;
        b2_ = b2;
        a1_ = a1;
        a2_ = a2;
    }

    double tick(double input) {
        double temp = last_;
        last_ = b0_ * input + b1_ * prevIn_ + b2_ * prevIn__;
        last_ -=  a1_ * temp + a2_ * last__;
        prevIn__ = prevIn_;
        prevIn_ = input;
        last__ = temp;
        return last_;
    }

 protected:
    double b0_, b1_, b2_, a1_, a2_, last_, prevIn_, prevIn__, last__;
}

/**
 * general finite impulse response filter class.
 *
 * This class provides a generic digital filter structure that can be
 * used to implement FIR filters.  For filters with feedback terms,
 * the Iir class should be used.
 */
class Fir : Filter { // FIXME
    
    this(double sr, double[] coefficients) {
        sampleRate_ = sr;
        gain_ = 1.0;
        b_ = coefficients;
        inputs_ = new double[coefficients.length];
        this.clear();
    }
    
    void clear() {
        
    }
    
    void setCoefficients(double[] coefficients) {    
        if (b_.length != coefficients.length) {
          b_ = coefficients;
          inputs_ = new double[coefficients.length];
        } else {
          for (uint i = 0; i < b_.length; i++) b_[i] = coefficients[i];
        }
    }

    double tick(double input) {
        last_ = 0.0;
        inputs_[0] = gain_ * input;
    
        for (uint i = b_.length - 1; i > 0; i--) {
          last_ += b_[i] * inputs_[i];
          inputs_[i] = inputs_[i-1];
        }
        last_ += b_[0] * inputs_[0];
        return last_;
    }
    
    // common functionality for Fir and Iir
    double phaseDelay(double frequency) { 
        double omegaT = 2 * PI * frequency / sampleRate_;
        double r = 0.0, i = 0.0;
        for (uint j = 0; j < b_.length; j++ ) {
          r += b_[j] * cos(j * omegaT);
          i -= b_[j] * sin(j * omegaT);
        }
        r *= gain_;
        i *= gain_;

        double phase = atan2(i, r);

        r = 0.0, i = 0.0;
        /*for (uint j=0; j < a_.length; j++ ) {
          r += a_[j] * cos(j * omegaT);
          i -= a_[j] * sin(j * omegaT);
        }*/

        phase -= atan2(i, r);
        phase = fmod(-phase, 2 * PI );
        return phase / omegaT;
    }    

  protected:
    double[] inputs_, b_;
    double last_, sampleRate_;

}

/**
 * general infinite impulse response filter class.
 *
 * This class provides a generic digital filter structure that can be
 * used to implement IIR filters.  For filters containing only
 * feedforward terms, the Fir class is slightly more efficient.
 */
class Iir : Filter { // FIXME

    this(double[]  bCoefficients, double[]  aCoefficients) {    
        gain_ = 1.0;
        b_ = bCoefficients;
        a_ = aCoefficients;
        this.clear();
    }

    void clear() {
        
    }

    void setCoefficients(double[] bCoefficients, double[] aCoefficients) {
        numerator = bCoefficients;
        denominator = aCoefficients;
    }

    @property void numerator(double[] bCoefficients) {
        if (b_.length != bCoefficients.length) {
          b_ = bCoefficients;
          inputs_ = new double[b_.length];
        } else {
          for (uint i=0; i<b_.length; i++) b_[i] = bCoefficients[i];
        }
    }

    @property void denominator(double[] aCoefficients) {    
        if (a_.length != aCoefficients.length) {
          a_ = aCoefficients;
          outputs_ = new double[a_.length];
        } else {
          for (uint i = 0; i < a_.length; i++) a_[i] = aCoefficients[i];
        }
    
        // Scale coefficients by a[0] if necessary
        if (a_[0] != 1.0) {
          uint i;
          for (i = 0; i < b_.length; i++) b_[i] /= a_[0];
          for (i = 1; i < a_.length; i++)  a_[i] /= a_[0];
        }
    }

    double tick(double input) {
        uint i;
        outputs_[0] = 0.0;
        inputs_[0] = gain_ * input;
        for (i = b_.length - 1; i > 0; i--) {
          outputs_[0] += b_[i] * inputs_[i];
          inputs_[i] = inputs_[i-1];
        }
        outputs_[0] += b_[0] * inputs_[0];
    
        for (i = a_.length- 1; i > 0; i--) {
          outputs_[0] += -a_[i] * outputs_[i];
          outputs_[i] = outputs_[i-1];
        }
        last_ = outputs_[0];
        return last_;
    }

  protected:
    double[] a_, b_, inputs_, outputs_;
    double last_;
     
}
