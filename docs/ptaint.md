# ptaint

## Introduction

主要是根据ptaint这篇论文的思想，将指针分析和污点分析统一起来进行分析，建议先学习下面三份资料

- https://yanniss.github.io/ptaint-oopsla17-prelim.pdf
  - https://www.youtube.com/watch?v=IA08d-kiCy8
- https://pascal-group.bitbucket.io/lectures/Security.pdf

污点分析：which sources can reach which sinks

指针分析：which object sources can reach which variables

指针分析是计算指针在运行过程中可能指向哪些对象，也可以理解为创建之后的对象，会传播到哪些指针。

```java
A a = new A("foo"); // object created
if (*)
   aa = a;          // flows locally
B b = foo(a);       // flows in/out via stack
b.parent = a;       // stored/loaded on heap
```

污点分析是计算sink函数的参数是否是污点，也可以理解为污点源会传播到哪些指针

```java
String a = source.readLine(); // taint source
if (*)
   aa = a;          // flows locally
B b = foo(a);       // flows in/out via stack
b.parent = a;       // stored/loaded on heap
```

两者可以统一成，值在指针之间的传播，也就是在PFG(Pointer Flow Graph)中传播

污点分析和指针分析还多了一些东西，比如污点转移，以及污点消除(净化函数)

```java
String a = source.readLine(); // taint source
if (*)
   aa = a;          // flows locally
B b = foo(a);       // flows in/out via stack
b.parent = a;       // stored/loaded on heap

byte[] aAsbytes = a.getBytes(); // transfer

String aSafe = URLEncoder.encode(a, "UTF-8"); // sanitize
```

Ptaint论文中将污点视为独立的对象，而不是给传统的对象打上污点标记，会创建新的污点对象，和传统的对象分开各自独立沿着相同的PFG传播



按照论文中的给的示例规则得到的实现

