{...}: {
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/B4C6E5E6C6E5A936";
    fsType = "ntfs3";
    options = ["rw" "uid=1000" "gid=100" "iocharset=utf8" "nofail" "x-gvfs-show"];
  };
}
