using UnityEngine;
using System.Collections;
using System.Runtime.InteropServices;
using System;


public enum ReplayErrorCode
{
    FAIL_TO_START_RECORDING,
    FAIL_TO_STOP_BY_STATE_ALREADYSTOPPING_OR_NONE,
    FAIL_TO_STOP_BY_ERROR,
    FAIL_TO_STOP_BY_OS_ERROR// iOS 11.4 has stop error.
}

public class ReplayKitWrapper
{

    /* Interface to native implementation */

    [DllImport("__Internal")]
    private static extern int _alloc();

    [DllImport("__Internal")]
    private static extern int _dealloc();

    [DllImport("__Internal")]
    private static extern int _startRecording();

    [DllImport("__Internal")]
    private static extern int _stopRecording();

    [DllImport("__Internal")]
    private static extern bool _isRecording();

    [DllImport("__Internal")]
    private static extern bool _failed();

    [DllImport("__Internal")]
    private static extern string _failedReason();


    private enum ReplayState
    {
        NONE,
        RECORDING,
        STOPPING,
    }


    private static ReplayState state = ReplayState.NONE;

    public static IEnumerator StartRecording(float seconds, Action recordStarted, Action recordTimeout, Action recordCompleted, Action<ReplayErrorCode, string> recordFailed)
    {
        switch (state)
        {
            case ReplayState.NONE:
                // pass.
                break;
            default:
                Debug.Log("開始失敗、すでに録画中か停止中");
                yield break;
        }

        switch (_alloc())
        {
            case 0:// 初期化
            case 1:// 初期化済みなのでpass.
                break;
            default:
                // 異常値なので、終了させる。
                Debug.Log("初期化に失敗");
                yield break;
        }

        var code = 0;
        if ((code = _startRecording()) != 0)
        {
            Debug.Log("レコーディング開始失敗 code:" + code);
            recordFailed(ReplayErrorCode.FAIL_TO_START_RECORDING, "failed to start recording. code:" + code);
            yield break;
        }

        while (!_isRecording())
        {
            yield return null;
        }

        state = ReplayState.RECORDING;
        recordStarted();

        // 指定の秒数待つ。
        var date = DateTime.Now;
        while ((DateTime.Now - date).TotalSeconds < seconds)
        {
            switch (state)
            {
                case ReplayState.RECORDING:
                    // continue.
                    yield return null;
                    break;
                default:
                    // プレイヤーが自分でストップを押した場合ここにくる(stopのハンドラは別のルートで着火している)
                    yield break;
            }
        }

        // 一定時間突破時点、この時点でレコーディングが完了していれば、終了
        if (!_isRecording())
        {
            yield break;
        }

        // タイムアウトを発生させる
        recordTimeout();

        // この時点でStopをできないようにする
        var cor = StopRecording(recordCompleted, recordFailed);
        while (cor.MoveNext())
        {
            // 停止完了するまで待つ
            if (_failed())
            {
                // stateはstop側で設定されてる。
                yield break;
            }
            yield return null;
        }
    }

    public static IEnumerator StopRecording(Action stopCompleted, Action<ReplayErrorCode, string> stopFailed)
    {
        switch (state)
        {
            case ReplayState.RECORDING:
                break;
            default:
                stopFailed(ReplayErrorCode.FAIL_TO_STOP_BY_STATE_ALREADYSTOPPING_OR_NONE, "state is " + state);
                yield break;
        }

        state = ReplayState.STOPPING;

        var code = 0;
        if ((code = _stopRecording()) != 0)
        {
            state = ReplayState.NONE;
            stopFailed(ReplayErrorCode.FAIL_TO_STOP_BY_ERROR, "failed to stop recording. code:" + code);
            yield break;
        }

        while (_isRecording())
        {
            if (_failed())
            {
                state = ReplayState.NONE;
                stopFailed(ReplayErrorCode.FAIL_TO_STOP_BY_OS_ERROR, "failed to stop recording. reason:" + _failedReason());
                yield break;
            }
            yield return null;
        }

        state = ReplayState.NONE;
        stopCompleted();
    }


}
