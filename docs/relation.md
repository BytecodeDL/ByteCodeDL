# relation

## Subtypes

```
// 指令 可以定位出动作（比如call,load,sotre,assign）发生时的代码位置
.type Insn <: symbol
// 变量 
.type Var <: symbol
// 堆 也可以理解为内存中的对象
.type Heap <: symbol
// 字段
.type Field <: symbol
// 方法
.type Method <: symbol
// 类
.type Class <: symbol
```

## Class

- 类名
  - 对应的就是Class这个类型，是一个字符串
- 类的修饰符号
  - `ClassModifier(mod:symbol, class:Class)`
  - 表示`class`存在`mod`这种修饰符
  - `mod`可能是public，private，static等修饰符
  - `class`是形如java.lang.Object这样的类名
- 是否是非接口类
  - `ClassType(class:Class)`
  - 表示`class`是非接口类
- 是否是Interface
  - `InterfaceType(interface:Class)`
  - 表示`interface`是接口类
- 是出现在待分析的应用中还是在第三方库中
  - `ApplicationClass(class:Class)`
    - 表示`class`是应用类
- 直接继承了什么类
  - `DirectSuperclass(child:Class, parent:Class)`
    - 表示`child`直接extend了`parnet`
- 直接实现了什么接口
  - `DirectSuperinterface(child:Class, parent:Class)`
    - 表示`child`直接implement了`parent`

对于方法中有哪些方法和字段，会通过Method和Field相关信息进行反查。

## Method

- 方法的基本信息
  - `MethodInfo(method:Method, simplename:symbol, param:symbol, class:Class, return:Class, jvmDescriptor:symbol, arity:number)`
    - `method` 完整的方法名，如：
    - `simplename` 简单的方法名
    - `param` 参数类型
    - `class` 在哪个class声明的
    - `return` 返回类型
    - `jvmDescriptor` jvm描述符
    - `arity` 参数个数
- 方法的修饰符
  - `MethodModifier(mod:symbol, method:Method)`
- 方法对应的this变量
  - `ThisVar(method:Method, this:Var)`
- 方法的形式参数
  - `FormalParam(n:number, method:Method, param:Var)`
  - method的第n个形式参数为param变量
- 方法的返回值
  - `Return(insn:Insn, index:number, var:Var, method:Method)`
  - method的函数内返回的变量为var
  
Java中方法调用，可以分为三类

- SpecialMethodInvocation
  - 包括private，super，以及构造函数
  - `SpecialMethodInvocation(insn:Insn, index:number, callee:Method, receiver:Var, caller:Method)`
  - 在caller中，通过指令insn，调用了receiver.callee()
- StaticMethodInvocation
  - 静态方法调用
  - `StaticMethodInvocation(insn:Insn, index:number, callee:Method, caller:Method)`
  - 在caller中，通过指令insn调用了静态方法callee
- VirtualMethodInvocation
  - 虚拟方法调用
  - `VirtualMethodInvocation(insn:Insn, index:number, callee:Method, receiver:Var, caller:Method)`
  - 在caller中，通过指令insn，调用了receiver.callee()

SpecialMethodInvocation和StaticMethodInvocation在编译时就能确定被调方法，但是VirtualMethodInvocation由于多态的原因，只有在运行时根据receiver变量的实际类型才能确定具体的被调方法。

以及调用时涉及到的
- 实际参数
  - `ActualParam(n:number, insn:Insn, var:Var)`
  - 在调用insn发生时，实际传入的第n个参数为var
- 函数调用后的返回值赋值
  - `AssignReturnValue(insn:Insn, var:Var)`
  - 在调用insn返回时，将返回结果赋值给var变量

## Field
- 字段的基本信息
  - `FieldInfo(field:Field, declaringType:Class, simplename:symbol, type:Class)`
    - `field` 完整的名称
    - `declaringType` 所属的类
    - `simplename` 字段名
    - `type` 类型
- 字段的修饰符
  - `FieldModifier(modifier:symbol, field:Field)`
- 读取字段，也就是load
  - `LoadInstanceField(insn:Insn, index:number, var:Var, base:Var, field:Field, inMethod:Method)`
  - 表示在inMethod方法中，var = base.field
- 写入字段，也就是store
  - `StoreInstanceField(insn:Insn, index:number, var:Var, base:Var, field:Field, inMethod:Method)`
  - 表示在inMethod中，base.field = var

## Array

- 从数组中读
  - `LoadArrayIndex(insn:Insn, index:number, to:Var, array:Var, inMethod:Method)`
  - 表示在inMethod中，to = array[]
- 往数组中写
  - `StoreArrayIndex(insn:Insn, index:number, from:Var, array:Var, inMethod:Method)`
  - 表示在inMethod中，array[] = from
- 数组中的元素类型
  - `ComponentType(arrayType:Class, componentType:Class)`
  - 表示arrayType中元素的类型为componentType

## Others

- 变量的声明类型
  - `VarType(var:Var, class:Class)`
  - 表示变量var的声明类型为class
- 局部变量赋值
  - `AssignLocal(insn:Insn, index:number, from:Var, to:Var, inMethod: Method)`
  - 表示在inMethod中，to = from
- 类型转换
  - `AssignCast(insn:Insn, index:number, from:Var, to:Var, type:Class, inMethod:Method)`
  - 表示在inMethod中，to = (type) from
- 创建对象赋值
  - `AssignHeapAllocation(insn:Insn, index:number, heap:Heap, var:Var, inMethod:Method, linenumber:number)`
  - 表示在inMethod中，var = new heap()
- 堆中对象对应的类型
  - `NormalHeap(value:Heap, class:Class)`
  - 表示heap的类型为class