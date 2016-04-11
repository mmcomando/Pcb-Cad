/**
 Module consists enums required to load KiCad files
 Copyright: © 2014-2015 MM
 License: Eyes -> 0.0 Mine
 Authors: Michał Masiukiewicz
 */
module kicad_enums;

///
enum YesNo {
    Y, ///No
    N ///Yes
}
///
enum Fill {
    F, ///Filled with foreground
    f, ///Filled with background
    N ///Not filled
}

///
enum Justify {
    L, ///Left
    R, ///Right
    C, ///Center
    T, ///Top
    B, ///Bottom
}
///
enum Power {
    N, ///No power 
    P ///Power
}
///
enum UnitsLocked {
    L, ///Units are not identical and cannot be swapped 
    F ///Units are identical and therefore can be swapped
}

///
enum Visible {
    I, ///Invisible
    V ///Visible
}
///
enum Orientation {
    V, ///Vertical
    H ///Horizontal
}
///
enum Direction {
    R, ///Right
    L, ///Left
    U, ///Up
    D, ///Down
}
///
enum ElectricalType {
    I, ///Input
    O, ///Output
    B, ///Bidi
    T, ///Tristate
    P, ///Passive
    U, ///Unspecified
    W, ///Power in
    w, ///Power out
    C, ///Open Colector
    E, ///Open emiter
    N, ///Not connected
}

enum PADShape {
    C,
    O,
    R,
    T
}

enum PADType {
    STD, /// for a standard pad with a hole, 
    SMD, /// for a surface-mount pad, 
    CONN, /// for a connector, or 
    HOLE, /// for a hole. flag is 
    N, /// unknown
}
