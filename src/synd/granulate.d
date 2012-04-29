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
module synd.granulate;

import std.math;
import synd.common;
import synd.envelope;
import synd.noise;
import synd.files;

/**
 * granular synthesis class.
 *
 * This class implements a real-time granular synthesis algorithm that 
 * operates on an input soundfile.  Multi-channel files are supported.  
 * Various functions are provided to allow control over voice and grain 
 * parameters.
 */ 
class Granulate: Generator {
 
    this(double sr) {
        sampleRate_ = sr;
        this.setGrainParameters(); // use default values
        this.setRandomFactor();
        gStretch_ = 0;
        stretchCounter_ = 0;
        gain_ = 1.0;
    }

    this(double sr, uint nVoices, string fileName, bool typeRaw = false) {
        sampleRate_ = sr;
        this.setGrainParameters(); // use default values
        this.setRandomFactor();
        gStretch_ = 0;
        stretchCounter_ = 0;
        this.openFile(fileName, typeRaw);
        this.setVoices(nVoices);
    }

    void openFile(string fileName, bool typeRaw = false) {
        FileRead file = new FileRead(fileName, typeRaw);
        data_.resize(file.fileSize(), file.channels());
        file.read(data_);
        lastFrame_.resize(1, file.channels(), 0.0);
        this.reset();
        
    }
  
    void reset() {
        gPointer_ = 0;
    
        // Reset grain parameters.
        uint count, nVoices = grains_.length;
        for (uint i=0; i<grains_.length; i++) {
          grains_[i].repeats = 0;
          count = cast(uint) (i * gDuration_ * 0.001 * sampleRate_ / nVoices);
          grains_[i].counter = count;
          grains_[i].state = GrainState.GRAIN_STOPPED;
        }
    
        for (uint i=0; i<lastFrame_.channels(); i++)
          lastFrame_[i] = 0.0;
    }

    void setVoices(uint nVoices = 1) {    
        uint oldSize = grains_.length;
        grains_ = new Grain[nVoices];
    
        // Initialize new grain voices.
        uint count;
        for (uint i=oldSize; i<nVoices; i++) {
          grains_[i].repeats = 0;
          count = cast(uint) (i * gDuration_ * 0.001 * sampleRate_ / nVoices);
          grains_[i].counter = count;
          grains_[i].pointer = gPointer_;
          grains_[i].state = GrainState.GRAIN_STOPPED;
        }
    
        gain_ = 1.0 / grains_.length;
    }

    void setStretch(uint stretchFactor = 1) {
        if (stretchFactor <= 1)
          gStretch_ = 0;
        else if (gStretch_ >= 1000)
          gStretch_ = 1000;
        else
          gStretch_ = stretchFactor - 1;
    }

    void setGrainParameters(uint duration = 30, uint rampPercent = 50,
                                          int offset = 0, uint delay = 0) {
        gDuration_ = duration;    
        gRampPercent_ = rampPercent;    
        gOffset_ = offset;
        gDelay_ = delay;
    }

    void setRandomFactor(double randomness = 0.1) {
        if (randomness < 0.0) gRandomFactor_ = 0.0;
        else if (randomness > 1.0) gRandomFactor_ = 0.97;
        gRandomFactor_ = 0.97 * randomness;
    }

    double lastOut(uint channel = 0) { return lastFrame_[channel]; }

