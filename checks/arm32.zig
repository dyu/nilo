//! Compile check for 32-bit targets (`zig build check-arm32`): a program that reaches the whole call
//! path of nilo_fetch (whole-body calls, a streamed answer, a chunked upload), so that code which does
//! not build on arm-linux-musleabihf (64-bit atomics, struct alignment) is analysed. Built, never run.
const std = @import("std");
const fetch = @import("nilo_fetch");
const core = @import("nilo_core");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    var threaded: std.Io.Threaded = .init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var client: fetch.Client = .init(gpa, .{ .max_in_flight = 1, .timeout_ms = 0, .stall_ms = 10_000 });
    defer client.deinit();
    try client.nilo_start(io, .none);
    var scope: core.Run = .init(gpa);
    defer scope.deinit();

    const got = try client.get(&scope, "https://example.com/", .{});
    const posted = try client.post(&scope, "https://example.com/", "{}", .{});

    var ex: fetch.Exchange = .idle;
    defer ex.end();
    _ = try ex.begin(&client, .{ .method = .GET, .url = "https://example.com/big" });
    var sink: std.Io.Writer.Discarding = .init(&.{});
    _ = try ex.pipe(&sink.writer);

    var up: fetch.Exchange.Upload = .{};
    var ex2: fetch.Exchange = .idle;
    defer ex2.end();
    try ex2.beginUpload(&client, &scope, &up, .{ .method = .POST, .url = "https://example.com/up" }, null);
    defer up.deinit();
    try up.writer().writeAll("x");
    _ = try up.end();

    std.debug.print("{d} {d}\n", .{ @intFromEnum(got.status), @intFromEnum(posted.status) });
}
