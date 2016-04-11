module serializer;

import std.stdio : writeln;

import cerealed.cerealiser;
import cerealed.decerealiser;
import cerealed.traits;

unittest {
    struct Test {
        string name;
        @NoCereal int bb;
        ;

        int[] ints;

        void accept(C)(auto ref C cereal) {
            //do NOT call cereal.grain(this), that would cause an infinite loop
            cereal.grainAllMembers(this);
            writeln("im  herer ", cereal);
            cereal.grain(bb);
            static if (isDecerealiser!C) {
                writeln("DDDDDDD");

            }
            writeln("im  herer2 ", bb);
        }
        //FootprintsLibrary[] footprintsLibraries;
        //private Footprint[] footprints;		
        //Trace[] traces;
    }

    Test tt;
    tt.name = "Aasha hjgd asf";
    tt.ints = [2, 65, 8, 345, 865];
    tt.bb = 34;

    ubyte[] data;

    auto cerealiser = Cerealiser();
    cerealiser ~= tt;

    auto decerealiser = Decerealiser(cerealiser.bytes);
    Test ntt = decerealiser.value!Test;
    writeln(tt);
    writeln(ntt);
    assert(tt.name == ntt.name);
    assert(tt.ints == ntt.ints);

    //assert(tt.noo!=ntt.noo);

}
