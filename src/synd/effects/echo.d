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

module synd.effects.echo;

import synd.common;
import synd.delay;

/**
 * echo effect class.
 *
 * This class implements an echo effect.
 */
class Echo : Effect {
    
    this(uint maxDelay) { 
        maximumDelay =  maxDelay;
        delayLine_ = new Delay();
        delayLine_.delay = length_ >> 1;
        effectMix_ = 0.5;
        clear();
    }

    void clear() {
        delayLine_.clear();
        last_ = 0.0;
    }

    @property void maximumDelay(uint delay){    
        delayLine_.maximumDelay = delay;
    }

    @property void delay(uint delay){    
        delayLine_.delay = delay;
    }

    double tick(double input, uint channel = 0) {
        last_ = effectMix_ * (delayLine_.tick(input) - input) + input;
        return last_;
    }

  protected:
    Delay delayLine_;
    uint length_;
    double last_;

}

