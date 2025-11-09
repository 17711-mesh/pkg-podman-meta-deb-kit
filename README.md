# Quickstart

Build the meta package:
```bash
chmod +x build-podman-meta-deb.sh
sudo ./build-podman-meta-deb.sh /opt/podman-v5.7.0
sudo dpkg -i podman-meta-v5.7.0_arm64.deb
```

After install (already enabled by postinst):
```bash
systemctl status podman.socket
podman --version
```

Example network & volume and a demo container:
```bash
podman network ls
podman volume ls
podman run --rm --network=demo -v demo-vol:/data alpine sh -lc 'echo ok >/data/test && cat /data/test'
```
