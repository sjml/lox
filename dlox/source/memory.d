module memory;

import core.exception : OutOfMemoryError;
static import core.stdc.stdlib;
static import core.stdc.string;

void collectGarbage() {

}

void* reallocate(void* pointer, size_t oldSize, size_t newSize) {
    if (newSize == 0) {
        core.stdc.stdlib.free(pointer);
        return null;
    }

    void* res = core.stdc.stdlib.realloc(pointer, newSize);
    if (res == null) {
        throw new OutOfMemoryError();
    }
    return res;
}

void clear(void* pointer, size_t size) {
    core.stdc.string.memset(pointer, 0x0, size);
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

