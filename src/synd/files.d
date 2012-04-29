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

module synd.files;

import std.math;
import synd.common;
import synd.wave;

enum Format {
    SINT8, SINT16, SINT24, SINT32, FLOAT32, FLOAT64
}

/**
 * audio file input class.
 *
 * This class provides input support for various audio file formats.  
 * Multi-channel (>2) soundfiles are supported.  The file data is
 * returned via an external Frames object passed to the read() function.  
 * This class does not store its own copy of the file data, rather the data 
 * is read directly from disk.
 */
class FileRead {

    // TODO : implement using libsndfile

    this() { 
        fd_ = 0; 
        dataType_ = Format.SINT16; 
    }
    
    this(string fileName, bool typeRaw = false, uint nChannels = 1,
         Format format = Format.SINT16, double rate = 22050.0) { 
        fd_ = 0;
        open(fileName, typeRaw, nChannels, format, rate);
    }
    
    ~this() {
        //if (fd_) fclose(fd_); FIXME
    }
 
    void open(string fileName, bool typeRaw = false, uint nChannels = 1,
              Format format = Format.SINT16, double rate = 22050.0) {
        // TODO
    }

    void close() {
        //if (fd_) fclose(fd_); FIXME
        fd_ = 0;
        wavFile_ = false;
        fileSize_ = 0;
        channels_ = 0;
        dataType_ = Format.SINT16;
        fileRate_ = 0.0;
    }
    
    bool isOpen() {
        if (fd_) return true;
        else return false;
    }

    @property uint fileSize() { return fileSize_; }

    @property uint channels() { return channels_; }

    @property Format format() { return dataType_; }

    @property double fileRate() { return fileRate_; }
    
    void  read(ref Frames buffer, uint startFrame = 0, bool doNormalize = true) {
        // TODO
    }

protected:


    //FILE *fd_;
    uint fd_; // FIXME
    bool byteswap_;
    bool wavFile_;
    uint fileSize_;
    uint dataOffset_;
    uint channels_;
    Format dataType_;
    double fileRate_;
};

/**
 * audio file input class.
 *
 * This class inherits from WvIn.  It provides a "tick-level"
 * interface to the FileRead class.  It also provides variable-rate
 * "playback" functionality.  Audio file support is provided by the
 * FileRead class.  Linear interpolation is used for fractional "read
 * rates".
 *
 * FileWvIn supports multi-channel data.  It is important to distinguish
 * the tick() methods, which return samples produced by averaging
 * across sample frames, from the tickFrame() methods, which return
 * references to multi-channel sample frames.
 *
 * FileWvIn will either load the entire content of an audio file into
 * local memory or incrementally read file data from disk in chunks.
 * This behavior is controlled by the optional constructor arguments
 * \e chunkThreshold and \e chunkSize.  File sizes greater than \e
 * chunkThreshold (in sample frames) will be read incrementally in
 * chunks of \e chunkSize each (also in sample frames).
 *
 * When the file end is reached, subsequent calls to the tick()
 * functions return zero-valued data and isFinished() returns \e
 * true.
 */
class FileWvIn : WvIn {

    this(double sr, uint chunkThreshold = 1000000, uint chunkSize = 1024) { 
        sampleRate_ = sr;
        finished_ = (true); 
        interpolate_ = (false); 
        time_ = (0.0); 
        rate_ = (0.0);
        chunkThreshold_ = (chunkThreshold); 
        chunkSize_ = (chunkSize);
    }

    
    this(double sr, string fileName, bool raw = false, bool doNormalize = true,
          uint chunkThreshold = 1000000, uint chunkSize = 1024) { 
        sampleRate_ = sr;
        finished_ = (true); 
        interpolate_ = (false); 
        time_ = (0.0); 
        rate_ = (0.0);
        chunkThreshold_ = (chunkThreshold); 
        chunkSize_ = (chunkSize);
        openFile(fileName, raw, doNormalize);
    }
    
    ~this() {
        this.closeFile();
    }
    
