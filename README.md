Small script to compare SFrame binary size impact by wrapping size(1)
and comparing two directories with Linux userland.

## gentoo.csv

I've included `gentoo.csv` which was created with the following environment.

`baseline` and `new` both used the same Gentoo stage3 tarball:
`stage3-amd64-systemd-20251019T170404Z.tar.xz`.

`sys-devel/binutils` was configured with `EXTRA_ECONF="--disable-default-sframe"`
for `baseline` and `EXTRA_ECONF="--enable-default-sframe"` for `new`.

Repository states:
```
* Head commit of repository gentoo: d9a302164bd45b6e96a4c39a5a43d8dcf1866e59
* Head commit of repository sam_c: 5cd1d03a66d549e016d9b0c711efa383d86beec4
* binutils-patches.git: 389be9bc3a5f0d16f7f4214c69440b4bb4828a96
* binutils-gdb.git: 157da75362cc082f8f8067155d137dfe98ac230c
* binutils SFrame patches: https://github.com/thesamesam/overlay/tree/f1490b61932ddf5433611061d6d7a3d9a8fa5699/sys-devel/binutils/files/sframe
```
