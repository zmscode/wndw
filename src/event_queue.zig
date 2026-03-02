/// Platform-agnostic event queue — fixed-capacity circular buffer.
///
/// Used internally by each platform backend to buffer OS events between
/// calls to `Window.poll()`. The queue sits inside the `Window` struct
/// (no heap allocation) and holds up to `QUEUE_CAP - 1` events.
///
/// On overflow the newest event is silently dropped; already-queued events
/// are preserved. This keeps the queue lock-free and bounded — important
/// because OS delegate callbacks can fire at any time during event draining.
const event = @import("event.zig");
pub const Event = event.Event;

/// Maximum number of events the ring buffer can hold (actual capacity
/// is `QUEUE_CAP - 1` due to the sentinel slot distinguishing full vs empty).
pub const QUEUE_CAP = 128;

pub const EventQueue = struct {
    /// Fixed-size ring buffer storage. Only indices `[head..tail)` (mod CAP)
    /// contain valid events.
    buf: [QUEUE_CAP]Event = undefined,
    /// Index of the oldest event (next to be popped).
    head: usize = 0,
    /// Index of the next free slot (next to be written).
    tail: usize = 0,

    /// Enqueue an event. If the buffer is full the event is silently dropped
    /// rather than overwriting older events — this matches the principle that
    /// the user should see events in order, even if some are lost.
    pub fn push(q: *EventQueue, ev: Event) void {
        const next = (q.tail + 1) % QUEUE_CAP;
        if (next == q.head) return; // full — drop newest
        q.buf[q.tail] = ev;
        q.tail = next;
    }

    /// Dequeue the oldest event, or return `null` if the queue is empty.
    pub fn pop(q: *EventQueue) ?Event {
        if (q.head == q.tail) return null;
        const ev = q.buf[q.head];
        q.head = (q.head + 1) % QUEUE_CAP;
        return ev;
    }

    /// Returns `true` when there are no queued events.
    pub fn isEmpty(q: *const EventQueue) bool {
        return q.head == q.tail;
    }

    /// Number of events currently queued (0 to `QUEUE_CAP - 1`).
    pub fn len(q: *const EventQueue) usize {
        return (q.tail + QUEUE_CAP - q.head) % QUEUE_CAP;
    }
};
