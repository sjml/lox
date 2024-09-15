module memory;

import core.exception : OutOfMemoryError;
import core.memory : GC;

// TODO: use memset to clear out memory (search for "calloc")

void collectGarbage() {

}

void* reallocate(void* pointer, size_t oldSize, size_t newSize) {
    if (newSize == 0) {
        GC.free(pointer);
        return null;
    }

    void* res = GC.realloc(pointer, newSize); // throws on OutOfMemory
    return res;
}

void free(T)(void* pointer) {
    reallocate(pointer, T.sizeof, 0);
}

void freeArray(T)(void* pointer, size_t oldCount) {
    reallocate(pointer, T.sizeof * oldCount, 0);
}

size_t growCapacity(size_t currentCap)
{
    if (currentCap < 8)
        return 8;
    return currentCap * 2;
}

