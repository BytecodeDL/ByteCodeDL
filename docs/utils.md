# utils

## Class Hierachy

需要构建一个类型层次图，用于寻找某个类的子类、父类，或者用于判断两个类之间是否有继承关系。

从bytecode中能够解析出直接继承关系，其中extend对应的是DirectSuperclass ， implement对应的是DirectSuperinterface 。

创建个新的relation SubClass(subclass:Class, class:Class) 表示subclass是class的子类。
那么推理规则可以有：

1. 如果满足class x 和 y DirectSuperclass(x, y) 或者DirectSuperinterface(x, y) 那么 x , y 也一定满足 SubClass(x, y)
2. 还需要利用递推，判断非直接的层次关系。如果x 和 z 满足SubClass(x, z) 且 z 和 y 满足 DirectSuperclass(z, y) 或者DirectSuperinterface(z, y) 那么能够推导出 SubClass(x, y)

将上面的规则翻译成datalog如下：

```
SubClass(subclass, class) :- DirectSuperclass(subclass, class).
SubClass(subclass, class) :- DirectSuperinterface(subclass, class).
SubClass(subclass, class) :- 
    (
        DirectSuperclass(subclass, tmp);
        DirectSuperinterface(subclass, tmp)
    ),
    SubClass(tmp, class).
```
其中`;` 表示或，`,` 表示逻辑且

## Method Dispatch

针对VirtualMethodInvocation(insn:Insn, index:number, callee:Method, receiver:Var, caller:Method)调用，其中的callee并不是真实调用，需要根据receiver运行时类型rclass和callee的函数签名sig解析出实际调用的方法。

解析过程分为两种情况：

1. 如果rclass中有实现方法method.sig == sig 且method没有被abstract修饰，则直接返回method
2. 如果rclass没有对应的方法实现，则需要去父类中寻找相同函数签名的方法。

创建新的relation Dispatch(simplename:symbol, descriptor:symbol, class:Class, method:Method) simplename和descriptor 能拼凑成函数签名，class 表示要解析的类型，根据这三个元素能够找到对应的method。

可将上面的规则翻译成如下的datalog

```
Dispatch(simplename, descriptor, class, method) :-
    MethodInfo(method, simplename, _, class, _, descriptor, _),
    !MethodModifier("abstract", method).

Dispatch(simplename, descriptor, class, method) :-
    !MethodInfo(_, simplename, _, class, _, descriptor, _),
    DirectSuperclass(class, superclass),
    Dispatch(simplename, descriptor, superclass, method),
    !MethodModifier("abstract", method).
```
`_` 表示可以为任意值

这部分对应的代码见 `logic/utils.dl`