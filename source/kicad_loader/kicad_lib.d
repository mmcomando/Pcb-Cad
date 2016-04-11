/**
 Module to load and save KiCad *.lib files
 Copyright: © 2014-2015 MM
 License: Eyes -> 0.0 Mine
 Authors: Michał Masiukiewicz
 */
module kicad_lib;

import core.exception;
import std.algorithm;
import std.array;
import std.meta;
import std.stdio : writeln, readln, File;
import std.file;

import struct_string;
import kicad_enums;

string[] tokenize(string str) {
    return str.split("\n").filter!(a => !a.startsWith('#')).join('\n').replace("\n", " \n ").split(" ").filter!(
        a => !a.empty).array;
}
/// Loads and saves *.lib files
struct LibraryDef {
    string header;
    FootprintDef[] footprints;
    void loadSaveCustom(Load load)(ref string[] str) {
        static if (load == Load.yes) {
            header = null;
        }
        lineTextHere!(load)(str, header);
        static if (load == Load.yes) {
            footprints = null;
            while (!str.empty && str[0] == "DEF") {
                FootprintDef ff;
                loadSave!(Load.yes)(str, ff);
                footprints ~= ff;
                textHere!(load)(str, "ENDDEF");
                newlineHere!(load)(str);
                ignore!(load)(str, ["\n"]);
            }
        } else {
            foreach (ff; footprints) {
                loadSave!(Load.no)(str, ff);
                textHere!(load)(str, "ENDDEF");
                newlineHere!(load)(str);
            }
        }

    }
    ///Loads Library from file
    void loadFromFile(string file_path) {
        string str = readText(file_path);
        string[] tokens = str.tokenize;
        //tokens.join(' ').writeln;
        loadSave!(Load.yes)(tokens, this);
    }
}

///Footprint data
struct FootprintDef {
    ///Header struct
    static struct Header {
        string name; ///
        string reference; ///
        int _1;
        int textOffset; ///
        YesNo drawPinNum; ///
        YesNo drawPinName; ///
        byte unitCount; ///
        UnitsLocked unitsLocked; ///
        Power isPower; ///
    }

    ///F0_F1_Data data
    static struct F0_F1_Data {
        string name; ///
        int posx; ///
        int posy; ///
        int text_size; ///
        Orientation orien; ///
        Visible visible; ///
        Justify htext_justify; ///
        string _1;
    }
    ///Load or save Footprint
    void loadSaveCustom(Load load)(ref string[] str) {
        try {
            loadHeader!(load)(str);
            textHere!(load)(str, "DRAW");
            newlineHere!(load)(str);
            loadShapes!(load)(str);
            textHere!(load)(str, "ENDDRAW");
            newlineHere!(load)(str);
        }
        catch (RangeError e) {
            throw new Exception("Wrong format. Range violation occured.");
        }
    }

    private void loadHeader(Load load)(ref string[] str) {
        textHere!(load)(str, "DEF");

        loadSave!(load)(str, header);
        newlineHere!(load)(str);
        textHere!(load)(str, "F0");
        loadSave!(load)(str, componentReference);
        newlineHere!(load)(str);
        textHere!(load)(str, "F1");
        loadSave!(load)(str, component);
        newlineHere!(load)(str);
        lineTextHere!(load)(str, F2);
        lineTextHere!(load)(str, F3);

    }
    ///Loading shapes requires custom loadSave so there it is
    private void loadShapes(Load load)(ref string[] str) {

        alias firstWord = AliasSeq!("S", "P", "X", "A", "C");
        alias Type = AliasSeq!(Rectangle, Polyline, Pin, Arc, Circle);
        alias Container = AliasSeq!("rectangles", "polylines", "pins", "arcs", "circles");

        static if (load == Load.yes) {
            enum l = firstWord.length;
            static assert(firstWord.length == l && Type.length == l && Container.length == l);

            upperLoop: while (true) {
                foreach (ii, ___s; firstWord) {
                    if (firstWord[ii] == str[0]) {
                        str.popFront;
                        alias MyType = Type[ii];
                        MyType shape;
                        loadSave!(Load.yes)(str, shape);
                        mixin(Container[ii] ~ "~=shape;");
                        newlineHere!(load)(str);
                        continue upperLoop;
                    }
                }
                break;
            }
        } else {
            foreach (ii, ___s; firstWord) {
                mixin("auto container=" ~ Container[ii] ~ ";");
                foreach (ref obj; container) {
                    str ~= firstWord[ii];
                    loadSave!(Load.no)(str, obj);
                    newlineHere!(load)(str);
                }
            }
        }
    }

    string F2;
    string F3;
    Header header; ///Footprint header information
    F0_F1_Data componentReference; ///
    F0_F1_Data component; ///

    Arc[] arcs; ///Arcs
    Circle[] circles; ///	
    Polyline[] polylines; ///
    Rectangle[] rectangles; ///
    Text[] texts; ///	
    Pin[] pins; ///
}

///Kicad Polyline
///P point_count unit convert thickness (posx posy)* fill
///P 4 0 1 6  -200 650  200 450  -200 250  -200 650 f
struct Polyline {
    int[2][] points; ///
    Fill fill; ///
    int _unit; ///
    int _convert; ///
    int _thickness; ///

