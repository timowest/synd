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

module synd.noise;

import std.c.stdlib;
import std.c.time;
import std.math;
import synd.common;

/**
 * noise generator.
 *
 * Generic random number generation using the C rand() function. The 
 * quality of the rand() function varies from one OS to another.
 */
class Noise : Generator {

    this(uint s = 0) {
        seed = s;
    }

    @property void seed(uint s = 0) {
        if (s == 0) srand(cast(uint) time(null));
        else srand(s);
    }
    
    @property lastOut() { return last_; }

    void reset() {}

    double tick() {
        return last_ = cast(double) (2.0 * rand() / (RAND_MAX + 1.0) - 1.0);
    }

  protected:
    double last_;

}
