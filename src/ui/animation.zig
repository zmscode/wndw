// ── Animation ────────────────────────────────────────────────────────
//
// Simple tween animation: interpolates a f32 from → to over a duration,
// using a configurable easing function.

const std = @import("std");

pub const EasingFn = *const fn (f32) f32;

pub const Easing = struct {
    /// Linear interpolation — constant speed.
    pub fn linear(t: f32) f32 {
        return t;
    }

    /// Quadratic ease-in — starts slow, accelerates.
    pub fn ease_in(t: f32) f32 {
        return t * t;
    }

    /// Quadratic ease-out — starts fast, decelerates.
    pub fn ease_out(t: f32) f32 {
        return t * (2 - t);
    }

    /// Quadratic ease-in-out — slow start and end.
    pub fn ease_in_out(t: f32) f32 {
        if (t < 0.5) {
            return 2 * t * t;
        } else {
            return -1 + (4 - 2 * t) * t;
        }
    }
};

pub const Animation = struct {
    from: f32,
    to: f32,
    duration: f32,
    easing: EasingFn,
    progress: f32 = 0,

    pub fn init(from: f32, to: f32, duration: f32, easing: EasingFn) Animation {
        return .{
            .from = from,
            .to = to,
            .duration = duration,
            .easing = easing,
        };
    }

    /// Advance the animation by dt seconds.
    pub fn advance(self: *Animation, dt: f32) void {
        self.progress = @min(self.progress + dt / self.duration, 1.0);
    }

    /// Get the current interpolated value.
    pub fn value(self: Animation) f32 {
        const t = self.easing(self.progress);
        return self.from + (self.to - self.from) * t;
    }

    /// Returns true when the animation has completed.
    pub fn isFinished(self: Animation) bool {
        return self.progress >= 1.0;
    }
};
