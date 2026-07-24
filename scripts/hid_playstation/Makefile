# Out-of-tree build of the kernel's hid-playstation driver (DualShock 4 /
# DualSense / clones). Invoked directly (`make`) or by DKMS, which passes
# KDIR for the kernel being built against. kbuild rules live in Kbuild.
KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
