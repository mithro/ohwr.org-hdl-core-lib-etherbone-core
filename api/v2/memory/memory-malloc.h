/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * This implements Etherbone memory using an system malloc/free.
 */

#ifndef EB_MEMORY_MALLOC_H
#define EB_MEMORY_MALLOC_H
#ifdef EB_USE_MALLOC

#define EB_CYCLE_OPERATION(x) (x)
#define EB_CYCLE(x) (x)
#define EB_DEVICE(x) (x)
#define EB_SOCKET(x) (x)
#define EB_HANDLER_CALLBACK(x) (x)
#define EB_HANDLER_ADDRESS(x) (x)
#define EB_RESPONSE(x) (x)

#endif
#endif
