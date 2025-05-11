const std = @import("std");

var m = std.Thread.Mutex{};

pub fn main() !void {
  const addr = try std.net.Address.parseIp("127.0.0.1", 4242);
  var server: std.net.Server = try std.net.Address.listen(addr, .{ .reuse_address = true, .reuse_port = true });

  std.debug.print("Server up and running !\n", .{});

  // Thread pool
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();
  const allocator = gpa.allocator();
  var pool: std.Thread.Pool = undefined;
  try pool.init(.{ .allocator = allocator });
  defer pool.deinit();

  while (true) {
      handleClient(&server);
      try pool.spawn(handleClient, .{&server});
  }
}

// Accept new clients in the spawned thread
fn handleClient(server: *std.net.Server) void {
  const conn = server.*.accept() catch {
      std.debug.print("Error while accepting a new client\n", .{});
      return;
  }; // Blocking call
  var buffer: [1024]u8 = undefined; // Buffer size does not affect performance
  var http_server_with_client = std.http.Server.init(conn, &buffer);
  defer conn.stream.close();

  // Simulate work
  std.time.sleep(1 * std.time.ns_per_ms);

  while (http_server_with_client.state == .ready) {
      // Read request
      var req = http_server_with_client.receiveHead() catch |err| switch (err) { // Blocking call
          error.HttpConnectionClosing => break,
          else => {
              std.debug.print("Unhandled error {any}\n", .{err});
              return;
          },
      };

      _ = req.reader() catch |err| {
          std.debug.print("Error while reading request: {any}\n", .{err});
          return;
      };

      // Send response
      req.respond("bonjour", .{}) catch |err| {
          std.debug.print("Error while sending response: {any}\n", .{err});
          return;
      };
  }
}

