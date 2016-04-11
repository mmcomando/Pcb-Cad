/**
 Module to load and save KiCad *.net files
 Copyright: © 2014-2015 MM
 License: Eyes -> 0.0 Mine
 Authors: Michał Masiukiewicz
 */
module kicad_net;

import core.exception;
import std.algorithm;
import std.range;
import std.file;
import std.stdio : writeln, write, File;

import struct_string;
import kicad_enums;

string[] tokenize(in string str) {
    string[] func(string a, string needle) {
        auto r = a.findSplit(needle);
        string[] ret1;
        string[] ret2;
        if (!r[1].empty) {
            //writeln("asd");
            ret1 = func(r[0], needle);
            ret2 = func(r[2], needle);
        } else {
            //writeln("22123asd");
            ret1 = [r[0]];
            ret2 = [r[1]];
        }
        return chain(ret1, [r[1]], ret2).array;
    }

    return str.split.map!(a => func(a, "(")).join.map!(a => func(a, ")")).join.filter!(a => !a.empty).array;
}

class Variable {
    string name;
    string[] strings;
    Variable[string] variables;
    void print() {
        writeln("--------");
        writeln("start var:  " ~ name);
        //writeln("strings:");
        strings.each!(a => writeln("    " ~ a));
        //writeln("variables:");
        variables.each!(a => a.print);
        writeln("end var:  " ~ name);
    }
}

Variable toVariable(ref string[] tokens) {
    Variable var = new Variable;
    if (tokens[0] != "(")
        throw new Exception(" Something before");
    tokens.popFront;
    var.name = tokens[0];
    tokens.popFront;
    while (tokens[0] != ")") {
        if (tokens[0] == "(") {
            Variable tmpVar = toVariable(tokens);
            var.variables[tmpVar.name] = tmpVar;

        } else {
            var.strings ~= tokens[0];
            tokens.popFront;
        }
    }
    tokens.popFront; // )
    return var;
}

string toString(Variable var) {
    string str;
    str ~= "(" ~ var.name ~ " ";
    foreach (s; var.strings) {
        str ~= s ~ " ";
    }
    foreach (v; var.variables) {
        str ~= toString(v);
    }
    str ~= ")";
    return str;
}

struct NetFile {
    Variable main;
    void loadFromFile(string file_path) {
        string str = readText(file_path);
        loadFromString(str);

    }

    void loadFromString(string str) {
        string[] tokens = tokenize(str);
        main = toVariable(tokens);
        writeln(toString(main));
        //tokens.each!writeln;
        if (tokens.length > 0) {
            //tokens.each!writeln;
            throw new Exception("There should be end");
        }

    }
}
