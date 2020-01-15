const std = @import("std");
const json = std.json;

pub const Snowflake = struct {
    id: i64,

    // this is used because discord sends snowflakes as strings to
    // bypass integer overflow
    fn from_json(obj: json.Value) !Snowflake {
        if (obj != .String) return error.ExpectingString;
        return Snowflake{
            .id = try std.fmt.parseInt(i64, obj.String, 10),
        };
    }
};

pub const User = struct {
    id: Snowflake,
    username: []const u8,
    avatar: ?[]const u8 = null,
    discriminator: []const u8,
    email: ?[]const u8 = null,
    is_verified: ?bool = null,
    locale: ?[]const u8 = null,
    is_bot: ?bool = null,
    is_system: ?bool = null,
    is_mfa_enabled: ?bool = null,
    phone: ?[]const u8 = null,
    flags: ?i64 = null,

    const PremiumType = enum {
        NitroClassic,
        Nitro,

        fn from_json(obj: json.Value) !PremiumType {
            if (obj != .Integer) return error.ExpectingInteger;
            switch (obj.Integer) {
                1 => return .NitroClassic,
                2 => return .Nitro,
                else => return error.UnexpectedValue,
            }
        }
    };
    premium_type: ?PremiumType = null,

    // CHORE(haze): extra safe checks
    pub fn from_json(obj: json.Value) !User {
        if (obj != .Object) return error.NotAnObject;
        var user = User{
            .id = try Snowflake.from_json((obj.Object.getValue("id") orelse return error.MissingId)),
            .username = (obj.Object.getValue("username") orelse return error.MissingUsername).String,
            .discriminator = (obj.Object.getValue("discriminator") orelse return error.MissingDiscriminator).String,
        };
        if (obj.Object.getValue("is_bot")) |bot| {
            user.is_bot = bot.Bool;
        }
        if (obj.Object.getValue("is_verified")) |verified| {
            user.is_verified = verified.Bool;
        }
        if (obj.Object.getValue("is_system")) |system| {
            user.is_system = system.Bool;
        }
        if (obj.Object.getValue("is_mfa_enabled")) |mfa_enabled| {
            user.is_mfa_enabled = mfa_enabled.Bool;
        }
        if (obj.Object.getValue("email")) |_email| {
            user.email = _email.String;
        }
        if (obj.Object.getValue("premium_type")) |prem_type| {
            user.premium_type = try PremiumType.from_json(prem_type);
        }
        return user;
    }
};
