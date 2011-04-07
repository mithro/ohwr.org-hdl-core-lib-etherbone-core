/* Copyright 2010-2011 GSI GmbH.
 * All rights reserved.
 *
 * A quick-and-dirty implementation of GF(2^8).
 * Optimized for ease of translation into hardware, not speed.
 *
 * Author: Wesley W. Terpstra
 */

#ifndef __GF256_H__
#define __GF256_H__

#include <iostream>
#include <iomanip>

class GF256
{
  protected:
    typedef unsigned char rep;
    rep value;
    
    GF256(rep x) : value(x) { }
  
  public:
    GF256() : value(0) { }
    GF256(const GF256& y) : value(y.value) { }
    
    /* Important constants */
    static const GF256 zero;
    static const GF256 one;
    static const GF256 g;
    
    /* Explicit conversion operators */
    static GF256 embed(rep v) { return GF256(v); }
    rep project() const { return value; }
    
    bool operator == (GF256 y)
    {
      return value == y.value;
    }
    
    bool operator != (GF256 y)
    {
      return value != y.value;
    }
    
    GF256& operator = (GF256 y)
    {
      value = y.value;
      return *this;
    }
    
    GF256& operator += (GF256 y)
    {
      value ^= y.value;
      return *this;
    }
    
    GF256& operator -= (GF256 y)
    {
      value ^= y.value;
      return *this;
    }
    
    GF256 operator + (GF256 y) const
    {
      GF256 out(*this);
      out += y;
      return out;
    }
    
    GF256 operator - (GF256 y) const
    {
      GF256 out(*this);
      out -= y;
      return out;
    }
    
    GF256 operator - () const
    {
      return GF256(*this);
    }
    