    ///Polyline requires custom loadSave so there it is
    void loadSaveCustom(Load load)(ref string[] str) {
        static if (load == Load.yes) {
            int pointsCount;
            loadSave!(load)(str, pointsCount);
            points.length = pointsCount;
        } else {
            int pointsCount = cast(int) points.length;
            loadSave!(load)(str, pointsCount);
        }
        loadSave!(load)(str, _unit);
        loadSave!(load)(str, _convert);
        loadSave!(load)(str, _thickness);
        foreach (ref point; points) {
            loadSave!(load)(str, point[0]);
            loadSave!(load)(str, point[1]);
        }
        loadSave!(load)(str, fill);
    }
}

///Kicad Rectangle
///S startx starty endx endy unit convert thickness fill
///S -200 -150 200 150 0 1 0 N
struct Rectangle {
    int startx; ///
    int starty; ///
    int endx; ///
    int endy; ///
    int _1;
    int _2;
    int _3;
    Fill fill; ///
}

///Kicad Pin
///X name num posx posy length direction name_text_size num_text_size unit convert electrical_type pin_type
///X 1 VI -400 50 200 R 40 40 1 1 I
struct Pin {
    string name; ///
    int num; ///
    int posx; ///
    int posy; ///
    int length; ///
    Direction direction; /// 
    int nameTextSize; ///
    int numTextSize; ///
    int _something1;
    int _something2;
    ElectricalType electrical_type; ///
}
///Kicad Text
///T direction posx posy text_size text_type unit convert text text_italic text_hjustify text_vjustify
///T 0 -50 100 80 0 0 0 +  Normal 0 C C
struct Text {
    int direction; ///
    int posx; ///
    int posy; ///
    int text_size; ///
    int text_type; ///
    int _unit;
    int _convert;
    string text; ///
    int text_italic; ///
    Justify text_hjustify; ///
    Justify text_vjustify; ///
}
///Kicad Arc
///A posx posy radius start_angle end_angle unit convert thickness fill startx starty endx endy
///A 0 -200 180 563 1236 0 1 15 N 100 -50 -100 -50
struct Arc {
    int posx; ///
    int posy; ///
    int radius; ///
    int start_angle; ///
    int end_angle; ///
    int _unit;
    int _convert;
    int _thickness;
    Fill fill; ///
    int startx; ///
    int starty; ///
    int endx; ///
    int endy; ///
}
///Kicad Circle
///C posx posy radius unit convert thickness fill
struct Circle {
    int posx; ///
    int posy; ///
    int radius; ///
    int _unit;
    int _convert;
    int _thickness;
    Fill fill; ///
}

unittest {
    string[] str = `DEF LCD_1602A_QAPASS LCD 0 40 N Y 1 F N
F0 "LCD" -1050 750 60 H V C CNN
F1 "CD_2" -322 123 13 V I R ???
F2 asdfasdf
F3 fsadfasd
DRAW
X D7 14 -1800 -650 250 R 50 50 1 1 T
S -1550 700 1200 -700 0 1 0 N
P 2 0 1 0  -1050 0  -600 0 N
ENDDRAW
`
        .tokenize;
    FootprintDef d;
    d.loadSaveCustom!(Load.yes)(str);

    assert(d.header.name == "LCD_1602A_QAPASS" && d.header.reference == "LCD"
        && d.header.textOffset == 40 && d.header.drawPinNum == YesNo.N
        && d.header.drawPinName == YesNo.Y && d.header.unitCount == 1
        && d.header.unitsLocked == UnitsLocked.F && d.header.isPower == Power.N);
    FootprintDef.F0_F1_Data f = d.componentReference;
    assert(f.name == "\"LCD\"" && f.posx == -1050 && f.posy == 750 && f.text_size == 60
        && f.orien == Orientation.H && f.visible == Visible.V && f.htext_justify == Justify.C);
    f = d.component;
    assert(f.name == "\"CD_2\"" && f.posx == -322 && f.posy == 123 && f.text_size == 13
        && f.orien == Orientation.V && f.visible == Visible.I && f.htext_justify == Justify.R);
    assert(d.pins.length == 1);
    Pin p = d.pins[0];
    assert(p.name == "D7" && p.num == 14 && p.posx == -1800 && p.posy == -650 && p.length == 250
        && p.direction == Direction.R && p.nameTextSize == 50 && p.numTextSize == 50
        && p.electrical_type == ElectricalType.T);
    assert(d.rectangles.length == 1);
    Rectangle r = d.rectangles[0];
    assert(r.startx == -1550 && r.starty == 700 && r.endx == 1200 && r.endy == -700 && r.fill == Fill.N);
    assert(d.polylines.length == 1 && d.polylines[0].points.length == 2);
    Polyline pl = d.polylines[0];
    assert(pl.points[0][0] == -1050 && pl.points[0][1] == 0 && pl.points[1][0] == -600
        && pl.points[1][1] == 0 && pl.fill == Fill.N);
}