    void openFile( string fileName, bool raw = false, bool doNormalize = true) {
        // Call close() in case another file is already open.
        this.closeFile();
    
        // Attempt to open the file ... an error might be thrown here.
        file_.open(fileName, raw);
    
        // Determine whether chunking or not.
        if (file_.fileSize() > chunkThreshold_) {
          chunking_ = true;
          chunkPointer_ = 0;
          data_.resize(chunkSize_, file_.channels());
          if (doNormalize) normalizing_ = true;
          else normalizing_ = false;
        } else {
          chunking_ = false;
          data_.resize(cast(size_t) file_.fileSize(), file_.channels());
        }
    
        // Load all or part of the data.
        file_.read(data_, 0, doNormalize);
    
        // Resize our lastFrame container.
        lastFrame_.resize(1, file_.channels());
    
        // Set default rate based on file sampling rate.
        this.rate = data_.dataRate() / sampleRate_;
    
        if (doNormalize & !chunking_) this.normalize();
    
        this.reset();
    }
    
    void closeFile() {
        if (file_.isOpen()) file_.close();
        finished_ = true;
        lastFrame_.resize(0, 0);
    }

    
    void reset() {
        time_ = cast(double) 0.0;
        for (uint i=0; i<lastFrame_.length; i++) lastFrame_[i] = 0.0;
        finished_ = false;
    }
    
    void normalize() {
        this.normalize(1.0);
    }
    
    // Normalize all channels equally by the greatest magnitude in all of the data.
    void normalize(double peak) {
        // When chunking, the "normalization" scaling is performed by FileRead.
        if (chunking_) return;
    
        size_t i;
        double max = 0.0;
    
        for (i=0; i<data_.length; i++) {
          if (fabs(data_[i]) > max)
            max = cast(double) fabs(cast(double) data_[i]);
        }
    
        if (max > 0.0) {
          max = 1.0 / max;
          max *= peak;
          for (i=0; i<data_.length; i++)
            data_[i] *= max;
        }
    }

    @property uint length() { return data_.frames(); }

    @property double fileRate() { return data_.dataRate(); }

    bool isOpen() { return file_.isOpen(); }

    @property bool finished() { return finished_; }

    @property void rate(double rate) {
        rate_ = rate;
    
        // If negative rate and at beginning of sound, move pointer to end
        // of sound.
        if ((rate_ < 0) && (time_ == 0.0)) time_ = file_.fileSize() - 1.0;
    
        if (fmod(rate_, 1.0) != 0.0) interpolate_ = true;
        else interpolate_ = false;
    }
    
    void addTime(double time)    {
        // Add an absolute time in samples 
        time_ += time;
    
        if (time_ < 0.0) time_ = 0.0;
        if (time_ > file_.fileSize() - 1.0) {
          time_ = file_.fileSize() - 1.0;
          for (uint i=0; i<lastFrame_.length; i++) lastFrame_[i] = 0.0;
          finished_ = true;
        }
    }

    void setInterpolate(bool doInterpolate) { interpolate_ = doInterpolate; }
    
    double lastOut(uint channel = 0) {    
        if (finished_) return 0.0;
        return lastFrame_[channel];
    }
    
    double tick(uint channel = 0) {    
        if (finished_) return 0.0;
    
        if (time_ < 0.0 || time_ > cast(double) (file_.fileSize() - 1.0)) {
          for (uint i=0; i<lastFrame_.length; i++) lastFrame_[i] = 0.0;
          finished_ = true;
          return 0.0;
        }
    
        double tyme = time_;
        if (chunking_) {
    
          // Check the time address vs. our current buffer limits.
          if ((time_ < cast(double) chunkPointer_) ||
               (time_ > cast(double) (chunkPointer_ + chunkSize_ - 1))) {
    
            while (time_ < cast(double) chunkPointer_) { // negative rate
              chunkPointer_ -= chunkSize_ - 1; // overlap chunks by one frame
              if (chunkPointer_ < 0) chunkPointer_ = 0;
            }
            while (time_ > cast(double) (chunkPointer_ + chunkSize_ - 1)) { // positive rate
              chunkPointer_ += chunkSize_ - 1; // overlap chunks by one frame
              if (chunkPointer_ + chunkSize_ > file_.fileSize()) // at end of file
                chunkPointer_ = file_.fileSize() - chunkSize_;
            }
    
            // Load more data.
            file_.read(data_, chunkPointer_, normalizing_);
          }
    
          // Adjust index for the current buffer.
          tyme -= chunkPointer_;
        }
    
        if (interpolate_) {
          for (uint i=0; i<lastFrame_.length; i++)
            lastFrame_[i] = data_.interpolate(tyme, i);
        } else {
          for (uint i=0; i<lastFrame_.length; i++)
            lastFrame_[i] = data_[ cast(size_t) tyme, i ];
        }
    
        // Increment time, which can be negative.
        time_ += rate_;
    
        return lastFrame_[channel];
    }
    
