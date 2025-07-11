// AI-generated extensive test

const std = @import("std");
const testing = std.testing;

// Import the buddy allocator from the main file
const buddy_allocator = @import("alloc.zig");
const Allocator = buddy_allocator.Allocator;

test "nextPowerOf2 function" {
    try testing.expectEqual(@as(u32, 1), Allocator.nextPowerOf2(0));
    try testing.expectEqual(@as(u32, 1), Allocator.nextPowerOf2(1));
    try testing.expectEqual(@as(u32, 2), Allocator.nextPowerOf2(2));
    try testing.expectEqual(@as(u32, 4), Allocator.nextPowerOf2(3));
    try testing.expectEqual(@as(u32, 4), Allocator.nextPowerOf2(4));
    try testing.expectEqual(@as(u32, 8), Allocator.nextPowerOf2(5));
    try testing.expectEqual(@as(u32, 16), Allocator.nextPowerOf2(15));
    try testing.expectEqual(@as(u32, 16), Allocator.nextPowerOf2(16));
    try testing.expectEqual(@as(u32, 32), Allocator.nextPowerOf2(17));
}

test "basic allocation and deallocation" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Allocate 4 blocks
    const addr = try buddy.allocate(4);
    try testing.expect(addr != null);
    try testing.expectEqual(@as(u32, 0), addr.?);
    try testing.expectEqual(@as(u32, 4), buddy.getTotalAllocatedBlocks());
    try testing.expectEqual(@as(u32, 60), buddy.getTotalFreeBlocks());

    // Free the blocks
    const freed = try buddy.free(0);
    try testing.expect(freed);
    try testing.expectEqual(@as(u32, 0), buddy.getTotalAllocatedBlocks());
    try testing.expectEqual(@as(u32, 64), buddy.getTotalFreeBlocks());
}

test "power of 2 allocation rounding" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Request 3 blocks, should get 4
    const addr1 = try buddy.allocate(3);
    try testing.expect(addr1 != null);
    try testing.expectEqual(@as(u32, 4), buddy.getTotalAllocatedBlocks());

    // Request 5 blocks, should get 8
    const addr2 = try buddy.allocate(5);
    try testing.expect(addr2 != null);
    try testing.expectEqual(@as(u32, 12), buddy.getTotalAllocatedBlocks());

    // Request 9 blocks, should get 16
    const addr3 = try buddy.allocate(9);
    try testing.expect(addr3 != null);
    try testing.expectEqual(@as(u32, 28), buddy.getTotalAllocatedBlocks());
}

test "buddy merging on free" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Allocate two adjacent 4-block chunks
    const addr1 = try buddy.allocate(4);
    const addr2 = try buddy.allocate(4);
    try testing.expectEqual(@as(u32, 0), addr1.?);
    try testing.expectEqual(@as(u32, 4), addr2.?);

    // Should have split into smaller blocks
    try testing.expect(buddy.getFragmentCount() > 2);

    // Free both blocks
    _ = try buddy.free(0);
    _ = try buddy.free(4);

    // Should merge back together
    try testing.expectEqual(@as(u32, 64), buddy.getTotalFreeBlocks());
    // After full merge, should have fewer fragments
    try testing.expect(buddy.getFragmentCount() < 5);
}

test "allocation failure when full" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Allocate all 64 blocks
    const addr1 = try buddy.allocate(32);
    const addr2 = try buddy.allocate(32);
    try testing.expect(addr1 != null);
    try testing.expect(addr2 != null);
    try testing.expectEqual(@as(u32, 64), buddy.getTotalAllocatedBlocks());

    // Try to allocate more - should fail
    const addr3 = try buddy.allocate(1);
    try testing.expect(addr3 == null);
}

test "free non-existent block" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Try to free a block that doesn't exist
    const freed = try buddy.free(10);
    try testing.expect(!freed);
}

