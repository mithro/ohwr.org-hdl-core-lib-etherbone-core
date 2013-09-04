/** @file irq.c
 *  @brief MSI capable IRQ handler for the LM32
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  @author Mathias Kreider <m.kreider@gsi.de>
 *
 *  @bug None!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */

#include "ebm.h"

extern unsigned int* ebm;




void ebm_op(unsigned int address, unsigned int value, unsigned int optype)
{
    unsigned int offset = EBM_OFFS_DAT;
    offset += optype;
     offset += (address & ADR_MASK);
    *(ebm + (offset>>2)) = value;
    return;
}

void ebm_flush(void)
{
  *(ebm + (EBM_REG_FLUSH>>2)) = 0x01;
}

