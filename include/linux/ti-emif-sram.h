/*
 * TI AM33XX EMIF Routines
 *
 * Copyright (C) 2014 Texas Instruments Inc.
 *          Dave Gerlach <d-gerlach@ti.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation version 2.
 *
 * This program is distributed "as is" WITHOUT ANY WARRANTY of any
 * kind, whether express or implied; without even the implied warranty
 * of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */
#ifndef __LINUX_TI_EMIF_H
#define __LINUX_TI_EMIF_H

#ifdef CONFIG_TI_EMIF_SRAM
int ti_emif_copy_pm_function_table(void *dst);
int ti_emif_get_mem_type(void);
#else
static inline int ti_emif_copy_pm_function_table(void *dst) { return -ENODEV; }
static inline int ti_emif_get_mem_type(void) { return -ENODEV; }
#endif /* CONFIG_TI_EMIF_SRAM */
#endif /* __LINUX_TI_EMIF_H */
