using Toybox.Application;
using Toybox.Lang;

// One Storage key holding an array, oldest first (ADR 0006). Values cap at
// 32 KB; 120 records at ~25 bytes is ~3 KB, comfortably inside one value.
module RecordStore {

    function all() as Lang.Array {
        var stored = Application.Storage.getValue(Constants.STORAGE_KEY);
        if (stored == null) { return []; }
        return stored as Lang.Array;
    }

    function save(records as Lang.Array) as Void {
        Application.Storage.setValue(Constants.STORAGE_KEY, records);
    }

    function clear() as Void {
        Application.Storage.setValue(Constants.STORAGE_KEY, []);
    }

    function hasRecordFor(dayKey as Lang.Number) as Lang.Boolean {
        var records = all();
        for (var i = 0; i < records.size(); i += 1) {
            if (records[i][:day] == dayKey) { return true; }
        }
        return false;
    }

    function latest() as Lang.Dictionary? {
        var records = all();
        if (records.size() == 0) { return null; }
        return records[records.size() - 1];
    }

    function put(record as Lang.Dictionary) as Void {
        var records = all();
        var out = [];

        // One record per day: a rewrite of the same day replaces it
        for (var i = 0; i < records.size(); i += 1) {
            if (records[i][:day] != record[:day]) {
                out.add(records[i]);
            }
        }
        out.add(record);

        // Evict oldest-first
        while (out.size() > Constants.MAX_RECORDS) {
            out = out.slice(1, out.size());
        }

        save(out);
    }
}
