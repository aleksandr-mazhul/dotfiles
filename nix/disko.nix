# Default device is the Kingston SNV2S500G (the Windows nvme), named "main" so
# a new machine can override it: install-machine /dev/disk/by-id/...
# This module is not imported by the test VM. Do not point it at the running
# Arch disk. install-machine refuses to format the disk that holds /.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-KINGSTON_SNV2S500G_50026B76866AEA46";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
