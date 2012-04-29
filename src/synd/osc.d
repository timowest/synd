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

module synd.osc;

import std.math;
import synd.common;

const TABLE_SIZE = 8192;

/**
 * sinusoid oscillator class.
 *
 * This class computes and saves a static sine "table" that can be shared by 
 * multiple instances. It has an interface similar to the WaveLoop class but 
 * inherits from the Generator class.  Output values are computed using 
 * linear interpolation.
 */
class SineWave : Generator {
    
    private static double[TABLE_SIZE + 1] table_;
    
    static this() {
        double temp = 1.0 / TABLE_SIZE;
        for (uint i= 0; i <= TABLE_SIZE; i++)
        table_[i] = sin( TWO_PI * i * temp);
    }
    
    this(double sr) {
        sampleRate = sr; 
        time_ = (0.0); rate_ = (1.0); phaseOffset_ = (0.0);
    }

    void reset() {
        time_ = 0.0;
        lastOut_ = 0.0;
    }

    @property void rate( double rate) { rate_ = rate; }

    @property void frequency( double frequency) {
        this.rate = TABLE_SIZE * frequency / sampleRate;
    }

    void addTime( double time) {
        time_ += time;
    }

    void addPhase( double phase) {
        time_ += TABLE_SIZE * phase;
    }

    void addPhaseOffset( double phaseOffset) {
        time_ += ( phaseOffset - phaseOffset_) * TABLE_SIZE;
        phaseOffset_ = phaseOffset;
    }

    double tick() {
        while ( time_ < 0.0)
          time_ += TABLE_SIZE;
        while ( time_ >= TABLE_SIZE)
          time_ -= TABLE_SIZE;
    
        iIndex_ = cast(uint) time_;
        alpha_ = time_ - iIndex_;
        double tmp = table_[ iIndex_ ];
        tmp += ( alpha_ * ( table_[ iIndex_ + 1 ] - tmp));
    
        // Increment time, which can be negative.
        time_ += rate_;
    
        lastOut_ = tmp;
        return lastOut_;
    }

protected:  
    double sampleRate;
    double time_;
    double rate_;
    double phaseOffset_;
    uint iIndex_;
    double alpha_;
    double lastOut_;

}

/*struct maxiOsc {
        
        double frequency;
        double phase;
        double startphase;
        double endphase;
        double output;
        double tri;

        
public://run dac! 
        
        static maxiOsc opCall(){
                phase = 0.0;
        //      memset(phases,0,500);
        //      memset(freqs,0,500);
        }
        
        double sinewave(double frequency) {
                output=sin (phase*TWOPI);
                if ( phase >= 1.0 ) phase -= 1.0;
                phase += (1./(maxiSettings.sampleRate/frequency));
                return output;
                
        }
        
        double coswave(double frequency) {
                output=cos (phase*TWOPI);
                if ( phase >= 1.0 ) phase -= 1.0;
                phase += (1./(maxiSettings.sampleRate/frequency));
                return output;
                
        }
        
        double phasor(double frequency) {
                output=phase;
                if ( phase >= 1.0 ) phase -= 1.0;
                phase += (1./(maxiSettings.sampleRate/frequency));
                return output;
        }
        
        double phasor(double frequency, double startphase, double endphase) {
                output=phase;
                if (phase<startphase) {
                        phase=startphase;
                }
                if ( phase >= endphase ) phase = startphase;
                phase += ((endphase-startphase)/(maxiSettings.sampleRate/frequency));
                return output;
        }
        
        
        double saw(double frequency) {
                
                output=phase;
                if ( phase >= 1.0 ) phase -= 2.0;
                phase += (1./(maxiSettings.sampleRate/frequency));
                return output;
                
        } 
        
        double triangle(double frequency) {
                if ( phase >= 1.0 ) phase -= 1.0;
                phase += (1./(maxiSettings.sampleRate/frequency));
                if (phase <= 0.5 ) {
                        output =(phase*4)-1;
                } else {
                        output =((0.5-phase)*4)-1;
                }
                return output;
                
        } 
        
        double square(double frequency) {
                if (phase<0.5) output=-1;
                if (phase>0.5) output=1;
                if ( phase >= 1.0 ) phase -= 1.0;
                phase += (1./(maxiSettings.sampleRate/frequency));
                return output;
        }
        
        double pulse(double frequency, double duty) {
                if (duty<0.) duty=0;
                if (duty>1.) duty=1;
                if ( phase >= 1.0 ) phase -= 1.0;
                phase += (1./(maxiSettings.sampleRate/frequency));
                if (phase<duty) output=-1.;
                if (phase>duty) output=1.;
                return output;
        }
        
        double noise() {
                //always the same unless you seed it.
                float r = rand()/cast(float)RAND_MAX;
                output=r*2-1;
                return output;
        }
        
        double sinebuf(double frequency) {
                double remainder;
                phase += 512./(maxiSettings.sampleRate/(frequency*chandiv));
                if ( phase >= 511 ) phase -=512;
                remainder = phase - floor(phase);
                output = cast(double) ((1-remainder) * sineBuffer[1+ cast(int) phase] + remainder * sineBuffer[2+cast(int) phase]);
                return output;
        }
        
        double sinebuf4(double frequency) {
                double remainder;
                double a,b,c,d,a1,a2,a3;
                phase += 512./(maxiSettings.sampleRate/frequency);
                if ( phase >= 511 ) phase -=512;
                remainder = phase - floor(phase);
                
                if (phase==0) {
                        a=sineBuffer[cast(int) 512];
                        b=sineBuffer[cast(int) phase];
                        c=sineBuffer[cast(int) phase+1];
                        d=sineBuffer[cast(int) phase+2];
                        
                } else {
                        a=sineBuffer[cast(int) phase-1];
                        b=sineBuffer[cast(int) phase];
                        c=sineBuffer[cast(int) phase+1];
                        d=sineBuffer[cast(int) phase+2];
                        
                }
                
                a1 = 0.5f * (c - a);
                a2 = a - 2.5 * b + 2.f * c - 0.5f * d;
                a3 = 0.5f * (d - a) + 1.5f * (b - c);
                output = double (((a3 * remainder + a2) * remainder + a1) * remainder + b);
                return output;
        }
        
        void phaseReset(double phaseIn) {
                phase=phaseIn;
                
        }
        
};*/
