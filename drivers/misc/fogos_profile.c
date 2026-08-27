// SPDX-License-Identifier: GPL-2.0-only
/*
 * FogOS profile control
 *
 * This driver deliberately exposes a narrow, validated interface.  It never
 * accepts arbitrary sysfs, scheduler, frequency, voltage, thermal, or ioctl
 * values.  The selected profile may apply only a bounded CPU-idle latency QoS
 * request: it can reduce wake-up latency during a foreground game, but cannot
 * raise clocks, relax thermal trips, alter voltages, or disable throttling.
 *
 * The device node is /dev/fogos_profile.  Android SELinux policy must label
 * that node as fogos_profile_device and grant access only to the signed FogOS
 * control application (or a trusted system service).  The 0666 mode is not an
 * authorization boundary; SELinux is the authorization boundary.
 */

#include <linux/fs.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/pm_qos.h>
#include <linux/string.h>
#include <linux/uaccess.h>

#define FOGOS_PROFILE_MAX 32
/*
 * Restrict only the exit latency of deep CPU-idle states.  These values are
 * intentionally modest; they are not CPU/GPU frequency requests and stock
 * Qualcomm/Motorola thermal mitigation remains fully authoritative.
 */
#define FOGOS_PERFORMANCE_LATENCY_US 1000
#define FOGOS_EXTREME_GAMING_LATENCY_US 500

static DEFINE_MUTEX(fogos_profile_lock);
static char fogos_active_profile[FOGOS_PROFILE_MAX] = "balanced";
static struct pm_qos_request fogos_latency_qos;

static bool fogos_profile_valid(const char *profile)
{
	return !strcmp(profile, "balanced") ||
	       !strcmp(profile, "performance") ||
	       !strcmp(profile, "extreme_gaming");
}

static s32 fogos_profile_latency_us(const char *profile)
{
	if (!strcmp(profile, "performance"))
		return FOGOS_PERFORMANCE_LATENCY_US;
	if (!strcmp(profile, "extreme_gaming"))
		return FOGOS_EXTREME_GAMING_LATENCY_US;
	return PM_QOS_DEFAULT_VALUE;
}

static void fogos_apply_latency_qos(const char *profile)
{
	s32 latency_us = fogos_profile_latency_us(profile);

	/* Balanced removes this driver's request entirely; it restores stock idle. */
	if (latency_us == PM_QOS_DEFAULT_VALUE) {
		if (pm_qos_request_active(&fogos_latency_qos))
			pm_qos_remove_request(&fogos_latency_qos);
		return;
	}

	if (pm_qos_request_active(&fogos_latency_qos))
		pm_qos_update_request(&fogos_latency_qos, latency_us);
	else
		pm_qos_add_request(&fogos_latency_qos, PM_QOS_CPU_DMA_LATENCY,
				   latency_us);
}

static ssize_t fogos_profile_read(struct file *file, char __user *buffer,
				  size_t count, loff_t *position)
{
	char snapshot[FOGOS_PROFILE_MAX + 1];
	int length;

	mutex_lock(&fogos_profile_lock);
	length = scnprintf(snapshot, sizeof(snapshot), "%s\n",
			   fogos_active_profile);
	mutex_unlock(&fogos_profile_lock);

	return simple_read_from_buffer(buffer, count, position, snapshot, length);
}

static ssize_t fogos_profile_write(struct file *file,
				  const char __user *buffer, size_t count,
				  loff_t *position)
{
	char requested[FOGOS_PROFILE_MAX];
	char *profile;
	s32 latency_us;

	if (!count || count >= sizeof(requested))
		return -EINVAL;
	if (copy_from_user(requested, buffer, count))
		return -EFAULT;

	requested[count] = '\0';
	profile = strim(requested);
	if (!fogos_profile_valid(profile))
		return -EINVAL;

	mutex_lock(&fogos_profile_lock);
	fogos_apply_latency_qos(profile);
	strscpy(fogos_active_profile, profile, sizeof(fogos_active_profile));
	latency_us = fogos_profile_latency_us(profile);
	mutex_unlock(&fogos_profile_lock);

	if (latency_us == PM_QOS_DEFAULT_VALUE)
		pr_info_ratelimited("fogos_profile: selected %s; stock idle latency restored\n",
				    profile);
	else
		pr_info_ratelimited("fogos_profile: selected %s; CPU-idle latency cap=%d us\n",
				    profile, latency_us);
	return count;
}

static const struct file_operations fogos_profile_fops = {
	.owner = THIS_MODULE,
	.read = fogos_profile_read,
	.write = fogos_profile_write,
	.llseek = no_llseek,
};

static struct miscdevice fogos_profile_miscdev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "fogos_profile",
	.fops = &fogos_profile_fops,
	.mode = 0666,
};

static int __init fogos_profile_init(void)
{
	int error;

	error = misc_register(&fogos_profile_miscdev);
	if (error)
		pr_err("fogos_profile: unable to register device: %d\n", error);
	else
		pr_info("fogos_profile: /dev/fogos_profile ready; balanced profile active\n");
	return error;
}

static void __exit fogos_profile_exit(void)
{
	mutex_lock(&fogos_profile_lock);
	if (pm_qos_request_active(&fogos_latency_qos))
		pm_qos_remove_request(&fogos_latency_qos);
	mutex_unlock(&fogos_profile_lock);
	misc_deregister(&fogos_profile_miscdev);
}

module_init(fogos_profile_init);
module_exit(fogos_profile_exit);

MODULE_DESCRIPTION("FogOS restricted rootless gaming profile control");
MODULE_LICENSE("GPL");
MODULE_AUTHOR("FogOS");
