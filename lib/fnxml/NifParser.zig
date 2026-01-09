const std = @import("std");
const beam = @import("beam");

const MAX_EVENTS: usize = 1024;
const MAX_ATTRS: usize = 64;

// Main parse function - returns {events_list, leftover_pos_or_nil, {line, col, byte}}
pub fn nif_parse(
    block: []const u8,
    prev_block: ?[]const u8,
    prev_pos: u32,
    state_line: u32,
    state_col: u32,
    state_byte: u32
) struct { beam.term, beam.term, struct { u32, u32, u32 } } {
    var line: u32 = state_line;
    var col: u32 = state_col;
    var byte_offset: u32 = state_byte;

    // For building event list
    var events: [MAX_EVENTS]beam.term = undefined;
    var event_count: usize = 0;

    // Determine input to parse
    var input: []const u8 = undefined;
    var allocated_input: ?[]u8 = null;

    if (prev_block) |prev| {
        const prev_slice = prev[prev_pos..];
        const combined = beam.allocator.alloc(u8, prev_slice.len + block.len) catch {
            return .{ beam.make(.@"error", .{}), beam.make(.nil, .{}), .{ state_line, state_col, state_byte } };
        };
        @memcpy(combined[0..prev_slice.len], prev_slice);
        @memcpy(combined[prev_slice.len..], block);
        allocated_input = combined;
        input = combined;
    } else {
        input = block;
    }
    defer if (allocated_input) |alloc| beam.allocator.free(alloc);

    var pos: usize = 0;
    var leftover_pos: ?u32 = null;
    var cr_pending: bool = false;
    const prev_slice_len: usize = if (prev_block) |prev| prev.len - prev_pos else 0;

    // Check for UTF-16 BOM at start
    if (byte_offset == 0 and input.len >= 2) {
        if ((input[0] == 0xFE and input[1] == 0xFF) or
            (input[0] == 0xFF and input[1] == 0xFE)) {
            if (event_count < MAX_EVENTS) {
                events[event_count] = beam.make(.{
                    .@"error", .utf16, .nil, .{ line, col, byte_offset }
                }, .{});
                event_count += 1;
            }
            leftover_pos = 0;
            const events_list = beam.make(events[0..event_count], .{});
            const leftover_term = beam.make(@as(u32, 0), .{});
            return .{ events_list, leftover_term, .{ line, col, byte_offset } };
        }
    }

    // Main parsing loop
    while (pos < input.len) {
        if (event_count >= MAX_EVENTS - 2) break;  // Leave room for end events

        const start_pos = pos;
        const c = input[pos];

        // Handle line ending normalization
        if (cr_pending) {
            cr_pending = false;
            if (c == '\n') {
                pos += 1;
                byte_offset += 1;
                continue;
            }
        }

        if (c == '\r') {
            cr_pending = true;
            line += 1;
            col = 0;
            pos += 1;
            byte_offset += 1;
            continue;
        }

        if (c == '\n') {
            line += 1;
            col = 0;
            pos += 1;
            byte_offset += 1;
            continue;
        }

        if (c == '<') {
            const result = parseTag(input, pos, &line, &col, &byte_offset, &events, &event_count);
            if (result.incomplete) {
                // Return position relative to current block, not combined input
                if (start_pos >= prev_slice_len) {
                    leftover_pos = @intCast(start_pos - prev_slice_len);
                } else {
                    // Leftover starts in prev_block - return 0 to indicate start of block
                    // and the prev_block handling will need to account for this
                    leftover_pos = 0;
                }
                break;
            }
            pos = result.new_pos;
        } else {
            const result = parseText(input, pos, &line, &col, &byte_offset, &events, &event_count);
            pos = result.new_pos;
        }
    }

    const events_list = beam.make(events[0..event_count], .{});
    const leftover_term = if (leftover_pos) |lp| beam.make(lp, .{}) else beam.make(.nil, .{});

    return .{ events_list, leftover_term, .{ line, col, byte_offset } };
}

const ParseResult = struct {
    new_pos: usize,
    incomplete: bool,
};

