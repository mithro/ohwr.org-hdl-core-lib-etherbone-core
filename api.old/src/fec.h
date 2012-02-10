#ifndef FEC_H
#define FEC_H

#ifdef __cplusplus
extern "C" {
#endif

/* Initialize any buffers / state needed to encode/decode packets */
void fec_open(void);

/* Free any resources used by the encoder/decoder */
void fec_close(void);

/* Input: data received from ethernet payload [chunk, chunk+*len)
 * Output:
 *   If cannot (yet) decode, returns 0
 *   Otherwise, returns pointer to decoded message and modifies *len
 *
 * Note: inside be buffers
 */
const unsigned char* fec_decode(const unsigned char* chunk, unsigned int* len);

/* Input: ethernet payload to send [chunk, chunk+*len)
 *        index, starts at 0 and incremented each call until done
 * Output:
 *   If no more chunks follow, returns 0
 *   Returns encoded packet and modifies *len
 */
const unsigned char* fec_encode(const unsigned char* chunk, unsigned int* len, int index);

#ifdef __cplusplus
}
#endif

#endif
