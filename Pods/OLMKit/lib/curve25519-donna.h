/* header file for the curve25519-donna implementation, because the
 * authors of that project don't supply one.
 */
#ifndef CURVE25519_DONNA_H
#define CURVE25519_DONNA_H

#ifdef __cplusplus
extern "C" {
#endif

extern int curve25519_donna(unsigned char *output, const unsigned char *a,
                            const unsigned char *b);

#ifdef __cplusplus
}
#endif

#endif
