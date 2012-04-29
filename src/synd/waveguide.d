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

module synd.waveguide;

import std.math;

// This function provides a flue jet non-linear function, computed by a polynomial calculation.
// Contrary to the name, this is not a "table".
pure double jetTable(double input) {
    // Perform "table lookup" using a polynomial
    // calculation (x^3 - x), which approximates
    // the jet sigmoid behavior.
    double output = input * (input * input - 1.0);
    
    // Saturate at +/- 1.0.
    if (output > 1.0) output = 1.0;
    if (output < -1.0) output = -1.0; 
    return output;
}

// This class implements a simple one breakpoint, non-linear reed function, as described by
// Smith (1986).  This function is based on a memoryless non-linear spring model of the reed
// (the reed mass is ignored) which saturates when the reed collides with the mouthpiece facing.
pure double reedTable(double offset, double slope, double input) {
    // The input is differential pressure across the reed.
    double output = offset + (slope * input);
    
    // If output is > 1, the reed has slammed shut and the
    // reflection function value saturates at 1.0.
    if (output > 1.0) output = 1.0;
    
    // This is nearly impossible in a physical system, but
    // a reflection function value of -1.0 corresponds to
    // an open end (and no discontinuity in bore profile).
    if (output < -1.0) output = -1.0;
    return output;
}

// This class implements a simple bowed string non-linear function, as described by Smith
// (1986).  The output is an instantaneous reflection coefficient value.
pure double bowTable(double offset, double slope, double min, double max, double input) {
    // The input represents differential string vs. bow velocity.
    double sample  = (input + offset) * slope;  // add bias to input and scale it
    double output = pow(abs(sample) + 0.75, -4.0);
    if (output < min) output = min;
    if (output > max) output = max;
    return output;
}

pure double cubic(double a1_, double a2_, double a3_, double gain_, double threshold_, double input) {
    double inSquared = input * input;
    double inCubed = inSquared * input;
    double output = gain_ * (a1_ * input + a2_ * inSquared + a3_ * inCubed);
    // Apply threshold if we are out of range.
    if (fabs(output) > threshold_) {
        output = (output < 0 ? -threshold_ : threshold_);
    }
    return output;    
}

/**
 * cubic non-linearity class.
 *
 * This class implements the cubic non-linearity that was used in SynthBuilder.
 *
 * The formula implemented is:
 * 
 * \code
 * output = gain * (a1 * input + a2 * input^2 + a3 * input^3)
 * \endcode
 *
 * followed by a limiter for values outside +-threshold.
 */
class Cubic {
    
    this() { 
        a1_ = 0.5; 
        a2_ = 0.5; 
        a3_ = 0.5; 
        gain_ = 1.0; 
        threshold_ = 1.0;
    }

    void setParameters(double a1, double a2, double a3, double gain, double threshold) {
        a1_ = a1;
        a2_ = a2;
        a3_ = a3;
        gain_ = gain;
        threshold_ = threshold;        
    }

    double tick(double input) {
        double inSquared = input * input;
        double inCubed = inSquared * input;
        double output = gain_ * (a1_ * input + a2_ * inSquared + a3_ * inCubed);
        // Apply threshold if we are out of range.
        if (fabs(output) > threshold_) {
            output = (output < 0 ? -threshold_ : threshold_);
        }
        return output;
    }

  protected:
    double a1_, a2_, a3_, gain_, threshold_;
  
}
