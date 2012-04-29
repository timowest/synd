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

module synd.wave;

import synd.common;

/**
 * audio input abstract base class.
 *
 * This class provides common functionality for a variety of audio
 * data input subclasses. 
 */
class WvIn  {

    @property uint channelsOut() { return data_.channels(); }

    @property ref Frames lastFrame() { return lastFrame_; }

    abstract double tick(uint channel = 0);

    abstract ref Frames tick(ref Frames frames);

  protected:
    Frames data_;
    Frames lastFrame_;

};

    
/**
 * audio output abstract base class.
 *
 * This class provides common functionality for a variety of audio
 * data output subclasses.
 *
 * Currently, WvOut is non-interpolating and the output rate is
 * always Stk::sampleRate().
 */
class WvOut {

    this(double sr) {
        sampleRate_ = sr;
    }

    @property uint getFrameCount() { return frameCounter_; }

    @property double time() { return cast(double) frameCounter_ / sampleRate_; }

    @property bool clipStatus() { return clipping_; }

    void resetClipStatus() { clipping_ = false; }

    abstract void tick(double sample);

    abstract void tick(ref Frames frames);

  protected:
    
    ref double clipTest(ref double  sample) {
        bool clip = false;
        if (sample > 1.0) {
          sample = 1.0;
          clip = true;
        } else if (sample < -1.0) {
          sample = -1.0;
          clip = true;
        }        
        return sample;
    }

    Frames data_;
    uint frameCounter_;
    bool clipping_;
    double sampleRate_;

};