    double tick(uint channel = 0) {    
        uint i, j, nChannels = lastFrame_.channels();
        for (j=0; j < nChannels; j++) lastFrame_[j] = 0.0;
    
        if (data_.length == 0) return 0.0;
    
        double sample;
        for (i=0; i < grains_.length; i++) {
    
          if (grains_[i].counter == 0) { // Update the grain state.
    
            switch (grains_[i].state) {
    
            case GrainState.GRAIN_STOPPED:
              // We're done waiting between grains ... setup for new grain
              this.calculateGrain(grains_[i]);
              break;
    
            case GrainState.GRAIN_FADEIN:
              // We're done ramping up the envelope
              if (grains_[i].sustainCount > 0) {
                grains_[i].counter = grains_[i].sustainCount;
                grains_[i].state = GrainState.GRAIN_SUSTAIN;
                break;
              }
              // else no sustain state (i.e. perfect triangle window)
    
            case GrainState.GRAIN_SUSTAIN:
              // We're done with flat part of envelope ... setup to ramp down
              if (grains_[i].decayCount > 0) {
                grains_[i].counter = grains_[i].decayCount;
                grains_[i].eRate = -grains_[i].eRate;
                grains_[i].state = GrainState.GRAIN_FADEOUT;
                break;
              }
              // else no fade out state (gRampPercent = 0)
    
            case GrainState.GRAIN_FADEOUT:
              // We're done ramping down ... setup for wait between grains
              if (grains_[i].delayCount > 0) {
                grains_[i].counter = grains_[i].delayCount;
                grains_[i].state = GrainState.GRAIN_STOPPED;
                break;
              }
              
            default: break;  
              
              // else no delay (gDelay = 0)
    
              this.calculateGrain(grains_[i]);
          }
        }
    
          // Accumulate the grain outputs.
          if (grains_[i].state > 0) {
            for (j=0; j<nChannels; j++) {
              sample = data_[ cast(uint) (nChannels * grains_[i].pointer + j)]; // FIXME
    
              if (grains_[i].state == GrainState.GRAIN_FADEIN || grains_[i].state == GrainState.GRAIN_FADEOUT) {
                sample *= grains_[i].eScaler;
                grains_[i].eScaler += grains_[i].eRate;
              }
    
              lastFrame_[j] += sample;
            }
    
    
            // Increment and check pointer limits.
            grains_[i].pointer++;
            if (grains_[i].pointer >= data_.frames)
              grains_[i].pointer = 0;
          }
    
          // Decrement counter for all states.
          grains_[i].counter--;
        }
    
        // Increment our global file pointer at the stretch rate.
        if (stretchCounter_++ == gStretch_) {
          gPointer_++;
          if (cast(uint) gPointer_ >= data_.frames) gPointer_ = 0;
          stretchCounter_ = 0;
        }
    
        return lastFrame_[channel];
    }

 protected:


    void calculateGrain(Grain grain) {
        if (grain.repeats > 0) {
          grain.repeats--;
          grain.pointer = grain.startPointer;
          if (grain.attackCount > 0) {
            grain.eScaler = 0.0;
            grain.eRate = -grain.eRate;
            grain.counter = grain.attackCount;
            grain.state = GrainState.GRAIN_FADEIN;
          } else {
             grain.counter = grain.sustainCount;
             grain.state = GrainState.GRAIN_SUSTAIN;
          }
          return;
        }

        // Calculate duration and envelope parameters.
        double seconds = gDuration_ * 0.001;
        seconds += (seconds * gRandomFactor_ * noise.tick());
        uint count = cast(uint) (seconds * sampleRate_);
        grain.attackCount = cast(uint) (gRampPercent_ * 0.005 * count);
        grain.decayCount = grain.attackCount;
        grain.sustainCount = count - 2 * grain.attackCount;
        grain.eScaler = 0.0;
        if (grain.attackCount > 0) {
          grain.eRate = 1.0 / grain.attackCount;
          grain.counter = grain.attackCount;
          grain.state = GrainState.GRAIN_FADEIN;
        } else {
          grain.counter = grain.sustainCount;
          grain.state = GrainState.GRAIN_SUSTAIN;
        }
    
        // Calculate delay parameter.
        seconds = gDelay_ * 0.001;
        seconds += (seconds * gRandomFactor_ * noise.tick());
        count = cast(uint) (seconds * sampleRate_);
        grain.delayCount = count;
    
        // Save stretch parameter.
        grain.repeats = gStretch_;
    
        // Calculate offset parameter.
        seconds = gOffset_ * 0.001;
        seconds += (seconds * gRandomFactor_ * abs(noise.tick()));
        int offset = cast(int) (seconds * sampleRate_);
    
        // Add some randomization to the pointer start position.
        seconds = gDuration_ * 0.001 * gRandomFactor_ * noise.tick();
        offset += cast(int) (seconds * sampleRate_);
        grain.pointer += offset;
        while (grain.pointer >= data_.frames()) grain.pointer -= data_.frames();
        if (grain.pointer <  0) grain.pointer = 0;
        grain.startPointer = cast(uint) grain.pointer; // FIXME
    }

    enum GrainState {
        GRAIN_STOPPED, GRAIN_FADEIN, GRAIN_SUSTAIN, GRAIN_FADEOUT
    }

    class Grain {
        double eScaler;
        double eRate;
        uint attackCount;
        uint sustainCount;
        uint decayCount;
        uint delayCount;
        uint counter;
        //unsigned long pointer;
        double pointer;
        uint startPointer;
        uint repeats;
        GrainState state = GrainState.GRAIN_STOPPED;
    }

    Frames data_;
    Frames lastFrame_;
    Grain[] grains_;
    Noise noise;
    //long gPointer_;
    double gPointer_;

    // Global grain parameters.
    uint gDuration_;
    uint gRampPercent_;
    uint gDelay_;
    uint gStretch_;
    uint stretchCounter_;
    int gOffset_;
    double gRandomFactor_;
    double gain_;
    double sampleRate_;

};
