module table;

import std.algorithm.comparison : equal;

import lobj : ObjString;
import value : Value, ValueType;
import memory : growCapacity, markObject, markValue;

static const float TABLE_MAX_LOAD = 0.75;

struct Entry
{
    ObjString* key = null;
    Value value = Value.nil();
}

struct Table
{
    size_t count = 0;
    Entry[] entries;

    void free()
    {
        entries.length = 0;
        this.count = 0;
    }

    bool set(ObjString* key, Value val)
    {
        if (this.count + 1 > this.entries.length * TABLE_MAX_LOAD)
        {
            size_t capacity = growCapacity(this.entries.length);
            this.adjustCapacity(capacity);
        }

        Entry* entry = Table.findEntry(this.entries, key);
        bool isNewKey = entry.key == null;
        if (isNewKey && entry.value.valType == ValueType.Nil)
        {
            this.count += 1;
        }
        entry.key = key;
        entry.value = val;
        return isNewKey;
    }

    bool get(ObjString* key, Value* value)
    {
        if (this.count == 0)
        {
            return false;
        }

        Entry* entry = Table.findEntry(this.entries, key);
        if (entry.key == null)
        {
            return false;
        }

        *value = entry.value;
        return true;
    }

    bool remove(ObjString* key)
    {
        if (this.count == 0)
        {
            return false;
        }

        Entry* entry = Table.findEntry(this.entries, key);
        if (entry.key == null)
        {
            return false;
        }

        entry.key = null;
        entry.value = Value(true);
        return true;
    }

    void removeWhite() {
        for (size_t i = 0; i < this.entries.length; i++) {
            Entry* entry = &this.entries[i];
            if (entry.key != null && !entry.key.obj.isMarked) {
                this.remove(entry.key);
            }
        }
    }

    static void addAll(Table* from, Table* to)
    {
        for (size_t idx = 0; idx < from.entries.length; idx++)
        {
            Entry* entry = &from.entries[idx];
            if (entry.key != null)
            {
                to.set(entry.key, entry.value);
            }
        }
    }

    static Entry* findEntry(Entry[] haystack, ObjString* key)
    {
        uint idx = key.hash % haystack.length;
        Entry* tombstone = null;

        while (true)
        {
            Entry* entry = &haystack[idx];
            if (entry.key == null)
            {
                if (entry.value.valType == ValueType.Nil)
                {
                    return tombstone != null ? tombstone : entry;
                }
                else
                {
                    if (tombstone == null)
                    {
                        tombstone = entry;
                    }
                }
            }
            else if (entry.key == key)
            {
                return entry;
            }

            idx = (idx + 1) % haystack.length;
        }
    }

    ObjString* findString(string needle, uint hash)
    {
        if (this.count == 0)
        {
            return null;
        }

        uint index = hash % this.entries.length;
        while (true)
        {
            Entry* entry = &this.entries[index];
            if (entry.key == null)
            {
                if (entry.value.valType == ValueType.Nil)
                {
                    return null;
                }
            }
            else if ((entry.key.length == needle.length)
                    && (entry.key.hash == hash)
                    && (entry.key.chars[0 .. entry.key.length].equal(needle.ptr[0 .. needle.length])))
            {
                return entry.key;
            }

            index = (index + 1) % this.entries.length;
        }
    }

    private void adjustCapacity(size_t capacity)
    {
        Entry[] newEntries;
        newEntries.length = capacity;

        this.count = 0;
        for (size_t idx = 0; idx < this.entries.length; idx++)
        {
            Entry* entry = &this.entries[idx];
            if (entry.key == null)
            {
                continue;
            }

            Entry* dest = Table.findEntry(newEntries, entry.key);
            dest.key = entry.key;
            dest.value = entry.value;
            this.count += 1;
        }

        this.entries.length = 0;
        this.entries = newEntries;
    }
}
