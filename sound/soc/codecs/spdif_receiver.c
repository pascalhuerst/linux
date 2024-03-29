/*
 * ALSA SoC SPDIF DIR (Digital Interface Reciever) driver
 *
 * Based on ALSA SoC SPDIF DIT driver
 *
 *  This driver is used by controllers which can operate in DIR (SPDI/F) where
 *  no codec is needed.  This file provides stub codec that can be used
 *  in these configurations. SPEAr SPDIF IN Audio controller uses this driver.
 *
 * Author:      Vipin Kumar,  <vipin.kumar@st.com>
 * Copyright:   (C) 2012  ST Microelectronics
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/slab.h>
#include <sound/soc.h>
#include <sound/pcm.h>
#include <sound/initval.h>
#include <linux/of.h>

static const struct snd_soc_dapm_widget dir_widgets[] = {
	SND_SOC_DAPM_INPUT("spdif-in"),
};

static const struct snd_soc_dapm_route dir_routes[] = {
	{ "Capture", NULL, "spdif-in" },
};

#define STUB_RATES	SNDRV_PCM_RATE_8000_192000
#define STUB_FORMATS	(SNDRV_PCM_FMTBIT_S8 |\
			SNDRV_PCM_FMTBIT_U8 |\
			SNDRV_PCM_FMTBIT_S16_LE |\
			SNDRV_PCM_FMTBIT_S16_BE |\
			SNDRV_PCM_FMTBIT_U16_LE |\
			SNDRV_PCM_FMTBIT_U16_BE |\
			SNDRV_PCM_FMTBIT_S24_LE |\
			SNDRV_PCM_FMTBIT_S24_BE |\
			SNDRV_PCM_FMTBIT_U24_LE |\
			SNDRV_PCM_FMTBIT_U24_BE |\
			SNDRV_PCM_FMTBIT_S32_LE |\
			SNDRV_PCM_FMTBIT_S32_BE |\
			SNDRV_PCM_FMTBIT_U32_LE |\
			SNDRV_PCM_FMTBIT_U32_BE |\
			SNDRV_PCM_FMTBIT_FLOAT_LE |\
			SNDRV_PCM_FMTBIT_FLOAT_BE |\
			SNDRV_PCM_FMTBIT_FLOAT64_LE |\
			SNDRV_PCM_FMTBIT_FLOAT64_BE |\
			SNDRV_PCM_FMTBIT_IEC958_SUBFRAME_LE  |\
			SNDRV_PCM_FMTBIT_IEC958_SUBFRAME_BE |\
			SNDRV_PCM_FMTBIT_MU_LAW |\
			SNDRV_PCM_FMTBIT_A_LAW |\
			SNDRV_PCM_FMTBIT_IMA_ADPCM |\
			SNDRV_PCM_FMTBIT_MPEG |\
			SNDRV_PCM_FMTBIT_GSM |\
			SNDRV_PCM_FMTBIT_SPECIAL |\
			SNDRV_PCM_FMTBIT_S24_3LE |\
			SNDRV_PCM_FMTBIT_U24_3LE |\
			SNDRV_PCM_FMTBIT_S24_3BE |\
			SNDRV_PCM_FMTBIT_U24_3BE |\
			SNDRV_PCM_FMTBIT_S20_3LE |\
			SNDRV_PCM_FMTBIT_U20_3LE |\
			SNDRV_PCM_FMTBIT_S20_3BE |\
			SNDRV_PCM_FMTBIT_U20_3BE |\
			SNDRV_PCM_FMTBIT_S18_3LE |\
			SNDRV_PCM_FMTBIT_U18_3LE |\
			SNDRV_PCM_FMTBIT_S18_3BE |\
			SNDRV_PCM_FMTBIT_U18_3BE |\
			SNDRV_PCM_FMTBIT_G723_24 |\
			SNDRV_PCM_FMTBIT_G723_24_1B |\
			SNDRV_PCM_FMTBIT_G723_40 |\
			SNDRV_PCM_FMTBIT_G723_40_1B |\
			SNDRV_PCM_FMTBIT_DSD_U8 |\
			SNDRV_PCM_FMTBIT_DSD_U16_LE |\
			SNDRV_PCM_FMTBIT_DSD_U32_LE |\
			SNDRV_PCM_FMTBIT_DSD_U16_BE |\
			SNDRV_PCM_FMTBIT_DSD_U32_BE)

static struct snd_soc_codec_driver soc_codec_spdif_dir = {
	.dapm_widgets = dir_widgets,
	.num_dapm_widgets = ARRAY_SIZE(dir_widgets),
	.dapm_routes = dir_routes,
	.num_dapm_routes = ARRAY_SIZE(dir_routes),
};

static struct snd_soc_dai_driver dir_stub_dai = {
	.name		= "dir-hifi",
	.capture	= {
		.stream_name	= "Capture",
		.channels_min	= 1,
		.channels_max	= 384,
		.rates		= STUB_RATES,
		.formats	= STUB_FORMATS,
	},
};

static int spdif_dir_probe(struct platform_device *pdev)
{
	return snd_soc_register_codec(&pdev->dev, &soc_codec_spdif_dir,
			&dir_stub_dai, 1);
}

static int spdif_dir_remove(struct platform_device *pdev)
{
	snd_soc_unregister_codec(&pdev->dev);
	return 0;
}

#ifdef CONFIG_OF
static const struct of_device_id spdif_dir_dt_ids[] = {
	{ .compatible = "linux,spdif-dir", },
	{ }
};
MODULE_DEVICE_TABLE(of, spdif_dir_dt_ids);
#endif

static struct platform_driver spdif_dir_driver = {
	.probe		= spdif_dir_probe,
	.remove		= spdif_dir_remove,
	.driver		= {
		.name	= "spdif-dir",
		.of_match_table = of_match_ptr(spdif_dir_dt_ids),
	},
};

module_platform_driver(spdif_dir_driver);

MODULE_DESCRIPTION("ASoC SPDIF DIR driver");
MODULE_AUTHOR("Vipin Kumar <vipin.kumar@st.com>");
MODULE_LICENSE("GPL");
