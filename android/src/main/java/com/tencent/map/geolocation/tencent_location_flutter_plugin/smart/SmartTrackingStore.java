package com.tencent.map.geolocation.tencent_location_flutter_plugin.smart;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Native session metadata and bounded diagnostics, independent of a Flutter engine. */
public final class SmartTrackingStore {
    private static final String TAG = "TencentSmart";
    private static final long MAX_LOG_BYTES = 512 * 1024;
    private final SharedPreferences prefs;
    private final File log;

    public SmartTrackingStore(Context context) {
        prefs = context.getSharedPreferences("tencent_native_smart", Context.MODE_PRIVATE);
        log = new File(context.getFilesDir(), "tencent-smart.jsonl");
    }

    public boolean enabled() { return prefs.getBoolean("enabled", false); }
    public boolean privacyAgreed() { return prefs.getBoolean("privacyAgreed", false); }
    public String sdkValue(String key) { return prefs.getString("sdk." + key, ""); }

    public void saveSdk(String key, String value) {
        if (!prefs.edit().putString("sdk." + key, value).commit()) throw new IllegalStateException("Saving SDK restore field failed: " + key);
    }

    public void savePrivacy(boolean agreed) {
        SharedPreferences.Editor edit = prefs.edit().putBoolean("privacyAgreed", agreed);
        if (!agreed) edit.putBoolean("enabled", false);
        if (!edit.commit()) throw new IllegalStateException("Saving SDK privacy agreement failed");
    }

    public void saveSession(Map<?, ?> arguments) {
        if (!prefs.edit().putString("session", new JSONObject(arguments).toString()).putBoolean("enabled", true).commit()) {
            throw new IllegalStateException("Saving native Smart session failed");
        }
    }

    public Map<String, Object> session() { return read("session"); }
    public Map<String, Object> motion() { return read("motion"); }

    public void saveMotion(Map<String, Object> motion) {
        prefs.edit().putString("motion", new JSONObject(motion).toString()).apply();
    }

    public void disable() {
        if (!prefs.edit().putBoolean("enabled", false).commit()) throw new IllegalStateException("Stopping native Smart session could not be persisted");
    }

    private Map<String, Object> read(String key) {
        String text = prefs.getString(key, null);
        if (text == null) return new LinkedHashMap<>();
        try {
            return jsonToMap(new JSONObject(text));
        } catch (JSONException error) {
            throw new IllegalStateException("Invalid persisted Smart " + key, error);
        }
    }

    public synchronized void append(String event, Map<String, Object> state, Throwable error) {
        Map<String, Object> row = new LinkedHashMap<>(state);
        row.remove("lastLocation"); // Diagnostics retain timing/state, not route coordinates or addresses.
        row.put("type", event);
        row.put("wallMs", System.currentTimeMillis());
        if (error != null) row.put("error", Log.getStackTraceString(error));
        String line = new JSONObject(row).toString() + "\n";
        if (error == null) Log.i(TAG, event + ": " + state.get("reason"));
        else Log.e(TAG, event + ": " + state.get("reason"), error);
        try {
            File previous = new File(log.getPath() + ".1");
            if (log.length() >= MAX_LOG_BYTES) {
                if (previous.exists() && !previous.delete()) throw new IOException("Could not delete previous Smart diagnostic log");
                if (!log.renameTo(previous)) throw new IOException("Could not rotate Smart diagnostic log");
            }
            try (FileOutputStream stream = new FileOutputStream(log, true)) {
                stream.write(line.getBytes(StandardCharsets.UTF_8));
            }
        } catch (IOException failure) {
            Log.e(TAG, "Writing native Smart diagnostics failed", failure);
        }
    }

    public synchronized String getLog() throws IOException {
        return readFile(new File(log.getPath() + ".1")) + readFile(log);
    }

    public synchronized void clearLog() throws IOException {
        for (File file : new File[]{log, new File(log.getPath() + ".1")}) {
            if (file.exists() && !file.delete()) throw new IOException("Could not delete Smart diagnostic log " + file.getName());
        }
    }

    private static String readFile(File file) throws IOException {
        if (!file.exists()) return "";
        if (file.length() > MAX_LOG_BYTES + 64 * 1024) throw new IOException("Smart diagnostic log exceeds its bound");
        try (FileInputStream input = new FileInputStream(file); java.io.ByteArrayOutputStream output = new java.io.ByteArrayOutputStream()) {
            byte[] bytes = new byte[8192]; int count;
            while ((count = input.read(bytes)) != -1) output.write(bytes, 0, count);
            return output.toString("UTF-8");
        }
    }

    public static Map<String, Object> jsonToMap(JSONObject object) throws JSONException {
        Map<String, Object> result = new LinkedHashMap<>();
        Iterator<String> keys = object.keys();
        while (keys.hasNext()) { String key = keys.next(); result.put(key, fromJson(object.get(key))); }
        return result;
    }

    private static Object fromJson(Object value) throws JSONException {
        if (value == JSONObject.NULL) return null;
        if (value instanceof JSONObject) return jsonToMap((JSONObject) value);
        if (value instanceof JSONArray) {
            List<Object> result = new ArrayList<>();
            for (int i = 0; i < ((JSONArray) value).length(); i++) result.add(fromJson(((JSONArray) value).get(i)));
            return result;
        }
        return value;
    }
}
