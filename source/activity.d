module action;

import std.algorithm : remove;
import std.stdio : writeln;

class ActionList {

    void add(Action a) {
        if (currPos != actions.length) {
            actions = actions[0 .. currPos];
        }
        actions ~= a;
        currPos++;
        a.doAction();
    }

    void back() {
        if (currPos == 0)
            return;
        actions[currPos - 1].undoAction();
        currPos--;
    }

    void forward() {
        if (currPos == actions.length)
            return;
        actions[currPos].doAction();
        currPos++;
    }

private:
    uint currPos = 0;
    Action[] actions;
}

unittest {
    class Test : Action {
        void doAction() {
        }

        void undoAction() {
        }
    }

    auto list = new ActionList;
    assert(list.currPos == 0);
    list.add(new Test);
    list.add(new Test);
    list.add(new Test);
    list.forward();
    list.forward();
    assert(list.currPos == 3);
    list.back();
    list.back();
    assert(list.currPos == 1);
    assert(list.actions.length == 3);
    list.forward();
    assert(list.currPos == 2);
    assert(list.actions.length == 3);
    list.add(new Test);
    assert(list.currPos == 3);
    assert(list.actions.length == 3);
    list.back();
    list.back();
    list.back();
    assert(list.currPos == 0);
    assert(list.actions.length == 3);
}

interface Action {
    void doAction();
    void undoAction();
}
