# ReplayKitWrapper

iOS ReplayKit Wrapper for Unity 2017 or later.  
written in almost pure swift4.


## Usage
let's start recording, then stop recording.  
 or, just wait the timeout of started recording.

### Start the recording with timelimit(seconds).
```csharp
runner.StartCoroutine(
    ReplayKitWrapper.StartRecording(
        10,
        () => Debug.Log("start."),// fire when the recording is started.
        rest => Debug.Log("rest:" + rest),// rest time(seconds) against timelimit.
        () => Debug.Log("timeout."),// fire when timeout occuered. process to complete.
        () => Debug.Log("timeout completed."),// fire when timeout completed.
        (errorCode, reason) => Debug.Log("timeout errorCode:" + errorCode + " reason:" + reason)// fire when error occurred.
    )
);
```

### Stop the recording.
```csharp
runner.StartCoroutine(
    ReplayKitWrapper.StopRecording(
        () => Debug.Log("stpped."),// fire when recording finished without any error.
        (errorCode, reason) => Debug.Log("stop errorCode:" + errorCode + " reason:" + reason)// fire when error occurred.
    )
);
```

