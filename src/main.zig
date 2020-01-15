const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const json = std.json;
usingnamespace @import("api.zig");
usingnamespace @cImport({
    @cInclude("curl/curl.h");
});

const testing = std.testing;

fn saveBodyToBuffer(argContent: *c_void, size: usize, nmemb: usize, userData: ?*c_void) callconv(.C) usize {
    var buffer = @ptrCast(*std.Buffer, @alignCast(8, userData));
    var content = @ptrCast([*:0]u8, argContent);
    buffer.replaceContents(content[0 .. size * nmemb :0]) catch {
        std.debug.warn("summ bad happened\n", .{});
        return 0;
    };
    // std.debug.warn("got: \"{s}\"\n", .{buffer.toSliceConst()});
    return size * nmemb;
}

pub const TransportOptions = struct {
    verboseCurl: bool = false,
    userAgent: []const u8 = "zigcord (https://github.com/haze/zigcord, 0.0.1)",
    token: []const u8,
};

// The DiscordTransport is responsible for facilitating requests
// to and from the discord api servers. It handles things like:
//   Automatically setting User Agent
//   Automatically setting Authorization token
pub const DiscordTransport = struct {
    const apiUrl: []const u8 = "https://discordapp.com/api/v6";
    const Self = @This();

    allocator: *mem.Allocator,
    curlHandle: *CURL,
    authHeader: []const u8,
    jsonParser: json.Parser,

    options: TransportOptions,

    pub fn init(allocator: *mem.Allocator, options: TransportOptions) !Self {
        return DiscordTransport{
            .allocator = allocator,
            .options = options,
            // null terminate since we're sending it to c
            .authHeader = try fmt.allocPrint(allocator, "Authorization: {}\x00", .{options.token}),
            .curlHandle = curl_easy_init() orelse return error.CURLInitFailed,
            // copy strings so we can throw parse result away without losing parsed structures
            .jsonParser = json.Parser.init(allocator, true),
        };
    }

    pub fn deinit(self: *Self) void {
        curl_easy_cleanup(self.curlHandle);
        self.jsonParser.deinit();
        self.* = undefined;
    }

    fn getJSON(self: *Self, path: []const u8) !json.Value {
        const data = try self.get(path);
        std.debug.warn("got data: \"{}\"\n", .{data});
        const root = (try self.jsonParser.parse(data)).root;
        self.jsonParser.reset();
        if (DiscordError.fromJson(root) catch null) |err| {
            std.debug.warn("Got error: {s}\n", .{err.message});
            return error.DiscordError;
        }
        return root;
    }

    // caller owns returned memory
    fn get(self: Self, path: []const u8) ![]const u8 {
        // null terminate bcuz sending to c
        var url: []const u8 = try fmt.allocPrint(self.allocator, "{}{}\x00", .{ apiUrl, path });
        // std.debug.warn("url=\"{}\"\n", .{url});
        var buffer = try std.Buffer.initCapacity(self.allocator, 0);

        _ = curl_easy_setopt(self.curlHandle, @intToEnum(CURLoption, CURLOPT_URL), url[0..:0].ptr);
        _ = curl_easy_setopt(self.curlHandle, @intToEnum(CURLoption, CURLOPT_NOPROGRESS), @as(c_long, 1));
        if (self.options.verboseCurl) {
            _ = curl_easy_setopt(self.curlHandle, @intToEnum(CURLoption, CURLOPT_VERBOSE), @as(c_long, 1));
        }

        var cSaveBodyBufferPtr = @intToPtr(?*c_void, @ptrToInt(saveBodyToBuffer));
        _ = curl_easy_setopt(self.curlHandle, @intToEnum(CURLoption, CURLOPT_WRITEFUNCTION), @ptrCast(*c_void, cSaveBodyBufferPtr));
        _ = curl_easy_setopt(self.curlHandle, @intToEnum(CURLoption, CURLOPT_WRITEDATA), @ptrCast(*c_void, &buffer));
        _ = curl_easy_setopt(self.curlHandle, @intToEnum(CURLoption, CURLOPT_USERAGENT), self.options.userAgent[0..:0].ptr);

        var chunk: [*c]struct_curl_slist = null;
        chunk = curl_slist_append(chunk, self.authHeader[0..:0].ptr);
        _ = curl_easy_setopt(self.curlHandle, @intToEnum(CURLoption, CURLOPT_HTTPHEADER), chunk);

        const ret = @enumToInt(curl_easy_perform(self.curlHandle));
        if (ret != 0) {
            std.debug.warn("curl error: {}\n", .{ret});
            return error.CURL;
        }
        return buffer.toOwnedSlice();
    }

    pub fn get_current_user(self: *Self) !User {
        return User.fromJson(try self.getJSON("/users/@me"));
    }

    pub fn get_user(self: *Self, id: Snowflake) !User {
        return User.fromJson(try self.getJSON(try fmt.allocPrint(self.allocator, "/users/{}", .{id.id})));
    }
};
