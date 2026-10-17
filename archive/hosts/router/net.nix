# Shared constants for the router machine profile.
# Imported by the per-feature modules under hosts/router/.
rec {
  lanIp = "10.10.10.1";
  lanAddress = "${lanIp}/24";
  lanInterface = "enp0s20f0u1";
  wanInterface = "eno1";
  username = "cyrene";
  sshAuthorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINT+WzW9LGGDbBqxxJVAnJjIN5JYbLtLxtGY9PmrS0fU";
  lanDevice = "sys-subsystem-net-devices-${lanInterface}.device";
}