    ref Frames tick(ref Frames frames) {
        if (!file_.isOpen()) {
          return frames;
        }    
        uint nChannels = lastFrame_.channels();    
        uint j, counter = 0;
        for (uint i=0; i<frames.frames(); i++) {
          this.tick();
          for (j=0; j<nChannels; j++)
            frames[counter++] = lastFrame_[j];
        }    
        return frames;
    }

protected:
    
    void sampleRateChanged(double newRate, double oldRate) {
        this.rate = oldRate * rate_ / newRate;
    }

    FileRead file_;
    bool finished_;
    bool interpolate_;
    bool normalizing_;
    bool chunking_;
    double time_;
    double rate_;
    uint chunkThreshold_;
    uint chunkSize_;
    int chunkPointer_;
    double sampleRate_;

};

/** 
 * file looping / oscillator class.
 *
 * This class provides audio file looping functionality.  Any audio
 * file that can be loaded by FileRead can be looped using this
 * class.
 *
 * FileLoop supports multi-channel data.  It is important to
 * distinguish the tick() method that computes a single frame (and
 * returns only the specified sample of a multi-channel frame) from
 * the overloaded one that takes an Frames object for
 * multi-channel and/or multi-frame data.
 */
class FileLoop : FileWvIn {
    
    this(double sr, uint chunkThreshold = 1000000, uint chunkSize = 1024) { 
        super(sr,chunkThreshold, chunkSize); phaseOffset_ = (0.0);
    }
    
    this(double sr, string fileName, bool raw = false, bool doNormalize = true,
                          uint chunkThreshold = 1000000, uint chunkSize = 1024) { 
        super(sr, chunkThreshold, chunkSize); phaseOffset_ = (0.0);
        this.openFile(fileName, raw, doNormalize);
    }
    
    void openFile(string fileName, bool raw = false, bool doNormalize = true) {
        // Call close() in case another file is already open.
        this.closeFile();
    
        // Attempt to open the file ... an error might be thrown here.
        file_.open(fileName, raw);
    
        // Determine whether chunking or not.
        if (file_.fileSize() > chunkThreshold_) {
          chunking_ = true;
          chunkPointer_ = 0;
          data_.resize(chunkSize_ + 1, file_.channels());
          if (doNormalize) normalizing_ = true;
          else normalizing_ = false;
        } else {
          chunking_ = false;
          data_.resize(file_.fileSize() + 1, file_.channels());
        }
    
        // Load all or part of the data.
        file_.read(data_, 0, doNormalize);
    
        if (chunking_) { // If chunking, save the first sample frame for later.
          firstFrame_.resize(1, data_.channels());
          for (uint i=0; i<data_.channels(); i++)
            firstFrame_[i] = data_[i];
        } else {  // If not chunking, copy the first sample frame to the last.
          for (uint i=0; i<data_.channels(); i++)
            data_[ data_.frames() - 1, i ] = data_[i];
        }
    
        // Resize our lastOutputs container.
        lastFrame_.resize(1, file_.channels());
    
        // Set default rate based on file sampling rate.
        this.rate = data_.dataRate() / sampleRate_;
    
        if (doNormalize & !chunking_) this.normalize();
    
        this.reset();
    }

    void closeFile() { FileWvIn.closeFile(); }

    void reset() { FileWvIn.reset(); }

