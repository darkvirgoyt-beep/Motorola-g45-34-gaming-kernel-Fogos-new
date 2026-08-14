// SPDX-License-Identifier: GPL-2.0-only
/*
 * FogOS profile control
 *
 * This driver intentionally exposes a very small interface.  It does not
 * accept arbitrary sysfs, scheduler, frequency, thermal, or ioctl values.
 * Userspace may only select one of the profiles that the FogOS runtime
 * profile manager already knows how to apply.
 *
 * The device node is /dev/fogos_profile.  Android SELinux policy must label
 * that node as fogos_profile_device and grant access only to the signed
 * FogOS control application (or a trusted system service).  The 0666 mode is
 * not an authorization boundary; SELinux is the authorization boundary.
 */

#include <linux/fs.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/string.h>
#include <linux/uaccess.h>

#define FOGOS_PROFILE_MAX 32

static DEFINE_MUTEX(fogos_profile_lock);
static char fogos_active_profile[FOGOS_PROFILE_MAX] = "balanced";

static bool fogos_profile_valid(const char *profile)
{
	return !strcmp(profile, "balanced") ||
	       !strcmp(profile, "performance") ||
	       !strcmp(profile, "extreme_gaming");
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

	if (!count || count >= sizeof(requested))
		return -EINVAL;
	if (copy_from_user(requested, buffer, count))
		return -EFAULT;

	requested[count] = '\0';
	profile = strim(requested);
	if (!fogos_profile_valid(profile))
		return -EINVAL;

	mutex_lock(&fogos_profile_lock);
	strscpy(fogos_active_profile, profile, sizeof(fogos_active_profile));
	mutex_unlock(&fogos_profile_lock);

	pr_info_ratelimited("fogos_profile: requested %s\n", profile);
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
		pr_info("fogos_profile: /dev/fogos_profile ready\n");
	return error;
}

static void __exit fogos_profile_exit(void)
{
	misc_deregister(&fogos_profile_miscdev);
}

module_init(fogos_profile_init);
module_exit(fogos_profile_exit);

MODULE_DESCRIPTION("FogOS restricted kernel profile control");
MODULE_LICENSE("GPL");
MODULE_AUTHOR("FogOS");
