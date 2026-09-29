package com.qingmang.qingmang_weiji

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.InputMethodInfo
import android.view.inputmethod.InputMethodManager
import android.view.inputmethod.InputMethodSubtype
import android.widget.FrameLayout
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var keyboardChannel: MethodChannel? = null
    private var systemChannel: MethodChannel? = null
    private var insetsChannel: MethodChannel? = null
    private var volumeTurnEnabled = false

    /**
     * 切英文之前用户正在用的输入法与子类型。
     *
     * 非空表示"当前处于我们切换过的状态"，离开学习页时要还原回去。
     * 只记第一次，避免每道题都覆盖成"已经是英文"的状态。
     */
    private var originalImeId: String? = null
    private var originalSubtype: InputMethodSubtype? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        //Android 12+ 启动屏 API，统一启动画面
        installSplashScreen()
        super.onCreate(savedInstanceState)
        //edge-to-edge 全屏布局，由 Flutter 侧处理安全区内边距
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "qingmang_weiji/reader_volume"
        ).also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "setEnabled") {
                    volumeTurnEnabled = call.argument<Boolean>("enabled") ?: false
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }

        //拼写 / 听力要求输入英文单词，这里配合 Dart 侧把输入法切到英文
        keyboardChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "qingmang_weiji/keyboard"
        ).also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "switchToEnglish") {
                    switchToEnglishSubtype()
                    result.success(null)
                } else if (call.method == "restore") {
                    restoreInputMethod()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }

        //系统设置跳转（通知权限被拒后，从提醒开关的报错提示里直接带用户过去）
        systemChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "qingmang_weiji/system"
        ).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    //跳转是否成功如实回传（此前无条件返回 true，
                    //ROM 拦截时 Dart 侧也会以为已经打开了设置页）
                    "openNotificationSettings" -> result.success(openNotificationSettings())
                    //国产 ROM 缺英文语音数据时，引导用户去系统语音设置安装引擎
                    "openTtsSettings" -> result.success(openTtsSettings())
                    //每日提醒受 Doze/省电策略影响，引导用户关闭电池优化
                    "openBatterySettings" -> result.success(openBatterySettings())
                    else -> result.notImplemented()
                }
            }
        }

        setupInsetsProbe(flutterEngine)
    }

    /**
     * 挖孔 / 状态栏 insets 探针（配合 Dart 侧 InsetsProbe）。
     *
     * Flutter 引擎在部分 ROM 的沉浸式下仍把 padding.top 报告成整条状态栏
     * 高度，Dart 侧无法区分"状态栏"与"摄像头挖孔"。这里挂一个 0x0 的旁路
     * View 读取原生 WindowInsets：不参与布局，也不拦截 Flutter 自身的
     * insets 分发（listener 原样返回 insets）。insets 变化（旋转、分屏、
     * 系统栏显隐）都会重新上报，Dart 侧据此计算真正的顶部避让。
     */
    private fun setupInsetsProbe(flutterEngine: FlutterEngine) {
        insetsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "qingmang_weiji/insets"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "get") {
                    //兜底查询：Dart 侧 handler 注册晚了会漏掉首帧前的推送
                    val payload = currentInsetsPayload()
                    if (payload != null) result.success(payload) else result.success(null)
                } else {
                    result.notImplemented()
                }
            }
            val probe = View(this)
            ViewCompat.setOnApplyWindowInsetsListener(probe) { _, insets ->
                channel.invokeMethod("onInsets", insetsPayload(insets))
                insets
            }
            addContentView(probe, FrameLayout.LayoutParams(0, 0))
        }
    }

    /** 把原生 insets 换算成 Dart 侧逻辑像素（dp）的上报结构 */
    private fun insetsPayload(insets: WindowInsetsCompat): Map<String, Any?> {
        val density = resources.displayMetrics.density
        val cutout = insets.getInsets(WindowInsetsCompat.Type.displayCutout())
        val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
        return mapOf(
            "cutoutTop" to cutout.top / density,
            "statusBarTop" to bars.top / density,
            //状态栏当前是否真的可见（分屏 / 临时唤出通知栏时为 true）。
            //不能用 bars.top > 0 判断：沉浸式下多数 ROM 仍上报非零的
            //systemBars insets，那样会把已隐藏的状态栏整条高度白白避让出来
            "statusBarVisible" to insets.isVisible(WindowInsetsCompat.Type.statusBars())
        )
    }

    private fun currentInsetsPayload(): Map<String, Any?>? {
        val insets = ViewCompat.getRootWindowInsets(window.decorView) ?: return null
        return insetsPayload(insets)
    }

    /**
     * 打开本应用的通知设置页。
     *
     * Android 8+ 有专属的"应用通知"设置页；更早的版本没有，
     * 退而打开应用详情页（里面同样能找到通知开关）。
     * 个别 ROM 会拦截这类跳转，此时返回 false，由 Dart 侧决定如何提示。
     */
    private fun openNotificationSettings(): Boolean {
        val appDetails = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        val primary = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            appDetails
        }
        return startFirstAvailable(listOf(primary, appDetails))
    }

    /**
     * 依次尝试启动候选 Intent，任一成功即返回 true。
     *
     * 这些系统设置页在不同 ROM 上存在性不一，且可能被拦截；
     * 逐个尝试并静默降级，避免任何一次跳转失败影响到应用本身。
     */
    private fun startFirstAvailable(intents: List<Intent>): Boolean {
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (t: Throwable) {
                //换下一个候选页面
            }
        }
        return false
    }

    /**
     * 打开系统的"文字转语音输出"设置页。
     *
     * 国产 ROM 常缺英文语音数据，用户需要在这里安装/选择语音引擎。
     * 该页面没有公开常量（AOSP 用的是 com.android.settings.TTS_SETTINGS），
     * 个别 ROM 无此页面时退到应用详情页。
     */
    private fun openTtsSettings(): Boolean = startFirstAvailable(
        listOf(
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
    )

    /**
     * 打开电池优化设置页。
     *
     * Android 6+ 的 Doze 与国产 ROM 的省电策略会延迟甚至拦截每日提醒的闹钟；
     * 这里跳系统"电池优化"列表让用户把本应用设为"不优化"。
     * 不使用 ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 是为了避免申请
     * REQUEST_IGNORE_BATTERY_OPTIMIZATIONS 权限（商店审核敏感）。
     */
    private fun openBatterySettings(): Boolean = startFirstAvailable(
        listOf(
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        )
    )

    /**
     * 兜底还原输入法。
     *
     * Dart 侧离开学习页时会主动调 restore；这里是进程/界面销毁前的最后一道保险：
     * 例如用户直接在拼写题里杀掉 App，若不做这一步，系统输入法会一直停在我们
     * 切过去的英文输入法上。
     */
    override fun onDestroy() {
        restoreInputMethod()
        //清理通道：handler lambda 隐式持有本 Activity，若将来改用
        //FlutterEngineCache 预热引擎，不清理会导致 Activity 无法回收
        channel?.setMethodCallHandler(null)
        keyboardChannel?.setMethodCallHandler(null)
        systemChannel?.setMethodCallHandler(null)
        //insetsChannel 的 handler 会调用 currentInsetsPayload()/insetsPayload()，
        //这两个方法都是本 Activity 的成员（隐式持有 this），同样必须清掉
        insetsChannel?.setMethodCallHandler(null)
        super.onDestroy()
    }

    /**
     * 离开前台时立即解除音量键拦截。
     *
     * 只依赖 Dart 侧 dispose 通知是不够的：只要有一次通道消息丢失
     * （引擎重建、Dart 异常、进程生命周期错乱），本应用就会在**全局范围**
     * 继续吞掉音量键 —— 用户连系统音量条都调不出来，且没有任何自愈路径。
     * Dart 侧回到前台会按当前设置重新下发（见阅读器的生命周期回调）。
     */
    override fun onPause() {
        volumeTurnEnabled = false
        super.onPause()
    }

    /**
     * 阅读模式下拦截音量键，转为翻页事件回传 Flutter。
     *
     * 长按音量键时系统会持续投递 repeatCount > 0 的重复事件，这里连同
     * 后续事件一起吞掉（不再翻页，也不让系统调音量），否则按住不放会连翻几十页。
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeTurnEnabled) {
            val isVolumeKey = keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
                keyCode == KeyEvent.KEYCODE_VOLUME_UP
            if (isVolumeKey) {
                if ((event?.repeatCount ?: 0) > 0) return true
                val direction = if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) 1 else -1
                channel?.invokeMethod("onVolumeKey", mapOf("direction" to direction))
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    /**
     * 把输入法切到英文，两级策略：
     *
     * 1. 优先切**当前输入法**自带的英文子类型（Gboard / 搜狗 等大多有），
     *    输入法应用保持不变，体感最轻；
     * 2. 当前输入法没有英文子类型时，退而在用户已启用的其它输入法里找一个
     *    带英文子类型的切过去——这是"兜底"路径，会真的换掉系统输入法，
     *    所以同时记下原来的输入法与子类型，离开学习页时还原（见 [restoreInputMethod]）。
     *
     * 两级都不成时直接放弃，交给 Dart 侧的 visiblePassword 键盘类型兜底。
     *
     * 注意：**Android 9（API 28）及以上这条路径注定无效**（原因见 [applySubtype]），
     * 现代机型上实际由 Dart 侧的 visiblePassword 键盘类型保证只出英文候选，
     * 这里直接提前返回，省掉一次无意义的反射调用与输入法闪动。
     */
    private fun switchToEnglishSubtype() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) return
        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                ?: return
            val currentImeId = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.DEFAULT_INPUT_METHOD
            ) ?: return
            val imeInfo = imm.enabledInputMethodList.firstOrNull { it.id == currentImeId }
                ?: return

            //已经是英文子类型就不用再切，避免输入法面板闪一下
            val current = imm.currentInputMethodSubtype
            if (current != null && isEnglishSubtype(current)) return

            //第一级：当前输入法自己的英文子类型
            val ownEnglish = enabledSubtypes(imm, imeInfo)
                ?.firstOrNull { !it.isAuxiliary && isEnglishSubtype(it) }
            if (ownEnglish != null) {
                rememberOriginal(imeId = currentImeId, subtype = current)
                applySubtype(imm, currentImeId, ownEnglish)
                return
            }

            //第二级：换到别的英文输入法
            val fallback = findEnglishInputMethod(imm, exceptImeId = currentImeId) ?: return
            rememberOriginal(imeId = currentImeId, subtype = current)
            applySubtype(imm, fallback.first, fallback.second)
        } catch (t: Throwable) {
            //系统拒绝或输入法不支持：静默失败
        }
    }

    /** 只在第一次切换时记录原始状态，后续切题不要覆盖 */
    private fun rememberOriginal(imeId: String, subtype: InputMethodSubtype?) {
        if (originalImeId != null) return
        originalImeId = imeId
        originalSubtype = subtype
    }

    /**
     * 还原到切换前的输入法。
     *
     * 优先按原输入法 + 原子类型还原；子类型取不到（被禁用、语言包被删）时退而
     * 找该输入法里的第一个非英文子类型，至少把输入法应用换回来，不至于让用户
     * 只能打英文。
     */
    private fun restoreInputMethod() {
        val imeId = originalImeId
        val subtype = originalSubtype
        originalImeId = null
        originalSubtype = null
        if (imeId == null) return

        try {
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
                ?: return
            val imeInfo = imm.enabledInputMethodList.firstOrNull { it.id == imeId } ?: return

            if (subtype != null && applySubtype(imm, imeId, subtype)) return

            val chineseBack = enabledSubtypes(imm, imeInfo)
                ?.firstOrNull { !it.isAuxiliary && !isEnglishSubtype(it) }
                ?: return
            applySubtype(imm, imeId, chineseBack)
        } catch (t: Throwable) {
            //还原失败只能靠用户手动切换，不影响答题
        }
    }

    /**
     * 在已启用的输入法里找一个可用的英文候选。
     *
     * 排除当前输入法本身，也排除语音输入之类的辅助输入法——切过去只会更麻烦。
     */
    private fun findEnglishInputMethod(
        imm: InputMethodManager,
        exceptImeId: String
    ): Pair<String, InputMethodSubtype>? {
        for (ime in imm.enabledInputMethodList) {
            if (ime.id == exceptImeId) continue
            if (ime.id.contains("voice", ignoreCase = true)) continue
            val english = enabledSubtypes(imm, ime)
                ?.firstOrNull { !it.isAuxiliary && isEnglishSubtype(it) }
                ?: continue
            return ime.id to english
        }
        return null
    }

    /**
     * 调用 `setInputMethodAndSubtype` 切换到指定子类型（仅 Android 8 及以下可用）。
     *
     * 该 API 在 Android 9（API 28）被标记废弃，且系统侧加了权限校验：
     * 普通三方应用调用会被 InputMethodManagerService 直接忽略 —— **只写一条日志、
     * 不抛异常**，因此无法从返回值判断结果；3 参重载要求的 token 是"输入法自身的
     * token"，应用也拿不到（传 Activity 的 windowToken 一定被忽略）。
     *
     * 结论：28+ 直接返回 false（由调用方提前拦截），不再假装成功。
     * 该方法只有旧设备才会真正走到。
     */
    private fun applySubtype(
        imm: InputMethodManager,
        imeId: String,
        subtype: InputMethodSubtype
    ): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) return false
        val methods = try {
            InputMethodManager::class.java.methods.filter {
                it.name == "setInputMethodAndSubtype"
            }
        } catch (t: Throwable) {
            return false
        }

        for (method in methods) {
            try {
                when (method.parameterTypes.size) {
                    2 -> method.invoke(imm, imeId, subtype)
                    3 -> method.invoke(imm, window.decorView.windowToken, imeId, subtype)
                    else -> continue
                }
                return true
            } catch (t: Throwable) {
                //换下一个签名继续试
            }
        }
        return false
    }

    private fun isEnglishSubtype(subtype: InputMethodSubtype): Boolean {
        return try {
            val tag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                subtype.languageTag
            } else {
                ""
            }
            @Suppress("DEPRECATION")
            val locale = subtype.locale
            tag.startsWith("en", ignoreCase = true) ||
                (tag.isEmpty() && locale.startsWith("en", ignoreCase = true))
        } catch (t: Throwable) {
            false
        }
    }

    /**
     * 读取某个输入法已启用的子类型列表。
     *
     * getEnabledInputMethodSubtypeList 在 AOSP 里是 @hide，但很多 ROM 仍可反射调用；
     * 被隐藏 API 限制拦下时返回 null，调用方据此放弃切换。
     */
    private fun enabledSubtypes(
        imm: InputMethodManager,
        imeInfo: InputMethodInfo
    ): List<InputMethodSubtype>? {
        return try {
            val method = InputMethodManager::class.java.getMethod(
                "getEnabledInputMethodSubtypeList",
                InputMethodInfo::class.java,
                Boolean::class.javaPrimitiveType
            )
            @Suppress("UNCHECKED_CAST")
            method.invoke(imm, imeInfo, true) as? List<InputMethodSubtype>
        } catch (t: Throwable) {
            null
        }
    }
}