fn parseTag(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
            events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    if (start + 1 >= input.len) {
        return .{ .new_pos = start, .incomplete = true };
    }

    const next = input[start + 1];

    if (next == '/') {
        return parseEndElement(input, start, line, col, byte_offset, events, event_count);
    } else if (next == '!') {
        if (start + 3 >= input.len) {
            return .{ .new_pos = start, .incomplete = true };
        }
        if (input[start + 2] == '-' and input[start + 3] == '-') {
            return parseComment(input, start, line, col, byte_offset, events, event_count);
        } else if (start + 9 <= input.len and std.mem.eql(u8, input[start + 2 .. start + 9], "[CDATA[")) {
            return parseCData(input, start, line, col, byte_offset, events, event_count);
        } else if (start + 9 <= input.len and std.mem.eql(u8, input[start + 2 .. start + 9], "DOCTYPE")) {
            return parseDTD(input, start, line, col, byte_offset, events, event_count);
        } else {
            return skipToNextTag(input, start + 1, line, col, byte_offset, events, event_count);
        }
    } else if (next == '?') {
        return parsePI(input, start, line, col, byte_offset, events, event_count);
    } else if (isNameStartChar(next)) {
        return parseStartElement(input, start, line, col, byte_offset, events, event_count);
    } else {
        return skipToNextTag(input, start + 1, line, col, byte_offset, events, event_count);
    }
}

fn parseStartElement(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
                     events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    var pos = start + 1;
    const tag_start = pos;

    while (pos < input.len and isNameChar(input[pos])) {
        pos += 1;
    }
    if (pos >= input.len) {
        return .{ .new_pos = start, .incomplete = true };
    }

    const tag_name = input[tag_start..pos];

    while (pos < input.len and isWhitespace(input[pos])) {
        pos += 1;
    }
    if (pos >= input.len) {
        return .{ .new_pos = start, .incomplete = true };
    }

    // Parse attributes
    var attrs: [MAX_ATTRS]beam.term = undefined;
    var attr_count: usize = 0;
    var has_duplicate = false;
    var attr_names: [MAX_ATTRS][]const u8 = undefined;

    while (pos < input.len and input[pos] != '>' and input[pos] != '/') {
        while (pos < input.len and isWhitespace(input[pos])) {
            pos += 1;
        }
        if (pos >= input.len) {
            return .{ .new_pos = start, .incomplete = true };
        }
        if (input[pos] == '>' or input[pos] == '/') break;

        const attr_name_start = pos;
        while (pos < input.len and isNameChar(input[pos])) {
            pos += 1;
        }
        if (pos >= input.len) {
            return .{ .new_pos = start, .incomplete = true };
        }

        const attr_name = input[attr_name_start..pos];

        // Check duplicate
        for (attr_names[0..attr_count]) |existing| {
            if (std.mem.eql(u8, existing, attr_name)) {
                has_duplicate = true;
                break;
            }
        }
        if (attr_count < MAX_ATTRS) {
            attr_names[attr_count] = attr_name;
        }

        while (pos < input.len and isWhitespace(input[pos])) {
            pos += 1;
        }
        if (pos >= input.len or input[pos] != '=') {
            return .{ .new_pos = start, .incomplete = true };
        }
        pos += 1;

        while (pos < input.len and isWhitespace(input[pos])) {
            pos += 1;
        }
        if (pos >= input.len) {
            return .{ .new_pos = start, .incomplete = true };
        }

        const quote = input[pos];
        if (quote != '"' and quote != '\'') {
            return skipToNextTag(input, pos, line, col, byte_offset, events, event_count);
        }
        pos += 1;

        const attr_val_start = pos;
        while (pos < input.len and input[pos] != quote) {
            pos += 1;
        }
        if (pos >= input.len) {
            return .{ .new_pos = start, .incomplete = true };
        }

        const attr_val = input[attr_val_start..pos];
        pos += 1;

        if (attr_count < MAX_ATTRS) {
            attrs[attr_count] = beam.make(.{ attr_name, attr_val }, .{});
            attr_count += 1;
        }
    }

    if (pos >= input.len) {
        return .{ .new_pos = start, .incomplete = true };
    }

    var self_closing = false;
    if (input[pos] == '/') {
        self_closing = true;
        pos += 1;
        if (pos >= input.len or input[pos] != '>') {
            return .{ .new_pos = start, .incomplete = true };
        }
    }

    if (input[pos] != '>') {
        return .{ .new_pos = start, .incomplete = true };
    }
    pos += 1;

    // Emit duplicate attribute error
    if (has_duplicate and event_count.* < MAX_EVENTS) {
        events[event_count.*] = beam.make(.{
            .@"error", .attr_unique, .nil, .{ line.*, col.*, byte_offset.* }
        }, .{});
        event_count.* += 1;
    }

    // Emit start element
    if (event_count.* < MAX_EVENTS) {
        events[event_count.*] = beam.make(.{
            .start_element, tag_name, attrs[0..attr_count], .{ line.*, col.*, byte_offset.* }
        }, .{});
        event_count.* += 1;
    }

    const len: u32 = @intCast(pos - start);
    col.* += len;
    byte_offset.* += len;

    // Emit end element for self-closing
    if (self_closing and event_count.* < MAX_EVENTS) {
        events[event_count.*] = beam.make(.{
            .end_element, tag_name, .{ line.*, col.*, byte_offset.* }
        }, .{});
        event_count.* += 1;
    }

    return .{ .new_pos = pos, .incomplete = false };
}

