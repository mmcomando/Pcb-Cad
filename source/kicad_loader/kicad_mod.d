/**
 Module to load and save KiCad *.mod files
 Copyright: © 2014-2015 MM
 License: Eyes -> 0.0 Mine
 Authors: Michał Masiukiewicz
 */
module kicad_mod;

import core.exception;
import std.algorithm;
import std.array;
import std.meta;
import std.traits;
import std.typecons;
import std.range;
import std.stdio : writeln, readln, File;
import std.file;
import std.string;

import struct_string;
import kicad_enums;

string[] tokenize(string str) {
    return str.split("\n").filter!(a => !a.startsWith('#')).join('\n').replace("\n", " \n ").split(" ").filter!(
        a => !a.empty).array;
}

void loadVarAndNewLine(Load load, T)(ref string[] str, string token, ref T var) {
    textHere!(load)(str, token);
    loadSave!(load)(str, var);
    newlineHere!(load)(str);
}

/// Loads and saves *.lib files
struct ModFile {
    string header;
    string units;
    string[] indices;
    Module[] modules;
    void loadSaveCustom(Load load)(ref string[] str) {
        static if (load == Load.yes) {
            header = units = null;
            indices.length = modules.length = 0;
        }
        lineTextHere!(load)(str, header);
        lineTextHere!(load)(str, units);
        textHere!(load)(str, "$INDEX");
        newlineHere!(load)(str);
        static if (load == Load.yes) {
            while (!str.startsWith("$EndINDEX")) {
                string ff;
                lineTextHere!(load)(str, ff);
                indices ~= ff;
            }
        } else {
            foreach (ref ff; indices) {
                lineTextHere!(load)(str, ff);
            }
        }
        //writeln(indices);
        textHere!(load)(str, "$EndINDEX");
        newlineHere!(load)(str);
        modules.length = indices.length;
        foreach (ref obj; modules) {
            loadSave!(load)(str, obj);
        }

        textHere!(load)(str, "$EndLIBRARY");
        newlineHere!(load)(str);
    }
    ///Loads Library from file
    void loadFromFile(string file_path) {
        string str = readText(file_path);
        string[] tokens = str.tokenize;

        //tokens.join(' ').split("\n").
        //	map!(a=>a.strip()).
        //		join("\n").writeln;
        loadSave!(Load.yes)(tokens, this);

    }
}

struct DS_DC {
    float x1;
    float y1;
    float x2;
    float y2;
    float width;
    float layer;

}

struct DA_Type {
    float x1;
    float y1;
    float x2;
    float y2;
    float angle;
    float width;
    float layer;

}
///FModule
struct Module {
    string name;
    Pad[] pads; ///Arcs
    Shape3D[] shapes3D; ///

    string Po;
    string Li;
    string Cd;
    string Kw;
    string Sc;
    string AR;
    string Op;
    string T0;
    string T1;
    string T2;
    string At;
    DS_DC[] DS;
    DS_DC[] DC;
    DA_Type[] DA;

    void loadMyLine(Load load, T)(ref string[] str, string token, ref T var) {
        if (load == Load.no) {
            if (var.empty && token != "AR") {
                return;
            }
        }
        textHere!(load)(str, token);
        lineTextHere!(load)(str, var);
    }

    static string makeSwitch(string[] strs) {
        string code;
        foreach (str; strs) {
            code ~= "case \"" ~ str ~ "\":loadMyLine!(load)(str,\"" ~ str ~ "\"," ~ str ~ ");break;";
        }
        return code;
    }

    static string saveVars(string[] strs) {
        string code;
        foreach (str; strs) {
            code ~= "loadMyLine!(load)(str,\"" ~ str ~ "\"," ~ str ~ ");";
        }
        return code;
    }

