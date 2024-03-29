/*
 * Low level suspend code for AM43XX SoCs
 *
 * Copyright (C) 2013 Texas Instruments Incorporated - http://www.ti.com/
 * Dave Gerlach <d-gerlach@ti.com>
 * Vaibhav Bedia <vaibhav.bedia@ti.com>
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

#include <linux/linkage.h>
#include <asm/memory.h>
#include <asm/assembler.h>

#include "iomap.h"
#include "cm33xx.h"
#include "prm33xx.h"
#include "prcm43xx.h"

#include "common.h"
#include "omap-secure.h"
#include "omap44xx.h"
#include <asm/hardware/cache-l2x0.h>

#define EMIF_POWER_MGMT_SR_TIMER_MASK			0x00f0

#define EMIF_POWER_MGMT_SELF_REFRESH_MODE		0x0200
#define EMIF_POWER_MGMT_SELF_REFRESH_MODE_MASK		0x0700
#define EMIF_POWER_MGMT_DELAY_PERIOD			0x1000

#define EMIF_LPDDR2_AM43XX_REFRESH_EN_CS0		0x40000002
#define EMIF_LPDDR2_AM43XX_REFRESH_EN_CS1		0xC0000002
#define AM43XX_EMIF_PHY_CTRL_REG_COUNT			0x120

#define AM33XX_CM_CLKCTRL_MODULEMODE_DISABLE		0x0003
#define AM33XX_CM_CLKCTRL_MODULEMODE_ENABLE		0x0002

#define AM43XX_EMIF_POWEROFF_ENABLE			0x1
#define AM43XX_EMIF_POWEROFF_DISABLE		0x0

#define AM43XX_CM_CLKSTCTRL_CLKTRCTRL_SW_SLEEP		0x1
#define AM43XX_CM_CLKSTCTRL_CLKTRCTRL_HW_AUTO		0x3

#define AM43XX_CM_BASE                 0x44DF0000

#define AM43XX_CTRL_CKE_OVERRIDE       0x44E1131C

#define AM43XX_CM_REGADDR(inst, reg)                           \
       AM33XX_L4_WK_IO_ADDRESS(AM43XX_CM_BASE + (inst) + (reg))

#define AM43XX_PM_MPU_PWRSTCTRL AM43XX_CM_REGADDR(0x0300, 0x00)
#define AM43XX_CM_MPU_CLKSTCTRL AM43XX_CM_REGADDR(0x8300, 0x00)
#define AM43XX_CM_MPU_MPU_CLKCTRL AM43XX_CM_REGADDR(0x8300, 0x20)
#define AM43XX_CM_PER_EMIF_CLKCTRL  AM43XX_CM_REGADDR(0x8800, 0x0720)

#define AM43XX_CM_PER_EMIF_CLKCTRL_OFFSET 0x0720
#define AM43XX_PRM_EMIF_CTRL_OFFSET    0x30

	.text
	.align 3

ENTRY(am43xx_do_wfi)
	stmfd	sp!, {r4 - r11, lr}	@ save registers on stack

	/* Retrieve l2 cache virt address BEFORE we shut off EMIF */
	ldr	r1, get_l2cache_base
	blx	r1
	str	r0, l2_base_virt

	/*
	 * Flush all data from the L1 and L2 data cache before disabling
	 * SCTLR.C bit.
	 */
	ldr	r1, kernel_flush
	blx	r1

	/*
	 * Clear the SCTLR.C bit to prevent further data cache
	 * allocation. Clearing SCTLR.C would make all the data accesses
	 * strongly ordered and would not hit the cache.
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #(1 << 2)	@ Disable the C bit
	mcr	p15, 0, r0, c1, c0, 0
	isb
	dsb

	/*
	 * Invalidate L1 and L2 data cache.
	 */
	ldr	r1, kernel_flush
	blx	r1

	/*
	 * The kernel doesn't interwork: v7_flush_dcache_all in particluar will
	 * always return in Thumb state when CONFIG_THUMB2_KERNEL is enabled.
	 * This sequence switches back to ARM.  Note that .align may insert a
	 * nop: bx pc needs to be word-aligned in order to work.
	 */
 THUMB(	.thumb		)
 THUMB(	.align		)
 THUMB(	bx	pc	)
 THUMB(	nop		)
	.arm

#ifdef CONFIG_CACHE_L2X0
	/*
	 * Clean and invalidate the L2 cache.
	 */
#ifdef CONFIG_PL310_ERRATA_727915
	mov	r0, #0x03
	mov	r12, #OMAP4_MON_L2X0_DBG_CTRL_INDEX
	dsb
	smc	#0
	dsb