fn parseEndElement(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
                   events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    var pos = start + 2;
    const tag_start = pos;

    while (pos < input.len and isNameChar(input[pos])) {
        pos += 1;
    }
    if (pos >= input.len) {
        return .{ .new_pos = start, .incomplete = true };
    }

    const tag_name = input[tag_start..pos];

    while (pos < input.len and isWhitespace(input[pos])) {
        pos += 1;
    }
    if (pos >= input.len or input[pos] != '>') {
        return .{ .new_pos = start, .incomplete = true };
    }
    pos += 1;

    if (event_count.* < MAX_EVENTS) {
        events[event_count.*] = beam.make(.{
            .end_element, tag_name, .{ line.*, col.*, byte_offset.* }
        }, .{});
        event_count.* += 1;
    }

    const len: u32 = @intCast(pos - start);
    col.* += len;
    byte_offset.* += len;

    return .{ .new_pos = pos, .incomplete = false };
}

fn parseComment(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
                events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    var pos = start + 4;
    const content_start = pos;
    var has_double_dash = false;

    while (pos + 2 < input.len) {
        if (input[pos] == '-' and input[pos + 1] == '-') {
            if (input[pos + 2] == '>') {
                const content = input[content_start..pos];
                if (event_count.* < MAX_EVENTS) {
                    events[event_count.*] = beam.make(.{
                        .comment, content, .{ line.*, col.*, byte_offset.* }
                    }, .{});
                    event_count.* += 1;
                }

                if (has_double_dash and event_count.* < MAX_EVENTS) {
                    events[event_count.*] = beam.make(.{
                        .@"error", .comment, .nil, .{ line.*, col.*, byte_offset.* }
                    }, .{});
                    event_count.* += 1;
                }

                pos += 3;
                const len: u32 = @intCast(pos - start);
                col.* += len;
                byte_offset.* += len;
                return .{ .new_pos = pos, .incomplete = false };
            } else {
                has_double_dash = true;
            }
        }
        if (input[pos] == '\n') {
            line.* += 1;
            col.* = 0;
        } else {
            col.* += 1;
        }
        byte_offset.* += 1;
        pos += 1;
    }

    return .{ .new_pos = start, .incomplete = true };
}

fn parseCData(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
              events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    var pos = start + 9;
    const content_start = pos;

    while (pos + 2 < input.len) {
        if (input[pos] == ']' and input[pos + 1] == ']' and input[pos + 2] == '>') {
            const content = input[content_start..pos];
            if (event_count.* < MAX_EVENTS) {
                events[event_count.*] = beam.make(.{
                    .cdata, content, .{ line.*, col.*, byte_offset.* }
                }, .{});
                event_count.* += 1;
            }

            pos += 3;
            const len: u32 = @intCast(pos - start);
            col.* += len;
            byte_offset.* += len;
            return .{ .new_pos = pos, .incomplete = false };
        }
        if (input[pos] == '\n') {
            line.* += 1;
            col.* = 0;
        } else {
            col.* += 1;
        }
        byte_offset.* += 1;
        pos += 1;
    }

    return .{ .new_pos = start, .incomplete = true };
}

