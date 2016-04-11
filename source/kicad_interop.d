module kicad_interop;
import objects;
import std.algorithm : min, max, strip;
import gl3n.linalg;
import kicad_enums;
import ki_ld = kicad_lib;
import ki_mod = kicad_mod;

FootprintData[] getFootprintsFromModFile(string path) {
    ki_mod.ModFile lib;
    lib.loadFromFile(path);
    FootprintData[] ffs;
    ffs.length = lib.modules.length;
    foreach (i, m; lib.modules) {
        ffs[i] = fromKicadFootprint(m);
    }
    return ffs;
}

private FootprintData fromKicadFootprint(ki_mod.Module md) {
    FootprintData ft = new FootprintData;
    foreach (ref ob; md.DS) {
        vec2 p1 = vec2(ob.x1, ob.y1);
        vec2 p2 = vec2(ob.x2, ob.y2);
        ft.lines ~= [p1, p2];
    }

    foreach (ref ob; md.DC) {
        vec2 p1 = vec2(ob.x1, ob.y1);
        vec2 p2 = vec2(ob.x2, ob.y2);
        ft.circles ~= Circle(p1, (p1 - p2).length);
    }
    foreach (ref ob; md.DA) {
        vec2 p1 = vec2(ob.x1, ob.y1);
        vec2 p2 = vec2(ob.x2, ob.y2);
        vec2 st_en = vec2(0, ob.angle);
        //TODO starting point is on p2
        ft.arcs ~= Arc(p1, st_en, (p1 - p2).length);
    }
    foreach (uint i, ref ob; md.pads) {
        vec2 p1 = vec2(ob.po.x, ob.po.y);
        vec2 p2 = vec2(ob.sh.sizex, ob.sh.sizey);
        Pad p;
        //p.pos=p1;
        ft.snapPoints ~= p1;
        ob.ne.connection = ob.ne.connection.strip('"');
        if (ob.ne.connection.length > 0 && ob.ne.connection[0] != 'N')
            p.connection = ob.ne.connection;
        else
            p.connection = "?";
        //p.wireID=i;
        final switch (ob.at.padType) {
        case PADType.SMD:
        case PADType.CONN:
        case PADType.N:
            p.type = PadType.SMD;
            break;

        case PADType.HOLE:
        case PADType.STD:
            p.type = PadType.THT;
            break;
        }
        Shape shape;
        shape.pos = p1;
        ft.snapPoints ~= p1;
        shape.xy = p2;

        final switch (ob.sh.padShape) {

        case PADShape.R:
            shape.type = ShapeType.Rectangle;
            ft.shapes ~= shape;
            p.shapeID = cast(uint) ft.shapes.length - 1;
            break;
        case PADShape.T:
        case PADShape.O:
        case PADShape.C:
            shape.type = ShapeType.Circle;
            shape.xy.x = shape.xy.y = min(shape.xy.x, shape.xy.y);
            shape.xy.x = shape.xy.y = max(shape.xy.x, 0.1);
            ft.shapes ~= shape;
            p.shapeID = cast(uint) ft.shapes.length - 1;
            //break;
            //ft.points~=p1;
            //p.shapeID=cast(uint)ft.shapes.length-1;
        }
        ft.pads ~= p;

    }
    ft.name = md.name;
    ft.boundingBox = ft.computeBoundingBox();
    return ft;
}
