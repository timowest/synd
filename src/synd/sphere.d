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

module synd.sphere;

import std.math;

/**
 * sphere class.
 *
 * This class implements a spherical ball with radius, mass, position, 
 * and velocity parameters.
 */
class Sphere  {
    
    this(double radius = 1.0) { 
        radius_ = radius; 
        mass_ = 1.0; 
    }  

    void setPosition(double x, double y, double z) { position_.setXYZ(x, y, z); }

    void setVelocity(double x, double y, double z) { velocity_.setXYZ(x, y, z); }

    @property void radius(double radius) { radius_ = radius; }

    @property void mass(double mass) { mass_ = mass; }

    @property Vector3D position() { return position_; }
    
    @property double radius() { return radius_; }

    @property double mass() { return mass_; }

    Vector3D getRelativePosition(Vector3D position) {
      workingVector_.setXYZ(position.x - position_.x,
                            position.y - position_.x,  
                            position.z - position_.z);
      return workingVector_;
    }

    double getVelocity(Vector3D velocity) {
      velocity.setXYZ(velocity_.x, velocity_.y, velocity_.z);
      return velocity_.length;
    }

    double isInside(Vector3D position) {
      // Return directed distance from aPosition to spherical boundary (<
      // 0 if inside).
      Vector3D tempVector = getRelativePosition(position);
      double distance = tempVector.length;
      return distance - radius_;
    }



    void addVelocity(double x, double y, double z) {
      velocity_.x = velocity_.x + x;
      velocity_.y = velocity_.y + y;
      velocity_.z = velocity_.z + z;
    }

    void tick(double timeIncrement) {
      position_.x = position_.x + (timeIncrement * velocity_.x);
      position_.y = position_.y + (timeIncrement * velocity_.y);
      position_.z = position_.z + (timeIncrement * velocity_.z);
    }
   
  private:
    Vector3D position_;
    Vector3D velocity_;
    Vector3D workingVector_;
    double radius_;
    double mass_;
}

/**
 * 3D vector class.
 *
 * This class implements a three-dimensional vector.
 */
class Vector3D {

    this(double _x = 0.0, double _y = 0.0, double _z = 0.0) { 
        setXYZ(_x, _y, _z);
    }
    
    void setXYZ(double _x, double _y, double _z) {
        x = _x; y = _y; z = _z;
    }

    @property double length() {
        return sqrt(x*x + y*y + z*z);
    }
    
    double x, y, z;      
}
