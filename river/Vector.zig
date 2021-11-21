// This file is part of river, a dynamic tiling wayland compositor.
//
// Copyright 2021 The River Developers
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const math = std.math;
const wlr = @import("wlroots");

const Self = @This();

x: i32,
y: i32,

/// Returns the difference between two vectors.
pub fn diff(a: Self, b: Self) Self {
    return .{
        .x = b.x - a.x,
        .y = b.y - a.y,
    };
}

/// Returns the direction of the vector.
pub fn getDirection(self: Self) ?wlr.OutputLayout.Direction {
    // A zero length vector has no direction
    if (self.x == 0 and self.y == 0) return null;

    // Here we define direction mathematically as the endpoint of the vector
    // falling into one of the quadrants bounded by the two functions
    // f1: Z -> Z, x |-> x
    // f2: Z -> Z, x |-> -x
    if ((math.absInt(self.y) catch return null) > (math.absInt(self.x) catch return null)) {
        // Careful: We are still operating in the Y-inverted coordinate system
        // as everywhere else in river.
        return if (self.y > 0) .down else .up;
    }
    return if (self.x > 0) .right else .left;
}

/// Returns the length of the vector.
pub fn getLength(self: Self) usize {
    const x = math.absInt(self.x) catch math.maxInt(i32);
    const y = math.absInt(self.y) catch math.maxInt(i32);
    const x_pow_2 = @intCast(usize, math.pow(i32, x, 2));
    const y_pow_2 = @intCast(usize, math.pow(i32, y, 2));
    return math.sqrt(x_pow_2 + y_pow_2);
}
