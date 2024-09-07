pub fn grow_capacity(cap: usize) -> usize {
    if cap < 8 {
        return 8;
    }
    cap * 2
}
