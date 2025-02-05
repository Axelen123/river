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

const server = &@import("../main.zig").server;

const Direction = @import("../command.zig").Direction;
const Error = @import("../command.zig").Error;
const Seat = @import("../Seat.zig");
const View = @import("../View.zig");
const ViewStack = @import("../view_stack.zig").ViewStack;
const wlr = @import("wlroots");

/// Focus either the next or the previous visible view, depending on the enum
/// passed. Does nothing if there are 1 or 0 views in the stack.
pub fn focusView(
    _: std.mem.Allocator,
    seat: *Seat,
    args: []const [:0]const u8,
    _: *?[]const u8,
) Error!void {
    if (args.len < 2) return Error.NotEnoughArguments;
    if (args.len > 2) return Error.TooManyArguments;

    if (try getView(seat, args[1], false)) |view| {
        seat.focus(view);
        server.root.startTransaction();
    }
}

/// Swap the currently focused view another in the visible stack, based either
/// on logical or physical direction.
pub fn swap(
    _: std.mem.Allocator,
    seat: *Seat,
    args: []const [:0]const u8,
    _: *?[]const u8,
) Error!void {
    if (args.len < 2) return Error.NotEnoughArguments;
    if (args.len > 2) return Error.TooManyArguments;

    if (try getView(seat, args[1], true)) |view| {
        const output = seat.focused_output;
        const focused_node = @fieldParentPtr(ViewStack(View).Node, "view", seat.focused.view);
        const swap_node = @fieldParentPtr(ViewStack(View).Node, "view", view);
        output.views.swap(focused_node, swap_node);
        output.arrangeViews();
        server.root.startTransaction();
    }
}

fn getView(seat: *Seat, str: []const u8, comptime only_layout: bool) !?*View {
    const output = seat.focused_output;

    // If No currently no view is focused , just focus the first in the stack.
    if (seat.focused != .view) {
        var it = ViewStack(View).iter(output.views.first, .forward, output.pending.tags, Filter(only_layout).filter);
        return it.next();
    }

    if (only_layout and seat.focused.view.pending.float) return null;

    // If the focused view is fullscreen, do nothing
    if (seat.focused.view.current.fullscreen) return null;

    if (std.meta.stringToEnum(Direction, str)) |direction| { // Logical directoin
        // Focus the next visible view in the stack.
        const focused_node = @fieldParentPtr(ViewStack(View).Node, "view", seat.focused.view);
        var it = switch (direction) {
            .next => ViewStack(View).iter(focused_node, .forward, output.pending.tags, Filter(only_layout).filter),
            .previous => ViewStack(View).iter(focused_node, .reverse, output.pending.tags, Filter(only_layout).filter),
        };

        // Skip past the focused node
        _ = it.next();

        // Focus the next visible node if there is one.
        if (it.next()) |view| return view;

        // If there is no next visible node, we need to wrap.
        it = switch (direction) {
            .next => ViewStack(View).iter(output.views.first, .forward, output.pending.tags, Filter(only_layout).filter),
            .previous => ViewStack(View).iter(output.views.last, .reverse, output.pending.tags, Filter(only_layout).filter),
        };
        if (it.next()) |view| return view;

        return null;
    } else if (std.meta.stringToEnum(wlr.OutputLayout.Direction, str)) |direction| { // Spacial direction
        var ret: ?*View = null;
        const focus_center = seat.focused.view.current.box.getCenter();
        var closeness: usize = std.math.maxInt(usize);
        var it = ViewStack(View).iter(output.views.first, .forward, output.pending.tags, Filter(only_layout).filter);
        while (it.next()) |view| {
            if (view == seat.focused.view) continue;
            const diff_vector = focus_center.diff(view.current.box.getCenter());
            if ((diff_vector.getDirection() orelse continue) != direction) continue;
            const len = diff_vector.getLength();
            if (len >= closeness) continue;
            closeness = len;
            ret = view;
        }
        return ret;
    } else {
        return Error.InvalidDirection;
    }
}

fn Filter(comptime only_layout: bool) type {
    return struct {
        fn filter(view: *View, filter_tags: u32) bool {
            if (comptime only_layout) {
                return view.surface != null and !view.pending.float and
                    !view.pending.fullscreen and view.pending.tags & filter_tags != 0;
            } else {
                return view.surface != null and view.pending.tags & filter_tags != 0;
            }
        }
    };
}
