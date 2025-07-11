const std = @import("std");
const io = std.io;
const print = std.debug.print;

const TOTAL_BLOCKS = 64;

const Block = struct {
    start: u32,
    size: u32,
    allocated: bool,
};

const Allocator = struct {
    blocks: std.ArrayList(Block),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) !Allocator {
        var blocks = std.ArrayList(Block).init(allocator);
        try blocks.append(Block{
            .start = 0,
            .size = TOTAL_BLOCKS,
            .allocated = false,
        });
        return Allocator{
            .blocks = blocks,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Allocator) void {
        self.blocks.deinit();
    }

    fn nextPowerOf2(n: u32) u32 {
        if (n == 0) return 1;
        var power: u32 = 1;
        while (power < n) {
            power *= 2;
        }
        return power;
    }

    fn allocate(self: *Allocator, requested: u32) !void {
        const needed = nextPowerOf2(requested);

        // Find a free block large enough
        var best_idx: ?usize = null;
        var best_size: u32 = TOTAL_BLOCKS + 1;

        for (self.blocks.items, 0..) |block, i| {
            if (!block.allocated and block.size >= needed and block.size < best_size) {
                best_idx = i;
                best_size = block.size;
            }
        }

        if (best_idx == null) {
            print("No suitable block found\n", .{});
            return;
        }

        const idx = best_idx.?;
        var current_block = self.blocks.items[idx];

        // Split blocks until we get the right size
        while (current_block.size > needed) {
            const half_size = current_block.size / 2;
            print("(splitting {}/{d})\n", .{ current_block.start, current_block.size });

            // Update current block to half size
            self.blocks.items[idx].size = half_size;

            // Insert buddy block
            try self.blocks.insert(idx + 1, Block{
                .start = current_block.start + half_size,
                .size = half_size,
                .allocated = false,
            });

            current_block = self.blocks.items[idx];
        }

        // Allocate the block
        self.blocks.items[idx].allocated = true;
        print("Blocks {d}-{d} allocated:\n", .{ current_block.start, current_block.start + current_block.size - 1 });
    }

    fn free(self: *Allocator, start: u32) !void {
        // Find the block to free
        var idx: ?usize = null;
        for (self.blocks.items, 0..) |block, i| {
            if (block.start == start and block.allocated) {
                idx = i;
                break;
            }
        }

        if (idx == null) {
            print("Block not found or not allocated\n", .{});
            return;
        }

        // Free the block
        self.blocks.items[idx.?].allocated = false;

        // Try to merge with buddy
        var merged = true;
        while (merged) {
            merged = false;
            var i: usize = 0;
            while (i < self.blocks.items.len - 1) {
                const block = self.blocks.items[i];
                const next = self.blocks.items[i + 1];

                // Check if blocks can be merged (both free, same size, aligned)
                if (!block.allocated and !next.allocated and
                    block.size == next.size and
                    block.start + block.size == next.start and
                    (block.start / block.size) % 2 == 0)
                {
                    print("(merging {d}/{d} and {d}/{d})\n", .{ block.start, block.size, next.start, next.size });

                    // Merge blocks
                    self.blocks.items[i].size *= 2;
                    _ = self.blocks.orderedRemove(i + 1);
                    merged = true;
                    break;
                }
                i += 1;
            }
        }

        print("Blocks {d}-{d} freed:\n", .{ start, start + self.blocks.items[idx.?].size - 1 });
    }

    fn display(self: *Allocator) void {
        print("|", .{});

        var pos: u32 = 0;
        for (self.blocks.items, 0..) |block, i| {
            const c: u8 = if (block.allocated) '#' else '-';
            var j: u32 = 0;
            while (j < block.size) : (j += 1) {
                print("{c}", .{c});
            }

            // Add separator if not the last block
            if (i < self.blocks.items.len - 1) {
                print("|", .{});
            }

            pos += block.size;
        }

        print("|\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var buddy = try Allocator.init(allocator);
    defer buddy.deinit();

    const stdin = io.getStdIn().reader();
    var buf: [100]u8 = undefined;

    print("% ./buddy-demo\n", .{});
    buddy.display();

    while (true) {
        print("Type command:\n", .{});

        if (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var parts = std.mem.tokenizeScalar(u8, line, ' ');
            const cmd = parts.next() orelse continue;

            if (cmd[0] == 'q') {
                print("%\n", .{});
                break;
            } else if (cmd[0] == 'a') {
                if (parts.next()) |num_str| {
                    const num = try std.fmt.parseInt(u32, num_str, 10);
                    try buddy.allocate(num);
                    buddy.display();
                }
            } else if (cmd[0] == 'f') {
                if (parts.next()) |addr_str| {
                    const addr = try std.fmt.parseInt(u32, addr_str, 10);
                    try buddy.free(addr);
                    buddy.display();
                }
            }
        }
    }
}
