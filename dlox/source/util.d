module util;

size_t growCapacity(size_t current_cap) {
    if (current_cap < 8) return 8;
    return current_cap * 2;
}
