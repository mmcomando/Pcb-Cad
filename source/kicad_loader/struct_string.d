/**
 Module defines functions for easy saving structures in strings and to easly load from them.
 All functions take to parameters of type: string and T.

 Based on compile time parameter load functions load data from string to T or saves data from T to string.

 Thanks to such a structure in many cases you can write description of your format and don't worry if you are loading or saving data.

 While loading from string is deleted part which was used. While saving data is appended to string.

 Copyright: © 2014-2015 MM
 License: Eyes -> 0.0 Mine
 Authors: Michał Masiukiewicz
 */
module struct_string;

import std.algorithm;
import std.conv;
import std.traits;
import std.range;

import std.stdio : writeln;

enum Load {
    no,
    yes
}
/// Func function
/// Load or save structure to or from string depending on copiletime parameter load.
///If structure has loadSaveCustom it will be called to load/save structure instead.
void loadSave(Load load, T)(ref string[] str, ref T structure) {
    //writeln(typeid(T));
    static if (hasMember!(T, "loadSaveCustom")) {
        structure.loadSaveCustom!(load)(str);
    } else static if (!is(T == struct)) {
        loadSaveVar!(load)(str, structure);
    } else static if (load == Load.yes) {
        foreach (i, ref a; structure.tupleof) {
            alias typeof(a) Type;
            static assert(is(Type == string) || !isArray!Type,
                "loadSave don't support arrays consider defining loadSaveCustom for your struct");
            //writeln(str[0..11]);
            a = str[0].to!Type;
            str.popFront;
        }
    } else {
        foreach (i, a; structure.tupleof) {
            alias typeof(a) Type;
            str ~= a.to!string;
            if (str.length > 5) {
                //writeln(str[$-5..$]);

            }
        }
    }
}
//For tests
private enum En {
    ok,
    notOk
}

private struct Example {
    int a;
    En b;
    int c;
}
///Loading
unittest {
    Example ex;
    string[] tests = ["-313", "notOk", "67"];
    loadSave!(Load.yes)(tests, ex);
    assert(ex.a == -313);
    assert(ex.b == En.notOk);
    assert(ex.c == 67);
}
///Saving
unittest {
    Example my = Example(123, En.ok, -88);
    string[] text;
    loadSave!(Load.no)(text, my);
    assert(text == ["123", "ok", "-88"]);
}

///Adds fixed text
void textHere(Load load)(ref string[] str, string text) {
    static if (load == Load.yes) {
        if (str.front != text) {
            throw new Exception("There should be text: " ~ text);
        }
        str.popFront;
    } else {
        str ~= text;
    }
}
///Load
unittest {
    string[] str = ["MyText", "oj", "ej"];
    textHere!(Load.yes)(str, "MyText");
    assert(str == ["oj", "ej"]);
    //textHere!(Load.yes)(str,"SomethingElse");//Exception
}
///Save
unittest {
    string[] str;
    textHere!(Load.no)(str, "MyText");
    assert(str == ["MyText"]);
}
///Ignore line
void ignore(Load load)(ref string[] str, string[] to_ignore) {
    static if (load == Load.yes) {
        while (!str.empty && !to_ignore.find(str.front).empty) {
            str.popFront;
        }
    }
}
///Load
unittest {
}
///Load text
void lineTextHere(Load load)(ref string[] str, ref string text) {
    static if (load == Load.yes) {
        string[] toJoin;
        while (str.front != "\n") {
            toJoin ~= str.front;
            str.popFront;
        }
        text = toJoin.join(' ');
        str.popFront;
    } else {
        str ~= text;
        str ~= "\n";
    }
}
///Load
unittest {
    string[] str = ["MyText", "oj", "ej", "\n", "zzz"];
    string text;
    lineTextHere!(Load.yes)(str, text);
    assert(text == "MyText oj ej");
    assert(str == ["zzz"]);
}
///Save
unittest {
    string[] str;
    string text = "MyText";
    lineTextHere!(Load.no)(str, text);
    assert(str == ["MyText", "\n"]);
}

///Add new line
void newlineHere(Load load)(ref string[] str) {
    static if (load == Load.yes) {
        if (str[0] != "\n") {
            throw new Exception("There should be newline.");
        }
        str.popFront;
    } else {
        str ~= "\n";
    }
}
///Load
unittest {
    string[] str = ["\n", "aa"];
    newlineHere!(Load.yes)(str);
    assert(str == ["aa"]);
}
///Save
unittest {
    string[] str = ["aa"];
    newlineHere!(Load.no)(str);
    assert(str == ["aa", "\n"]);
}
///Loads or saves variable
private void loadSaveVar(Load load, T)(ref string[] str, ref T var) {
    static if (load == Load.yes) {
        var = str[0].to!T;
        str.popFront;
    } else {
        str ~= var.to!string;
    }
}
///Load
unittest {
    En en;
    string[] str = ["notOk", "aaa"];
    loadSaveVar!(Load.yes)(str, en);
    assert(str == ["aaa"]);
    assert(en == En.notOk);
}
///Save
unittest {
    En en = En.ok;
    string[] str;
    loadSaveVar!(Load.no)(str, en);
    assert(str == ["ok"]);
}
