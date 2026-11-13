# Kingston SNV2S500G only. This is the Windows nvme. It is not imported by the
# test VM. Do not point nixos-anywhere at the running Arch system: that kexecs
# this machine and formats the disk named here.
{
  disko.devices.disk.nvme = {
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
