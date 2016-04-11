module engine.renderer.memory;

import std.algorithm : remove;
import std.array : insertInPlace;
import derelict.opengl3.gl3;

struct GpuMemory {
    uint id;
    uint start;
    uint end;
    void write(uint target = GL_ARRAY_BUFFER, T)(T[] obj) if (__traits(isPOD, T)) {
        size_t size = T.sizeof * obj.length;
        if (size > end - start)
            throw new Exception("Gpu range overflow");
        glBindBuffer(target, id);
        glBufferSubData(target, start, size, obj.ptr);
    }
}

GpuMemory getEmptyMemory() {
    __gshared static uint id;
    __gshared static bool init = false;
    if (!init) {
        glGenBuffers(1, &id);
        glBindBuffer(GL_ARRAY_BUFFER, id);
        glBufferData(GL_ARRAY_BUFFER, 0, null, GL_STATIC_DRAW);
        init = true;
    }
    return GpuMemory(id, 0, 0);
}
//TODO target ignored ?? xD
class GpuAllocator(GLenum target) {
    static GpuMemory allocate(size_t size) {
        uint id;
        glGenBuffers(1, &id);
        glBindBuffer(GL_ARRAY_BUFFER, id);
        glBufferData(GL_ARRAY_BUFFER, size, null, GL_STATIC_DRAW);
        return GpuMemory(id, 0, cast(uint) size);
    }

    static void deallocate(GpuMemory memory) {
        glDeleteBuffers(1, &memory.id);
    }
}

class GpuChunkAllocator(GLenum target) {
    GpuMemory[] meta;
    GLuint vbo;
    uint buffSize;
    this(size_t buffSize = 8096 * 1024) {
        assert(buffSize <= uint.max);
        this.buffSize = cast(uint) buffSize;
        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, buffSize, null, GL_STATIC_DRAW);
    }

    void remove() {
        //glDeleteBuffers(1, &vbo);
    }

    GpuMemory allocate(size_t size) {
        if (size == 0)
            return getEmptyMemory();
        uint metaIndex = 0;
        uint start = 0;
        uint freeSpace = buffSize;
        if (meta.length != 0) {
            foreach (uint i, m; meta) {
                uint space = m.start - start;
                freeSpace -= m.end - m.start;
                if (space >= size) {
                    metaIndex = i;
                    break;
                }
                start = m.end;
            }
            if (metaIndex == 0 && start != 0) {
                start = meta[$ - 1].end;
                if ((buffSize - start) < size) {
                    throw new Exception("No memory");
                }
                metaIndex = cast(uint) meta.length;
            }
        }
        freeSpace -= size;
        GpuMemory d = GpuMemory(vbo, start, start + cast(uint) size);
        meta.insertInPlace(metaIndex, d);
        return d;
    }

    void deallocate(GpuMemory memory) {
        if (memory.start == 0 && memory.end == 0)
            return;
        foreach (uint i, m; meta) {
            if (m.start == memory.start) {
                assert(m.end == memory.end);
                meta = meta.remove(i);
                return;
            }
        }
        assert(0);
    }

}

//Niech komilator wyklepie kod by były błędy kompilacji
unittest {
    import std.exception;

    GpuAllocator!GL_ARRAY_BUFFER a1;
    GpuChunkAllocator!GL_ARRAY_BUFFER a2;
    GpuMemory m;
    assertThrown(m.write([1, 2, 3, 4, 5]));
}

//TODO add simple opengl initialization for unittests
/*unittest{
 static struct V{
 float f;
 }
 static class M{
 float m;
 }
 alias Buf=Bufferr!(V,M);
 alias BufData=Buf.Data;
 Buf bf;
 bf=new Buf(null);
 BufData[] bdd;
 bdd~=bf.addVertices([V(23)]);
 bdd~=bf.addVertices([V(23)]);
 bdd~=bf.addVertices([V(23)]);
 bdd~=bf.addVertices([V(23)]);
 bdd~=bf.addVertices([V(23)]);
 assert(bf.meta.length==5);
 foreach(d;bdd[1..4])bf.removeData(d);
 assert(bf.meta.length==2);
 bdd~=bf.addVertices([V(23)]);
 bdd~=bf.addVertices([V(23)]);
 bdd~=bf.addVertices([V(23)]);
 bdd~=bf.addVertices([V(23)]);
 assert(bf.meta.length==6);
 foreach(i,m;bf.meta){
 assert(m.start==i);
 assert(m.end==i+1);
 }
 }
 */