    @property uint channelsOut() { return data_.channels(); }

    void normalize() { FileWvIn.normalize(1.0); }

    void normalize(double peak) { FileWvIn.normalize(peak); }

    @property uint length() { return data_.frames(); }

    @property double fileRate() { return data_.dataRate(); }
  
    @property void rate(double rate) {
        rate_ = rate;    
        if (fmod(rate_, 1.0) != 0.0) interpolate_ = true;
        else interpolate_ = false;
    }

    @property void frequency(double frequency) { 
        this.rate = file_.fileSize() * frequency / sampleRate_; 
    }
    
    void addTime(double time) {
        // Add an absolute time in samples.
        time_ += time;
    
        double fileSize = file_.fileSize();
        while (time_ < 0.0)
          time_ += fileSize;
        while (time_ >= fileSize)
          time_ -= fileSize;
    }
    
    void addPhase(double angle) {
        // Add a time in cycles (one cycle = fileSize).
        double fileSize = file_.fileSize();
        time_ += fileSize * angle;
    
        while (time_ < 0.0)
          time_ += fileSize;
        while (time_ >= fileSize)
          time_ -= fileSize;
    }
    
    void addPhaseOffset(double angle) {
        // Add a phase offset in cycles, where 1.0 = fileSize.
        phaseOffset_ = file_.fileSize() * angle;
    }

    double lastOut(uint channel = 0) { return FileWvIn.lastOut(channel); }
    
    double tick(uint channel = 0) {    
        // Check limits of time address ... if necessary, recalculate modulo
        // fileSize.
        double fileSize = file_.fileSize();
    
        while (time_ < 0.0)
          time_ += fileSize;
        while (time_ >= fileSize)
          time_ -= fileSize;
    
        double tyme = time_;
        if (phaseOffset_) {
          tyme += phaseOffset_;
          while (tyme < 0.0)
            tyme += fileSize;
          while (tyme >= fileSize)
            tyme -= fileSize;
        }
    
        if (chunking_) {
    
          // Check the time address vs. our current buffer limits.
          if ((time_ < cast(double) chunkPointer_) ||
               (time_ > cast(double) (chunkPointer_ + chunkSize_ - 1))) {
    
            while (time_ < cast(double) chunkPointer_) { // negative rate
              chunkPointer_ -= chunkSize_ - 1; // overlap chunks by one frame
              if (chunkPointer_ < 0) chunkPointer_ = 0;
            }
            while (time_ > cast(double) (chunkPointer_ + chunkSize_ - 1)) { // positive rate
              chunkPointer_ += chunkSize_ - 1; // overlap chunks by one frame
              if (chunkPointer_ + chunkSize_ > file_.fileSize()) { // at end of file
                chunkPointer_ = file_.fileSize() - chunkSize_ + 1; // leave extra frame at end of buffer
                // Now fill extra frame with first frame data.
                for (uint j=0; j<firstFrame_.channels(); j++)
                  data_[ data_.frames() - 1, j ] = firstFrame_[j];
              }
            }
    
            // Load more data.
            file_.read(data_, chunkPointer_, normalizing_);
          }
    
          // Adjust index for the current buffer.
          tyme -= chunkPointer_;
        }
    
        if (interpolate_) {
          for (uint i=0; i<lastFrame_.length; i++)
            lastFrame_[i] = data_.interpolate(tyme, i);
        } else {
          for (uint i=0; i<lastFrame_.length; i++)
            lastFrame_[i] = data_[ cast(size_t) tyme, i ];
        }
    
        // Increment time, which can be negative.
        time_ += rate_;
    
        return lastFrame_[channel];
    }
    
    ref Frames   tick(ref Frames  frames) {
        if (!file_.isOpen()) {
          return frames;
        }
    
        uint nChannels = lastFrame_.channels();
    
        uint j, counter = 0;
        for (uint i=0; i<frames.frames(); i++) {
          this.tick();
          for (j=0; j<nChannels; j++)
            frames[counter++] = lastFrame_[j];
        }
    
        return frames;
    }

 protected:

    Frames firstFrame_;
    double phaseOffset_;

};
