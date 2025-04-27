const std = @import("std");
const assert = std.debug.assert;

pub const std_options: std.Options = .{
    .log_level = .info,
};

pub fn main() !void {
    const gpa = std.heap.smp_allocator;
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    if (args.len != 4) {
        failWithUsage(args[0]);
    }

    std.log.info("opening input file", .{});
    const file_in = try std.fs.cwd().openFile(args[1], .{});
    defer file_in.close();

    std.log.info("parsing count", .{});
    const count: usize = try std.fmt.parseInt(u32, args[2], 10);
    const raw_count = 91 * count;

    std.log.info("creating output file", .{});
    const file_out = try std.fs.cwd().createFile(args[3], .{});
    defer file_out.close();

    std.log.info("allocating raw sudoku input buffer", .{});
    const puzzles_raw_in: []u8 = try gpa.alloc(u8, raw_count);
    defer gpa.free(puzzles_raw_in);

    std.log.info("allocating raw sudoku output buffer", .{});
    const puzzles_raw_out: []u8 = try gpa.alloc(u8, raw_count);
    defer gpa.free(puzzles_raw_out);

    std.log.info("loading in all raw sudoku boards", .{});
    const read_count = try file_in.readAll(puzzles_raw_in);
    assert(read_count == raw_count);

    std.log.info("solving puzzles", .{});
    const start = std.time.nanoTimestamp();

    // working grid for output puzzles
    var grid: [81]u8 = undefined;
    for (0..count) |puzzle| {
        const file_offset = puzzle * 91;

        // load the puzzle
        var input: [81]u8 = undefined;
        for (0..9) |row| {
            for (0..9) |col| {
                const buf_offset = col + row * 9;
                // include an extra byte for each row newline
                const raw_offset = file_offset + buf_offset + row;
                input[buf_offset] = puzzles_raw_in[raw_offset] - '0';
            }
        }

        // solve the puzzle
        const is_solved = solve(&input, &grid);
        assert(is_solved);

        // store the puzzle
        var out_idx: usize = file_offset;
        for (0..9) |row| {
            for (0..9) |col| {
                const buf_offset = col + row * 9;
                const raw_offset = out_idx + col;
                puzzles_raw_out[raw_offset] = grid[buf_offset] + '0';
            }
            // include an extra byte for the row newline
            puzzles_raw_out[out_idx + 9] = '\n';
            out_idx += 10;
        }
        // include an extra byte for the grid newline
        puzzles_raw_out[file_offset + 90] = '\n';
    }

    const end = std.time.nanoTimestamp();
    const elapsed = end - start;
    std.log.info("Elapsed time: {} ns", .{elapsed});

    std.log.info("writing solved puzzles", .{});
    try file_out.writeAll(puzzles_raw_out);
}

fn failWithUsage(program: []const u8) noreturn {
    std.debug.print(
        \\Usage: {s} PUZZLES_IN COUNT PUZZLES_OUT
        \\
        \\Where PUZZLES_IN is a file containing sudoku puzzles,
        \\0 replacing "unknown" digits, split into grids of 9x9 cells,
        \\with a single newline separating each grid, line, respectively.
        \\
        \\Where COUNT is an unsigned 32 bit base-10 integer representing
        \\the number of puzzles to solve, which the file PUZZLES_IN must
        \\cointain at the least.
        \\
        \\Where PUZZLES_OUT is the file to write the solved puzzles.
        \\
    , .{program});
    std.process.exit(1);
}

// Backtracking sudoku solver -
fn solve(initial: *const [81]u8, state: *[81]u8) bool {
    state.* = initial.*;
    var current: u32 = 0;

    while (true) {
        for (0..current) |idx| {
            const cell = state[idx];
            assert(cell >= 1 and cell <= 9);
        }

        while (check(state, current)) {
            // search for a cell we can change
            while (state[current] != 0) {
                if (current == 80) {
                    return true;
                } else {
                    current += 1;
                }
            }

            state[current] = 9;
        }

        backtrack: while (true) {
            // skip back to a cell we can change
            while (initial[current] != 0) {
                if (current == 0) {
                    for (0..81) |idx| {
                        assert(state[idx] == initial[idx]);
                    }
                    return false;
                } else {
                    current -= 1;
                }
            }

            // change the cell
            assert(initial[current] == 0);
            assert(state[current] != 0);
            state[current] -= 1;

            // make sure we are in a stable state
            if (state[current] == 0) {
                if (current == 0) {
                    for (0..81) |idx| {
                        assert(state[idx] == initial[idx]);
                    }
                    return false;
                } else {
                    current -= 1;
                }
            } else {
                break :backtrack;
            }
        }
    }
}

// return true on success - skip cells == 0
fn check(grid: *const [81]u8, idx: u32) bool {
    if (grid[idx] == 0) return true;
    return rows(grid, idx) and cols(grid, idx) and blocks(grid, idx);
}

fn rows(grid: *const [81]u8, idx: u32) bool {
    const row = idx / 9;
    const col = idx % 9;

    for (0..9) |cmp| {
        if (cmp == col) continue;
        const cmp_idx = cmp + row * 9;
        if (grid[idx] == grid[cmp_idx]) {
            return false;
        }
    }

    return true;
}

fn cols(grid: *const [81]u8, idx: u32) bool {
    const row = idx / 9;
    const col = idx % 9;

    for (0..9) |cmp| {
        if (cmp == row) continue;
        const cmp_idx = col + cmp * 9;
        if (grid[idx] == grid[cmp_idx]) {
            return false;
        }
    }

    return true;
}

fn blocks(grid: *const [81]u8, idx: u32) bool {
    const block_row = (idx / 9) / 3;
    const block_col = (idx % 9) / 3;

    for (0..3) |cmp_row_off| {
        for (0..3) |cmp_col_off| {
            const cmp_row = cmp_row_off + block_row * 3;
            const cmp_col = cmp_col_off + block_col * 3;
            const cmp_idx = cmp_col + cmp_row * 9;
            if (cmp_idx == idx) continue;
            if (grid[idx] == grid[cmp_idx]) {
                return false;
            }
        }
    }

    return true;
}