#endif
	ldr	r0, l2_base_virt

	mov	r2, r0
	ldr	r0, [r2, #L2X0_AUX_CTRL]
	str	r0, l2_aux_ctrl_val
	ldr	r0, [r2, #L310_PREFETCH_CTRL]
	str	r0, l2_prefetch_ctrl_val

	ldr	r0, l2_val
	str	r0, [r2, #L2X0_CLEAN_INV_WAY]
wait:
	ldr	r0, [r2, #L2X0_CLEAN_INV_WAY]
	ldr	r1, l2_val
	ands	r0, r0, r1
	bne	wait
#ifdef CONFIG_PL310_ERRATA_727915
	mov	r0, #0x00
	mov	r12, #OMAP4_MON_L2X0_DBG_CTRL_INDEX
	dsb
	smc	#0
	dsb
#endif
l2x_sync:
	ldr	r0, l2_base_virt
	mov	r2, r0
	mov	r0, #0x0
	str	r0, [r2, #L2X0_CACHE_SYNC]
sync:
	ldr	r0, [r2, #L2X0_CACHE_SYNC]
	ands	r0, r0, #0x1
	bne	sync
#endif

	mov	r0, #0x1
	ldr	r1, ti_emif_save_context
	blx	r1

	ldr	r1, ti_emif_enter_sr
	blx	r1

	/* Disable EMIF */
	ldr	r1, am43xx_virt_emif_clkctrl
	ldr	r2, [r1]
	bic	r2, r2, #AM33XX_CM_CLKCTRL_MODULEMODE_DISABLE
	str	r2, [r1]

wait_emif_disable:
	ldr	r2, [r1]
	ldr	r3, module_disabled_val
	cmp	r2, r3
	bne	wait_emif_disable

	/*
	 * For the MPU WFI to be registered as an interrupt
	 * to WKUP_M3, MPU_CLKCTRL.MODULEMODE needs to be set
	 * to DISABLED
	 */
	ldr	r1, am43xx_virt_mpu_clkctrl
	ldr	r2, [r1]
	bic	r2, r2, #AM33XX_CM_CLKCTRL_MODULEMODE_DISABLE
	str	r2, [r1]

	/*
	 * Put MPU CLKDM to SW_SLEEP
	 */
	ldr	r1, am43xx_virt_mpu_clkstctrl
	mov	r2, #AM43XX_CM_CLKSTCTRL_CLKTRCTRL_SW_SLEEP
	str	r2, [r1]

	/*
	 * Execute a barrier instruction to ensure that all cache,
	 * TLB and branch predictor maintenance operations issued
	 * have completed.
	 */
	dsb
	dmb

	/*
	 * Execute a WFI instruction and wait until the
	 * STANDBYWFI output is asserted to indicate that the
	 * CPU is in idle and low power state. CPU can specualatively
	 * prefetch the instructions so add NOPs after WFI. Sixteen
	 * NOPs as per Cortex-A9 pipeline.
	 */
	wfi

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	/* We come here in case of an abort due to a late interrupt */
	ldr	r1, am43xx_virt_mpu_clkstctrl
	mov	r2, #AM43XX_CM_CLKSTCTRL_CLKTRCTRL_HW_AUTO
	str	r2, [r1]

	/* Set MPU_CLKCTRL.MODULEMODE back to ENABLE */
	ldr	r1, am43xx_virt_mpu_clkctrl
	mov	r2, #AM33XX_CM_CLKCTRL_MODULEMODE_ENABLE
	str	r2, [r1]

	/* Re-enable EMIF */
	ldr	r1, am43xx_virt_emif_clkctrl
	mov	r2, #AM33XX_CM_CLKCTRL_MODULEMODE_ENABLE
	str	r2, [r1]
wait_emif_enable:
	ldr	r3, [r1]
	cmp	r2, r3
	bne	wait_emif_enable

	/*
	 * Set SCTLR.C bit to allow data cache allocation
	 */
	mrc	p15, 0, r0, c1, c0, 0
	orr	r0, r0, #(1 << 2)	@ Enable the C bit
	mcr	p15, 0, r0, c1, c0, 0
	isb

	ldr	r1, ti_emif_abort_sr
	blx	r1

	/* EMIF needs some time before read/write possible */
	mov r0, #EMIF_POWER_MGMT_DELAY_PERIOD
wait_abt:
	subs   r0, r0, #1
	bne wait_abt

	/* Let the suspend code know about the abort */
	mov	r0, #1
	ldmfd	sp!, {r4 - r11, pc}	@ restore regs and return
ENDPROC(am43xx_do_wfi)

	.align
ENTRY(am43xx_resume_offset)
	.word . - am43xx_do_wfi

ENTRY(am43xx_resume_from_deep_sleep)
	/* For AM43xx, use EMIF power down until context is restored */
	ldr	r2, am43xx_phys_emif_poweroff
	mov	r1, #AM43XX_EMIF_POWEROFF_ENABLE
	str	r1, [r2, #0x0]

	/* Re-enable EMIF */
	ldr	r1, am43xx_phys_emif_clkctrl
	mov	r2, #AM33XX_CM_CLKCTRL_MODULEMODE_ENABLE
	str	r2, [r1]
wait_emif_enable1:
	ldr	r3, [r1]
	cmp	r2, r3
	bne	wait_emif_enable1

	adr	sp, temp_stack

	mov	r0, #0x1
	ldr	r1, ti_emif_restore_context
	blx	r1

	ldr	r1, ti_emif_exit_sr
	blx	r1

	ldr     r2, am43xx_phys_emif_poweroff
	mov     r1, #AM43XX_EMIF_POWEROFF_DISABLE
	str     r1, [r2, #0x0]

#ifdef CONFIG_CACHE_L2X0
	ldr	r2, l2_cache_base
	ldr	r0, [r2, #L2X0_CTRL]
	and	r0, #0x0f
	cmp	r0, #1
	beq	skip_l2en			@ Skip if already enabled
	ldr     r0, l2_prefetch_ctrl_val

	ldr	r12, l2_smc1
	dsb
	smc	#0
	dsb
set_aux_ctrl:
	ldr	r0, l2_aux_ctrl_val
	ldr	r12, l2_smc2
	dsb
	smc	#0
	dsb

	/* L2 invalidate on resume */
	ldr	r0, l2_val
	ldr	r2, l2_cache_base
	str	r0, [r2, #L2X0_INV_WAY]
wait2:
	ldr	r0, [r2, #L2X0_INV_WAY]
	ldr	r1, l2_val
	ands	r0, r0, r1
	bne	wait2
#ifdef CONFIG_PL310_ERRATA_727915
	mov	r0, #0x00
	mov	r12, #OMAP4_MON_L2X0_DBG_CTRL_INDEX
	dsb
	smc	#0
	dsb
#endif
l2x_sync2:
	ldr	r2, l2_cache_base
	mov	r0, #0x0
	str	r0, [r2, #L2X0_CACHE_SYNC]
sync2:
	ldr	r0, [r2, #L2X0_CACHE_SYNC]
	ands	r0, r0, #0x1
	bne	sync2

	mov	r0, #0x1
	ldr	r12, l2_smc3
	dsb
	smc	#0
	dsb
#endif
skip_l2en:
	/* We are back. Branch to the common CPU resume routine */
	mov	r0, #0
	ldr	pc, resume_addr
ENDPROC(am43xx_resume_from_deep_sleep)

/*
 * Local variables
 */
	.align
resume_addr:
	.word	cpu_resume - PAGE_OFFSET + 0x80000000
get_l2cache_base:
	.word	omap4_get_l2cache_base
kernel_flush:
	.word   v7_flush_dcache_all
ddr_start:
	.word	PAGE_OFFSET

cke_override_virt:
	.word	0xDEADBEEF
cke_override_phys:
	.word	AM43XX_CTRL_CKE_OVERRIDE

am43xx_phys_emif_poweroff:
	.word   (AM43XX_CM_BASE + AM43XX_PRM_DEVICE_INST + \
		 AM43XX_PRM_EMIF_CTRL_OFFSET)
am43xx_virt_mpu_pwrstctrl:
	.word	(AM43XX_PM_MPU_PWRSTCTRL)
am43xx_virt_mpu_clkstctrl:
	.word	(AM43XX_CM_MPU_CLKSTCTRL)
am43xx_virt_mpu_clkctrl:
	.word	(AM43XX_CM_MPU_MPU_CLKCTRL)
am43xx_virt_emif_clkctrl:
	.word	(AM43XX_CM_PER_EMIF_CLKCTRL)
am43xx_phys_emif_clkctrl:
	.word	(AM43XX_CM_BASE + AM43XX_CM_PER_INST + \
		 AM43XX_CM_PER_EMIF_CLKCTRL_OFFSET)
module_disabled_val:
	.word	0x30000

/* L2 cache related defines for AM437x */
l2_base_virt:
	.word	0xDEADBEEF
l2_aux_ctrl_val:
	.word	0xDEADBEEF
l2_prefetch_ctrl_val:
	.word	0xDEADBEEF
l2_cache_base:
	.word	OMAP44XX_L2CACHE_BASE
l2_val:
	.word	0xffff
l2_smc1:
	.word	OMAP4_MON_L2X0_PREFETCH_INDEX
l2_smc2:
	.word	OMAP4_MON_L2X0_AUXCTRL_INDEX
l2_smc3:
	.word	OMAP4_MON_L2X0_CTRL_INDEX


/* DDR related defines */
ENTRY(am43xx_emif_sram_table)
ti_emif_save_context:
	.word	0x00000000
ti_emif_restore_context:
	.word	0x00000000
ti_emif_enter_sr:
	.word	0x00000000
ti_emif_exit_sr:
	.word	0x00000000
ti_emif_abort_sr:
	.word	0x00000000
	.align 3
	.space 64
temp_stack:
	.align 3
ENTRY(am43xx_do_wfi_sz)
	.word	. - am43xx_do_wfi