[ptaint.dl](https://github.com/BytecodeDL/ByteCodeDL/blob/ptaint/logic/ptaint.dl) 

```dl
.comp PTaint{
    // 指针分析原有的relation
    .decl VarPointsTo(heap:Heap, var:Var)
    .decl InstanceFieldPointsTo(heap:Heap, baseHeap:Heap, field:Field)
    .decl CallGraph(insn:Insn, caller:Method, callee:Method)
    .decl Reachable(method:Method)
    .decl InterProcAssign(from:Var, to:Var)
		
		// 污点分析相关的新relation
		// 表示通过insn指令，创建的新的污点对象heap，包括污点源的生成，以及污点转移时的生成
    .decl TaintHeap(insn:Insn, heap:Heap)
    // 表示调用指令insn发生时，危险函数的参数指向了污点对象heap
    .decl Leak(insn:Insn, heap:Heap)
    // 表示source函数，其返回值表示污点源
    .decl SourceMethod(method:Method)
    // 表示sink函数，其第n个实际参数如果指向污点对象，则表示可能存在安全风险
    .decl SinkMethod(method:Method, n:number)
		// 表示sanitize函数，经过其处理的污点，将不再是污点，也就是说污点无法通过sanitize传播，是在实际参数向形式参数传播时阻断的
    .decl SanitizeMethod(method:Method)
    // 表示sanitize函数的形式参数
    .decl SanitizeMethodParam(var:Var)
		// 筛选出sanitize函数的形式参数
    SanitizeMethodParam(var) :-
        FormalParam(_, method, var),
        SanitizeMethod(method).
		
		// 污点转移相关的
		// base 是 污点 返回值也是污点
    .decl BaseToRetTransfer(method:Method)
    // 参数是污点返回也是污点
    .decl ArgToRetTransfer(method:Method, n:number)
    // 将上面两个合并成一个，或者将污点转移抽象成from变量污染了to变量
    .decl IsTaintedFrom(insn:Insn, from:Var, to:Var)
    // heap 对象 污染了 newHeap对象
    .decl TransferTaint(heap:Heap, newHeap:Heap)
    

    // new
    VarPointsTo(heap, var) :-
        Reachable(method),
        AssignHeapAllocation(_, _, heap, var, method, _).
    
    // assign
    VarPointsTo(heap, to) :- 
        Reachable(method),
        VarPointsTo(heap, from),
        AssignLocal(_, _, from, to, method).
    
    // load field
    VarPointsTo(heap, to) :-
        Reachable(method),
        LoadInstanceField(_, _, to, base, field, method),
        VarPointsTo(baseHeap, base),
        InstanceFieldPointsTo(heap, baseHeap, field).
    
    // store field
    InstanceFieldPointsTo(heap, baseHeap, field) :-
        Reachable(method),
        StoreInstanceField(_, _, from, base, field, method),
        VarPointsTo(heap, from),
        VarPointsTo(baseHeap, base).
    
    // virtual call
    Reachable(callee),
    CallGraph(insn, caller, callee) :- 
        Reachable(caller),
        VirtualMethodInvocation(insn, _, method, base, caller),
        VarPointsTo(baseHeap, base),
        NormalHeap(baseHeap, class),
        MethodInfo(method, simplename, _, _, _, descriptor, _),
        Dispatch(simplename, descriptor, class, callee).
    
    // arg -> param
    InterProcAssign(arg, param) :-
        CallGraph(insn, _, callee),
        ActualParam(n, insn, arg),
        FormalParam(n, callee, param).
    
    // var -> return
    InterProcAssign(var, return) :-
        CallGraph(insn, _, callee),
        Return(_, _, var, callee),
        AssignReturnValue(insn, return).

    // normal heap
    // 正常对象正常传播
    VarPointsTo(heap, to) :- 
        InterProcAssign(from, to),
        VarPointsTo(heap, from),
        // 比起指针分析多了个这个限制，用于限制heap为正常对象
        NormalHeap(heap, _).
    
    // taint heap
    // 阻断污点对象传播到净化函数的形式参数
    VarPointsTo(heap, to) :- 
        InterProcAssign(from, to),
        VarPointsTo(heap, from),
        TaintHeap(_, heap),
        !SanitizeMethodParam(to).
    
    // this
    VarPointsTo(heap, this) :-
        CallGraph(insn, _, callee),
        VirtualMethodInvocation(insn, _, _, base, _),
        VarPointsTo(heap, base),
        ThisVar(callee, this).
    
    // 污点对象的生成
    TaintHeap(insn, heap),
    VarPointsTo(heap, to) :-
        SourceMethod(callee),
        CallGraph(insn, _, callee),
        AssignReturnValue(insn, to),
        heap = cat("NewTainted::", insn).
    
    // 判断sink函数的参数是否指向污点对象
    Leak(insn, heap) :-
        CallGraph(insn, _, callee),
        SinkMethod(callee, n),
        ActualParam(n, insn, arg),
        VarPointsTo(heap, arg),
        TaintHeap(_, heap).
		
		// base -> ret
    IsTaintedFrom(insn, base, ret) :-
        CallGraph(insn, _, callee),
        BaseToRetTransfer(callee),
        VirtualMethodInvocation(insn, _, _, base, _),
        AssignReturnValue(insn, ret).
    // arg -> ret
    IsTaintedFrom(insn, arg, ret) :-
        CallGraph(insn, _, callee),
        ArgToRetTransfer(callee, n),
        ActualParam(n, insn, arg),
        AssignReturnValue(insn, ret).
		
		// 污点转移
		// from 指向了污点对象heap
		// 且from能污染to
		// 那么to也是污点对象，也要指向一个污点对象
		// 这里没有直接让to指向新创建的污点对象
		// 而是先找到to指向的正常对象oldHeap，oldHeap第一个流向的指针var，然后让newHeap也流向指针var，即var指向newHeap
		// 由于oldHeap流向var之后，通过PFG可以流到to，那么newHeap也能流到to，这样也把和var alias的指针一并污染了
    TaintHeap(insn, newHeap),
    TransferTaint(heap, newHeap),
    VarPointsTo(newHeap, var) :- 
        IsTaintedFrom(insn, from, to),
        VarPointsTo(heap, from),
        TaintHeap(_, heap),
        newHeap = cat("TransferTaint::", insn),
        VarPointsTo(oldHeap, to),
        AssignHeapAllocation(_, _, oldHeap, var, _, _).
}
```

[ptaint-example-1.dl](https://github.com/BytecodeDL/ByteCodeDL/blob/ptaint/example/ptaint-example-1.dl)

```
#include "inputDeclaration.dl"
#include "utils.dl"
#include "ptaint.dl"

.init ptaint = PTaint

ptaint.Reachable("<com.bytecodedl.benchmark.demo.TaintDemo3: void main(java.lang.String[])>").

ptaint.SourceMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Source()>").
ptaint.SinkMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: void Sink(java.lang.String)>", 0).

ptaint.BaseToRetTransfer("<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>").
ptaint.BaseToRetTransfer("<java.lang.StringBuilder: java.lang.String toString()>").

ptaint.ArgToRetTransfer("<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>", 0).

ptaint.SanitizeMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Sanitize(java.lang.String)>").


.decl TaintVar(var:Var)

TaintVar(var) :-
    ptaint.VarPointsTo(heap, var),
    ptaint.TaintHeap(_, heap).

.output TaintVar

.output ptaint.TaintHeap
.output ptaint.TransferTaint
.output ptaint.VarPointsTo
```

可以看到大部分的规则都是和指针分析一样的，那么我能不能利用之前实现的[pt-noctx.dl](https://github.com/BytecodeDL/ByteCodeDL/blob/pt-noctx/logic/pt-noctx.dl)呢？答案是可以的，但是有一处要稍微改一下就是

```
// param
VarPointsTo(heap, param) :- 
    CallGraph(insn, _, callee),
    ActualParam(n, insn, arg),
    FormalParam(n, callee, param),
    VarPointsTo(heap, arg),
    // 在实际参数向形式参数传播的时候，正常的对象可以任意传播，污点对象还需要考虑被sanitize阻断的问题
    NormalHeap(heap, _).
```

更改后的[pt-noctx.dl](https://github.com/BytecodeDL/ByteCodeDL/blob/ptaint-upgrade/logic/pt-noctx.dl)

更新后的[ptaint.dl](https://github.com/BytecodeDL/ByteCodeDL/blob/ptaint-upgrade/logic/ptaint.dl)

```dl
#include "pt-noctx.dl"

.comp PTaint{
		// 实例上下文无关指针分析
    .init cipt = ContextInsensitivePt
		
		// 定义污点分析相关的
    .decl TaintHeap(insn:Insn, heap:Heap)
    .decl SourceMethod(method:Method)
    .decl SinkMethod(method:Method, n:number)

    .decl SanitizeMethod(method:Method)

    .decl BaseToRetTransfer(method:Method)
    .decl ArgToRetTransfer(method:Method, n:number)
    .decl IsTaintedFrom(insn:Insn, from:Var, to:Var)
    .decl TransferTaint(heap:Heap, newHeap:Heap)
    
    // 阻止污点对象传播到sanitize函数的形式参数
    // taint arg to param
    cipt.VarPointsTo(heap, param) :- 
        cipt.CallGraph(insn, _, callee),
        ActualParam(n, insn, arg),
        FormalParam(n, callee, param),
        cipt.VarPointsTo(heap, arg),
        TaintHeap(_, heap),
        !SanitizeMethod(callee).
    
    
    TaintHeap(insn, heap),
    cipt.VarPointsTo(heap, to) :-
        SourceMethod(callee),
        cipt.CallGraph(insn, _, callee),
        AssignReturnValue(insn, to),
        heap = cat("NewTainted::", insn).

    IsTaintedFrom(insn, base, ret) :-
        cipt.CallGraph(insn, _, callee),
        BaseToRetTransfer(callee),
        VirtualMethodInvocation(insn, _, _, base, _),
        AssignReturnValue(insn, ret).
    
    IsTaintedFrom(insn, arg, ret) :-
        cipt.CallGraph(insn, _, callee),
        ArgToRetTransfer(callee, n),
        ActualParam(n, insn, arg),
        AssignReturnValue(insn, ret).

    TaintHeap(insn, newHeap),
    TransferTaint(heap, newHeap),
    cipt.VarPointsTo(newHeap, var) :- 
        IsTaintedFrom(insn, from, to),
        cipt.VarPointsTo(heap, from),
        TaintHeap(_, heap),
        newHeap = cat("TransferTaint::", insn),
        cipt.VarPointsTo(oldHeap, to),
        AssignHeapAllocation(_, _, oldHeap, var, _, _).
}
```



## Example 1

我们先分析Benchmark中的[TaintDemo3](https://github.com/BytecodeDL/Benchmark/blob/main/src/main/java/com/bytecodedl/benchmark/demo/TaintDemo3.java)

```java
public class TaintDemo3 {
    public static void main(String[] args) {
        TaintDemo3 demo = new TaintDemo3();
        String name = demo.Source();
        demo.test1(name);
    }

    public void test1(String name){
        String sql0= "select * from user where name='" + name + "'";
        String sql1 = sql0;
        String sql = Sanitize(sql1);
        Sink(sql);
    }

    public void Sink(String param){

    }

    public String Sanitize(String param){
        String ret = param.replace('\'', '`');
        return ret;
    }

    public String Source(){
        return "tainted name";
    }
}
```

执行

```bash
// 代码下载到本地
git clone git@github.com:BytecodeDL/Benchmark.git
// 打包
mvn clean package
// 切换目录
cd target
// 生成facts
java8 -jar ~/code/soot-fact-generator/build/libs/soot-fact-generator.jar -i Benchmark-1.0-SNAPSHOT.jar --full -l /Library/Java/JavaVirtualMachines/jdk1.8.0_211.jdk/Contents/Home/jre/lib/rt.jar -d tainttest --allow-phantom --generate-jimple
// 切换目录
cd tainttest
// 执行souffle
souffle -I ~/code/ByteCodeDL/logic -F . -D output ~/code/ByteCodeDL/example/ptaint-example-1.dl
```

然后在ouput目录能够看到`grep "Demo3" TaintVar.csv`结果

```
<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>/@parameter0
<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>/$stack5
<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>/$stack6
<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>/$stack7
<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>/$stack8
<com.bytecodedl.benchmark.demo.TaintDemo3: void main(java.lang.String[])>/name#_6
<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>/name#_0
<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>/sql1#_12
<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>/sql0#_11
```

可以看到sql1和sql0都是污点，sql不是污点，比较符合我们的预期。

下面介绍如何编写出[ptaint-example-1.dl](https://github.com/BytecodeDL/ByteCodeDL/blob/ptaint-upgrade/example/ptaint-example-1.dl)

首先要实例化Ptaint 并 初始化污点分析的起始方法，在这里起始方法，也就是分析的入口，为TaintDemo3的main函数

```
// 实例化ptaint
.init ptaint = PTaint

// 初始化上下文无关文法的入口函数
ptaint.cipt.Reachable("<com.bytecodedl.benchmark.demo.TaintDemo3: void main(java.lang.String[])>").
```

然后定义Source，Sink和Sanitize函数

```
// 定义source函数
ptaint.SourceMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Source()>").
// 定义危险函数
ptaint.SinkMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: void Sink(java.lang.String)>", 0).
// 定义净化函数
ptaint.SanitizeMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Sanitize(java.lang.String)>").
```

接下来就是定义污点转移函数了，这时候只看java代码看不出来东西，这时候需要看soot生成的jimple代码，也就是下面的代码

```jimple
 public void test1(java.lang.String)
    {
        java.lang.StringBuilder $stack5, $stack6, $stack7, $stack8;
        java.lang.String name#_0, sql0#_11, sql1#_12, sql#_13;
        com.bytecodedl.benchmark.demo.TaintDemo3 this#_0;

        this#_0 := @this: com.bytecodedl.benchmark.demo.TaintDemo3;

        name#_0 := @parameter0: java.lang.String;

        $stack5 = new java.lang.StringBuilder;

        specialinvoke $stack5.<java.lang.StringBuilder: void <init>()>();

        $stack6 = virtualinvoke $stack5.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>("select * from user where name=\'");

        $stack7 = virtualinvoke $stack6.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>(name#_0);

        $stack8 = virtualinvoke $stack7.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>("\'");

        sql0#_11 = virtualinvoke $stack8.<java.lang.StringBuilder: java.lang.String toString()>();

        sql1#_12 = sql0#_11;

        sql#_13 = virtualinvoke this#_0.<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Sanitize(java.lang.String)>(sql1#_12);

        virtualinvoke this#_0.<com.bytecodedl.benchmark.demo.TaintDemo3: void Sink(java.lang.String)>(sql#_13);

        return;
    }
```

也就是将字符串的拼接分成了下面几步

```

$stack5 = new java.lang.StringBuilder;

specialinvoke $stack5.<java.lang.StringBuilder: void <init>()>();

$stack6 = virtualinvoke $stack5.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>("select * from user where name=\'");

$stack7 = virtualinvoke $stack6.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>(name#_0);

$stack8 = virtualinvoke $stack7.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>("\'");

sql0#_11 = virtualinvoke $stack8.<java.lang.StringBuilder: java.lang.String toString()>();
```

转换成java就是

```
$stack5 = new StringBuilder();
$stack6 = $stack5.append("select * from user where name=\'");
$stack7 = $stack6.append(name#_0);
$stack8 = $stack7.append("\'");
$sql0#_11 = $stack8.toString();
```

name#_0 是污点变量，由于`$stack7 = $stack6.append(name#_0);` ，我门希望`$stack7`也是污点变量，所以这里应该添加个arg 向 ret的转移。

```
ptaint.ArgToRetTransfer("<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>", 0).
```

由于`$stack7`是污点变量，由于`$stack8 = $stack7.append("\'");` ，我们希望`$stack8`也是污点变量，所以这里应该添加个base 向 ret的转移。

```
ptaint.BaseToRetTransfer("<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>").
```

由于`$stack8`是污点变量，由于`$sql0#_11 = $stack8.toString();`，我们希望`$sql0#_11`也是污点变量，所以这里应该添加个base 向ret的转移。

```
ptaint.BaseToRetTransfer("<java.lang.StringBuilder: java.lang.String toString()>").
```

全部规则如下： [ptaint-example-1.dl](https://github.com/BytecodeDL/ByteCodeDL/blob/ptaint-upgrade/example/ptaint-example-1.dl)

```
#include "inputDeclaration.dl"
#include "utils.dl"
#include "ptaint.dl"

// 实例化ptaint
.init ptaint = PTaint

// 初始化上下文无关文法的入口函数
ptaint.cipt.Reachable("<com.bytecodedl.benchmark.demo.TaintDemo3: void main(java.lang.String[])>").

// 定义source函数
ptaint.SourceMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Source()>").
// 定义危险函数
ptaint.SinkMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: void Sink(java.lang.String)>", 0).
// 定义净化函数
ptaint.SanitizeMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Sanitize(java.lang.String)>").

// 定义污点转移函数
ptaint.BaseToRetTransfer("<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>").
ptaint.BaseToRetTransfer("<java.lang.StringBuilder: java.lang.String toString()>").

ptaint.ArgToRetTransfer("<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>", 0).




.decl TaintVar(var:Var)

TaintVar(var) :-
    ptaint.cipt.VarPointsTo(heap, var),
    ptaint.TaintHeap(_, heap).

.output TaintVar

.output ptaint.TaintHeap
.output ptaint.TransferTaint
.output ptaint.cipt.VarPointsTo
```

但是在分析[TaintDemo2](https://github.com/BytecodeDL/Benchmark/blob/main/src/main/java/com/bytecodedl/benchmark/demo/TaintDemo2.java)的时候，就会发现遇到问题了

```java
public class TaintDemo2 {
    public static void main(String[] args) {
        TaintDemo2 demo = new TaintDemo2();
        String name = demo.Source();
        demo.test1(name);
    }

    public void test1(String name){
        String sql = "select * from user where name='" + name + "'";
        sql = Sanitize(sql);
        Sink(sql);
    }

    public void Sink(String param){

    }

    public String Sanitize(String param){
        String ret = param.replace('\'', '`');
        return ret;
    }

    public String Source(){
        return "tainted name";
    }
}
```

对应的jimple为

```
public void test1(java.lang.String)
    {
        java.lang.StringBuilder $stack3, $stack4, $stack5, $stack6;
        java.lang.String name#_0, sql#_11;
        com.bytecodedl.benchmark.demo.TaintDemo2 this#_0;

        this#_0 := @this: com.bytecodedl.benchmark.demo.TaintDemo2;

        name#_0 := @parameter0: java.lang.String;

        $stack3 = new java.lang.StringBuilder;

        specialinvoke $stack3.<java.lang.StringBuilder: void <init>()>();

        $stack4 = virtualinvoke $stack3.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>("select * from user where name=\'");

        $stack5 = virtualinvoke $stack4.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>(name#_0);

        $stack6 = virtualinvoke $stack5.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>("\'");

        sql#_11 = virtualinvoke $stack6.<java.lang.StringBuilder: java.lang.String toString()>();

        sql#_11 = virtualinvoke this#_0.<com.bytecodedl.benchmark.demo.TaintDemo2: java.lang.String Sanitize(java.lang.String)>(sql#_11);

        virtualinvoke this#_0.<com.bytecodedl.benchmark.demo.TaintDemo2: void Sink(java.lang.String)>(sql#_11);

        return;
    }
```

将ptaint-example-1.dl中的TaintDemo3换成TaintDemo2之后后

```
<com.bytecodedl.benchmark.demo.TaintDemo2: void test1(java.lang.String)>/@parameter0
<com.bytecodedl.benchmark.demo.TaintDemo2: void Sink(java.lang.String)>/@parameter0
<com.bytecodedl.benchmark.demo.TaintDemo2: java.lang.String Sanitize(java.lang.String)>/ret#_21
<com.bytecodedl.benchmark.demo.TaintDemo2: void test1(java.lang.String)>/$stack3
<com.bytecodedl.benchmark.demo.TaintDemo2: void test1(java.lang.String)>/$stack4
<com.bytecodedl.benchmark.demo.TaintDemo2: void test1(java.lang.String)>/$stack5
<com.bytecodedl.benchmark.demo.TaintDemo2: void test1(java.lang.String)>/$stack6
<com.bytecodedl.benchmark.demo.TaintDemo2: void main(java.lang.String[])>/name#_6
<com.bytecodedl.benchmark.demo.TaintDemo2: void test1(java.lang.String)>/name#_0
<com.bytecodedl.benchmark.demo.TaintDemo2: void test1(java.lang.String)>/sql#_11
<com.bytecodedl.benchmark.demo.TaintDemo2: void Sink(java.lang.String)>/param#_0
```

会发现`sql#_11` 虽然经过了Sanitize处理，但是还是被标记为了污点变量，这是为什么呢？这是因为目前的分析都是流不敏感的，有没有什么办法解决呢？有在创建facts时加上`--ssa`参数

```
java8 -jar ~/code/soot-fact-generator/build/libs/soot-fact-generator.jar -i Benchmark-1.0-SNAPSHOT.jar --full -l /Library/Java/JavaVirtualMachines/jdk1.8.0_211.jdk/Contents/Home/jre/lib/rt.jar -d tainttest --allow-phantom --generate-jimple --ssa
```

加上这个参数之后会生成shimple，保证每个变量只会被赋值一次，就会变成下面这样

```shimple
public void test1(java.lang.String)
    {
        java.lang.StringBuilder $stack3, $stack4, $stack5, $stack6;
        java.lang.String name#_0, sql#_11, sql_$$A_1#_12;
        com.bytecodedl.benchmark.demo.TaintDemo2 this#_0;

        this#_0 := @this: com.bytecodedl.benchmark.demo.TaintDemo2;

        name#_0 := @parameter0: java.lang.String;

        $stack3 = new java.lang.StringBuilder;

        specialinvoke $stack3.<java.lang.StringBuilder: void <init>()>();

        $stack4 = virtualinvoke $stack3.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>("select * from user where name=\'");

        $stack5 = virtualinvoke $stack4.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>(name#_0);

        $stack6 = virtualinvoke $stack5.<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>("\'");

        sql#_11 = virtualinvoke $stack6.<java.lang.StringBuilder: java.lang.String toString()>();

        sql_$$A_1#_12 = virtualinvoke this#_0.<com.bytecodedl.benchmark.demo.TaintDemo2: java.lang.String Sanitize(java.lang.String)>(sql#_11);

        virtualinvoke this#_0.<com.bytecodedl.benchmark.demo.TaintDemo2: void Sink(java.lang.String)>(sql_$$A_1#_12);

        return;
    }
```

原本Sanitize返回的也是`sql#_11` 现在变成了`sql_$$A_1#_12`，这样就能区分原本两个同名变量在不同时刻的值了。

## Example 2

在实际的场景中，比如spring开发框架下，污点源不是来自source函数的返回值，可能来自函数的参数，这种情况该怎么处理呢？

我们还以TaintDemo3为例，我们以test1方法为分析的起点，形式参数name作为污点源。这时候我们需要模拟创建对象，包括test1@this 以及name参数

```
.decl EntryMethod(method:Method)

EntryMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>").


ptaint.cipt.Reachable(method) :-
    EntryMethod(method).

NormalHeap(heap, class),
ptaint.cipt.VarPointsTo(heap, this) :-
    ThisVar(method, this),
    EntryMethod(method),
    VarType(this, class),
    heap = cat("Mock::", class).

NormalHeap(heap, class),
ptaint.TaintHeap(insn, taintHeap),
ptaint.cipt.VarPointsTo(heap, param),
ptaint.cipt.VarPointsTo(taintHeap, param) :- 
    EntryMethod(method),
    FormalParam(_, method, param),
    VarType(param, class),
    heap = cat("Mock::", class),
    taintHeap = cat("NewTainted::", class),
    insn = "Init::Param".
```

其他部分同ptaint-example-1.dl，完整见[ptaint-example-2.dl](https://github.com/BytecodeDL/ByteCodeDL/blob/ptaint-upgrade/example/ptaint-example-2.dl)

```
#include "inputDeclaration.dl"
#include "utils.dl"
#include "ptaint.dl"

.init ptaint = PTaint

// 定义入口函数
.decl EntryMethod(method:Method)

EntryMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: void test1(java.lang.String)>").

// 初始化指针分析入口函数
ptaint.cipt.Reachable(method) :-
    EntryMethod(method).

// test1@this 指向虚拟创建的对象
NormalHeap(heap, class),
ptaint.cipt.VarPointsTo(heap, this) :-
    ThisVar(method, this),
    EntryMethod(method),
    VarType(this, class),
    heap = cat("Mock::", class).

// test1的参数，指向虚拟创建的污点对象和正常对象
NormalHeap(heap, class),
ptaint.TaintHeap(insn, taintHeap),
ptaint.cipt.VarPointsTo(heap, param),
ptaint.cipt.VarPointsTo(taintHeap, param) :- 
    EntryMethod(method),
    FormalParam(_, method, param),
    VarType(param, class),
    heap = cat("Mock::", class),
    taintHeap = cat("NewTainted::", class),
    insn = "Init::Param".


ptaint.SourceMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Source()>").
ptaint.SinkMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: void Sink(java.lang.String)>", 0).

ptaint.BaseToRetTransfer("<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>").
ptaint.BaseToRetTransfer("<java.lang.StringBuilder: java.lang.String toString()>").

ptaint.ArgToRetTransfer("<java.lang.StringBuilder: java.lang.StringBuilder append(java.lang.String)>", 0).

ptaint.SanitizeMethod("<com.bytecodedl.benchmark.demo.TaintDemo3: java.lang.String Sanitize(java.lang.String)>").


.decl TaintVar(var:Var)

TaintVar(var) :-
    ptaint.cipt.VarPointsTo(heap, var),
    ptaint.TaintHeap(_, heap).

.output TaintVar

.output ptaint.TaintHeap
.output ptaint.TransferTaint
.output ptaint.cipt.VarPointsTo
```

