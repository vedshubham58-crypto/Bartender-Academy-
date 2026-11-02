package com.vedshubham.neonads;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import java.util.Calendar;

import androidx.annotation.NonNull;
import androidx.collection.ArraySet;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.AdSize;
import com.google.android.gms.ads.AdView;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Set;

/**
 * Shows AdMob full-screen ads for the game. GDScript calls start(), then
 * showInterstitial() / showRewarded(), and hears back through signals:
 * interstitial_closed, and rewarded_closed(earned).
 */
public class NeonAds extends GodotPlugin {
    private volatile InterstitialAd interstitial;
    private volatile RewardedAd rewarded;
    private String interstitialId = "";
    private String rewardedId = "";
    private boolean loadingInterstitial;
    private boolean loadingRewarded;
    private boolean earned;

    public NeonAds(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "NeonAds";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new ArraySet<>();
        signals.add(new SignalInfo("interstitial_closed"));
        signals.add(new SignalInfo("rewarded_closed", Boolean.class));
        return signals;
    }

    @UsedByGodot
    public void start(String interstitialUnit, String rewardedUnit) {
        interstitialId = interstitialUnit;
        rewardedId = rewardedUnit;
        Activity activity = getActivity();
        if (activity == null) return;
        activity.runOnUiThread(() -> {
            MobileAds.initialize(activity, status -> { });
            loadInterstitial();
            loadRewarded();
        });
    }

    @UsedByGodot
    public boolean isInterstitialReady() {
        return interstitial != null;
    }

    @UsedByGodot
    public boolean isRewardedReady() {
        return rewarded != null;
    }

    /** Returns false (and asks for a new ad) if none is loaded yet. */
    @UsedByGodot
    public boolean showInterstitial() {
        Activity activity = getActivity();
        InterstitialAd ad = interstitial;
        if (activity == null || ad == null) {
            if (activity != null) activity.runOnUiThread(this::loadInterstitial);
            return false;
        }
        interstitial = null;
        activity.runOnUiThread(() -> {
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    send("interstitial_closed");
                    loadInterstitial();
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                    send("interstitial_closed");
                    loadInterstitial();
                }
            });
            ad.show(activity);
        });
        return true;
    }

    /** Returns false (and asks for a new ad) if none is loaded yet. */
    @UsedByGodot
    public boolean showRewarded() {
        Activity activity = getActivity();
        RewardedAd ad = rewarded;
        if (activity == null || ad == null) {
            if (activity != null) activity.runOnUiThread(this::loadRewarded);
            return false;
        }
        rewarded = null;
        earned = false;
        activity.runOnUiThread(() -> {
            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    send("rewarded_closed", earned);
                    loadRewarded();
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                    send("rewarded_closed", false);
                    loadRewarded();
                }
            });
            ad.show(activity, reward -> earned = true);
        });
        return true;
    }

    private void send(String signal, Object... args) {
        runOnRenderThread(() -> emitSignal(signal, args));
    }

    private void loadInterstitial() {
        Activity activity = getActivity();
        if (activity == null || interstitialId.isEmpty() || interstitial != null || loadingInterstitial) return;
        loadingInterstitial = true;
        InterstitialAd.load(activity, interstitialId, new AdRequest.Builder().build(), new InterstitialAdLoadCallback() {
            @Override
            public void onAdLoaded(@NonNull InterstitialAd ad) {
                interstitial = ad;
                loadingInterstitial = false;
            }

            @Override
            public void onAdFailedToLoad(@NonNull LoadAdError error) {
                loadingInterstitial = false;
            }
        });
    }

    private void loadRewarded() {
        Activity activity = getActivity();
        if (activity == null || rewardedId.isEmpty() || rewarded != null || loadingRewarded) return;
        loadingRewarded = true;
        RewardedAd.load(activity, rewardedId, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override
            public void onAdLoaded(@NonNull RewardedAd ad) {
                rewarded = ad;
                loadingRewarded = false;
            }

            @Override
            public void onAdFailedToLoad(@NonNull LoadAdError error) {
                loadingRewarded = false;
            }
        });
    }

    // ------------------------------------------------------------ banner

    private AdView banner;
    private FrameLayout bannerBox;

    /** Shows a standard banner along the bottom (or top) edge of the screen, over the game. */
    @UsedByGodot
    public void showBanner(String unitId, boolean top) {
        Activity a = getActivity();
        if (a == null || unitId.isEmpty()) return;
        a.runOnUiThread(() -> {
            if (banner == null) {
                banner = new AdView(a);
                banner.setAdUnitId(unitId);
                banner.setAdSize(AdSize.BANNER);
                bannerBox = new FrameLayout(a);
                a.addContentView(bannerBox, new FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                banner.loadAd(new AdRequest.Builder().build());
            }
            if (banner.getParent() == null) {
                bannerBox.addView(banner);
            }
            FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER_HORIZONTAL | (top ? Gravity.TOP : Gravity.BOTTOM));
            banner.setLayoutParams(lp);
            banner.setVisibility(android.view.View.VISIBLE);
            banner.resume();
        });
    }

    @UsedByGodot
    public void hideBanner() {
        Activity a = getActivity();
        if (a == null) return;
        a.runOnUiThread(() -> {
            if (banner != null) {
                banner.setVisibility(android.view.View.GONE);
                banner.pause();
            }
        });
    }

    // ------------------------------------------------------------ reminders

    /** Asks for permission to show notifications (Android 13+ only; older phones allow it). */
    @UsedByGodot
    public void requestNotificationPermission() {
        Activity a = getActivity();
        if (a == null || Build.VERSION.SDK_INT < 33) {
            return;
        }
        if (a.checkSelfPermission("android.permission.POST_NOTIFICATIONS") != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            a.runOnUiThread(() -> a.requestPermissions(new String[]{"android.permission.POST_NOTIFICATIONS"}, 7001));
        }
    }

    /**
     * Replaces the reminders: one a day for the next titles.length days at about [hour]:00.
     * Called every time the game opens or goes to the background, so they stop by
     * themselves when the player hasn't played for that many days.
     */
    @UsedByGodot
    public void scheduleReminders(String[] titles, String[] bodies, int hour) {
        Activity a = getActivity();
        if (a == null) {
            return;
        }
        Context c = a.getApplicationContext();
        AlarmManager am = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (am == null) {
            return;
        }
        for (int day = 1; day <= 7; day++) {
            am.cancel(reminder(c, day, "", ""));
        }
        for (int i = 0; i < titles.length && i < bodies.length; i++) {
            int day = i + 1;
            Calendar when = Calendar.getInstance();
            when.add(Calendar.DAY_OF_YEAR, day);
            when.set(Calendar.HOUR_OF_DAY, hour);
            when.set(Calendar.MINUTE, 0);
            when.set(Calendar.SECOND, 0);
            // inexact on purpose: no special alarm permission needed, and the OS can batch it
            am.set(AlarmManager.RTC_WAKEUP, when.getTimeInMillis(), reminder(c, day, titles[i], bodies[i]));
        }
    }

    private PendingIntent reminder(Context c, int day, String title, String body) {
        Intent i = new Intent(c, ReminderReceiver.class);
        i.putExtra("day", day);
        i.putExtra("title", title);
        i.putExtra("body", body);
        return PendingIntent.getBroadcast(c, 7100 + day, i, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }
}
