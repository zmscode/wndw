/// Platform-agnostic event queue — fixed-capacity circular buffer.
///
/// Capacity is 128 events. On overflow the newest event is silently dropped;
/// already-queued events are preserved.
const event = @import("event.zig");
pub const Event = event.Event;

pub const QUEUE_CAP = 128;

pub const EventQueue = struct {
    buf: [QUEUE_CAP]Event = undefined,
    head: usize = 0,
    tail: usize = 0,

    pub fn push(q: *EventQueue, ev: Event) void {
        const next = (q.tail + 1) % QUEUE_CAP;
        if (next == q.head) return; // drop on overflow
        q.buf[q.tail] = ev;
        q.tail = next;
    }

    pub fn pop(q: *EventQueue) ?Event {
        if (q.head == q.tail) return null;
        const ev = q.buf[q.head];
        q.head = (q.head + 1) % QUEUE_CAP;
        return ev;
    }

    pub fn isEmpty(q: *const EventQueue) bool {
        return q.head == q.tail;
    }

    /// Number of events currently queued.
    pub fn len(q: *const EventQueue) usize {
        return (q.tail + QUEUE_CAP - q.head) % QUEUE_CAP;
    }
};
