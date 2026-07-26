using Toybox.Application;
using Toybox.Lang;

// One Storage key holding an array, oldest first (ADR 0006). Values cap at
// 32 KB; 120 records at ~25 bytes is ~3 KB, comfortably inside one value.
// Both scopes: Capture writes through hasRecordFor()/put(), and the glance
// reads through latest(). This module is the only thing the two share.
(:background :glance)
module RecordStore {

    // Application.Storage.KeyType/ValueType exclude Symbol (see the SDK's own
    // "Symbols... are not to be used for Keys or Values" note), but every
    // record in the app is Symbol-keyed (DailyRecord.make). These two
    // functions are the only place that boundary is crossed, so the
    // Symbol<->String translation lives here and nowhere else has to know.
    function toStorable(record as Lang.Dictionary) as Lang.Dictionary {
        return {
            "day"           => record[:day],
            "score"         => record[:score],
            "body"          => record[:body],
            "recovery"      => record[:recovery],
            "rhr"           => record[:rhr],
            "overrideFired" => record[:overrideFired]
        };
    }

    function fromStorable(stored as Lang.Dictionary) as Lang.Dictionary {
        return {
            :day           => stored["day"],
            :score         => stored["score"],
            :body          => stored["body"],
            :recovery      => stored["recovery"],
            :rhr           => stored["rhr"],
            :overrideFired => stored["overrideFired"]
        };
    }

    function all() as Lang.Array {
        var stored = Application.Storage.getValue(Constants.STORAGE_KEY);
        if (stored == null) { return []; }
        var records = [];
        for (var i = 0; i < stored.size(); i += 1) {
            records.add(fromStorable(stored[i]));
        }
        return records;
    }

    function save(records as Lang.Array) as Void {
        var storable = [];
        for (var i = 0; i < records.size(); i += 1) {
            storable.add(toStorable(records[i]));
        }
        Application.Storage.setValue(Constants.STORAGE_KEY, storable);
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

    // Inserts in day order rather than appending. Appending would be correct
    // only while the local date never moves backward — but ADR 0006 explicitly
    // accepts a wearer crossing a timezone, which can do exactly that. An
    // out-of-order array makes latest() return a stale record as current, and
    // latest() is what decides whether the screen shows a band colour or the
    // greyed stale state.
    function put(record as Lang.Dictionary) as Void {
        var records = all();
        var out = [];
        var inserted = false;

        for (var i = 0; i < records.size(); i += 1) {
            // One record per day: a rewrite of the same day replaces it
            if (records[i][:day] == record[:day]) { continue; }

            if (!inserted && records[i][:day] > record[:day]) {
                out.add(record);
                inserted = true;
            }
            out.add(records[i]);
        }
        if (!inserted) { out.add(record); }

        // Evict oldest-first
        while (out.size() > Constants.MAX_RECORDS) {
            out = out.slice(1, out.size());
        }

        save(out);
    }
}
