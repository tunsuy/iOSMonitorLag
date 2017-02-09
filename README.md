# iOSMonitorLag

## 方案一 基于RunLoop

因为UIKit本身的特性,需要将所有的UI操作都放在主线程执行,所以也造成不少程序员都习惯将一些线程安全性不确定的逻辑,以及其它线程结束后的汇总工作等等放到了主线,所以主线程中包含的这些大量计算、IO、绘制都有可能造成卡顿.

在Xcode中已经集成了非常方便的调试工具Instruments,它可以帮助我们在开发测试阶段分析软件运行的性能消耗

监控卡顿,最直接就是找到主线程都在干些啥玩意儿.我们知道一个线程的消息事件处理都是依赖于NSRunLoop来驱动,所以要知道线程正在调用什么方法,就需要从NSRunLoop来入手

发现NSRunLoop调用方法主要就是在kCFRunLoopBeforeSources和kCFRunLoopBeforeWaiting之间,还有kCFRunLoopAfterWaiting之后,也就是如果我们发现这两个时间内耗时太长,那么就可以判定出此时主线程卡顿.

这种方式，当主线程中注册了timer等很多附加的东西时，会不断唤醒主线程，就会大量的调用observer回调，造成一定程度上的性能损耗

## 方案二 基于线程

简单来说，主线程为了达到接近60fps的绘制效率，不能在UI线程有单个超过（1/60s≈16ms）的计算任务。通过Instrument设置16ms的采样率可以检测出大部分这种费时的任务，但有以下缺点：

Instrument profile一次重新编译，时间较长。
只能针对特定的操作场景进行检测，要预先知道卡顿产生的场景。
每次猜测，更改，再猜测再以此循环，需要重新profile。
我们的目标方案是，检测能够自动发生，并不需要开发人员做任何预先配置或profile。运行时发现卡顿能即时通知开发人员导致卡顿的函数调用栈。

最理想的方案是让UI线程“主动汇报”当前耗时的任务，听起来简单做起来不轻松。

我们可以假设这样一套机制：每隔16ms让UI线程来报道一次，如果16ms之后UI线程没来报道，那就一定是在执行某个耗时的任务。

## 在项目中接入

将相关文件导入项目中，
在AppDelegate.m中开始监控：
[[PMainThreadWatcher sharedInstance] startWatch];  //方案一
[[DetectedRunLoop sharedInstance] startDetect];  //方案二
[[DetectedRunLoop_Other sharedInstance] startDetect];  // 方案二的另种实现方式

下面是以接入口袋助理测试的效果图

但是像在口袋助理这样大型负责的项目中，这些方法都存在一些弊端，监测出来的也不一定是真的由于代码问题引起的，
这只是可以作为一种自动提醒机制，让开发者自行去检查下提示的代码是否真的存在性能缺陷

