/* A hardware-like C++ implementation of a Reed-Solomon erasure code.
 * Copyright (C) 2010-2011 GSI GmbH.
 * Author: Wesley W. Terpstra
 */

#include "gf256.h"
#include <vector>
#include <cstdlib>
#include <cstdio>

#include <assert.h>

const GF256 GF256::zero(0);
const GF256 GF256::one(1);
const GF256 GF256::g(2);

/* The hard-coded number of losses this code is designed to recover.
 * Presumably a parameter for a VHDL generic.
 */
#define K 2

/* This Reed-Solomon code uses systematic encoding, which means that the
 * codewords include as a prefix the original message.
 * 
 * Each codeword c(x) is defined to be a multiple of product_i (x-g^i)
 * for i=0..(K-1). The encoder and decoder are implemented with the same
 * circuit. Given n symbols of which K are unknown (and set to 0), the
 * missing K values are recovered.
 */

/* This circuit precomputes the lambda values needed by the (en|de)coder.
 * It should be run once after all the packets have been received.
 * 
 * The output polynomial the lowest order polynomial with roots on the
 * generator; ie: lambda(x) := (x - g^i0)*(x - g^i1)*...
 *
 * Input:
 *   The indices of the lost packets.
 * Output:
 *   The coefficients of lambda(x).
 *   The roots of lambda(x).
 */
void precompute(int i[K], GF256 gi[K], GF256 lambda[K+1])
{
  GF256 g2;    /* Register for the expression g^2^clock */
  int   is[K]; /* Bit-shift register for the indices */
  
  /* Initial values of the registers */
  g2 = GF256::g;
  lambda[0] = GF256::one;
  for (int j = 0; j < K; ++j) {
    gi[j] = GF256::one;
    is[j] = i[j];
    lambda[j+1] = GF256::zero;
  }
  
  /* Step 1 is to compute the values gi */
  for (int clock = 0; clock < 8; ++clock) {
    /* Look at the low bit of the shift registers */
    for (int j = 0; j < K; ++j) {
      gi[j] = gi[j] * ((is[j]&1)?g2:GF256::one);
      is[j] = is[j] >> 1;
    }
    g2 = g2*g2;
  }
  
  /* Step 2 is to compute the polynomial product */
  for (int clock = 0; clock < K; ++clock) {
    /* A K-wide "shift" register composed of bytes */
    for (int j = K; j > 0; --j)
      lambda[j] =  lambda[j]*gi[clock] + lambda[j-1];
    lambda[0] = lambda[0] * gi[clock];
  }
}

/* Input:
 *   The number of symbols in the codeword (n > K)
 *   The indices of the codeword which are missing.
 *   The result of precompute on those indices.
 * Output:
 *   Fills in the missing values of c.
 */
void code(int n, GF256 c[], int i[K], GF256 gi[K], GF256 lambda[K+1])
{
  /* Registers */
  GF256 lg[K+1];  /* lambda[i]*g^(i*clock) */
  GF256 a[K];     /* Accumulator for the missing symbols */
  GF256 dli[K];   /* (d/dx lambda)(g^i) */
  GF256 gic[K];   /* g^i*g^-c */
  
  /* Hard-wired constants */
  GF256 gj1[K+1]; /* g^(j-1) */
  
  /* Clear the unknown symbols to zero */
//  for (int j = 0; j < K; ++j)
//    c[i[j]] = GF256::zero;
  
  /* Initialize the registers and constants */
  for (int j = 0; j < K; ++j) {
    lg[j] = lambda[j];
    gic[j] = gi[j];
    a[j] = GF256::zero;
    dli[j] = GF256::zero;
    gj1[j] = GF256::g^(j-1);
  }
  lg[K] = lambda[K];
  gj1[K] = GF256::g^(K-1);
  
  /* In each step, we read c[clock] from memory */
  for (int clock = 0; clock < n; ++clock) {
     /* This circuit feeds l1c and dlc into the decoders */
     GF256 dlc = GF256::zero, l1c = GF256::zero;
     for (int j = 0; j < K+1; ++j) {
       l1c += lg[j];                   /* XOR all the lg[j] together */
       dlc += (j&1)?lg[j]:GF256::zero; /* XOR the odd lg[j] together */
       
       lg[j] = lg[j] * gj1[j]; /* Hard-wired multiplier */
     }
     
     /* Load from main memory: */
     GF256 cc = c[clock];
     GF256 product = cc * l1c;
    
     /* Replicate this circuit for each K */
     for (int j = 0; j < K; ++j) {
       GF256 divisor = GF256::one - gic[j];
       gic[j] *= GF256::g.inverse(); /* Hard-wired multiplier */

       a[j] = a[j] + (product / divisor);
       /* Record dlc if it's our index */
       //if (clock == i[j]) 
       if (divisor == GF256::zero) dli[j] = dlc;
     }
  }
  
  /* Implement multiplicative inverse using a lookup table */
  for (int j = 0; j < K; ++j)
    c[i[j]] = a[j] * dli[j].inverse();
}

#define MAX_FRAG_SIZE 1500
static unsigned char result[K][MAX_FRAG_SIZE];

/* Command-line driven test-cases */
void RS_code(unsigned int fragLen, std::vector<const unsigned char*>& fragments) {
    int missing[K];
    int missing_index;

    assert (fragLen < MAX_FRAG_SIZE);
    assert (fragments.size() > K);

    missing_index = 0;
    for (unsigned int i = 0; i < fragments.size(); ++i) {
        if (fragments[i] == 0) {
            assert (missing_index < K);
            missing[missing_index++] = i;
        }
    }

    GF256 c[fragments.size()]; //code word

    GF256 gi[K]; 
    GF256 lambda[K+1];
    
    precompute(missing, gi, lambda);

    for (unsigned int i = 0; i < fragLen; ++i) { // stripe by stripe
        for (unsigned int j = 0; j < fragments.size(); ++j) { // code by code word 
            if (fragments[j])
                c[j] = GF256::embed(fragments[j][i]);
            else
                c[j] = GF256::zero;
        }

        code(fragments.size(), c, missing, gi, lambda); // fills in 0 values

        for (unsigned j = 0; j < K; ++j) 
            result[j][i] = c[missing[j]].project();
     }

     for (unsigned int j = 0; j < K; ++j)
         fragments[missing[j]] = result[j];
}