    enum myVars = ["Po", "Li", "Cd", "Kw", "Sc", "AR", "Op", "At", "T0", "T1", "T2"];
    ///Load or save Footprint
    void loadSaveCustom(Load load)(ref string[] str) {
        try {
            textHere!(load)(str, "$MODULE");
            loadSave!(load)(str, name);
            newlineHere!(load)(str);

            static if (load == Load.yes) {
                loop: while (1) {
                    switch (str.front) {
                        mixin(makeSwitch(myVars));

                    case "DC":
                        DS_DC s;
                        textHere!(load)(str, "DC");
                        loadSave!(load)(str, s);
                        newlineHere!(load)(str);
                        DC ~= s;
                        break;
                    case "DS":
                        DS_DC s;
                        textHere!(load)(str, "DS");
                        loadSave!(load)(str, s);
                        newlineHere!(load)(str);
                        DS ~= s;
                        break;
                    case "DA":
                        DA_Type s;
                        textHere!(load)(str, "DA");
                        loadSave!(load)(str, s);
                        newlineHere!(load)(str);
                        DA ~= s;
                        break;
                    default:
                        break loop;
                    }
                }
            } else {
                mixin(saveVars(myVars));
                foreach (v; DC) {
                    textHere!(load)(str, "DC");
                    loadSave!(load)(str, v);
                    newlineHere!(load)(str);
                }
                foreach (v; DS) {
                    textHere!(load)(str, "DS");
                    loadSave!(load)(str, v);
                    newlineHere!(load)(str);
                }
                foreach (v; DA) {
                    textHere!(load)(str, "DA");
                    loadSave!(load)(str, v);
                    newlineHere!(load)(str);
                }

            }
            loadShapes!(load)(str);
            textHere!(load)(str, "$EndMODULE");
            textHere!(load)(str, name);
            newlineHere!(load)(str);

        }
        catch (RangeError e) {
            throw new Exception("Wrong format. Range violation occured.");
        }
    }
    ///Loading shapes requires custom loadSave so there it is
    private void loadShapes(Load load)(ref string[] str) {
        static if (load == Load.yes) {
            pads.length = shapes3D.length = 0;
            while (1) {
                if (startsWith(str, "$PAD")) {
                    Pad s;
                    loadSave!(load)(str, s);
                    pads ~= s;
                } else if (startsWith(str, "$SHAPE3D")) {
                    Shape3D s;
                    loadSave!(load)(str, s);
                    shapes3D ~= s;
                } else {
                    break;
                }
            }
        } else {
            foreach (ref obj; pads) {
                loadSave!(load)(str, obj);
            }
            foreach (ref obj; shapes3D) {
                loadSave!(load)(str, obj);
            }

        }
    }

}

struct Sh {
    string s;
    PADShape padShape;
    float sizex;
    float sizey;
    float c;
    float d;
    float e;
}

struct Dr {
    float a;
    float b;
    float c;
}

struct At {
    PADType padType;
    string b;
    string c;
}

struct Ne {
    int a;
    string connection;
}

struct Po {
    float x;
    float y;
}
/*Kicad Pad
 Sh "3" C 1 1 0 0 0
 Dr 0.6 0 0
 At STD N 00E0FFFF
 Ne 0 ""
 Po -12.7 0
 */
struct Pad {
    Sh sh;
    Dr dr;
    At at;
    Ne ne;
    Po po;

    void loadSaveCustom(Load load)(ref string[] str) {

        textHere!(load)(str, "$PAD");
        newlineHere!(load)(str);

        loadVarAndNewLine!(load)(str, "Sh", sh);
        loadVarAndNewLine!(load)(str, "Dr", dr);
        loadVarAndNewLine!(load)(str, "At", at);
        loadVarAndNewLine!(load)(str, "Ne", ne);
        loadVarAndNewLine!(load)(str, "Po", po);

        textHere!(load)(str, "$EndPAD");
        newlineHere!(load)(str);
    }
}

/**Kicad Shape3D
 Na "pin_array/pins_array_12x1.wrl"
 Sc 1 1 1
 Of 0.25 0 0
 Ro 0 0 0
 */
struct vec3 {
    float x;
    float y;
    float z;
}

struct Shape3D {
    string path;
    vec3 scal;
    vec3 pos;
    vec3 rot;

    void loadSaveCustom(Load load)(ref string[] str) {
        textHere!(load)(str, "$SHAPE3D");
        newlineHere!(load)(str);

        loadVarAndNewLine!(load)(str, "Na", path);
        loadVarAndNewLine!(load)(str, "Sc", scal);
        loadVarAndNewLine!(load)(str, "Of", pos);
        loadVarAndNewLine!(load)(str, "Ro", rot);

        textHere!(load)(str, "$EndSHAPE3D");
        newlineHere!(load)(str);
    }
}
