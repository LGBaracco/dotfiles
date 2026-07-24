{...}: {
  fileSystems."/mnt/windowsdata" = {
    device = "/dev/disk/by-uuid/A68EDAC18EDA8967";
    fsType = "ntfs3";
    options = ["rw" "uid=1000" "gid=100" "windows_names" "nofail" "x-gvfs-show"];
  };
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/740C5E000C5DBDB4";
    fsType = "ntfs3";
    options = ["rw" "uid=1000" "gid=100" "windows_names" "nofail" "x-gvfs-show"];
  };
}
