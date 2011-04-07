#include "fec.h"
#include <vector>
#include <string>
#include <map>
#include <queue>
#include <iostream>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

#define K 2
#define MAX_MESSAGES    1024

extern void RS_code(unsigned int fragLen, std::vector<const unsigned char*>& fragments);

/*
 * =====================================================================================
 *
 *       Filename:  fec.cpp
 *
 *    Description:  
 *
 *        Version:  1.0
 *        Created:  04/07/2011 12:58:52 PM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  Cesar Prados Boda (cp), c.prados@gsi.de
 *        Company:  GSI
 *
 * =====================================================================================
 */

static uint32_t outgoing_msgID = 0;

void fec_open()
{
    srand(time(0));
    outgoing_msgID = rand();
}

void fec_close()
{
}

static unsigned int fec_chopchop(unsigned int msize) {
    // !!! Do something intelligent!
    return 2;
}

struct State 
{
    unsigned int msize;
    unsigned int divsize;
    unsigned int fragments_received;
    std::vector<std::string> received;
};

typedef std::map<uint32_t, State> Map;
typedef std::queue<uint32_t> Queue;

static Map cache;
static Queue inCache;

static std::string result;
const unsigned char* fec_decode(unsigned char* chunk, unsigned int* len) 
{
    unsigned int length = *len;
    unsigned int chunks = length / 9;
    if (length % 9 != 0 || length < 18) return 0;

    for (unsigned int i = 0; i < chunks; ++i) {
        uint8_t parity = chunk[chunks*8+i];
        // !!! Fix input range chunk[i*8...i*8+7]
    }

    // !!! Check CRC and discard if bad

    uint64_t header = 0;
    for (int i = 0; i < 8; ++i) 
    {
        header <<= 8;
        header |= chunk[i];
    }

    uint32_t mID         = (header >> 32) & 0xFFFFFFFF;
    unsigned int msize   = (header >> 20) & 0xFFF;
    unsigned int fragLen = (header >>  8) & 0xFFF;
    unsigned int index   = (header >>  0) & 0xFF;

    unsigned int messages = fec_chopchop(msize);
    unsigned int divsize = (msize+messages-1) / messages;
    unsigned int rsinsize = (divsize+7) & ~7;

    if (fragLen != length) return 0;
    if (fragLen != (rsinsize+8)/8*9) return 0;
    if (index > messages+K) return 0;

    Map::iterator state = cache.find(mID);
    if (state == cache.end())
    {
        if (inCache.size() > MAX_MESSAGES)
        {
            uint32_t kill = inCache.front();
            inCache.pop();
            cache.erase(cache.find(kill));
        }
        inCache.push(mID);

        State& newState = cache[mID]; // add it
        state = cache.find(mID);

        newState.msize = msize;
        newState.fragments_received = 0;
        newState.divsize = (msize + messages-1) / messages;
        newState.received.resize(messages + K);
    }

    if (state->second.msize != msize) return 0; // Doesn't fit with other packets
    if (!state->second.received[index].empty()) return 0; // Duplicated packet

    // Grab the data portion of the buffer
    state->second.received[index] = std::string(reinterpret_cast<const char*>(chunk)+8, (chunks-1)*8);

    // If we don't have enough packets yet (or already decode), stop now
    if (++state->second.fragments_received != messages) return 0;

    // DECODING TIME!
    std::vector<const unsigned char*> fragments;
    fragments.resize(state->second.received.size());
    for (unsigned int i = 0; i < fragments.size(); ++i)
        if (state->second.received[i].empty())
            fragments[i] = 0;
        else
            fragments[i] = reinterpret_cast<const unsigned char*>(state->second.received[i].data());

    // Do the work
    RS_code(divsize, fragments);

    // Reassemble the packet
    result.clear();
    result.reserve(divsize*messages);
    for (unsigned int i = 0; i < messages; ++i)
        for (unsigned int j = 0; j < divsize; ++j)
            result.push_back(fragments[i][j]);

    result.resize(msize); // clip the padding and done

    *len = result.size();
    return reinterpret_cast<const unsigned char*>(result.data());
}

static std::vector<std::string> messages;

static void fec_setup(unsigned char* chunk, unsigned int len)
{
    unsigned int msize = len;
    messages.clear();
    messages.resize(fec_chopchop(msize));

    unsigned int divsize = (msize+messages.size()-1) / messages.size();
    unsigned int rsinsize = (divsize+7) & ~7;

    // Make a message-id
    uint32_t msgID = ++outgoing_msgID;

    std::string buf((char*)chunk, msize);
    buf.resize(divsize); // Pad with 0 to a multiple of messages

    std::vector<const unsigned char*> fragments;
    fragments.reserve(messages.size()+K);

    for (unsigned int i = 0; i < messages.size(); ++i)
        fragments.push_back(reinterpret_cast<const unsigned char*>(buf.data() + i*divsize));
    for (unsigned int i = 0; i < K; ++i)
        fragments.push_back(0);

    // Do the actual RS-encoding
    RS_code(divsize, fragments);

    messages.resize(messages.size() + K);
    for (unsigned int i = 0; i < messages.size(); ++i)
    {
        std::string msg(8, 'x');

        unsigned int fragLen = (rsinsize + 8)/8*9;
        uint64_t header = 
            ((uint64_t)msgID   << 32) |
            ((uint64_t)msize   << 20) |
            ((uint64_t)fragLen <<  8) |
            ((uint64_t)i       <<  0);

        for (int j = 7; j > 0; --j) {
            uint8_t low = header & 0xFF;
            header >>= 8;
            msg[j] = static_cast<char>(low);
         }

        msg += std::string(reinterpret_cast<const char*>(fragments[i]), divsize);
        msg.resize(rsinsize + 8); // Pad with 0 to a multiple of 8

        unsigned int chunks = msg.size() / 8; // SEC-DED(72,64) is 8 bytes at once
        for (unsigned int j = 0; j < chunks; ++j)
        {
            // encode msg[j*chunks] to msg[j*chunks + chunks-1]
            msg.push_back(0); // !!! result of hamming code
        }

        messages[i] = msg;
    }
}

const unsigned char* fec_encode(unsigned char* chunk, unsigned int* len, int index)  
{
    if (index == 0) fec_setup(chunk, *len);
    if (index == (int)messages.size()) return 0;

    *len = messages[index].size();
    return reinterpret_cast<const unsigned char*>(messages[index].data());
}

