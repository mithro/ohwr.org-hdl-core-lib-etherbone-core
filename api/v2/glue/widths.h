/* Copyright (C) 2011-2012 GSI GmbH.
 *
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * Various width helper functions.
 */

#ifndef EB_WIDTH_H
#define EB_WIDTH_H

#include "../etherbone.h"

/* 1 if both addr and port widths are non-zero */
EB_PRIVATE int eb_width_possible(eb_width_t width);
/* 1 if both addr and port have exactly one width */
EB_PRIVATE int eb_width_refined(eb_width_t width);
/* Select the largest width out of possible widths */
EB_PRIVATE eb_width_t eb_width_refine(eb_width_t width);

#endif