fn parseDTD(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
            events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    var pos = start + 9;
    var depth: u32 = 1;
    var in_bracket: bool = false;

    while (pos < input.len and depth > 0) {
        const c = input[pos];
        if (c == '[') {
            in_bracket = true;
        } else if (c == ']') {
            in_bracket = false;
        } else if (!in_bracket) {
            if (c == '<') depth += 1;
            if (c == '>') depth -= 1;
        }

        if (c == '\n') {
            line.* += 1;
            col.* = 0;
        } else {
            col.* += 1;
        }
        byte_offset.* += 1;
        pos += 1;
    }

    if (depth > 0) {
        return .{ .new_pos = start, .incomplete = true };
    }

    const content = input[start..pos];
    if (event_count.* < MAX_EVENTS) {
        events[event_count.*] = beam.make(.{
            .dtd, content, .{ line.*, col.*, byte_offset.* }
        }, .{});
        event_count.* += 1;
    }

    return .{ .new_pos = pos, .incomplete = false };
}

fn parsePI(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
           events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    var pos = start + 2;
    const target_start = pos;

    while (pos < input.len and isNameChar(input[pos])) {
        pos += 1;
    }
    if (pos >= input.len) {
        return .{ .new_pos = start, .incomplete = true };
    }

    const target = input[target_start..pos];

    while (pos < input.len and isWhitespace(input[pos])) {
        pos += 1;
    }

    const data_start = pos;
    while (pos + 1 < input.len) {
        if (input[pos] == '?' and input[pos + 1] == '>') {
            const data = if (data_start < pos) input[data_start..pos] else "";

            if (std.mem.eql(u8, target, "xml")) {
                if (event_count.* < MAX_EVENTS) {
                    events[event_count.*] = beam.make(.{
                        .start_document, .{ line.*, col.*, byte_offset.* }
                    }, .{});
                    event_count.* += 1;
                }
            } else {
                if (event_count.* < MAX_EVENTS) {
                    events[event_count.*] = beam.make(.{
                        .processing_instruction, target, data, .{ line.*, col.*, byte_offset.* }
                    }, .{});
                    event_count.* += 1;
                }
            }

            pos += 2;
            const len: u32 = @intCast(pos - start);
            col.* += len;
            byte_offset.* += len;
            return .{ .new_pos = pos, .incomplete = false };
        }
        if (input[pos] == '\n') {
            line.* += 1;
            col.* = 0;
        } else {
            col.* += 1;
        }
        byte_offset.* += 1;
        pos += 1;
    }

    return .{ .new_pos = start, .incomplete = true };
}

fn parseText(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
             events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    var pos = start;
    var all_whitespace = true;
    const text_line = line.*;
    const text_col = col.*;
    const text_byte = byte_offset.*;

    while (pos < input.len and input[pos] != '<') {
        const c = input[pos];
        if (!isWhitespace(c)) {
            all_whitespace = false;
        }
        if (c == '\n') {
            line.* += 1;
            col.* = 0;
        } else {
            col.* += 1;
        }
        byte_offset.* += 1;
        pos += 1;
    }

    if (pos > start and event_count.* < MAX_EVENTS) {
        const content = input[start..pos];
        if (all_whitespace) {
            events[event_count.*] = beam.make(.{
                .space, content, .{ text_line, text_col, text_byte }
            }, .{});
        } else {
            events[event_count.*] = beam.make(.{
                .characters, content, .{ text_line, text_col, text_byte }
            }, .{});
        }
        event_count.* += 1;
    }

    return .{ .new_pos = pos, .incomplete = false };
}

fn skipToNextTag(input: []const u8, start: usize, line: *u32, col: *u32, byte_offset: *u32,
                 events: *[MAX_EVENTS]beam.term, event_count: *usize) ParseResult {
    if (event_count.* < MAX_EVENTS) {
        events[event_count.*] = beam.make(.{
            .@"error", .invalid_name, .nil, .{ line.*, col.*, byte_offset.* }
        }, .{});
        event_count.* += 1;
    }

    var pos = start;
    while (pos < input.len and input[pos] != '<') {
        if (input[pos] == '\n') {
            line.* += 1;
            col.* = 0;
        } else {
            col.* += 1;
        }
        byte_offset.* += 1;
        pos += 1;
    }

    return .{ .new_pos = pos, .incomplete = false };
}

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}

fn isNameStartChar(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_' or c == ':';
}

fn isNameChar(c: u8) bool {
    return isNameStartChar(c) or (c >= '0' and c <= '9') or c == '-' or c == '.';
}
