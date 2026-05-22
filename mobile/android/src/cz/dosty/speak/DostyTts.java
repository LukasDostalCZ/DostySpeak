package cz.dosty.speak;

import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import java.util.Locale;

public class DostyTts {
    private static TextToSpeech tts;
    private static boolean ready = false;
    private static String pendingText = null;
    private static float rate = 1.0f;
    private static float pitch = 1.0f;
    private static Locale locale = new Locale("cs", "CZ");

    public static void init(android.content.Context context) {
        if (tts != null) return;

        tts = new TextToSpeech(context.getApplicationContext(), status -> {
            ready = status == TextToSpeech.SUCCESS;
            if (ready) {
                tts.setLanguage(locale);
                tts.setSpeechRate(rate);
                tts.setPitch(pitch);
                tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                    @Override public void onStart(String utteranceId) {}
                    @Override public void onDone(String utteranceId) {}
                    @Override public void onError(String utteranceId) {}
                });

                if (pendingText != null) {
                    speak(pendingText);
                    pendingText = null;
                }
            }
        });
    }

    public static void setLanguage(String languageTag) {
        if (languageTag == null || languageTag.length() == 0) languageTag = "cs-CZ";
        locale = Locale.forLanguageTag(languageTag);
        if (tts != null && ready) tts.setLanguage(locale);
    }

    public static void setRate(float value) {
        rate = value;
        if (tts != null && ready) tts.setSpeechRate(rate);
    }

    public static void setPitch(float value) {
        pitch = value;
        if (tts != null && ready) tts.setPitch(pitch);
    }

    public static void speak(String text) {
        if (text == null || text.length() == 0) return;

        if (tts == null || !ready) {
            pendingText = text;
            return;
        }

        tts.stop();
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "dosty-speak");
    }

    public static void stop() {
        if (tts != null) tts.stop();
    }

    public static void shutdown() {
        if (tts != null) {
            tts.stop();
            tts.shutdown();
            tts = null;
            ready = false;
        }
    }
}