    GF256 operator * (GF256 y) const
    {
      rep a = value;
      rep b = y.value;
      
      rep a0 = (a>>0)&1;
      rep a1 = (a>>1)&1;
      rep a2 = (a>>2)&1;
      rep a3 = (a>>3)&1;
      rep a4 = (a>>4)&1;
      rep a5 = (a>>5)&1;
      rep a6 = (a>>6)&1;
      rep a7 = (a>>7)&1;
      
      rep b0 = (b>>0)&1;
      rep b1 = (b>>1)&1;
      rep b2 = (b>>2)&1;
      rep b3 = (b>>3)&1;
      rep b4 = (b>>4)&1;
      rep b5 = (b>>5)&1;
      rep b6 = (b>>6)&1;
      rep b7 = (b>>7)&1;
      

#if 1
      /* This is output from gates-gf targetting the modulus 2d */
      rep c0 = (a0&b0) ^ (a1&b7) ^ (a2&b6) ^ (a3&b5) ^ (a4&b4) ^ (a4&b7) ^ (a5&b3) ^ (a5&b6) ^ (a6&b2) ^ (a6&b5) ^ (a6&b7) ^ (a7&b1) ^ (a7&b4) ^ (a7&b6);
      rep c1 = (a0&b1) ^ (a1&b0) ^ (a2&b7) ^ (a3&b6) ^ (a4&b5) ^ (a5&b4) ^ (a5&b7) ^ (a6&b3) ^ (a6&b6) ^ (a7&b2) ^ (a7&b5) ^ (a7&b7);
      rep c2 = (a0&b2) ^ (a1&b1) ^ (a1&b7) ^ (a2&b0) ^ (a2&b6) ^ (a3&b5) ^ (a3&b7) ^ (a4&b4) ^ (a4&b6) ^ (a4&b7) ^ (a5&b3) ^ (a5&b5) ^ (a5&b6) ^ (a6&b2) ^ (a6&b4) ^ (a6&b5) ^ (a7&b1) ^ (a7&b3) ^ (a7&b4);
      rep c3 = (a0&b3) ^ (a1&b2) ^ (a1&b7) ^ (a2&b1) ^ (a2&b6) ^ (a2&b7) ^ (a3&b0) ^ (a3&b5) ^ (a3&b6) ^ (a4&b4) ^ (a4&b5) ^ (a5&b3) ^ (a5&b4) ^ (a5&b7) ^ (a6&b2) ^ (a6&b3) ^ (a6&b6) ^ (a6&b7) ^ (a7&b1) ^ (a7&b2) ^ (a7&b5) ^ (a7&b6);
      rep c4 = (a0&b4) ^ (a1&b3) ^ (a2&b2) ^ (a2&b7) ^ (a3&b1) ^ (a3&b6) ^ (a3&b7) ^ (a4&b0) ^ (a4&b5) ^ (a4&b6) ^ (a5&b4) ^ (a5&b5) ^ (a6&b3) ^ (a6&b4) ^ (a6&b7) ^ (a7&b2) ^ (a7&b3) ^ (a7&b6) ^ (a7&b7);
      rep c5 = (a0&b5) ^ (a1&b4) ^ (a1&b7) ^ (a2&b3) ^ (a2&b6) ^ (a3&b2) ^ (a3&b5) ^ (a3&b7) ^ (a4&b1) ^ (a4&b4) ^ (a4&b6) ^ (a5&b0) ^ (a5&b3) ^ (a5&b5) ^ (a6&b2) ^ (a6&b4) ^ (a6&b7) ^ (a7&b1) ^ (a7&b3) ^ (a7&b6) ^ (a7&b7);
      rep c6 = (a0&b6) ^ (a1&b5) ^ (a2&b4) ^ (a2&b7) ^ (a3&b3) ^ (a3&b6) ^ (a4&b2) ^ (a4&b5) ^ (a4&b7) ^ (a5&b1) ^ (a5&b4) ^ (a5&b6) ^ (a6&b0) ^ (a6&b3) ^ (a6&b5) ^ (a7&b2) ^ (a7&b4) ^ (a7&b7);
      rep c7 = (a0&b7) ^ (a1&b6) ^ (a2&b5) ^ (a3&b4) ^ (a3&b7) ^ (a4&b3) ^ (a4&b6) ^ (a5&b2) ^ (a5&b5) ^ (a5&b7) ^ (a6&b1) ^ (a6&b4) ^ (a6&b6) ^ (a7&b0) ^ (a7&b3) ^ (a7&b5);
#else
      rep modulus = 0x1b;
      
      /* ci = b*x^i */
      /* bi*modulus is just bi?modulus:0 */
      rep c0 = b;
      rep c1 = (c0 << 1) ^ (c0 >> 7)*modulus;
      rep c2 = (c1 << 1) ^ (c1 >> 7)*modulus;
      rep c3 = (c2 << 1) ^ (c2 >> 7)*modulus;
      rep c4 = (c3 << 1) ^ (c3 >> 7)*modulus;
      rep c5 = (c4 << 1) ^ (c4 >> 7)*modulus;
      rep c6 = (c5 << 1) ^ (c5 >> 7)*modulus;
      rep c7 = (c6 << 1) ^ (c6 >> 7)*modulus;
      
      /* x*y here is just y?x:0 */
      rep o0 = c0 * ((a>>0)&1);
      rep o1 = c1 * ((a>>1)&1);
      rep o2 = c2 * ((a>>2)&1);
      rep o3 = c3 * ((a>>3)&1);
      rep o4 = c4 * ((a>>4)&1);
      rep o5 = c5 * ((a>>5)&1);
      rep o6 = c6 * ((a>>6)&1);
      rep o7 = c7 * ((a>>7)&1);
      
      return ((o0^o1)^(o2^o3))^((o4^o5)^(o6^o7));
#endif
      return (c7<<7)|(c6<<6)|(c5<<5)|(c4<<4)|(c3<<3)|(c2<<2)|(c1<<1)|(c0<<0);
    }

    GF256& operator *= (GF256 y)
    {
      return *this = *this * y;
    }
    
    GF256 operator ^ (int x) const
    {
      GF256 out(1);
      GF256 pow(*this);
      
      x %= 255;
      if (x < 0) x += 255;
      
      for (; x > 0; x >>= 1)
      {
        if ((x & 1) != 0)
          out *= pow;
        pow *= pow;
      }
      return out;
    }
  
    GF256 inverse () const
    {
      return *this ^ 254;
    }
    
    GF256 operator / (GF256 y) const
    {
      return *this * y.inverse();
    }
    
    GF256& operator /= (GF256 y)
    {
      return *this = *this / y;
    }
  
  friend std::ostream& operator << (std::ostream& o, GF256 y)
  {
    return o << std::hex << std::setw(2) << (int)y.value;
  }
};

#endif
