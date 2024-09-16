module memory;

import std.stdio;
import core.exception : OutOfMemoryError;
static import core.stdc.stdlib;
static import core.stdc.string;

import vm : VM;
import compiler : Compiler;
import value;
import lobj;
import table;

static const size_t GC_HEAP_GROW_FACTOR = 2;

void collectGarbage() {
    version (DebugLogGC) {
        writeln("-- gc begin");
        size_t before = VM.instance.bytesAllocated;
    }

    markRoots();
    traceReferences();
    VM.instance.strings.removeWhite();
    sweep();

    VM.instance.nextGC = VM.instance.bytesAllocated * GC_HEAP_GROW_FACTOR;

    version (DebugLogGC) {
        writeln("-- gc end");
        writefln("   collected %u bytes (from %u to %u) next at %u",
                before - VM.instance.bytesAllocated, before,
                VM.instance.bytesAllocated, VM.instance.nextGC);
    }
}

void markRoots() {
    for (Value* slot = &VM.instance.stack[0]; slot < VM.instance.stackTop; slot++) {
        markValue(*slot);
    }

    for (size_t i; i < VM.instance.frameCount; i++) {
        markObject(&VM.instance.frames[i].closure.obj);
    }

    for (ObjUpvalue* upv = VM.instance.openUpvalues; upv != null; upv = upv.next) {
        markObject(&upv.obj);
    }

    markTable(&VM.instance.globals);

    markCompilerRoots();
    markObject(&VM.instance.initString.obj);
}

void markValue(Value val) {
    if (val.isObj()) {
        markObject(val.obj);
    }
}

void markArray(ValueArray* arr) {
    for (size_t i = 0; i < arr.count; i++) {
        markValue(arr.values[i]);
    }
}

void markObject(Obj* obj) {
    if (obj == null) {
        return;
    }
    if (obj.isMarked) {
        return;
    }
    version (DebugLogGC) {
        writefln("%x mark ", obj);
        Value(obj).print();
        writeln("");
    }
    obj.isMarked = true;

    if (VM.instance.grayCapacity < VM.instance.grayCount + 1) {
        VM.instance.grayCapacity = growCapacity(VM.instance.grayCapacity);
        VM.instance.grayStack = cast(Obj**) core.stdc.stdlib.realloc(VM.instance.grayStack,
                (Obj*).sizeof * VM.instance.grayCapacity);
        if (VM.instance.grayStack == null) {
            throw new OutOfMemoryError();
        }
    }
    VM.instance.grayStack[VM.instance.grayCount++] = obj;
}

void markTable(Table* tab) {
    // TODO: why is this looking at capacity instead of count?
    for (size_t i = 0; i < tab.entries.length; i++) {
        Entry* entry = &tab.entries[i];
        markObject(&entry.key.obj);
        markValue(entry.value);
    }
}

void markCompilerRoots() {
    Compiler* compiler = VM.instance.currentCompiler;
    while (compiler != null) {
        markObject(&compiler.fn.obj);
        compiler = compiler.enclosing;
    }
}

void* reallocate(void* pointer, size_t oldSize, size_t newSize) {
    VM.instance.bytesAllocated += newSize - oldSize;
    if (newSize > oldSize) {
        version (DebugStressGC) {
            collectGarbage();
        }
    }
    if (VM.instance.bytesAllocated > VM.instance.nextGC) {
        collectGarbage();
    }

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

void traceReferences() {
    while (VM.instance.grayCount > 0) {
        Obj* obj = VM.instance.grayStack[--VM.instance.grayCount];
        blackenObject(obj);
    }
}

void blackenObject(Obj* obj) {
    version (DebugLogGC) {
        writef("%x blacken ", obj);
        Value(obj).print();
        writeln("");
    }

    switch (obj.objType) {
    case ObjType.BoundMethod:
        ObjBoundMethod* bm = obj.as!ObjBoundMethod();
        markValue(bm.receiver);
        markObject(&bm.method.obj);
        break;
    case ObjType.Class:
        ObjClass* k = obj.as!ObjClass();
        markObject(&k.name.obj);
        markTable(&k.methods);
        break;
    case ObjType.Instance:
        ObjInstance* oi = obj.as!ObjInstance();
        markObject(&oi.klass.obj);
        markTable(&oi.fields);
        break;
    case ObjType.Closure:
        ObjClosure* cl = obj.as!ObjClosure();
        markObject(&cl.fn.obj);
        for (size_t i = 0; i < cl.upvalueCount; i++) {
            markObject(&cl.upvalues[i].obj);
        }
        break;
    case ObjType.Function:
        ObjFunction* fn = obj.as!ObjFunction();
        markObject(&fn.name.obj);
        markArray(&fn.c.constants);
        break;
    case ObjType.Upvalue:
        markValue(obj.as!ObjUpvalue().closed);
        break;
    case ObjType.Native, ObjType.String:
        break;
    default:
        assert(false); // unreachable
    }
}

void sweep() {
    Obj* prev = null;
    Obj* obj = &VM.instance.objects[0];
    while (obj != null) {
        if (obj.isMarked) {
            obj.isMarked = false;
            prev = obj;
            obj = obj.next;
        } else {
            Obj* unreached = obj;
            obj = obj.next;
            if (prev != null) {
                prev.next = obj;
            } else {
                VM.instance.objects = obj;
            }
            unreached.free();
        }
    }
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

// special-cased because it's allocated with raw realloc intead of the wrapper
void freeGrayStack() {
    core.stdc.stdlib.free(VM.instance.grayStack);
}

size_t growCapacity(size_t currentCap) {
    if (currentCap < 8)
        return 8;
    return currentCap * 2;
}
