An interactive buddy memory allocator in zig. This repository is for my school project.

Run:
  zig run alloc.zig

Commands:
  a <number>  - Allocate blocks (e.g., "a 4" allocates 4 blocks)
  f <address> - Free blocks at address (e.g., "f 0" frees block at address 0)
  q          - Quit

Example session:
  a 4    (allocate 4 blocks)
  a 16   (allocate 16 blocks)
  f 0    (free blocks starting at address 0)
  q      (quit)
