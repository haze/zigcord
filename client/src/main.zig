const std = @import("std");
const discord = @import("zigcord");

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var transport = try discord.DiscordTransport.init(allocator, .{ .token = "jdfoikjsdflkjsdlkfj" });
    defer transport.deinit();
    std.debug.warn("{?}\n", .{transport.get_current_user()});
    std.debug.warn("{?}\n", .{transport.get_user(.{ .id = 272713970823987206 })});
}
