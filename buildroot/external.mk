# STM32MP1 flight-control Buildroot external tree.
#
# Custom package makefiles can be added under buildroot/package/<name>/<name>.mk
# when project-specific Buildroot packages are introduced.

include $(sort $(wildcard $(BR2_EXTERNAL_STM32MP1_FLIGHT_PATH)/package/*/*.mk))