test "complex allocation pattern" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Allocate various sizes
    const addr1 = try buddy.allocate(1); // Gets 1 block
    const addr2 = try buddy.allocate(2); // Gets 2 blocks
    const addr3 = try buddy.allocate(3); // Gets 4 blocks
    const addr4 = try buddy.allocate(8); // Gets 8 blocks
    const addr5 = try buddy.allocate(15); // Gets 16 blocks

    try testing.expect(addr1 != null);
    try testing.expect(addr2 != null);
    try testing.expect(addr3 != null);
    try testing.expect(addr4 != null);
    try testing.expect(addr5 != null);

    // Total allocated should be 1 + 2 + 4 + 8 + 16 = 31
    try testing.expectEqual(@as(u32, 31), buddy.getTotalAllocatedBlocks());

    // Free in different order
    _ = try buddy.free(addr3.?);
    _ = try buddy.free(addr1.?);
    _ = try buddy.free(addr5.?);
    _ = try buddy.free(addr2.?);
    _ = try buddy.free(addr4.?);

    // Should be fully free again
    try testing.expectEqual(@as(u32, 0), buddy.getTotalAllocatedBlocks());
    try testing.expectEqual(@as(u32, 64), buddy.getTotalFreeBlocks());
}

test "fragmentation and defragmentation" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Create a checkerboard pattern of allocations
    var addrs: [8]?u32 = undefined;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        addrs[i] = try buddy.allocate(4);
        try testing.expect(addrs[i] != null);
    }

    // Free every other one
    i = 0;
    while (i < 8) : (i += 2) {
        _ = try buddy.free(addrs[i].?);
    }

    // Should have fragmentation
    const fragmented_count = buddy.getFragmentCount();
    try testing.expect(fragmented_count > 8);

    // Free the rest
    i = 1;
    while (i < 8) : (i += 2) {
        _ = try buddy.free(addrs[i].?);
    }

    // Should be defragmented
    try testing.expectEqual(@as(u32, 64), buddy.getTotalFreeBlocks());
    try testing.expect(buddy.getFragmentCount() < fragmented_count);
}

test "buddy splitting and merging behavior" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Start with 64 free blocks
    try testing.expectEqual(@as(u32, 64), buddy.getTotalFreeBlocks());

    // Allocate 16 blocks
    const addr1 = try buddy.allocate(16);
    try testing.expect(addr1 != null);
    try testing.expectEqual(@as(u32, 16), buddy.getTotalAllocatedBlocks());

    // Allocate 8 blocks
    const addr2 = try buddy.allocate(8);
    try testing.expect(addr2 != null);
    try testing.expectEqual(@as(u32, 24), buddy.getTotalAllocatedBlocks());

    // Free the 16-block allocation
    const freed1 = try buddy.free(addr1.?);
    try testing.expect(freed1);
    try testing.expectEqual(@as(u32, 8), buddy.getTotalAllocatedBlocks());

    // Allocate 8 blocks - should fit in available space
    const addr3 = try buddy.allocate(8);
    try testing.expect(addr3 != null);
    try testing.expectEqual(@as(u32, 16), buddy.getTotalAllocatedBlocks());

    // Allocate another 8 blocks
    const addr4 = try buddy.allocate(8);
    try testing.expect(addr4 != null);
    try testing.expectEqual(@as(u32, 24), buddy.getTotalAllocatedBlocks());

    // Free all allocations
    _ = try buddy.free(addr2.?);
    _ = try buddy.free(addr3.?);
    _ = try buddy.free(addr4.?);

    // Should have all blocks free again
    try testing.expectEqual(@as(u32, 0), buddy.getTotalAllocatedBlocks());
    try testing.expectEqual(@as(u32, 64), buddy.getTotalFreeBlocks());
}

test "maximum block allocation" {
    var buddy = try Allocator.init(testing.allocator);
    defer buddy.deinit();

    // Allocate maximum size (64 blocks)
    const addr = try buddy.allocate(64);
    try testing.expect(addr != null);
    try testing.expectEqual(@as(u32, 0), addr.?);
    try testing.expectEqual(@as(u32, 64), buddy.getTotalAllocatedBlocks());
    try testing.expectEqual(@as(u32, 0), buddy.getTotalFreeBlocks());
    try testing.expectEqual(@as(usize, 1), buddy.getFragmentCount());
}
