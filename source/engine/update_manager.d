module engine.update_manager;

import std.datetime;
import std.stdio;
import std.array;
import std.algorithm;

enum updateType {
    lockfree,
    async,
    sync
}

class UpdateManager {
private:
    static struct TimedDelegate {
        void delegate() del;
        TickDuration t;
    }

    void delegate()[][updateType.max + 1] everytimeTab;
    TimedDelegate[][updateType.max + 1] forTab;
    TimedDelegate[] atTimeTab;
    StopWatch sw;
    TickDuration time;

    union DelegateUnion {
        void*[2] ptr;
        void delegate() del;
    }

    void* getFuncAddress(void delegate() del) {
        DelegateUnion u;
        u.del = del;
        return u.ptr[1];
    }

    void* getObjectAddress(void delegate() del) {
        DelegateUnion u;
        u.del = del;
        return u.ptr[0];
    }

    unittest {
        UpdateManager man1 = new UpdateManager();
        UpdateManager man2 = new UpdateManager();
        DelegateUnion u1, u2;
        u1.del = &man1.update;
        u2.del = &man2.update;
        assert(u1.ptr[0] != u2.ptr[0]);
        assert(u1.ptr[1] == u2.ptr[1]);
    }

    static bool sameObject(void delegate() lhs, void delegate() rhs) {
        DelegateUnion u1, u2;
        u1.del = lhs;
        u2.del = rhs;
        return u1.ptr[0] == u2.ptr[0];
    }

    TickDuration getTickNumber(double time) {
        TickDuration now = sw.peek();
        ulong ticks = cast(ulong)(now.length + time * TickDuration.ticksPerSec);
        return TickDuration.from!"nsecs"(ticks);
    }

    void addToTab(void delegate() del, double time, ref TimedDelegate[] tab) {
        foreach (i, obj; tab) {
            if (getFuncAddress(obj.del) >= getFuncAddress(del)) {
                tab.insertInPlace(i, TimedDelegate(del, getTickNumber(time)));
                return;
            }
        }
        tab ~= TimedDelegate(del, getTickNumber(time));
    }

    void addToTab(void delegate() del, ref void delegate()[] tab) {
        foreach (i, obj; tab) {
            if (getFuncAddress(obj) >= getFuncAddress(del)) {
                tab.insertInPlace(i, del);
                return;
            }
        }
        tab ~= del;
    }

public:
    this() {
        sw.start();
    }

    void updateFor(updateType uT = updateType.sync)(void delegate() del, double time) {
        static if (uT == updateType.async || uT == updateType.lockfree) {
            foreach (timDel; forTab[uT]) {
                if (sameObject(timDel.del, del)) {
                    writeln("Object can not be updated twice in parrel.");
                    return;
                }
            }
        }
        addToTab(del, time, forTab[uT]);
    }

    void updateAfter(void delegate() del, double time) {
        addToTab(del, time, atTimeTab);
    }

    void updateEverytime(updateType uT = updateType.sync)(void delegate() del) {
        static if (uT == updateType.async || uT == updateType.lockfree) {
            foreach (dell; everytimeTab[uT]) {
                if (sameObject(dell, del)) {
                    writeln("Object can not be updated twice in parrel.");
                    return;
                }
            }
        }
        addToTab(del, everytimeTab[uT]);
    }

    bool removeFromUpdating(T)(T* obj) {
        static if (is(T == struct)) {
            return removeFromUpdatingImpl(obj);
        } else static if (is(T == class)) {
            void* ptr = ((Object o) => cast(void*) o)(*obj);
            return removeFromUpdatingImpl(ptr);
        } else {
            static assert(0);
        }
    }

    private bool removeFromUpdatingImpl(void* object) {
        foreach (num; 0 .. updateType.max + 1)
            foreach (i, ref elem; everytimeTab[num]) {
                if (getObjectAddress(elem) == object) {
                    everytimeTab[num] = everytimeTab[num].remove(i);
                    return true;
                }
            }

        foreach (num; 0 .. updateType.max + 1)
            foreach (i, ref elem; forTab[num])
                if (getObjectAddress(elem.del) == object) {
                    forTab[num] = forTab[num].remove(i);
                    return true;
                }
        foreach (i, ref elem; atTimeTab)
            if (getObjectAddress(elem.del) == object) {
                atTimeTab = atTimeTab.remove(i);
                return true;
            }
        return false;

    }

    void update() {
        import std.parallelism;

        TickDuration now = sw.peek();
        //everytime
        foreach (ref elem; taskPool.parallel(everytimeTab[updateType.lockfree], 10))
            elem();
        foreach (ref elem; taskPool.parallel(everytimeTab[updateType.async], 2))
            elem();
        foreach (ref elem; everytimeTab[updateType.sync].dup)
            elem();
        //for time
        foreach (ref elem; taskPool.parallel(forTab[updateType.lockfree], 10))
            elem.del();
        foreach (ref elem; taskPool.parallel(forTab[updateType.async], 2))
            elem.del();
        foreach (ref elem; forTab[updateType.sync].dup)
            elem.del();

        foreach (num; 0 .. updateType.max + 1) {
            bool sthToDelete = false;
            foreach (ref elem; forTab[num])
                if (now >= elem.t) {
                    sthToDelete = true;
                    elem.del = null;
                }
            if (sthToDelete)
                forTab[num] = remove!(a => a.del is null)(forTab[num]);
        }
        //after
        bool sthToDelete = false;
        foreach (i, obj; atTimeTab) {
            if (now >= obj.t) {
                obj.del();
                sthToDelete = true;
                atTimeTab[i].del = null;
            }
        }
        if (sthToDelete)
            atTimeTab = remove!(a => a.del is null)(atTimeTab);
    }
}
