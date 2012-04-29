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

module synd.envelope;

import std.math;
import synd.common;

/**
 * ADSR envelope class.
 *
 * This class implements a traditional ADSR (Attack, Decay, Sustain,
 * Release) envelope.  It responds to simple keyOn and keyOff
 * messages, keeping track of its state.  The \e state = ADSR::IDLE
 * before being triggered and after the envelope value reaches 0.0 in
 * the ADSR::RELEASE state.  All rate, target and level settings must
 * be non-negative.  All time settings must be positive.
 */
class ADSR : Generator {
    
    enum { A, D, S, R, IDLE }      
    
    void on() {
        state_ = A;
        last = 0.0;
    } 
            
    void off() {
        state_ = R;    
        releaseRate = last / releaseSamples;
    } 
    
    void setADSR(double _a, double _d, double _s, double _r) {
        attackRate = attackTarget / _a;
        decayRate = (attackTarget - _s) / _d;
        sustain = _s;
        releaseSamples = _r;
    }
    
    @property double lastOut() { return last; }

    @property int state() { return state_; }
    
    double tick() {
        if (state_ == A) { // attack
          last += attackRate;
          if (last >= attackTarget) {
            last = attackTarget;
            state_ = D;
          }     
        } else if (state_ == D) { // decay
          last -= decayRate;
          if (last <= sustain) {
            last = sustain;
            state_ = S;
          }  
        } else if (state_ == R) { // release
          last -= releaseRate;
          if (last < 0.0) {
            last = 0.0;
            state_ = IDLE;
          }    
        } 
        return last;
    }
    
  protected:
    double attackTarget = 1.0; // TODO : make modifiable
    double attackRate, decayRate, releaseSamples, releaseRate = 0.0;
    double sustain = 0.5;
    double last = 0.0;
    int state_ = IDLE;    
}

unittest {
    import std.stdio;
    ADSR adsr = new ADSR();
    adsr.setADSR(10, 5, 0.5, 20);

    adsr.on();
    assert(ADSR.A == adsr.state);
    for (uint i = 0; i < 11; i++) adsr.tick();
    assert(abs(1.0 - adsr.lastOut()) < 0.001);
    assert(ADSR.D == adsr.state); 
    for (uint i = 0; i < 6;  i++) adsr.tick();
    assert(abs(0.5 - adsr.lastOut()) < 0.001);
    assert(ADSR.S == adsr.state);  

    adsr.off();
    assert(ADSR.R == adsr.state);
    for (uint i = 0; i < 20; i++) adsr.tick();
    assert(0.0 == adsr.lastOut());
}

private const double TARGET_THRESHOLD = 0.000001;

/** 
 * asymptotic curve envelope class
 *
 * This class implements a simple envelope generator which 
 * asymptotically approaches a target value.
 * The algorithm used is of the form:
 *
 * y[n] = a y[n-1] + (1-a) target,
 *
 * where a = exp(-T/tau), T is the sample period, and tau is a
 * time constant.  The user can set the time constant 
 * (default value = 0.3) and target value. Theoretically, this 
 * recursion never reaches its target, though the calculations 
 * in this class are stopped when the current value gets within 
 * a small threshold value of the target (at which time the
 * current value is set to the target).  It responds
 * to \e keyOn and \e keyOff messages by ramping to 1.0 on 
 * keyOn and to 0.0 on keyOff.
 */
class Asymp : Generator {
 
    this(double sr){     
        sampleRate_ = sr;  
        factor_ = exp(-1.0 / (0.3 * sampleRate_));
    }

    void on() {
        target = 1.0;
    }

    void off() {
        target = 0.0;
    }

    @property void tau(double tau) {
        factor_ = exp(-1.0 / (tau * sampleRate_));
        constant_ = (1.0 - factor_) * target_;
    }

    @property void time(double time) {
        double tau = -time / log(TARGET_THRESHOLD);
        factor_ = exp(-1.0 / (tau * sampleRate_));
        constant_ = (1.0 - factor_) * target_;
    }

    @property void t60(double t60) {
        tau = t60 / 6.91;
    }

    @property void target(double target) {
        target_ = target;
        if (value_ != target_) state_ = true;
        constant_ = (1.0 - factor_) * target_;
    }

    @property void value(double value) {
        state_ = false;
        target_ = value;
        value_ = value;
    }

    @property int state() { return state_; }

    double tick() {
        if (state_) {    
          value_ = factor_ * value_ + constant_;    
          // Check threshold.
          if (target_ > value_) {
            if (target_ - value_ <= TARGET_THRESHOLD) {
              value_ = target_;
              state_ = false;
            }
          } else {
            if (value_ - target_ <= TARGET_THRESHOLD) {
              value_ = target_;
              state_ = false;
            }
          }
          last_ = value_;
      }    
      return value_;
    }

  protected:
    double sampleRate_;
    double last_, value_ = 0.0, target_, factor_, constant_;
    bool state_ = false;
}

unittest {
    import std.stdio;
    Asymp env = new Asymp(100.0);
    env.time = 0.1;

    env.on();
    for (uint i = 0; i < 10; i++)  env.tick();
    assert(abs(env.tick() - 1.0) < 0.001);

    env.off();
    for (uint i = 0; i < 10; i++)  env.tick();
    assert(env.tick() < 0.001);
}

/** 
 * linear line envelope class.
 *
 * This class implements a simple linear line envelope generator
 * which is capable of ramping to an arbitrary target value by a
 * specified \e rate.  It also responds to simple \e keyOn and \e
 * keyOff messages, ramping to 1.0 on keyOn and to 0.0 on keyOff.
 */
class Envelope : Generator {

    void on() { 
        target_ = 1.0; 
        state_ = last_ != target_;
    }

    void off() { target_ = 0.0; }
    
    @property void target(double t) {
        target_ = t;
        state_ = last_ != target_;
    }

    @property void time(double samples) {
        rate_ = 1.0 / samples;
    }
    
    @property void rate(double r) { rate_ = r; }

    double tick() {
        if (state_) {
          if (target_ > last_) {
            last_ += rate_;
            if (last_ >= target_) {
              last_ = target_;
              state_ = 0;
            }  
          } else {
            last_ -= rate_;
            if (last_ <= target_) {
              last_ = target_;
              state_ = 0;
            }     
          }
        }
        return last_;
    }

  protected:
    bool state_;
    double target_, last_ = 0.0, rate_;  
    
}

unittest {
    Envelope env = new Envelope();
    env.time = 10;

    
}
