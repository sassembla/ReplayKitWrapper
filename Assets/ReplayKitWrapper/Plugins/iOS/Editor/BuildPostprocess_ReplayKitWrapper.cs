using UnityEngine;
using UnityEditor;
using UnityEditor.Callbacks;

#if UNITY_IOS
using UnityEditor.iOS.Xcode;

public static class BuildPostprocess_ReplayKitWrapper// 生成で独自の名前をつける必要がありそう
{
    [PostProcessBuild(999)]
    public static void OnPostProcessBuild(BuildTarget buildTarget, string path)
    {
        if (buildTarget == BuildTarget.iOS)
        {
            var pluginName = "ReplayKitWrapper";
            var projectPath = path + "/Unity-iPhone.xcodeproj/project.pbxproj";

            var pbxProject = new PBXProject();
            pbxProject.ReadFromFile(projectPath);

            var target = pbxProject.TargetGuidByName("Unity-iPhone");

            // 存在しているプラグイン名のヘッダを読み込む。
            pbxProject.SetBuildProperty(target, "SWIFT_OBJC_BRIDGING_HEADER", "Libraries/Libraries/" + pluginName + "/Plugins/iOS/bridging-header-Swift.h");

            // この名前で共通のObj-C-Swift間のインターフェースとなるヘッダを指定する。
            pbxProject.SetBuildProperty(target, "SWIFT_OBJC_INTERFACE_HEADER_NAME", "Unity-Swift.h");

            // swiftのバージョン設定
            pbxProject.SetBuildProperty(target, "SWIFT_VERSION", "4.1");

            // リンクサーチパスを追加する。
            pbxProject.AddBuildProperty(target, "LD_RUNPATH_SEARCH_PATHS", "@executable_path/Frameworks");

            pbxProject.WriteToFile(projectPath);
        }
    }
}
#endif