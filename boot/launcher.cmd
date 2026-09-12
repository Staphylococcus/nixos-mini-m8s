# Vendor U-Boot SD slot number follows the documented GXBB convention.
# All loads go to RAM. No persistent environment or storage writes.
# Legacy Amlogic autoscr executes each physical line separately.
# Keep each complete conditional or loop on one physical line.
echo Mini M8S SD chainload test
if fatload mmc 0:1 0x01000000 u-boot.ext; then go 0x01000000; fi
echo SD chainload did not complete - remove power and SD to return to factory boot
# Stay here if the chainload fails/returns; do not fall through to vendor update.
while test 1 = 1; do sleep 1; done
