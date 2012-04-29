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

module synd.modulate;

import synd.common;
import synd.filter;
import synd.osc;
import synd.noise;

/**
 * periodic/random modulator.
 *
 * This class combines random and periodic modulations to give a nice, natural human
 * modulation function.
 */
class Modulate : Generator {
 
    this(double sr) {
      vibrato_ = new SineWave(sr);
      vibrato_.frequency = 6.0;
      vibratoGain_ = 0.04;
      noise_ = new Noise();
      noiseRate_ = cast(uint) (330.0 * sr / 22050.0);
      noiseCounter_ = noiseRate_;
      randomGain_ = 0.05;
      filter_ = new OnePole();
      filter_.setPole(0.999);
      filter_.gain = randomGain_;
    }

    void reset() { last_ = 0.0; }

    @property void vibratoRate(double rate) { vibrato_.frequency = rate; }

    @property void vibratoGain(double gain) { vibratoGain_ = gain; }

    @property void randomGain(double gain) {
      randomGain_ = gain;
      filter_.gain = randomGain_;
    }

    double tick() {
      // Compute periodic and random modulations.
      last_ = vibratoGain_ * vibrato_.tick();
      if (noiseCounter_++ >= noiseRate_) {
        noise_.tick();
        noiseCounter_ = 0;
      }
      last_ += filter_.tick(noise_.lastOut);
      return last_;
    }

 protected:   
    SineWave vibrato_;
    Noise noise_;
    OnePole  filter_;
    double vibratoGain_, randomGain_, last_;
    uint noiseRate_, noiseCounter_;

}
