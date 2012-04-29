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
module synd.singwave;

import synd.files;
import synd.common;
import synd.modulate;
import synd.envelope;

/**
 * "singing" looped soundfile class.
 *
 * This class loops a specified soundfile and modulates it both periodically 
 * and randomly to produce a pitched musical sound, like a simple voice or 
 * violin.  In general, it is not be used alone because of "munchkinification" 
 * effects from pitch shifting.
 */
class SingWave : Generator {
 
    this(double sr, string fileName, bool raw = false) {
        sampleRate_ = sr;
        // An exception could be thrown here.
        wave_ = new FileLoop(sr);
        wave_.openFile(fileName, raw);
    
        rate_ = 1.0;
        sweepRate_ = 0.001;
    
        modulator_ = new Modulate(sr);
        modulator_.vibratoRate = 6.0;
        modulator_.vibratoGain = 0.04;
        modulator_.randomGain = 0.005;
    
        envelope_ = new Envelope();
    
        pitchEnvelope_ = new Envelope();
        this.frequency = 75.0;
        pitchEnvelope_.rate = 1.0;
        this.tick();
        this.tick();
        pitchEnvelope_.rate = sweepRate_ * rate_;
    }
    
    void reset() { 
        wave_.reset(); 
        lastOut_ = 0.0; 
    }

    void normalize() { wave_.normalize(); }

    void normalize(double peak) { wave_.normalize(peak); }

    @property void frequency(double frequency) {
          double temp = rate_;
          rate_ = wave_.length * frequency / sampleRate_;
          temp -= rate_;
          if (temp < 0) temp = -temp;
          pitchEnvelope_.target = rate_;
          pitchEnvelope_.rate = sweepRate_ * temp;
    }

    @property void vibratoRate(double rate) { modulator_.vibratoRate = rate; }

    @property void vibratoGain(double gain) { modulator_.vibratoGain = gain; }

    @property void randomGain(double gain) { modulator_.randomGain = gain; }

    @property void sweepRate(double rate) { sweepRate_ = rate; }

    @property void gainRate(double rate) { envelope_.rate = rate; }

    @property void gainTarget(double target) { envelope_.target = target; }

    void on() { envelope_.on(); }

    void off() { envelope_.off(); }

    double tick() {
        // Set the wave rate.
        double newRate = pitchEnvelope_.tick();
        newRate += newRate * modulator_.tick();
        wave_.rate = newRate;
    
        lastOut_ = wave_.tick();
        lastOut_ *= envelope_.tick();
    
        return lastOut_;
    }


 protected:

  FileLoop wave_;
  Modulate modulator_;
  Envelope envelope_;
  Envelope pitchEnvelope_;
  double rate_, sweepRate_, lastOut_, sampleRate_;

}
