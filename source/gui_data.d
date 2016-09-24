module gui_data;

import pcb_project;

__gshared GuiData guiData;
shared static this() {
    guiData = new GuiData;
}

class GuiData {
    string[][string] footprints;
    bool footprintsChanged = true;
    void addFootprints(FootprintData[] arr, string libraryName) {
        foreach (foot; arr) {
            footprints[libraryName] ~= foot.name;
        }
        footprintsChanged = true;
    }

    string selectedFootprint = "BGA1295_1mm";
}
