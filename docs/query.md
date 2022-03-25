# query

有了前面的铺垫，到这节，我们就可以通过ByteCodeDL ，快速筛选出一些class和method。

## 案例一

比如这位群友的需求
> 有没有啥东西，可以自动找jvm里符合某些要求的类

> 比如 我只想找有两个构造参数的类，其中一个传入的还得是数组参数

> 就这样找，有啥现成的工具么

前置知识，构造函数在jimple中的simplename为`<init>`，souffle中提供了一些[字符串相关的函数](https://souffle-lang.github.io/constraints)，如contains，match等

有了前置知识之后，我们可以将上述的问题翻译成下面的三个条件：

1. 方法是构造函数，simplename=`<init>`
2. 构造函数有两个构造参数, arity=2
3. 其中一个构造函数的的参数是数组，contains(`[]`, param)

将上述的条件，翻译成datalog如下
`query-example1.dl`
```
#include "inputDeclaration.dl"

.decl QueryResult(class:Class, method:Method)
.output QueryResult

QueryResult(class, method) :- 
    MethodInfo(method, simplename, param, class, _, _, arity),
    simplename = "<init>",
    contains("[]", param),
    arity = 2.
```
然后执行`souffle -F facts-dir -D output-dir query-example1.dl -j 8` 需要用soot-fact-generator.jar对要分析的jar提前创建好facts，可参考 https://github.com/BytecodeDL/soot-fact-generator

结果示例

```
java.math.BigInteger    <java.math.BigInteger: void <init>(int,byte[])>
java.math.BigInteger    <java.math.BigInteger: void <init>(int,int[])>
java.math.BigInteger    <java.math.BigInteger: void <init>(int[],int)>
java.math.BigInteger    <java.math.BigInteger: void <init>(byte[],int)>
```

## 案例二

待补充